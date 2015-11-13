;==============================================================================
;
;	Method:		chamfer_match_2d
;
;	Description:
;				Coregisters 2 2D contours using chamfer matching as described
;				in van Herk M and Kooy HM. Automatic three-dimensional
;				correlation of CT-CT, CT-MRI, and CT-SPECT using chamfer
;				matching. Med. Phys. 21(7):1163-1178 (1994).
;
;	Version:
;				071107
;				First version.
;
;				071123
;				Version used to generate data sent to Huan on 071116.
;
;	Inputs:
;				2 sets of raw data (fixed and moving)
;
;	Outputs:
;				The moving image is over-written.
;				Returns the 6-parameter transformation matrix.
;
;	Required Modules:
;				textbox.pro
;
;	Written by:
;				Maggie Kusano, November 7, 2007
;
;==============================================================================

function chamfer_match_2d, $
	IMG1=fContMask, $
	PIXDIMS1=fPixDims, $
	IMG2=mContMask, $
	PIXDIMS2=mPixDims, $	; must be equal to fPixDims
	LIMITS=limits, $		; rot and trans limits in deg and mm
	MODVAL=modval, $
	SIMPLEX=simplex, $
	POWELL=powell, $
	CHAMFER=chamfer, $
	CITY=city, $
	DISPLAY=display, $
	DEBUG=debug, $
	TRANS_VALS=p			; Out: transform values (in deg and pix)

common chamfer_match_2d_cost_params, dImg, points, maxVals, dispImg

; Make sure image dimensions are the same
fImgDims = size( (fContMask), /DIM )
mImgDims = size( (mContMask), /DIM )
if n_elements( fPixDims ) eq 0 then fPixDims = [1,1]
if n_elements( mPixDims ) eq 0 then mPixDims = [1,1]
if (total( fImgDims ne mImgDims ) ne 0) or (total( fPixDims ne mPixDims ) ne 0) then begin
	void = dialog_message( /ERROR, 'Image dimensions do not match. Returning.' )
	return, -1L
endif

if n_elements( modval ) eq 0 then modval = 1
; Select type of optimization
if n_elements( simplex ) eq 0 and n_elements( powell ) eq 0 then simplex = 1b

bDisplay = 0b
if n_elements(display) ne 0 then bDisplay=1b
bDebug = 0b
if n_elements(debug) ne 0 then bDebug=1b

; Prep output
p = [0,0,0]
t3dMat = identity(3)

; Set parameter limits
maxVals = fltarr(4)
if n_elements( limits ) ne 3 then limits = [10,50,50]
maxVals = limits

dispImg = fContMask gt 0
points = where( mContMask ne 0, nPoints )
if nPoints gt 0 then dispImg[points] = 2b
indices = indgen( nPoints )
points = points[where( (indices mod modval) eq 0 )]

; Display original contours
if bDisplay then begin
	window, 1, XSIZE=fImgDims[0], YSIZE=fImgDims[1], TITLE='Original contours'
	tvscl, dispImg
endif

; Estimate initial vertical shift
yShift = align_vert_2d( fContMask, mContMask )

; Convert moving image to distance image
if keyword_set( chamfer ) then begin
	dImg = dt_2d( fContMask, /CHAMFER )
endif else begin
	dImg = dt_2d( fContMask, /CITY )
endelse

; Optimize cost
if keyword_set( simplex ) then begin

	; Downhill simplex
	retVal = amoeba( 1.0e-6, FUNCTION_NAME='chamfer_match_2d_cost', P0=[0,0,yShift], SCALE=maxVals, $
			NCALLS=nCalls, FUNCTION_VALUE=values )

	if n_elements( retVal ) eq 1 then begin
		void = dialog_message( /ERROR, 'amoeba failed to converge' )
		return, -1L
	endif

	if bDebug then begin
		print, 'rot (deg): ', strtrim( retVal[0] )
		print, 'shift (pix): ', strtrim( retVal[1:2] )
		print, 'nCalls: ', strtrim( nCalls )
	endif

	; Restart
	p = amoeba( 1.0e-6, FUNCTION_NAME='chamfer_match_2d_cost', P0=retVal, SCALE=maxVals, $
			NCALLS=nCalls, FUNCTION_VALUE=values )

	if n_elements( p ) eq 1 then begin
		void = dialog_message( /ERROR, 'amoeba failed to converge' )
		return, -1L
	endif

	if bDebug then begin
		print, 'rot (deg): ', strtrim( p[0] )
		print, 'shift (pix): ', strtrim( p[1:2] )
		print, 'nCalls: ', strtrim( nCalls )
	endif

endif else begin

	; Powell
	p = [0,0,0]
	xi = identity(2)
	powell, p, xi, 1.0e-8, fmin, 'chamfer_match_2d_cost', /DOUBLE
	if bDebug then print, p

endelse

; Perform transform
if p[0] ne 0 then begin
	retImg = rot( mContMask, -p[0], /INTERP, MISSING=0 )
	dispImg = rot( mContMask*100, -p[0], /INTERP, MISSING=0 )
endif
retImg = shift( retImg, p[1], p[2] )
dispImg = shift( dispImg, p[1], p[2] )

if bDisplay then begin
	indices = where( dispImg ne 0, count )
	dispImg = fContMask gt 0
	dispImg[indices] = 2b
	window, 2, XSIZE=fImgDims[0], YSIZE=fImgDims[1], TITLE='Transformed contours'
	tvscl, dispImg
endif

beep
if bDebug then print, 'Done'
return, retImg

end



function chamfer_match_2d_cost, p

common chamfer_match_2d_cost_params, dImg, points, maxVals, dispimg

dims = [size( dImg, /DIM ),1]

t3d, /RESET
t3d, TRANS=-(dims-1)/2.0
t3d, ROT=[0,0,p[0]]
t3d, TRANS=(dims-1)/2.0+[p[1:2],0]
coords = fltarr( 3, n_elements(points) )
coords[0:1,*] = array_indices( dImg, points )
coords = vert_t3d( coords )

f = interpolate( dImg, coords[0,*], coords[1,*], MISSING=-1 )

img = dispImg
img[coords[0,*],coords[1,*]] = 2b
wset, 1 & tvscl, img
xyouts, 10, 10, strtrim(p[0])+','+strtrim(p[1])+','+strtrim(p[2])

; Use mean instead of RMS
valid = where( f ne -1, nValid )
if nValid gt 0 then begin
	c = float(total(f[valid], /DOUBLE)) / nValid
endif else begin
	; Penalize if we're outside the image boundaries
	c = 100
endelse

;c = sqrt( total(f^2, /DOUBLE) ) / (n_elements(coords[0,*])-1)

; Constrain parameters by increasing cost if params are out of bounds
for i=0, n_elements(p)-1 do begin
	if p[i] lt -maxVals[i] then begin
		c = c + 100*(-maxVals[i]-p[i])
	endif else if p[i] gt maxVals[i] then begin
		c = c + 100*(p[i]-maxVals[i])
	endif
endfor

return, c

end ; of cost