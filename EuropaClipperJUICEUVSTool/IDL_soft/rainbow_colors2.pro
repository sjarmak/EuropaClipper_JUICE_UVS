PRO rainbow_colors2, N_COLORS = colnum

; Set colour table.
; Default, without keyword, is 254 rainbow colours running smoothly from
; purple (1) to red (254), plus black (0) and white (255). The number of
; colours excluding black and white can be reduced with keyword N_COLORS
; set to a value in the range 1 to 21. In the range 1 to 13, equidistant
; rainbow colours are used, where distances are defined by the CIEDE2000
; colour difference. In the range 14 to 21, rainbow colours are not
; discrete enough and instead, triplets of colours are used with varying
; brightness. These colour schemes work reasonably well for colourblind
; people (and much better than standard rainbow schemes). They are also
; suitable for printing.

; Written by: P.J.J. Tol, SRON, August 2009
; Improved palette, 17 January 2010
; Lighter purple, 14 June 2017


IF KEYWORD_SET(colnum) THEN BEGIN
   colnum = ROUND(colnum)
   IF (colnum LT 1 OR colnum GT 21) AND (colnum NE 256) THEN BEGIN
      MESSAGE, 'Number of colors is 1..21 or 256, set to 256.', /INFORMATIONAL
      colnum = 256
   ENDIF
ENDIF ELSE BEGIN
   colnum = 256
ENDELSE

; colour coordinates
IF colnum EQ 256 THEN x = 21*INDGEN(colnum)/(colnum-1.) ELSE $
   IF colnum LE 13 THEN BEGIN xarr = $
      [[0.137, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], $
       [0.137, 1., 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], $
       [0.137, 0.511, 1., 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], $
       [0.137, 0.36, 0.762, 1., 0, 0, 0, 0, 0, 0, 0, 0, 0], $
       [0.137, 0.335, 0.483, 0.794, 1., 0, 0, 0, 0, 0, 0, 0, 0], $
       [0.137, 0.287, 0.402, 0.651, 0.833, 1., 0, 0, 0, 0, 0, 0, 0], $
       [0., 0.195, 0.34, 0.436, 0.685, 0.843, 1., 0, 0, 0, 0, 0, 0], $
       [0., 0.177, 0.301, 0.39, 0.536, 0.735, 0.861, 1., 0, 0, 0, 0, 0], $
       [0., 0.162, 0.266, 0.36, 0.437, 0.617, 0.768, 0.874, 1., 0, 0, 0, 0], $
       [0., 0.149, 0.239, 0.337, 0.399, 0.508, 0.676, 0.794, 0.885, 1., 0, 0, 0], $
       [0., 0.137, 0.218, 0.312, 0.374, 0.44, 0.577, 0.715, 0.813, 0.894, 1., 0, 0], $
       [0., 0.128, 0.203, 0.284, 0.351, 0.402, 0.487, 0.628, 0.742, 0.826, 0.9, 1., 0], $
       [0., 0.118, 0.188, 0.259, 0.332, 0.38, 0.437, 0.544, 0.67, 0.765, 0.839, 0.907, 1.]]
      x = xarr[0:colnum-1,colnum-1]
   ENDIF ELSE BEGIN xarr = $
      [[0, 1, 2, 3, 4, 5, 9, 10, 11, 12, 13, 14, 15, 16, 0, 0, 0, 0, 0, 0, 0], $
       [0, 1, 2, 3, 4, 5, 9, 10, 11, 12, 13, 14, 15, 16, 17, 0, 0, 0, 0, 0, 0], $
       [20, 0, 1, 2, 3, 4, 5, 9, 10, 11, 12, 13, 14, 15, 16, 17, 0, 0, 0, 0, 0], $
       [19, 20, 0, 1, 2, 3, 4, 5, 9, 10, 11, 12, 13, 14, 15, 16, 17, 0, 0, 0, 0], $
       [18, 19, 20, 0, 1, 2, 3, 4, 5, 9, 10, 11, 12, 13, 14, 15, 16, 17, 0, 0, 0], $
       [20, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 0, 0], $
       [19, 20, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 0], $
       [18, 19, 20, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17]]
      x = xarr[0:colnum-1,colnum-14]
   ENDELSE

; colour set
IF colnum GE 14 AND colnum LE 21 THEN BEGIN
   distinctred = [17, 68, 119, 17, 68, 119, 17, 68, 136, 119, 170, 221, 119, 170, 221, 119, 170, 221, 119, 170, 204]
   distinctgreen = [68, 119, 170, 119, 170, 204, 119, 170, 204, 119, 170, 221, 68, 119, 170, 17, 68, 119, 17, 68, 153]
   distinctblue = [119, 170, 221, 119, 170, 204, 68, 119, 170, 17, 68, 119, 17, 68, 119, 34, 85, 136, 85, 136, 187]
   bowred = distinctred[[x]]
   bowgreen = distinctgreen[[x]]
   bowblue = distinctblue[[x]]
ENDIF ELSE BEGIN
   bowred = INTERPOLATE([111, 96, 85, 78, 77, 78, 84, 89, 96, 105, 119, 140, 166, 190, 209, 221, 228, 231, 230, 228, 223, 218], x)
   bowgreen = INTERPOLATE([76, 89, 104, 121, 138, 150, 158, 165, 171, 177, 183, 188, 190, 188, 181, 170, 156, 140, 121, 99, 72, 34], x)
   bowblue = INTERPOLATE([155, 169, 184, 197, 198, 188, 179, 169, 158, 144, 125, 104, 84, 72, 65, 60, 57, 53, 50, 45, 40, 34], x)
ENDELSE

; colour indices
IF colnum EQ 256 THEN ci = INDGEN(colnum) ELSE $
   ci = [ROUND(INDGEN(256)*colnum/256.+0.5), colnum] - 1

R = bowred[[ci]]
G = bowgreen[[ci]]
B = bowblue[[ci]]

TVLCT, R, G, B

END
