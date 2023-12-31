;+
; NAME: 
;  mkbias
; PURPOSE: 
;  Collect and combine CCD bias frames into a superbias frame
; DESCRIPTION:
;
;  The files are assumed to be named as 'root'NNN where 'root' is the
;  root of the file name that you supply and NNN is a three digit number.
;  If your file name has an imbedded '.' then add it to the root.
;
;  The specified range of files are all read in from FITS files.  Then each
;  image has the overscan mean subtracted (if desired), cropped (as indicated).
;  These images are then averaged.  The averaging is done with AVGCLIP.PRO
;  which does a robust average of the image stack so that cosmic rays or
;  other transient image defects are eliminated.
;
;  When done, the resulting bias image is returned to the caller and the image
;  is saved to a FITS file with the specified output filename.
;
; CATEGORY:
;  CCD data processing
; CALLING SEQUENCE:
;  mkbias,root,outsuf,start,nframes,bias,good
; INPUTS:
;  root    - Root of the file name (you must include . in the name).
;  outsuf  - The suffix of the final output file.
;  start   - First frame number to read (integer or long).
;               Start can also be a vector of explicit frame numbers to load.
;               In this case, nframes need not be specified and in fact will
;               be ignored.
;               Additionally, start can also be a string array containing the
;               file names of all files to be read.  In this case, set nframes
;               to 0 or someother innocuous integer.  Exclude is treated
;               differently.  In this case, exclude is a vector of the same
;               length as start and is 0 if the file is to be used, 1 if not.
;  nframes - Number of frames to average.
; OPTIONAL INPUT PARAMETERS:
; KEYWORD INPUT PARAMETERS:
;
;   CROP     = region of original image to save, default=no cropping.
;                 [x1,x2,y1,y2]
;
;  DIGITS   - Optional input to indicate how many digits are in the suffix
;                of the file name.  The default for this input is 0.  In this
;                case it uses the ROBOCCD scheme which is three digits up
;                to 999.  After that, it gets complicated, see numtoflist
;                for more information.  If you were to give it a value of
;                three you would get the same behavior except you won't get
;                the ROBOCDD extension.  This is really designed for when
;                you have four or more digits.
;
;   DDIR     = Directory to look for raw data in.  Default = ''
;
;   EXCLUDE - Optional vector of image numbers that should be excluded from
;                average.  Default is to include all frames.
;
;   OVERSCAN = column overscan region to use for frame bias level,
;                 default=no overscan subtraction.
;
;   RDNOISE  - Read noise of CCD [in DN], default=10
;   MINGOOD - Minimum number of frames required to be considered a good
;                bias.  (Default=15)
;   MAXBAD  - Maximum number of bad rows allowed per image (see gradebias)
;                Default is inherited from gradebias
;
; OUTPUTS:
;  bias - Final robust averaged/cropped bias image.
;  good  - Flag, true if this collection of bias images is considered to be
;            good.
; KEYWORD OUTPUT PARAMETERS:
; COMMON BLOCKS:
; SIDE EFFECTS:
; RESTRICTIONS:
; PROCEDURE:
; MODIFICATION HISTORY:
;  95/03/09 - Initial crude version written, Marc W. Buie, Lowell Observatory
;  95/06/13, MWB, added OVERSCAN and CROP keywords
;  95/11/22, MWB, add EXCLUDE keyword
;  2000/02/02, MWB, rewrite to add support for multigroup FITS files.
;  2000/02/28, MWB, added support for frame numbers > 999.
;  2001/02/23, MWB, added option to provide input file list.
;  2001/04/28, MWB, added DDIR keyword.
;  2005/01/04, MWB, changed so .fits tag can come and go in file names.
;  2006/07/14, MWB, added RDNOISE keyword
;  2006/10/23, MWB, fixed output header keyword problem (remove BSCALE/BZERO)
;  2007/06/20, MWB, fixed minor bug with image list for start
;  2015/04/26, MWB, added tool to provide a quality grade for set of images
;  2015/05/03, MWB, added much more sophisticated logic to build the superbias.
;                      Automatic filtering of bad frames is done internally.
;  2016/05/29, MWB, added DIGITS keyword
;-
pro mkbias,root,outsuf,start,nframes,bias,good, $
       DDIR=ddir,OVERSCAN=in_overscan,CROP=in_crop,EXCLUDE=exclude, $
       RDNOISE=rdnoise,MINGOOD=mingood,MAXBAD=maxbad,DIGITS=digits

   self='MKBIAS: '
   if badpar(root,   7,       0,caller=self+'(root) '   ) then return
   if badpar(outsuf, 7,       0,caller=self+'(outsuf) ' ) then return
   if badpar(start,  [2,3,7], [0,1],caller=self+'(start) ', $
                rank=start_rank,type=start_type  ) then return

   if badpar(exclude,[0,2,3], [0,1],caller=self+'(exclude) ',default=-1) then return

   if badpar(in_overscan,[0,2,3],[1,2],caller=self+'(overscan) ',rank=o_rank) then return
   if badpar(in_crop,    [0,2,3],[1,2],caller=self+'(crop) ',rank=c_rank) then return

   if badpar(ddir,[0,7],0,caller=self+'(DDIR) ',default='') then return
   if ddir ne '' then ddir=addslash(ddir)
   if badpar(rdnoise,[0,2,3,4,5],0,caller=self+'(RDNOISE) ',default=10.) then return
   if badpar(mingood,[0,2,3],0,caller=self+'(MINGOOD) ',default=15) then return
   if badpar(digits,[0,1,2,3],0,CALLER=self+'(DIGITS) ', $
                              default=0) then return

   ; Check to see if it's a sequential list or random list.
   if start_rank eq 0 then begin
      frames=start+indgen(nframes)
      if badpar(nframes,[2,3],   0,caller=self+'(nframes) ') then return
   endif else if start_type ne 7 then begin
      frames=start
      nframes=n_elements(frames)
   endif

   if start_type eq 7 then begin
      fname=start
      nframes=n_elements(fname)
      if exclude[0] eq -1 then $
         bad=intarr(nframes) $
      else $
         bad=exclude
   endif else begin
      ; Setup the file name format string
      if digits eq 0 then begin
         digits = fix(ceil(alog10(max(frames)+1))) > 3
      endif
      dig = strn(digits)
      fnfmt = '(i'+dig+'.'+dig+')'
      fname=root+string(frames,format=fnfmt)
      bad=intarr(nframes)
      ; Apply the exclusion criteria to the frames list.  Then, find out how
      ;   many frames are being collected and make sure there is something to do.
      for i=0,nframes-1 do begin
         z=where(frames[i] eq exclude,count)
         if count ne 0 then bad[i]=1
      endfor
   endelse

   zg=where(bad eq 0,countg)
   if countg eq 0 then $
      message,'Error ** you have excluded all frames, nothing to do.'

   ; Make the output file name
   outfile = root+outsuf

   ; Check header of image to see if it is a multi-extension image.
   if exists(ddir+fname[0]+'.fits') then ft='.fits' else ft=''
   hdr=headfits(ddir+fname[0]+ft)
   numext=sxpar(hdr,'NEXTEND')

   ; Setup the overscan/crop control values
   if numext eq 0 then begin
      extend=0
      numext=1
      if o_rank eq 0 then begin
         do_overscan=0
      endif else begin
         do_overscan=1
         overscan = in_overscan
      endelse
      if c_rank eq 0 then begin
         do_crop=0
      endif else begin
         do_crop=1
         crop = in_crop
      endelse
   endif else begin
      extend=1
      if o_rank eq 0 then begin
         do_overscan=0
      endif else if o_rank eq 1 then begin
         do_overscan=1
         overscan = rebin(in_overscan,n_elements(overscan),numext)
      endif else begin
         do_overscan=1
         overscan = in_overscan
      endelse
      if c_rank eq 0 then begin
         do_crop=0
      endif else if o_rank eq 1 then begin
         do_crop=1
         crop = rebin(in_crop,n_elements(crop),numext)
      endif else begin
         do_crop=1
         crop = in_crop
      endelse
   endelse

   ; If it's multi-extension, then the header we've just read is special
   ;   And must be written back out to start the output file.
   if extend then $
      writefits,outfile,0,hdr

   ; Main loop over extension, done just once on "normal" frames
   for ix=1,numext do begin
      ix0=ix-1

      print,'Load ',strn(nframes),' frames.'

      ; See if we need to append the .fits tag to the file name.
      if exists(ddir+fname[zg[0]]+'.fits') then ft='.fits' else ft=''
      if not exists(ddir+fname[zg[0]]+ft) then begin
         print,self,ddir+fname[zg[0]]+ft,' not found, unable to continue.'
         return
      endif

      ; Load all the frames considered to be good at the start.
      j=0
      for i=0,nframes-1 do begin

         if not bad[i] then begin

            ; See if we need to append the .fits tag to the file name.
            if exists(ddir+fname[i]+'.fits') then ft='.fits' else ft=''

            ; read in the new image, the dummy line before readfits is to dump
            ;   the storage for the array before it's used again.
            image = 0
            if i eq 0 then begin
               if extend then $
                  image = float(readfits(ddir+fname[i]+ft,hdr,exten_no=ix,/silent)) $
               else $
                  image = float(readfits(ddir+fname[i]+ft,hdr,/silent))
            endif else begin
               if extend then $
                  image = float(readfits(ddir+fname[i]+ft,exten_no=ix,/silent)) $
               else $
                  image = float(readfits(ddir+fname[i]+ft,/silent))
            endelse

            if do_overscan and do_crop then begin
               image = colbias(image,overscan[0,ix0],overscan[1,ix0], $
                        crop[0,ix0],crop[1,ix0],crop[2,ix0],crop[3,ix0], $
                        biasval=biasval,noiseval=noiseval)
               if extend then $
                  print,fname[i],' overscan value is ',biasval, $
                                 ' +/- ',noiseval,' extension ',strn(ix) $
               else $
                  print,fname[i],' overscan value is ',biasval,' +/- ',noiseval

            endif else if do_overscan then begin
               image = colbias(image,overscan[0,ix0],overscan[1,ix0], $
                          biasval=biasval,noiseval=noiseval)
               if extend then $
                  print,fname[i],' overscan value is ',biasval, $
                                 ' +/- ',noiseval,' extension ',strn(ix) $
               else $
                  print,fname[i],' overscan value is ',biasval,' +/- ',noiseval

            endif else if do_crop then begin
               image = image[crop[0,ix0]:crop[1,ix0],crop[2,ix0]:crop[3,ix0]]
               if extend then $
                  print,fname[i],' extension ',strn(ix) $
               else $
                  print,fname[i]

            endif else begin
               if extend then $
                  print,fname[i],' extension ',strn(ix) $
               else $
                  print,fname[i]

            endelse

            if j eq 0 then begin
               sz=size(image,/dim)
               cube=fltarr(sz[0],sz[1],countg,/nozero)
            endif

            cube[*,*,j]=image
            j=j+1
         endif

      endfor

      nf=j
      repeat begin
         bias=0
         tmpcube=cube
	 print,'Stack average ',strn(nf),' images.'
         avgclip,tmpcube,bias,noisemin=rdnoise
         gradebias,cube,bias,grade,maxbad=maxbad,filetest=filetest
	 print,filetest
         if grade gt 0 then begin
            z=where(filetest le maxbad,count)
            if count gt 0 then cube=cube[*,*,z]
            nf=count
         endif
      endrep until grade eq 0 or nf lt mingood

      good = grade eq 0 and nf ge mingood
      print,'Good=',good

      sxaddpar,hdr,'NAXIS1',sz[0]
      sxaddpar,hdr,'NAXIS2',sz[1]
      sxaddpar,hdr,'BITPIX',-32
      sxdelpar,hdr,'BSCALE'
      sxdelpar,hdr,'BZERO'
      if extend then begin
         print,outfile,',  writing extension ',strn(ix)
         writefits,outfile,bias,hdr,/append
      endif else begin
         print,'Saving final bias frame to ',outfile
         writefits,outfile,bias,hdr
      endelse

   endfor

end
