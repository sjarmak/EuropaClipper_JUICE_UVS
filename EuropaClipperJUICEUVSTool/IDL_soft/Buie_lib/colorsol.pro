;+
; NAME: 
;  colorsol
; PURPOSE: 
;  Find the standard color of an unknown star.
; DESCRIPTION:
; CATEGORY:
;  Photometry
; CALLING SEQUENCE:
;  colorsol, stand,fil,jd,am,serial,inst,instsig, $
;             color1,color2,trans1,trsig1,jdref1,trans2,trsig2,jdref2, $
;             object,std1,stdsig1,std2,stdsig2,stdcol,stdcolsig
;
; INPUTS:
;  stand    - String array of standard names.  (See coord.)
;  fil      - String array of filter names for observations.
;  jd       - Double precision array of the JD of observations.
;  am       - Floating point array of the airmass of observations.
;  serial   - Serial number of observation.
;  inst     - Instrumental magnitude
;  instsig  - Uncertainty of the instrumental magnitude
;  color1   - Name of filter for the first color.
;  color2   - Name of filter for the second color.
;  trans1   - Transformation coefficients (vector) for first filter.
;                trans1(0) = principal extinction coefficient
;                trans1(1) = second order extinction coefficient
;                trans1(2) = color term
;                trans1(3) = zero-point
;                trans1(4) = time-dependent extinction term
;     if provided:
;                trans1[5] = (f)  airmass squared term
;                trans1[6] = (g)  color squared term
;  trsig1   - Uncertainty on the transformation coefficients (vector).
;  jdref1   - Time reference point for extinction (first filter).
;  trans2   - Transformation coefficients (vector) for second filter.
;  trsig2   - Transformation coefficients (vector) for second filter.
;  jdref2   - Time reference point for extinction (second filter).
;
;     tran and transig can either be 5-element vectors or 5xN element arrays.
;                must match the number of transformation sets provided
;  
; OPTIONAL INPUT PARAMETERS:
; KEYWORD INPUT PARAMETERS:
;  BADFLAGS - Array of flags that mark data bad (if true).
;  DATABASE - Name of MYSQL database to save reduced observations.
;                 The default is 'phot'. 
;  DB       - Flag, if set, reduced observations will be saved to database.
;  DVERBOSE-  Code for dbphot and other routines for db transaction verbosity.
;  FILTER1 -  Name of the first filter
;  FILTER2 -  Name of the second filter
;  FULL    -  Flag, if true, will enable the complete printout, otherwise
;                just the final summary for each object will be printed.
;  NOEDIT  -  If set, suppresses the interactive editing of the star data.
;  NOPRINT -  Flag, if true, will inhibit the summary printout to the screen.
;  PATH    -  If SAVE is set, this points to the directory where
;                results should be written.
;  REFAM - Optional air mass reference for the transformation.  The default
;             is an airmass=0.
;  REFCOLOR - Optional color reference for the color term transformation.
;                 This term is normally C * (B-V) or some other standard
;                 color.  As written, the reference color is zero and this
;                 is the default.  By providing this value you are using
;                     C * ( (B-V) - REFCOLOR ) for the term instead.
;  REFID -    String uniquely identifying observing run. This is used in 
;               updating the data table with the reduced observations in the 
;               database. It must be specified if DB is used.
;  SAVE    -  Flag, if true, will save the final photometry to an output file,
;                and, if DB selected, to database.
;  TABLE    - Name of table in MYSQL database to save reduced observations.
;                The default is 'data'. 
;  TIDX     - Indexing array, same length as the input observations.  This
;                keyword is ignored if the input transformation vectors is
;                a simple 5-element vector.  If the transformation is provided
;                as a 5xN array then this keyword is REQUIRED.
;             Each element gives the index into the set of transformation
;             values.  This allows combining data that have different
;             photometric transformation coefficients.
;
;  RA       - Measured right ascension of object in that observation.  Do not
;                use a catalog or ephemeris position, only real astrometry.
;                default=no position, only needed for saving to database
;  DEC      - Measured declination of object in that observation.  Do not
;                use a catalog or ephemeris position, only real astrometry.
;                default=no position, only needed for saving to database
; OUTPUTS:
;  object    - Name(s) of program object.
;   std1      - Standard magnitude of first filter.
;   stdsig1   - Uncertainty of the standard magnitude.
;   std2      - Standard magnitude of second filter.
;   stdsig2   - Uncertainty of the standard magnitude.
;   stdcol    - Standard color, first filter - second filter.
;   stdcolsig - Uncertainty of the standard color.
; KEYWORD OUTPUT PARAMETERS:
; COMMON BLOCKS:
; SIDE EFFECTS:
; RESTRICTIONS:
; Data for objects completely removed from colorsol reduction due to bad
; flags will not be removed from the hard files.
; PROCEDURE:
; MODIFICATION HISTORY:
;  Written by Marc W. Buie, Lowell Observatory
;  96/11/25, MWB, added PATH, SAVE, FILTER1, and FILTER2 keywords
;  97/02/11, MWB, added new transformation support (k(t))
;  97/02/25, MWB, added NOEDIT keyword and actions
; 2006/08/14, Peter L. Collins, Lowell Observatory
;             add database support (save reduced observations) and header cleanup.
; 2006/09/26, PLC, add INSTRUMENT keyword to pass through to dbphot.
; 2006/10/17, PLC, modify effect of SAVE flag to control db update also.
; 2006/12/07, PLC, replace instrument and rundate keywords by REFID and
;                   change calls to dbphot.
; 2006/12/10, PLC, fix bug involving TABLE not passing through to dbphot.
; 2006/12/28, PLC, add DVERBOSE keyword, add 1 additional entry to 
;                  the db data table per object for the solved color value, and
;                  fix handling of hard files for refid length.
; 2007/01/04, PLC, further fix for the hard files.
; 2007/02/05, PLC, fix for adding color name to database entries. Improve logic
;                  for bad flags and data scrubbing.
; 2013/06/02, MWB, updated to support different transformation coefficients
;                  for the input data.
; 2013/06/18, MWB, added RA, DEC keywords
; 2013/06/25, MWB, added REFCOLOR keyword
; 2014/03/05, MWB, added REFAM keyword, added full set of second order terms
; 2014/05/20, MWB, fixed bugs with array input for trans1 & trans2
; 2015/10/10, MWB, fixed bug with color/colorsig indexing during solution
;-
pro colorsol, stand,fil,jd,am,serial,inst,instsig,color1,color2, $
              in_trans1,in_trsig1,jdref1,in_trans2,in_trsig2,jdref2, $
              object,std1,stdsig1,std2,stdsig2,stdcol,stdcolsig, $
              FULL = full, NOPRINT = noprint, PATH = in_path, $
              SAVE = save,FILTER1 = filter1,FILTER2 = filter2,REFID=refid, $
              BADFLAGS=bad, NOEDIT=noedit,DB=db,DATABASE=database, $
              TABLE=table,DVERBOSE=dverbose,TIDX=tidx,RA=ra,DEC=dec, $
              REFAM=refam,REFCOLOR=refcolor
   
   if n_params() eq 0 then begin
      print,'colorsol, stand,fil,am,serial,inst,instsig,'
      print,'   color1,color2,trans1,trsig1,jdref1,trans2,trsig2,jdref2,'
      print,'   object,std1,stdsig1,std2,stdsig2,stdcol,stdcolsig,'
      print,'   [FULL, NOPRINT]'
   endif

   self = 'COLORSOL: '

   if badpar(stand, 7,      1,caller=self+'(stand) ',  npts=n1) then return
   if badpar(fil,   7,      1,caller=self+'(fil) ',    npts=n2) then return
   if badpar(jd,    5,      1,caller=self+'(jd) ',     npts=n13) then return
   if badpar(am,    [4,5],  1,caller=self+'(am) ',     npts=n3) then return
   if badpar(serial,[1,2,3],1,caller=self+'(serial) ', npts=n4) then return
   if badpar(inst,  [4,5],  1,caller=self+'(inst) ',   npts=n5) then return
   if badpar(instsig,[4,5], 1,caller=self+'(instsig) ',npts=n6) then return
   if badpar(color1,7,      0,caller=self+'(color1) '         ) then return
   if badpar(color2,7,      0,caller=self+'(color2) '         ) then return
   if badpar(in_trans1,[4,5],[1,2],caller=self+'(trans1) ', $
                                npts=n9,rank=trank1) then return
   if badpar(in_trsig1,[4,5],[1,2],caller=self+'(transig1) ', $
                                npts=n10,rank=trank2) then return
   if badpar(jdref1,5,  [0,1],caller=self+'(jdref1) ',npts=n9a) then return
   if badpar(in_trans2,[4,5],[1,2],caller=self+'(trans2) ', $
                                npts=n11,rank=trank3) then return
   if badpar(in_trsig2,[4,5],[1,2],caller=self+'(transig2) ', $
                                npts=n12,rank=trank4) then return
   if badpar(jdref2,5,  [0,1],caller=self+'(jdref2) ',npts=n11a) then return

   if badpar(tidx,[0,2,3],[0,1],caller=self+'(TIDX) ', $
                              default=0,npts=n14) then return

   if badpar(in_path,[0,7], 0,caller=self+'(PATH) ',   default='./') then return
   if badpar(refid,[0,7], 0,caller=self+'(REFID) ',default='') then return
   if badpar(filter1,[0,7], 0,caller=self+'(FILTER1) ',default=color1) then return
   if badpar(filter2,[0,7], 0,caller=self+'(FILTER2) ',default=color2) then return
   if badpar(bad,[0,1,2,3],[0,1],caller=self+'(BADFLAGS) ', $
                                default=intarr(n1)) then return
   if badpar(noedit,[0,1,2,3],0,caller=self+'(NOEDIT) ',default=0) then return
   if badpar(save,[0,1,2,3],  0,caller=self+'(SAVE) ',default=0) then return
   if badpar(db,[0,1,2,3],    0,caller=self+'(DB) ', default=0) then return
   if badpar(database,[0,7],  0,caller=self+'(DATABASE) ', $
                                default='phot') then return
   if badpar(table,[0,7],     0,caller=self+'(TABLE) ', $
                                default='data') then return
   if badpar(dverbose,[0,1,2,3],  0,caller=self+'(DVERBOSE) ', $
                                   default=0) then return
   if badpar(refcolor,[0,2,3,4,5],  1,caller=self+'(REFCOLOR) ', $
                                   default=[0.0,0.0]) then return
   if badpar(refam,[0,2,3,4,5],1,caller=self+'(REFAM) ', $
                                   default=[0.0,0.0]) then return

   if badpar(ra,[0,4,5],1,caller=self+'(RA) ',type=ratype) then return
   if badpar(dec,[0,4,5],1,caller=self+'(DEC) ',type=dectype) then return
   if badpar(noprint,[0,1,2,3],0,caller=self+'(NOPRINT) ',default=0) then return

   savepos = ratype ne 0 and dectype ne 0

   path=addslash(in_path)

   edit = not noedit and !d.name ne 'PS'

   alln=[n1,n2,n3,n4,n5,n6,n13]
   if min(alln) ne max(alln) then begin
      print,self+' Error!  stand,fil,jd,am,serial,mag,err must be the same length.'
      return
   endif

   allr=[trank1,trank2,trank3,trank4]
   if min(allr) ne max(allr) then begin
      help,trank1,trank2,trank3,trank4
      print,self+'Error!  trans arrays must have the same rank.'
      return
   endif

   if trank1 eq 1 then begin

      if n9 eq 5 then begin
         trans1 = [in_trans1,0.,0.]
      endif else if n9 eq 7 then begin
         trans1 = in_trans1
      endif else begin
         print,self+' Error!  trans1 must be a 5 or 7 element vector.'
         return
      endelse

      if n9 eq n10 then begin
         if n9 eq 5 then $
            trsig1 = [in_trsig1,0.,0.] $
         else $
            trsig1 = in_trsig1
      endif else begin
         print,self+' Error!  trsig1 must be the same length as trans1.'
         return
      endelse

      if n11 eq 5 then begin
         trans2 = [in_trans2,0.,0.]
      endif else if n11 eq 7 then begin
         trans2 = in_trans2
      endif else begin
         print,self+' Error!  trans2 must be a 5 or 7 element vector.'
         return
      endelse

      if n11 eq n12 then begin
         if n11 eq 5 then $
            trsig2 = [in_trsig2,0.,0.] $
         else $
            trsig2 = in_trsig2
      endif else begin
         print,self+' Error!  trsig2 must be the same length as trans2.'
         return
      endelse

      if keyword_set(save) and refid eq '' then begin
         print,self+'Error!  REFID must be set if using /SAVE.'
         return
      endif
      if n9a ne 1 or n11a ne 1 then begin
         help,jdref1,jdref2
         print,self+'Error!  jdref must be a scalar with this tran array.'
         return
      endif
      tidx=replicate(0,n1)
   endif else begin

      if n9 ne n10 then begin
         help,in_trans1,in_trsig1
         print,self+'Error!  trans1 and transig1 must be the same length'
         return
      endif
      sz=size(in_trans1,/dimen)
      if sz[0] eq 5 then begin
         trans1 = [in_trans1,replicate(0.,2,sz[1])]
         trsig1 = [in_trsig1,replicate(0.,2,sz[1])]
      endif else if sz[0] eq 7 then begin
         trans1 = in_trans1
         trsig1 = in_trsig1
      endif else begin
         print,self+'Error!  trans1 array must be 5xN or 7xN'
         return
      endelse
      if n9a ne sz[1] then begin
         help,in_trans1,jdref1
         print,self+'Error!  jdref1 length does not match size of trans1 array'
         return
      endif

      if n11 ne n12 then begin
         print,self+'Error!  trans2 and transig2 must be the same length'
         return
      endif
      sz=size(in_trans2,/dimen)
      if sz[0] eq 5 then begin
         trans2 = [in_trans2,replicate(0.,2,sz[1])]
         trsig2 = [in_trsig2,replicate(0.,2,sz[1])]
      endif else if sz[0] eq 7 then begin
         trans2 = in_trans2
         trsig2 = in_trsig2
      endif else begin
         print,self+'Error!  trans2 array must be 5xN or 7xN'
         return
      endelse
      if n11a ne sz[1] then begin
         help,in_trans2,jdref2
         print,self+'Error!  jdref2 length does not match size of trans2 array'
         return
      endif

      if n14 ne n5 then begin
         help,inst,tidx
         print,self+'Error!  TIDX length does not match size of input data'
         return
      endif

   endelse

   colorname = filter1+'-'+filter2
   ; To start, guess that the color of all objects are REFCOLOR
   color = replicate(refcolor[0],n_elements(inst))
   colorsig = replicate(refcolor[0],n_elements(inst))
   blanks='                   '
   countchange = 0

again:

   ; Select out all the measurements for the requested filters: STARS ONLY!.
   ; z1,z2 are ones that will be used, z1tot,z2tot could be used except 
   ; for bad flags.
   z1=where(fil eq color1 and bad eq 0,count1)
   z1tot=where(fil eq color1, count1tot)
   z2=where(fil eq color2 and bad eq 0,count2)
   z2tot=where(fil eq color2, count2tot)

   ; Contruct a list of names.  Those names that have more than one serial
   ;   will have the serial number appended to the name.
   allobj = stand
   objlist=allobj[uniq(allobj,sort(allobj))]
   for i=0,n_elements(objlist)-1 do begin
      z=where(allobj eq objlist[i])
      if min(serial[z]) ne max(serial[z]) then $
         allobj[z]=allobj[z]+':'+string(serial[z],form='(i4.4)')
   endfor

   ; Find all objects that are measured in both filters with good observations.
   if count1 gt 0 and count2 gt 0 then  $
      intrsect,allobj[z1],allobj[z2],object,nall $
   else nall = 0
   ; Find all objects that are measured in both filters with any observations.
   if (count1tot) gt 0 and (count2tot) gt 0 then $
      intrsect,allobj[z1tot],allobj[z2tot],objecttot,nalltot $
   else nalltot = 0

   if nall gt 0 then objlist=object[uniq(object,sort(object))]
   if nalltot gt 0 then objlisttot=objecttot[uniq(objecttot,sort(objecttot))]

   if countchange eq 0 then begin  ; means first pass thru 'again' loop.
      ; scrub all previous db entries for objlisttot.
      if nalltot gt 0 and db and keyword_set(save) then begin
         ; scrub obj and single filter combination from db data table. 
         ; Concatenate ; arrays to do the two filters, and all objects, 
         ; at once. Eg, all the 'B'  and 'V' rows.
         nobjtot = n_elements(objlisttot)
         dummyjd = dblarr(2*nobjtot)
         dummymag = dummyjd
         dummymagerr = dummyjd
         filtpair = [ replicate(filter1,nobjtot),replicate(filter2,nobjtot)]
         dbphot,refid, [objlisttot, objlisttot], dummyjd, filtpair, $
                dummymag, dummymagerr, TABLE=table,/CLEANBYOBJFIL, $
                /CLEANONLY, NREMOV=nr , VERBOSE=dverbose, COLOR=colorname
         if nr gt 0 then begin 
            print, nr, ' observations in ' ,filter1, ', ', filter2,  $
                   ', and' , colorname, ' were removed.'
            print, ' objects include ', objlisttot
         endif
         ; scrub obj and (color) filter combination from db data table.
         ; Eg, the 'B-V' rows.
         dummyjd = dummyjd[0:nobjtot-1]
         dummymag = dummyjd
         dummymagerr = dummyjd
         filtcolor = replicate(colorname, nobjtot)
         dbphot,refid, objlisttot, dummyjd, filtcolor, dummymag, dummymagerr, $
                TABLE=table,/CLEANBYOBJFIL, /CLEANONLY, NREMOV=nr , $
                VERBOSE=dverbose
         if nr gt 0 then begin 
            print, nr, ' observations in ' , colorname,  ' were removed.'
            print, ' objects include ', objlisttot
         endif

      endif
   endif

   if nall eq 0 then begin
      oldbad = bad
      if edit and (count1tot - count1) gt 0 and nalltot gt 0 then begin
         print, 'There are no stars available in both filters.'        
         print, 'However there are bad points for filter ', color1, '.'        
         ans=''
         read,prompt='Fix bad pts for filter '+color1+'? (y,n)',ans
         if ans eq 'y' then begin
            s=sort(stand[z1tot])
            print,color1
            print,stand[z1tot[s]],format='(5(1x,a15))'
            tmpbad = bad[z1tot[s]]
            markdata,indgen(count1tot),inst[z1tot[s]],instsig[z1tot[s]], $
               tmpbad,/yflip, $
               xtitle='Point number',ytitle=color1+'Instrumental Magnitude'
            bad[z1tot[s]]=tmpbad
         endif
      endif
      if edit and (count2tot - count2) gt 0 and nalltot gt 0 then begin
         print, 'There are no stars available in both filters.'        
         print, 'However there are bad points for filter ', color2, '.'        
         ans=''
         read,prompt='Fix bad pts for filter '+color2+'? (y,n)',ans
         if ans eq 'y' then begin
            s=sort(stand[z2tot])
            print,color2
            print,stand[z2tot[s]],format='(5(1x,a15))'
            tmpbad = bad[z2tot[s]]
            markdata,indgen(count2tot),inst[z2tot[s]],instsig[z2tot[s]], $
               tmpbad,/yflip, $
               xtitle='Point number',ytitle=color2+'Instrumental Magnitude'
            bad[z2tot[s]]=tmpbad
         endif
      endif
      zc=where(oldbad ne bad,countchange)
      if countchange gt 0 then goto,again

      print,'COLORSOL: No stars were found in both filters.  Quitting.'
      return
   endif

   if not noprint then $
      print,'Solving for magnitudes and colors for ',nall,' objects'
   pass=0

   oldcolor = replicate(0.,nall)
   repeat begin

      ; Compute standard magnitudes for all observations in filter 1.
      inst2std,jd[z1],am[z1],inst[z1],instsig[z1],color[z1],colorsig[z1], $
         trans1[*,tidx[z1]],trsig1[*,tidx[z1]],jdref1[tidx[z1]], $
         allmag1,allerr1,tidx=lindgen(count1),refcolor=refcolor[0],refam=refam[0]

      ; Compute standard magnitudes for all observations in filter 2.
      inst2std,jd[z2],am[z2],inst[z2],instsig[z2],color[z2],colorsig[z2], $
         trans2[*,tidx[z2]],trsig2[*,tidx[z2]],jdref2[tidx[z2]], $
         allmag2,allerr2,tidx=lindgen(count2),refcolor=refcolor[1],refam=refam[1]

      ; Loop through the unique list and average all the objects found.
      std1    = fltarr(n_elements(object))
      stdsig1 = fltarr(n_elements(object))
      std2    = fltarr(n_elements(object))
      stdsig2 = fltarr(n_elements(object))
      stdcol  = fltarr(n_elements(object))
      stdcolsig = fltarr(n_elements(object))
      for i=0,nall-1 do begin

         z3 = where(allobj[z1] eq object[i],count)
         meanerr,allmag1[z3],allerr1[z3],avgmag,sigm,sigd
         std1[i] = avgmag
         if count eq 1 then $
            stdsig1[i] = sigm $
         else $
            stdsig1[i] = max([sigm,sigd/sqrt(n_elements(z3)-1)])

         z4  = where(allobj[z2] eq object[i],count)
         meanerr,allmag2[z4],allerr2[z4],avgmag,sigm,sigd
         std2[i] = avgmag
         if count eq 1 then $
            stdsig2[i] = sigm $
         else $
            stdsig2[i] = max([sigm,sigd/sqrt(n_elements(z4)-1)])

         stdcol[i] = std1[i] - std2[i]
         stdcolsig[i] = sqrt(stdsig1[i]^2+stdsig2[i]^2)

         color[z1[z3]] = stdcol[i]
         colorsig[z1[z3]] = stdcolsig[i]
         color[z2[z4]] = stdcol[i]
         colorsig[z2[z4]] = stdcolsig[i]
      endfor
      cdiff = abs(stdcol - oldcolor)
      zb = where(cdiff gt 0.001,nbad)
      oldcolor = stdcol
      pass=pass+1
      if not noprint then $
         print,'     End of pass ',pass,'   ',nbad,' left to converge.'
   endrep until nbad eq 0 or pass ge 10

   if nbad ne 0 then begin
      print,nbad,' objects did not converge, look at the following:'
      print,object[zb]
   endif

   if not noprint then begin
      print,filter1+blanks,filter2+blanks,filter1+'-'+filter2, $
         format='("Object",14x,a15,8x,a15,4x,a)'
      for i=0,nall-1 do begin
         z3 = where(allobj[z1] eq object[i],count)
         z4  = where(allobj[z2] eq object[i],count)
         if keyword_set(full) then begin
            print,object[i],'  First filter:',color1
            for j=0,n_elements(z3)-1 do begin
               print,allmag1[z3[j]],' +/- ',allerr1[z3[j]], $
                  allmag1[z3[j]]-std1[i],(allmag1[z3[j]]-std1[i])/stdsig1[i], $
                  format='(14x,f9.4,a,f6.4,1x,f7.4,1x,f7.4)'
            endfor
            print,object[i],'  Second filter:',color2
            for j=0,n_elements(z4)-1 do begin
               print,allmag2[z4[j]],' +/- ',allerr2[z4[j]], $
                  allmag2[z4[j]]-std2[i],(allmag2[z4[j]]-std2[i])/stdsig2[i], $
                  format='(14x,f9.4,a,f6.4,1x,f7.4,1x,f7.4)'
            endfor
         endif
         print,object[i]+blanks,n_elements(z3),std1[i],' +/- ',stdsig1[i], $
                         n_elements(z4),std2[i],' +/- ',stdsig2[i], $
                         stdcol[i],' +/- ',stdcolsig[i], $
            format='(a13,1x,i3,1x,f7.4,a,f6.4,1x,i3,1x,f7.4,a,f6.4,1x,f7.4,a,f6.4)'
      endfor
   endif

   if edit then begin
      oldbad=bad
      z1e=where(fil eq color1 and bad le 1,count1)
      z2e=where(fil eq color2 and bad le 1,count2)
      if count1 ne 0 and count2 ne 0 then begin

         s=sort(stand[z1e])
         print,color1
         print,stand[z1e[s]],format='(5(1x,a15))'
         tmpbad = bad[z1e[s]]
         inst2std,jd[z1e],am[z1e],inst[z1e],instsig[z1e], $
            color[z1e],colorsig[z1e], $
            trans1[*,tidx[z1e]],trsig1[*,tidx[z1e]],jdref1[tidx[z1e]], $
            allmag1e,allerr1e,tidx=lindgen(count1),refcolor=refcolor[0],refam=refam[0]
         markdata,indgen(count1),allmag1e[s],allerr1e[s],tmpbad,/yflip, $
            xtitle='Point number',ytitle=filter1+' Magnitude'
         bad[z1e[s]]=tmpbad

         s=sort(stand[z2e])
         print,color2
         print,stand[z2e[s]],format='(5(1x,a15))'
         tmpbad = bad[z2e[s]]
         inst2std,jd[z2e],am[z2e],inst[z2e],instsig[z2e], $
            color[z2e],colorsig[z2e], $
            trans2[*,tidx[z2e]],trsig2[*,tidx[z2e]],jdref2[tidx[z2e]], $
            allmag2e,allerr2e,tidx=lindgen(count2),refcolor=refcolor[1],refam=refam[1]
         markdata,indgen(count2),allmag2e[s],allerr2e[s],tmpbad,/yflip, $
            xtitle='Point number',ytitle=filter2+' Magnitude'
         bad[z2e[s]]=tmpbad
      endif
      z1e=where(oldbad ne bad,countchange)
      if countchange gt 0 then goto,again
   endif

   thistag=refid+' '+filter1+filter2
   if db and keyword_set(save) then begin 
      print,'Updating entries for ',thistag,' to ',database+'.'+table
      ; we are updating the reduced individual magnitudes in each filter
      ; for stars with data in both filters, only,  on this night.
      for i=0,nall-1 do begin
         z = where(allobj[z1] eq object[i],count)           
         print, 'updating ',  table, ': ', strn(count,len=3), $
                 ' obs for ', object[i], $
                 ' in filter ', filter1, ',', colorname, $
                 ' for RefID ', refid
         if count gt 0 then begin
            jds = jd[z1[z]]
            ; bad flag implicitly 0 because this is clean data.
            if savepos then begin
               dbphot,refid, object[i],jd[z1[z]],filter1,allmag1[z], $
                      allerr1[z],TABLE=table,/NOCLEAN, $
                      ra=ra[z1[z]],decl=dec[z1[z]], $
                      VERBOSE=dverbose,COLOR=colorname,/silent
            endif else begin
               dbphot,refid, object[i],jd[z1[z]],filter1,allmag1[z], $
                      allerr1[z],TABLE=table,/NOCLEAN, $
                      VERBOSE=dverbose,COLOR=colorname,/silent
            endelse
         endif else $
            print,self+ 'Impossible failure in database array selection, ', $
                   filter1

         z = where(allobj[z2] eq object[i],count)           
         print, 'updating ',  table, ': ', strn(count,len=3), $
                 ' obs for ', object[i], $
                 ' in filter ', filter2, ',', colorname, $
                 ' for RefID ', refid
         if count gt 0 then begin
            jds = [ jds, jd[z2[z]] ]
            ; bad flag implicitly 0 because this is clean data.
            if savepos then begin
               dbphot,refid,object[i],jd[z2[z]],filter2,allmag2[z],$
                      allerr2[z],TABLE=table,/NOCLEAN, $
                      ra=ra[z2[z]],decl=dec[z2[z]], $
                      VERBOSE=dverbose, COLOR=colorname,/silent
            endif else begin
               dbphot,refid,object[i],jd[z2[z]],filter2,allmag2[z],$
                      allerr2[z],TABLE=table,/NOCLEAN, $
                      VERBOSE=dverbose,COLOR=colorname,/silent
            endelse
         endif else $
            print,self+ 'Impossible failure in database array selection, ', $
                   filter2
         meanjd = mean(jds)
         color = filter1+'-'+filter2
         print, 'updating ',  table, ':   1 obs for ', object[i], $
                 ' in color ', color, ' for RefID ',refid
         ; bad flag implicitly 0 because this is clean data.
         ; The magnitude recorded is the effective color but
         ; but there is no color (color of the color) set.

         dbphot, refid, object[i], meanjd, color, stdcol[i], stdcolsig[i], $
                 TABLE=table,/NOCLEAN, VERBOSE=dverbose, /silent
      endfor
   endif
      
   if keyword_set(save) then begin
      thistag=refid+' '+filter1+filter2
      print,'Saving data to directory ',path
      suff=[filter1,filter2]
      for j=0,1 do begin
         for i=0,nall-1 do begin
            filename=path+nobname(object[i])+'.'+suff[j]

            ; get current file (if found).
            nlines=0
            if exists(filename) then begin
               openr,lun,filename,/get_lun
               line=''
               while not eof(lun) do begin
                  readf,lun,line,format='(a1)'
                  nlines=nlines+1
               endwhile
               tag=strarr(nlines)
               info=strarr(nlines)
               point_lun,lun,0
               bigstr=''
               ; go read current contents of the file.
               for k=0,nlines-1 do begin
                  readf,lun,bigstr,format='(a)'
                  ; separate the variable length refid from start.
                  ; This also handles older case of a 6 digit rundate.
                  strr = strsplit(bigstr, ' ',/EXTRACT)
                  if n_elements(strr) lt 3 then begin
                     print, self, ' file ', filename, ' line ', k+1, $
                                  ' bad line: ', bigstr
                     return
                  endif
                  ; this is the refid-filter for sort and selection.
                  tag[k] = strjoin(strr[0:1], ' ')
                  ; this is the entirety of the line.
                  info[k]=bigstr
               endfor
               free_lun,lun
            endif

            ; Keep values not from this night. (ie different refid or filters)
            if nlines ne 0 then begin
               z=where(tag ne thistag,oldcount)
               if oldcount ne 0 and oldcount ne nlines then begin
                  tag  = tag[z]
                  info = info[z]
                  nlines = n_elements(tag)
               endif else if oldcount eq 0 then nlines=0
            endif

            ; Add tonight's values
            if j eq 0 then z = where(allobj[z1] eq object[i],count)
            if j eq 1 then z = where(allobj[z2] eq object[i],count)
            if nlines eq 0 then begin
               tag=strarr(count)
               info=strarr(count)
            endif else begin
               tag=[tag,strarr(count)]
               info=[info,strarr(count)]
            endelse
            for k=0,count-1 do begin
               tag[k+nlines] = thistag
               if j eq 0 then $
                  info[k+nlines] = thistag+ $
                                 string(allmag1[z[k]],allerr1[z[k]],stdcol[i], $
                                 stdcolsig[i],format='(2(1x,f7.4,1x,f6.4))')
               if j eq 1 then $
                  info[k+nlines] =  thistag+ $
                                 string(allmag2[z[k]],allerr2[z[k]],stdcol[i], $
                                 stdcolsig[i],format='(2(1x,f7.4,1x,f6.4))')
            endfor
            nlines=nlines+count

            ; Sort data
            idx=sort(tag)

            ; Save data to file
            openw,lun,filename,/get_lun
            for k=0,nlines-1 do begin
               printf,lun,info[idx[k]],format='(a)'
            endfor
            free_lun,lun

         endfor
      endfor
   endif

end
