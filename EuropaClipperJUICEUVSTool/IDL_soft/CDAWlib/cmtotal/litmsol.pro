;+
; NAME:
;   LITMSOL
;
; AUTHOR:
;   Craig B. Markwardt, NASA/GSFC Code 662, Greenbelt, MD 20770
;   craigm@lheamail.gsfc.nasa.gov
;   UPDATED VERSIONs can be found on my WEB PAGE: 
;      http://cow.physics.wisc.edu/~craigm/idl/idl.html
;
; PURPOSE:
;   Solve the light-time equation between two moving bodies
;
; MAJOR TOPICS:
;   Geometry, Physics
;
; CALLING SEQUENCE:
;   LITMSOL, T1, X1, Y1, Z1, T2, INFO2, RAW2, OBJ2, INFOSUN, RAWSUN, $
;            /RECEIVER, TBASE=, TOLERANCE=, POSUNITS=, MAXITER=, $
;            /NO_SHAPIRO
;
; DESCRIPTION:
;
;  The procedure LITMSOL solves the light time equation between two
;  moving bodies in the solar system.  Given the time and position of
;  reception or transmission of a photon, this equation determines the
;  time of transmission or reception at the other solar system body.
;  Since both bodies may be moving, the equation must be solved
;  iteratively.
;
;  The trajectories of solar system bodies must be described by either
;  a JPL ephemeris, or by a JPL-like ephemeris generated by
;  JPLEPHMAKE.  This routine calls JPLEPHINTERP.
;
;  The user specifies the known time and position of interaction as
;  T1, X1, Y1 and Z1, in units of POSUNITS.  The time of interaction
;  at the other body -- the solution to the light time equation -- is
;  returned as T2.  If the photon was *received* at time T1, then the
;  RECEIVER keyword should be set (in which case the transmission must
;  have occurred in the past).
;
;  Since the solution is iterative, the user may specify a solution
;  tolerance, and a maximum number of iterations.
;
;  If users wish to include the Shapiro time delay, which has a
;  maximum amplitude of approximately 250 usec, they must specify the
;  ephemeris of the Sun (INFOSUN, RAWSUN).  The Shapiro delay is the
;  extra general relativistic delay caused by the Sun's potential.
;
;
; INPUTS:
;
;   T1 - epoch of interaction, in Julian days, in the TDB timescale.
;        (scalar or vector)
;
;   X1, Y1, Z1 - coordinates of interaction, referred to the solar
;                system barycenter, in J2000 coordinates.  Units are
;                described by POSUNITS. (scalar or vector)
;
;   INFO2, RAW2 - ephemeris of other solar system body, returned by
;                 JPLEPHREAD or JPLEPHMAKE.
;
;   INFOSUN, RAWSUN - ephemeris of at least the Sun, as returned by
;                     JPLEPHREAD.  Only used of NO_SHAPIRO is not set.
;
;
; OUTPUTS:
;
;   T2 - upon output, epoch of interaction at the second solar system
;        body, in Julian days, in the TDB timescale.
;
;
; KEYWORD PARAMETERS:
;
;   RECEIVER - if set, then the epoch T1 is a reception of a photon.
;              Otherwise T1 is the epoch of transmission of a photon.
;
;   VX1, VY1, VZ1 - upon input, the body velocity at time T1, in
;                   VELUNITS units.  This information is required only
;                   if the SHAPIRO_DERIV is required.
;
;   X2, Y2, Z2 - upon return, the body position at time T2, in
;                POSUNITS units.
;   VX2, VY2, VZ2 - upon return, the body velocity at time T2, in
;                VELUNITS units.
;
;   TBASE - a fixed epoch time (Julian days) to be added to each value
;           of T1.  Since subtraction of large numbers occurs with
;           TBASE first, the greatest precision is achieved when TBASE
;           is expressed as a nearby julian epoch, T1 is expressed
;           as a small offset from the fixed epoch.  
;           Default: 0
;
;   POSUNITS - the units for positions, one of 'CM', 'KM', 'LT-S' or
;              'AU'.
;              Default: 'CM'
;   VELUNITS - the units for velocities (and Shapiro derivative).
;              Default: POSUNITS+'/S'
;
;   TOLERANCE - the solution tolerance, expressed in POSUNITS.
;               Default: 1000 CM
;
;   ERROR - upon return, a vector giving the estimated error in the
;           solution for each point, expressed in POSUNITS.  This
;           quantity should be less than TOLERANCE unless the number
;           of iterations exceeded MAXITER.
;
;   MAXITER - maximum number of solution iterations to be taken.
;             Default: 5
;   NITER - upon return, contains the actual number of iterations used.
;
;   SHAPIRO_CALC - method of calculating Shapiro delay, a string with
;                  one value of 'NONE', 'DELAY' or 'BOTH'.  NONE means
;                  do not calculate any Shapiro delay values.  DELAY
;                  means calculate Shapiro delay only.  BOTH means
;                  calculate the delay *and* its derivative with
;                  respect to time.  If SHAPIRO_CALC is set to
;                  DELAY or BOTH, then INFOSUN and RAWSUN must be
;                  specified.  If BOTH, then VX1, VY1 and VZ1 must
;                  also be specified. This keyword overrides
;                  NO_SHAPIRO.
;   NO_SHAPIRO - if set, then the Shapiro delay will not be accounted
;                for.  Use SHAPIRO_CALC instead.
;   SHAPIRO_DELAY - upon return, contains the Shapiro delay in
;                   seconds, if SHAPIRO_CALC is set to 'DELAY' or
;                   'BOTH'.
;   SHAPIRO_DERIV - upon return, contains the derivative of the
;                   Shapiro delay, in light seconds per time unit of
;                   velocity (SHAPIRO_CALC must be set to 'BOTH' to
;                   enable this calculation).  Note that you must
;                   supply VX1, VY1 and VZ1 to get the derivative
;                   value.
;
;
; EXAMPLE:
;
;
;
; SEE ALSO:
;
;   JPLEPHREAD, JPLEPHINTERP
;
;
; MODIFICATION HISTORY:
;   Written, 6 May 2002, CM
;   Documented, 12 May 2002, CM
;   Added TGUESS keyword, 29 May 2002, CM
;   Added ERROR and X/Y/ZOFF keywords, 25 Sep 2002, CM
;   Extensive revisions: addition of SHAPIRO_{CALC,DELAY,DERIV}
;     values; input VX1, VY1 and VZ1; output X2, Y2, Z2 and VX2 VY2
;     and VZ2; and VELUNITS keyword, 07 Mar 2007, CM
;   Allow user specified function to interpolate INFO2/RAW2 via
;     INTERP_FUNC keyword, 09 Oct 2008, CM
;
;  $Id: litmsol.pro,v 1.7 2008/10/10 00:50:19 craigm Exp $
;
;-
; Copyright (C) 2002, 2007, 2008, Craig Markwardt
; This software is provided as is without any warranty whatsoever.
; Permission to use, copy, modify, and distribute modified or
; unmodified copies is granted, provided this copyright and disclaimer
; are included unchanged.
;-

pro litmsol, t1, x1, y1, z1, t2, info2, raw2, obj2, info, raw, $
             tbase=tbase, tolerance=tol0, posunits=posunits0, $
             receiver=receiver, maxiter=maxiter0, no_shapiro=noshap, $
             tguess=tguess, error=diff, niter=i, $
             shapiro_delay=shdelay, shapiro_deriv=shderiv, shapiro_calc=shcalc0, $
             vx1=vx1, vy1=vy1, vz1=vz1, velunits=velunits0, $
             x2=x2, y2=y2, z2=z2, vx2=vx2, vy2=vy2, vz2=vz2, $
             xoffset=xoff, yoffset=yoff, zoffset=zoff, $
             interp_func=intfunc0

  if n_elements(shcalc0) GT 0 then begin
      shcalc = strupcase(strtrim(shcalc0(0),2))
      if shcalc NE 'NONE' AND shcalc NE 'BOTH' AND $
         shcalc NE 'DELAY' then $
        message, 'ERROR: SHAPIRO_CALC value of "'+shcalc+'" was invalid.'
      if keyword_set(noshap) AND shcalc NE 'NONE' then $
        message, 'ERROR: SHAPIRO_CALC and NO_SHAPIRO did not agree.'
  endif else begin
      shcalc = 'DELAY'
      if keyword_set(noshap) then shcalc = 'NONE'
  endelse
      
  ;; Default position and velocity units
  if n_elements(posunits0) EQ 0 then begin
      posunits = 'CM'
  endif else begin
      posunits = strtrim(posunits0(0),1)
  endelse
  if n_elements(velunits0) EQ 0 then begin
      velunits=posunits+'/S'
  endif else begin
      velunits = strtrim(velunits0(0),1)
  endelse

  ;; Default tolerances
  if n_elements(tol0) EQ 0 then begin
      tol = 1000d     ;; 10 m tolerance
      posunits = 'CM'
  endif else begin
      tol = tol0(0)
  endelse

  ;; Default interpolation function: JPLEPHINTERP
  if n_elements(intfunc0) EQ 0 then begin
      intfunc = 'JPLEPHINTERP'
  endif else begin
      intfunc = strtrim(strupcase(intfunc0(0)),2)
  endelse

  if n_elements(xoff) EQ 0 then xoff = 0d
  if n_elements(yoff) EQ 0 then yoff = 0d
  if n_elements(zoff) EQ 0 then zoff = 0d

  if n_elements(maxiter0) EQ 0 then maxiter = 5L $
  else                              maxiter = floor(maxiter0(0))>2
      
  case posunits of 
      'CM':   clight = info2.c*1d2  ;; CM/S
      'KM':   clight = info2.c*1d-3 ;; KM/S
      'LT-S': clight = 1d           ;; LT-S/S
      'AU':   clight = 1d/info2.au  ;; AU/S
  endcase

  ;; Decide whether to compute derivative of shapiro delay
  if shcalc EQ 'BOTH' then begin
      calcvel = 1

      if n_elements(vx1) EQ 0 OR n_elements(vy1) EQ 0 OR $
        n_elements(vz1) EQ 0 then begin
          message, 'ERROR: You must specify VX1,VY1,VZ1 when computing '+$
            'the Shapiro derivative'
      endif
  endif
  if arg_present(vx2) OR arg_present(vy2) OR arg_present(vz2) then calcvel = 1

  ;; If any Shapiro calculations are required, pre-compute r1dot
  if shcalc NE 'NONE' then begin
      jplephinterp, info, raw, t1, xs, ys, zs, /sun, $
        velocity=calcvel, vxs, vys, vzs, $
        posunits=posunits, velunits=velunits, tbase=tbase
      r1 = sqrt((x1-xs)^2 + (y1-ys)^2 + (z1-zs)^2)
      if shcalc EQ 'BOTH' then $
        r1dot = ((x1-xs)*(vx1-vxs)+(y1-ys)*(vy1-vys)+(z1-zs)*(vz1-vzs))/r1
  endif

  ;; Use TGUESS if provided, otherwise estimate T2 as T1 to begin with
  dt0 = t1*0
  if n_elements(tguess) EQ n_elements(t1) then begin
      t2 = tguess 
      dtold = abs(tguess-t1)*86400d
      if keyword_set(receiver) then dtold = -dtold
  endif else begin
      t2 = t1
      dtold = 0d
  endelse


  ;; ==================== BEGIN ITERATION
  ct = 1L
  i = 0L
  while (ct GT 0) AND (i LT maxiter) do begin

      ;; Position and vel of body at estimated time T2
      call_procedure, intfunc, info2, raw2, t2, x2, y2, z2, objectname=obj2, $
        velocity=calcvel, vx2, vy2, vz2, $
        tbase=tbase, posunits=posunits, velunits=velunits

      ;; Compute distance from T1 to T2 in physical and light-second units
      dr = sqrt((x1-(x2+xoff))^2 + (y1-(y2+yoff))^2 + (z1-(z2+zoff))^2)
      dt = dr / clight

      ;; Add Shapiro delay
      if shcalc NE 'NONE' then begin

          ;; First iteration: recompute time of sun position, since
          ;; the actual sun position at time of closest approach will
          ;; be slightly different
          if i EQ 1 then begin
              ts = t1

              ;; Angle between S/C and sun, as seen from earth
              cos_th = ((x2-x1)*(xs-x1) + (y2-y1)*(ys-y1) + (z2-z1)*(zs-z1))/dr/r1
              whc = where(cos_th GT 0, ctc)
              ;; Correct for the light travel time to the time of
              ;; closest approach
              if ctc GT 0 then ts(whc) = (t1 + r1*cos_th/clight/86400d)(whc)

              ;; Recompute the sun position
              jplephinterp, info, raw, ts, xs, ys, zs, /sun, $
                velocity=calcvel, vxs, vys, vzs, $
                posunits=posunits, velunits=velunits, tbase=tbase
              r1 = sqrt((x1-xs)^2 + (y1-ys)^2 + (z1-zs)^2)
              if shcalc EQ 'BOTH' then $
                r1dot = ((x1-xs)*(vx1-vxs)+(y1-ys)*(vy1-vys)+(z1-zs)*(vz1-vzs))/r1
          endif

          
          ;; Compute Shapiro delay
          dt0 = 2*info.msol
          ;; Body-sun distance
          r2 = sqrt((x2-xs)^2 + (y2-ys)^2 + (z2-zs)^2)
          rsump = (r1+r2+dr+dt0*clight)
          rsumm = (r1+r2-dr+dt0*clight)
          shdelay = dt0*alog(rsump/rsumm)
          dt = dt + shdelay

          ;; Compute derivative of Shapiro delay
          if shcalc EQ 'BOTH' then begin
              r2dot = ((x2-xs)*(vx2-vxs)+(y2-ys)*(vy2-vys)+(z2-zs)*(vz2-vzs))/r2
              drdot = ((x2-x1)*(vx2-vx1)+(y2-y1)*(vy2-vy1)+(z2-z1)*(vz2-vz1))/dr
              shderiv = 2*dt0*(((r1+r2+dt0*clight)*drdot - (r1dot+r2dot)*dr) / $
                               (rsump*rsumm))
          endif
      endif

      ;; If 1 <-> 2 are switched, then reverse sign of DT
      if keyword_set(receiver) then dt = -dt

      ;; Correct T2 and compute how much change from previous iteration
      t2 = t1 + dt/86400d
      diff = abs(dtold-dt)*clight
      wh = where(diff GT tol, ct)

      ;; Prepare for next iteration
      dtold = dt
      i = i + 1
  endwhile

  return
end
