;+
; NAME:
;  stage1cat
; PURPOSE:   (one line only)
;  Generates the Stage1 catalog for a given Raw1 catalog
; DESCRIPTION:
; CATEGORY:
;  Photometry
; CALLING SEQUENCE:
;  stage1cat,id
; INPUTS:
;  id - String, id for the plphot table in the phot database (ex.'PL2010')
; OPTIONAL INPUT PARAMETERS:
; KEYWORD INPUT PARAMETERS:
; OUTPUTS:
; KEYWORD OUTPUT PARAMETERS:
; COMMON BLOCKS:
; SIDE EFFECTS:
; RESTRICTIONS:
; PROCEDURE:
; MODIFICATION HISTORY:
;  2011/04/08, Written by Erin R. George, Southwest Research Institute
;  2014/05/27, ERG, added weighted mean computation
;-
pro stage1cat,id

   self='stage1cat: '
   if badpar(id,7,0,CALLER=self+'(id) ') then return

   r1subid='Raw1'
   dcr=1.5/3600.0d0*!pi/180.0d0   ; 1.5 arcsec converted to radians

   openmysql,dblun,'phot'
   ; Query the database to get the list of refids for the
   ;    PL2010 raw1 catalog.
   cmd=['select refid from plphot', $
        'where id='+quote(id), $
        'and subid='+quote(r1subid), $
        'group by refid;']
   mysqlquery,dblun,cmd,refidlist,ngood=nrefids

   print,'There are ',strn(nrefids),' for ',id
   ntotal=0L
   for ii=0,nrefids-1 do begin
      ; Query the database for the ra and dec of each object for
      ;    each refid. Build the sets using msrcor, which will
      ;    take out any overlapping objects between the refids.
      cmd=['select ra,decl,rasig,decsig,b,bsig,v,vsig,bmv,bmvsig,'+ $
           'nbobs,nvobs,nbbad,nvbad,nbni,nvni from plphot where', $
           'id='+quote(id), $
           'and subid='+quote(r1subid), $
           'and refid='+quote(refidlist[ii])+';']
      mysqlquery,dblun,cmd,ra0,dec0,rasig0,decsig0,b0,bsig0,v0,vsig0, $
                col0,colsig0,nbobs0,nvobs0,nbbad0,nvbad0,nbni0,nvni0, $
                format='d,d,d,d,f,f,f,f,f,f,i,i,i,i,i,i',ngood=nfound
      print,refidlist[ii],nfound
      ntotal += nfound
      msrcor,set,ra0,dec0,dcr

      if ii eq 0 then begin
         rasig1=[rasig0]
         decsig1=[decsig0]
         b1=[b0]
         bsig1=[bsig0]
         v1=[v0]
         vsig1=[vsig0]
         col1=[col0]
         colsig1=[colsig0]
         nbobs1=[nbobs0]
         nvobs1=[nvobs0]
         nbbad1=[nbbad0]
         nvbad1=[nvbad0]
         nbni1=[nbni0]
         nvni1=[nvni0]
      endif else begin
         rasig1=[rasig1,rasig0]
         decsig1=[decsig1,decsig0]
         b1=[b1,b0]
         bsig1=[bsig1,bsig0]
         v1=[v1,v0]
         vsig1=[vsig1,vsig0]
         col1=[col1,col0]
         colsig1=[colsig1,colsig0]
         nbobs1=[nbobs1,nbobs0]
         nvobs1=[nvobs1,nvobs0]
         nbbad1=[nbbad1,nbbad0]
         nvbad1=[nvbad1,nvbad0]
         nbni1=[nbni1,nbni0]
         nvni1=[nvni1,nvni0]
      endelse
   endfor  ; ii loop

   print,strn(max(set.objid)),' unique sources found out of ',strn(ntotal),' measurements'

   for jj=0,max(set.objid) do begin
      z=where(set.objid eq jj)

      ; Set up weights for weighted means, meanerr2 is preferred over meanerr
      wra=1/(rasig1[z])^2
      wdec=1/(decsig1[z])^2
      wb=1/(bsig1[z])^2
      wv=1/(vsig1[z])^2
      wcol=1/(colsig1[z])^2

      meanerr2,set.x[z],wra,mra,sra
      meanerr2,set.y[z],wdec,mdec,sdec
      meanerr2,b1[z],wb,mb,sb
      meanerr2,v1[z],wv,mv,sv
      meanerr2,col1[z],wcol,mcol,scol

      bobs=total(nbobs1[z])
      vobs=total(nvobs1[z])
      bbad=total(nbbad1[z])
      vbad=total(nvbad1[z])
      nbn=total(nbni1[z])
      nvn=total(nvni1[z])

      if jj eq 0 then begin
         ra=[mra]
         dec=[mdec]
         rasig=[sra]
         decsig=[sdec]
         b=[mb]
         bsig=[sb]
         v=[mv]
         vsig=[sv]
         col=[mcol]
         colsig=[scol]
         nbobs=[bobs]
         nvobs=[vobs]
         nbbad=[bbad]
         nvbad=[vbad]
         nbni=[nbn]
         nvni=[nvn]
      endif else begin
         ra=[ra,mra]
         dec=[dec,mdec]
         rasig=[rasig,sra]
         decsig=[decsig,sdec]
         b=[b,mb]
         bsig=[bsig,sb]
         v=[v,mv]
         vsig=[vsig,sv]
         col=[col,mcol]
         colsig=[colsig,scol]
         nbobs=[nbobs,bobs]
         nvobs=[nvobs,vobs]
         nbbad=[nbbad,bbad]
         nvbad=[nvbad,vbad]
         nbni=[nbni,nbn]
         nvni=[nvni,nvn]

      endelse
   endfor  ; jj loop

   newsubid='Stage1'   ; IMPORTANT!

   ; Delete loop so that data is not replicated.
   cmddel=['delete from plphot where', $
           'id='+quote(id), $
           'and subid='+quote(newsubid)+';']
   mysqlcmd,dblun,cmddel,answer,nlines

   c=','
   nsaved=0
   for kk=0,max(set.objid) do begin
      z=where(set.objid eq kk)
      obs=n_elements(set.lidx[z])

      if obs lt 3 then continue
      cmd=['insert into plphot values', $
           '('+quote(id)+c, $                        ; PL2010
           quote(newsubid)+c, $                      ; Stage1
           'NULL'+c, $                               ; refid
           'NULL'+c, $                               ; jd
           string(ra[kk],format='(f11.9)')+c, $      ; ra
           string(dec[kk],format='(f12.9)')+c, $     ; dec
           string(rasig[kk],format='(f11.9)')+c, $   ; rasig
           string(decsig[kk],format='(f11.9)')+c, $  ; decsig
           string(b[kk],format='(f8.5)')+c, $        ; b mag
           string(bsig[kk],format='(f7.5)')+c, $     ; b mag err
           string(v[kk],format='(f8.5)')+c, $        ; v mag
           string(vsig[kk],format='(f7.5)')+c, $     ; v mag err
           string(col[kk],format='(f8.5)')+c, $      ; b-v col
           string(colsig[kk],format='(f7.5)')+c, $   ; b-v col sig
           string(nbobs[kk],format='(i2.1)')+c, $    ; tot b obs
           string(nvobs[kk],format='(i2.1)')+c, $    ; tot v obs
           string(nbbad[kk],format='(i2.1)')+c, $    ; tot b bad
           string(nvbad[kk],format='(i2.1)')+c, $    ; tot v bad
           string(nbni[kk],format='(i2.1)')+c, $     ; # nights for b
           string(nvni[kk],format='(i2.1)')+');']    ; # nights for v
      mysqlcmd,dblun,cmd,answer,nlines
      nsaved++
   endfor  ; kk loop
   free_lun,dblun

   print,strn(nsaved),' sources saved to ',id,' Stage1 catalog.'
end
