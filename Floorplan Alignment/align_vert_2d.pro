;==============================================================================
;
;	Method:		align_vert
;
;	Description:
;				Estimates vertical shift required to align 2 CT images.
;
;	Version:
;				071205
;				Original test version.
;
;	Inputs:
;				2 sets of raw data (fixed and moving)
;
;	Outputs:
;				Returns the z-shift
;
;	Required Modules:
;				textbox.pro
;
;	Written by:
;				Maggie Kusano, December 5, 2007
;
;==============================================================================
;
function align_vert_2d, fContImg, mContImg

fImgDims = size( fContImg, /DIM )

fCount = total( fContImg, 1 )
mCount = total( mContImg, 1 )

lag = indgen( fImgDims[1] ) - fImgDims[1]/2

correl = c_correlate( fCount, mCount, lag )

print, correl

d = -lag[ (where( correl eq max( correl ) ))[0] ]

return, d

end ; of align_vert