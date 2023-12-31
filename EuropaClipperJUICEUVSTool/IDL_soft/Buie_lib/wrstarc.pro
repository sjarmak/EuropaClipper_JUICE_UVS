;+
; NAME:
;  wrstarc
; PURPOSE:
;  Write a binary version of a star catalog.
; DESCRIPTION:
;  Writes a star catalog file.  This routine is coupled with rdstarc and
;    starcprmt and only knows how to write most recent version of the binary
;    catalog file.
; CATEGORY:
;  File I/O
; CALLING SEQUENCE:
;  wrstarc,file,nstars,ra,dec,bmag,rmag
; INPUTS:
;  file    - File name for saving star catalog data.
;  nstars  - Number of stars in the catalog.  This is provided so that you 
;               can specify zero.  If nstars=0 then the rest of the inputs
;               are ignored.
;  ra      - J2000 RA of stars (radians)
;  dec     - J2000 Dec of stars (radians)
;  bmag    - blue magnitude
;  rmag    - red magnitude
; OPTIONAL INPUT PARAMETERS:
; KEYWORD INPUT PARAMETERS:
; OUTPUTS:
; KEYWORD OUTPUT PARAMETERS:
; COMMON BLOCKS:
; SIDE EFFECTS:
; RESTRICTIONS:
; PROCEDURE:
;   Writes this version of file:
;
;   v1.0  Version line at the start:   STARC v1.0
;         Binary format in big endian order. 
;         The version line is a 10 byte string.
;         Next is a longword giving number of stars, >= 0.
;         This is followed by two double vectors for ra and dec, then float
;            vectors for bmag and rmag.
;
;   v1.1  Version line at the start:   STARC v1.1
;         Binary format in big endian order. 
;         The version line is a 10 byte string.
;         Next is a longword giving number of stars, >= 0.
;         Next is a double scalar with the catalog equinox (in years)
;         Next is a double scalar with the catalog epoch (in years)
;         This is followed by two double vectors for ra and dec, then float
;            vectors for bmag and rmag., then two double vectors for ra and dec
;            proper motion.
;
;         Proper motion is encoded as radians/year and the ra proper motion does
;            not include cos(dec) so that:
;             RA(t) = RA0 + RPM*(t-epoch) where RA0 is the value in the catalog
;             Dec(t) = Dec0 + DPM*(t-epoch)
;         everything is in radians and radians/year
;
; MODIFICATION HISTORY:
;  2012/07/15, Written by Marc W. Buie, Southwest Research Institute,
;                 separated out from starcprmt.pro
;  2016/09/20, MWB, added version 1.1 for proper motion support
;-
pro wrstarc,file,input,ra,dec,bmag,rmag,EPOCH=epoch

   self='WRSTARC: '
   if badpar(file,7,0,caller=self +  '(file) ') then return
   if badpar(input,[2,3,8],0,caller=self +  '(input) ',type=input_type) then return

   if input_type eq 8 then begin
      if badpar(epoch,[0,2,3,4,5],0,caller=self +  '(EPOCH) ',type=epoch_type) then return
      if epoch_type eq 0 then begin
         version='STARC v1.1'
         openw,slun,file,/GET_LUN
         ; write out the new version string for this file.
         version_out=swap_endian(version,/SWAP_IF_LITTLE_ENDIAN)
         writeu,slun,version_out
         ; write out the star count.
         nstars_out=swap_endian(input.nstars,/SWAP_IF_LITTLE_ENDIAN)
         writeu, slun, nstars_out
         equinox_out=swap_endian(input.equinox,/SWAP_IF_LITTLE_ENDIAN)
         writeu, slun, equinox_out
         epoch_out=swap_endian(input.epoch,/SWAP_IF_LITTLE_ENDIAN)
         writeu, slun, epoch_out
         if nstars gt 0 then begin
            ; ra vector, double of length nstars.
            ra=swap_endian(input.ra,/SWAP_IF_LITTLE_ENDIAN)
            writeu, slun,ra
            ; dec vector, double of length nstars.
            dec=swap_endian(input.dec,/SWAP_IF_LITTLE_ENDIAN)
            writeu, slun,dec
            ; bmag vector, double of length nstars.
            bmag=swap_endian(input.bmag,/SWAP_IF_LITTLE_ENDIAN)
            writeu, slun,bmag
            ; rmag vector, double of length nstars.
            rmag=swap_endian(input.rmag,/SWAP_IF_LITTLE_ENDIAN)
            writeu, slun,rmag
            ; RA proper motion vector, double of length nstars.
            rapm=swap_endian(input.rapm,/SWAP_IF_LITTLE_ENDIAN)
            writeu, slun,rapm
            ; Dec proper motion vector, double of length nstars.
            decpm=swap_endian(input.decpm,/SWAP_IF_LITTLE_ENDIAN)
            writeu, slun,decpm
         endif
         free_lun, slun
         return

      endif else begin
         nstars=input.nstars
         ra    =input.ra + input.rapm*(epoch-input.epoch)
         dec   =input.dec+ input.decpm*(epoch-input.epoch)
         bmag  =input.bmag
         rmag  =input.rmag
         n1=n_elements(ra)
         n2=n_elements(dec)
         n3=n_elements(bmag)
         n4=n_elements(rmag)
      endelse

   endif else begin
      nstars=input
      if nstars gt 0 then begin
         if badpar(ra,[4,5],1,caller=self +  '(ra) ',npts=n1) then return
         if badpar(dec,[4,5],1,caller=self +  '(dec) ',npts=n2) then return
         if badpar(bmag,[4,5],1,caller=self +  '(bmag) ',npts=n3) then return
         if badpar(rmag,[4,5],1,caller=self +  '(rmag) ',npts=n4) then return
      endif
   endelse

   if nstars ne 0 then begin
      if min([n1,n2,n3,n4,nstars]) ne max([n1,n2,n3,n4,nstars]) then begin
         print,self,'Error! RA, Dec, bmag, and rmag '+ $
                    'must all be the same length and match nstars.'
         return
      endif
   endif

   nstars=long(nstars)

   version='STARC v1.0'

   openw,slun,file,/GET_LUN

   ; write out the new version string for this file.
   version_out=swap_endian(version,/SWAP_IF_LITTLE_ENDIAN)
   writeu,slun,version_out

   ; write out the star count.
   nstars_out=swap_endian(nstars,/SWAP_IF_LITTLE_ENDIAN)
   writeu, slun, nstars_out

   if nstars gt 0 then begin
      ; ra vector, double of length nstars.
      swap_endian_inplace, ra, /SWAP_IF_LITTLE_ENDIAN
      writeu, slun,ra
      ; dec vector, double of length nstars.
      swap_endian_inplace, dec, /SWAP_IF_LITTLE_ENDIAN
      writeu, slun,dec
      ; bmag vector, float of length nstars.
      swap_endian_inplace, bmag, /SWAP_IF_LITTLE_ENDIAN
      writeu, slun,bmag
      ; rmag vector, float of length nstars.
      swap_endian_inplace, rmag, /SWAP_IF_LITTLE_ENDIAN
      writeu, slun,rmag
   endif

   free_lun, slun

end
