;+
; NAME:
;  astsn2xy
; PURPOSE:
;  Astrometry conversion from tangent plane ($\xi$,$\eta$) to image (x,y)
;
; DESCRIPTION:
;  This transformation can either be based on a simple linear transformation
;    with rotation from the celestial sphere to linear CCD chip coordinates.
;    Or, it can use a full astrometric solution (including linear).
;
; CATEGORY:
;  Astrometry
;
; CALLING SEQUENCE:
;  astsn2xy,xi,eta,info,x,y
;
; INPUTS:
;  xi     - Tangent plane coordinates (radians)
;  eta    - Tangent plane coordinates (radians)
;  info   - Transformation information held in an anonymous structure.  There
;              are two different groups of tags that can appear.  The original
;              simple linear transformation needs the following tags:
;                 pscale - Plate scale (arcsec/pixel).
;                 rang   - Rotation angle of image (radians).
;                 xflip  - -1 if image flipped in X, 1 if not.
;                 yflip  - -1 if image flipped in Y, 1 if not.
;
;              The full-up transformation requires a different set of tags:
;                 renormfac - normalization factor
;                 cxi - xi transformations coefficients (x,y -> xi)
;                 ceta - eta transformations coefficients (x,y -> eta)
;                 terms - xi terms flag array
;
;              Both types need the following.
;                 xcref  - X center of image.
;                 ycref  - Y center of image.
;                 raref  - Right ascension of center of image (tangent plane).
;                 decref - Declination of center of image (tangent plane).
;
; OPTIONAL INPUT PARAMETERS:
;
; KEYWORD INPUT PARAMETERS:
;
;  FULL - Flag, if set indicates the full transformation should be used.
;            Only the tags needed must be provided.
;  ARCSEC - Flag, if set indicates that the input xi,eta values are in
;            arcseconds.  Otherwise they are treated as radians.
;
; OUTPUTS:
;  x      - X coordinate in image
;  y      - Y coordinate in image
;
; KEYWORD OUTPUT PARAMETERS:
;
; COMMON BLOCKS:
;
; SIDE EFFECTS:
;
; RESTRICTIONS:
;
; PROCEDURE:
;
; MODIFICATION HISTORY:
;  2009/11/02 - Written by Marc W. Buie, Southwest Research Institute
;  2009/11/12, MWB, added ARCSEC keyword
;  2011/03/21, MWB, drastic improvement to starting guess.  Works on anything
;                    now.  Didn't work before if x,y was rotated by 45 degrees.
;  2012/05/24, MWB, changed linear case to use optical axis, not reference.
;  2015/08/12, MWB, changed back to use xcref,ycref.  Optical axis tags
;                      are now removed from all tools.  Use ref instead.
;-
pro astsn2xy,in_xi,in_eta,info,x,y,FULL=FULL,ARCSEC=arcsec

   self='ASTSN2XY: '
   if badpar(in_xi,[2,3,4,5],[0,1,2,3],caller=self+'(xi) ') then return
   if badpar(in_eta,[2,3,4,5],[0,1,2,3],caller=self+'(eta) ') then return
   if badpar(info,[8],[1],caller=self+'(info) ') then return
   if badpar(full,[0,1,2,3],0,caller=self+'(FULL) ',default=0) then return
   if badpar(arcsec,[0,1,2,3],0,caller=self+'(ARCSEC) ',default=0) then return

   ; make sure that xi,eta used internally here is always in arcsec
   if not arcsec then begin
      xi  = in_xi*180.0d0/!dpi*3600.0d0  ; convert to arcsec
      eta = in_eta*180.0d0/!dpi*3600.0d0
   endif else begin
      xi  = in_xi
      eta = in_eta
   endelse

   ; Full transformation
   if full then begin

      ; pull out the linear coefficients for use in computing the starting
      ;  guess.
      z=where(strlowcase(info.terms) eq 'const',/null)
      a0=trimrank(info.cxi[z])
      b0=trimrank(info.ceta[z])
      z=where(strlowcase(info.terms) eq 'x',/null)
      a1=trimrank(info.cxi[z])
      b1=trimrank(info.ceta[z])
      z=where(strlowcase(info.terms) eq 'y',/null)
      a2=trimrank(info.cxi[z])
      b2=trimrank(info.ceta[z])

      dx = trimrank((a2*(eta-b0)-b2*(xi-a0))/(b1*a2-b2*a1))
      dy = trimrank((a1*(eta-b0)-b1*(xi-a0))/(b2*a1-b1*a2))
      x = dx*info.renormfac + info.xcref
      y = dy*info.renormfac + info.ycref

      ; compute xi,eta from this
;      dx=(x-info.xcref)/info.renormfac
;      dy=(y-info.ycref)/info.renormfac
      new_eta= asteval(dx,dy,info.ceta,info.terms) ; /3600.0d0*!dpi/180.0d0
      new_xi = asteval(dx,dy,info.cxi,info.terms) ; /3600.0d0*!dpi/180.0d0

      dxi = xi - new_xi
      deta = eta - new_eta

      pass=0

      while max(abs(dxi)) gt 0.001 or max(abs(deta)) gt 0.001 do begin

         if abs(info.ceta[1]) gt abs(info.cxi[1]) then $
            delx = deta/info.ceta[1] * info.renormfac $
         else $
            delx = dxi/info.cxi[1] * info.renormfac

         if abs(info.ceta[2]) gt abs(info.cxi[2]) then $
            dely = deta/info.ceta[2] * info.renormfac $
         else $
            dely = dxi/info.cxi[2] * info.renormfac

         x = x + delx
         y = y + dely
         dx=(x-info.xcref)/info.renormfac
         dy=(y-info.ycref)/info.renormfac
         new_eta= asteval(dx,dy,info.ceta,info.terms)
         new_xi = asteval(dx,dy,info.cxi,info.terms)
         dxi = xi - new_xi
         deta = eta - new_eta

if pass eq 100 then begin
   print,self,'early exit',max(abs(dxi)),max(abs(deta))
   break
endif
         pass++

      endwhile

   ; Simple transformation
   endif else begin

      x = xi/info.pscale*cos(info.rang) - eta/info.pscale*sin(info.rang)
      y = xi/info.pscale*sin(info.rang) + eta/info.pscale*cos(info.rang)
;      x = info.xflip*x + info.xcref
;      y = info.yflip*y + info.ycref
      x = info.xflip*x + info.xcref
      y = info.yflip*y + info.ycref

   endelse

   x=trimrank(x,/overwrite)
   y=trimrank(y,/overwrite)

end

