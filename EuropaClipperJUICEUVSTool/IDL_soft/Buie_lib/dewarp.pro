;+
; NAME:
;  dewarp
;
; PURPOSE:
;  Transforms an image from (x,y) to ($\xi$,$\eta$) accounting for rotation and warping.
;
; DESCRIPTION:
;  Transforms an image from the (x,y) coordinate plane to the ($\xi$,$\eta$)
;  coordinate plane. If the image is rotated, the coefficients on the terms
;  of the basis can be adjusted to perform the rotation. Photometric pixel
;  values in the resulting image are obtained from interpolation if necessary.
;
; CATEGORY:
;  Astrometry
;
; CALLING SEQUENCE:
;  dewarp,ininfo,imgarr,outinfo,imgout,nx,ny
;
; INPUTS:
;  ininfo - Image transformation structure that describes how the input
;              image maps to the plane-of-the-sky.  See astxn2xy.pro for
;              required information.  Note that this routine only uses
;              the FULL transformation option.
;
;           This structure can also be of the type generated from the
;              Astronomy Users Libary routine, EXTAST.  If this structure
;              is provided it will be automatically detected and ad2xy
;              will be called instead of astrd2xy.
;
;  imgarr - Input image (array)
;  outinfo - Image transformation structure that describes how the output
;              image maps to the plane-of-the-sky.  See astxn2xy.pro for
;              required information.  Note that this routine only uses
;              the FULL transformation option.
;  imgout - Output image (array), may already exist and is added to if /ADD set
;  nx     - xsize of the output image, if imgout exists and ADD is set then
;              this value defaults to the existing size of imgout.  Without
;              /ADD this value is required.
;  ny     - ysize of the output image, if imgout exists and ADD is set then
;              this value defaults to the existing size of imgout.  Without
;              /ADD this value is required.
;
; OPTIONAL INPUT PARAMETERS:
;
; KEYWORD INPUT PARAMETERS:
;  ADD - Flag, if set indicates the dewarped image should be added to the
;           destination,
;           Else the dewarped image will be copied to the destination.
;  BILINEAR - Flag, if set force the interpolation to using a bilinear
;                interpolation method.  If not set, attempts to do something
;                similar to sinc interpolation.  Use this option for under
;                sampled data.
;  ROI     - Region of interest from master image that stack will be built
;               to.  The default is to do it for the entire image.  Provide
;               a 4-element vector [i0,j0,i1,j1] (lower left hand corner and
;               upper right hand corner of region) to use this option.
;
; OUTPUTS:
;  imgout - The transformed photometric array in (x,y) coordinates based on a
;           cubic convolution resampling of the original photometric array using
;           the transformed coordinates.
;
; KEYWORD OUTPUT PARAMETERS:
;  COUNT - An optional output array with the same dimensions as imgout. Each
;   element of the array indicates how many values have been added to the
;   corresponding pixel. This information then can be used during an averaging
;   process.
;
; COMMON BLOCKS:
;
; SIDE EFFECTS:
;
; RESTRICTIONS:
;    There is as yet an unresolved issue with flux normalization between
;      input and output images.  At the moment, the input and output should
;      be regarded to be on separate photometric systems.
; PROCEDURE:
;
; MODIFICATION HISTORY:
;  2009/11/04, Written by SwRI Clinic Team, Harvey Mudd College
;  2009/11/14, MWB, rework with some new logic
;  2010/02/28, MWB, minor change to reduce memory footprint
;  2011/12/08, MWB, added option to support the Astronomy Users Library
;                      tools for astrometric information on the input.
;  2011/12/09, MWB, changed to use new astcvt tool.
;  2011/12/12, MWB, fixed serious bug that generated incorrect output if
;                      the output image was not square.
;  2014/03/19, MWB, added BILINEAR keyword
;  2016/04/11, MWB, added ROI keyword
;-
pro dewarp,ininfo,imgarr,outinfo,imgout,nx,ny, $
       ADD=ADD,COUNT=count,BILINEAR=bilinear,ROI=in_roi

   self='DEWARP: '
   if badpar(ininfo,8,1,caller=self+'(ininfo) ') then return
   if badpar(imgarr,[2,3,4,5,12],2,caller=self+'(imgarr) ') then return
   if badpar(outinfo,8,1,caller=self+'(outinfo) ') then return
   if badpar(imgout,[0,2,3,4,5],[0,2],caller=self+'(imgarr) ', $
                                      type=outtype) then return
   if badpar(nx,[2,3],0,caller=self+'(nx) ') then return
   if badpar(ny,[2,3],0,caller=self+'(ny) ') then return
   if badpar(add,[0,1,2,3],0,caller=self+'(ADD) ',default=0) then return
   if badpar(bilinear,[0,1,2,3],0,caller=self+'(BILINEAR) ', $
                                  default=0) then return
   if badpar(in_roi,[0,2,3],1,caller=self+'(ROI) ',default=-1) then return

   if in_roi[0] lt 0 then roi=[0,0,nx-1,ny-1] else roi=in_roi

   ; Check out the input (ininfo) structure
   taglist=tag_names(ininfo)
   z=where(taglist eq 'CXI',count)
   if count eq 1 then begin
      infotype='buie'
   endif else begin
      z=where(taglist eq 'CRVAL',count)
      if count eq 0 then begin
         print,self,'Invalid input structure.'
         return
      endif
      infotype='astron'
   endelse

   ; Get the size of the input array?
   sz = size(imgarr,/dimen)

   ; Create two arrays that carry the native output pixel coordinates
   outy = lindgen(long(nx)*long(ny))
   outx = outy mod long(nx)
   outy = temporary(outy) / long(nx)

   ; Filter by the ROI
   zr=where(outx ge roi[0] and outx le roi[2] and $
            outy ge roi[1] and outy le roi[3],count)
   if count eq 0 then begin
      print,roi
      help,nx,ny
      print,self,'ROI does not intersect the output image'
      return
   endif
   outx=outx[zr]
   outy=outy[zr]

   ; Convert output pixel coordinates to position on sky
;   astxy2rd,outx,outy,outinfo,outra,outdec,/FULL
   astcvt,'xy',outx,outy,outinfo,'rd',outra,outdec

   ; dump outx and outy
   outx=0
   outy=0

   ; Convert sky positions to input pixel coordinates
   if infotype eq 'buie' then begin
;      astrd2xy,outra,outdec,ininfo,inx,iny,/FULL
      astcvt,'rd',outra,outdec,ininfo,'xy',inx,iny
   endif else begin
      outra  = outra  * 180.0d0 / !dpi
      outdec = outdec * 180.0d0 / !dpi
      ad2xy,outra,outdec,ininfo,inx,iny
   endelse

   ; dump outra and outdec
   outra=0
   outdec=0

   ; Create output image
   if not add or outtype eq 0 then begin
      imgout = fltarr(nx,ny)
      count=intarr(nx,ny)
   endif
   outsz=size(imgout,/dimen)
   if outsz[0] ne nx or outsz[1] ne ny then begin
      imgout = fltarr(nx,ny)
      count=intarr(nx,ny)
   endif

   ; Does count image exist and match the size of imgout?  If not, create it.
   csz=size(count,/structure)
   if csz.type_name eq 'UNDEFINED' or $
      (csz.type_name ne 'INT' and csz.type_name ne 'LONG') or $
      csz.n_dimensions ne 2 or csz.n_elements ne n_elements(imgout) then $
      count=intarr(nx,ny)

   ; find those output pixels that map onto input array
   zg = where(inx ge 0 and inx lt sz[0] and $
              iny ge 0 and iny lt sz[1], countg)

   if countg gt 0 then begin
      if bilinear then begin
         newvals = interpolate(imgarr,inx[zg],iny[zg])
      endif else begin
         newvals = interpolate(imgarr,inx[zg],iny[zg],cubic=-0.5)
      endelse
      count[zr[zg]] += 1
      if add then imgout[zr[zg]] += newvals else imgout[zr[zg]] = newvals
   endif else begin
      print,self,'Warning!, no overlap between input and output images.'
   endelse

end
