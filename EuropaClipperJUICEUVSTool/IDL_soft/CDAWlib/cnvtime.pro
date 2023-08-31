;$Author: kovalick $
;$Date: 1996/08/09 17:13:43 $
;$Header: /home/cdaweb/dev/control/RCS/cnvtime.pro,v 1.2 1996/08/09 17:13:43 kovalick Exp johnson $
;$Locker: johnson $
;$Revision: 1.2 $
;
;Copyright 1996-2013 United States Government as represented by the 
;Administrator of the National Aeronautics and Space Administration. 
;All Rights Reserved.
;
;------------------------------------------------------------------
;+
; NAME:
;	CNVTIME
;
; PURPOSE:
; 	This provides an alternate entry point to CNV_MDHMS_SEC
;
;----------------------------------------------------------------
;
function cnvtime,yr,mo,dy,hr,mn,sc
return,cnv_mdhms_sec(yr,mo,dy,hr,mn,sc)
end
