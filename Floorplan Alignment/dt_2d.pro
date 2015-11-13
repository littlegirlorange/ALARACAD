;==============================================================================
;
;	Method:		dt_2d
;
;	Description:
;				Computes the distance transform (DT) of a binary image.
;
;				Based on the algorithms described by:
;
;					Grevara GJ. Distance transform algorithms and their
;					implementation and evaluation. In: Deformable Models:
;					Biomedical and Clinical Applications (Topics in Biomedical
;					Engineering. International Book Series). Suri JS and Farag
;					AA, Eds. Springer-Verlag, New York. 2007:33-60.
;
;					Borgefors, G. On digital distance transforms in three
;					dimensions. Computer Vision and Image Understanding 1996
;					64(3):368-376.
;
;	Version:
;				071123
;				Original test version.  City block and chamfer only.
;
;				071227
;				2D version for EGF (whole body scan) project.
;
;	Inputs:
;				Binary image (bytarr).  NB: voxels must be isotropic.
;
;	Outputs:
;				Distance transform (fltarr).
;
;	Required Modules:
;
;	Written by:
;				Maggie Kusano, November 23, 2007
;
;==============================================================================
;
function dt_2d, $
	mask, $
	CITYBLOCK=city, $
	CHAMFER=chamfer

dims = size( mask, /DIM )
maxDist = total( dims )

d = [1,maxDist]
type = 'city'
if keyword_set( chamfer ) then begin
	d=[3,4]
	type = 'chamfer'
endif

dImg = fix( (mask eq 0b)*maxDist + (mask gt 0b)*0 )

if type eq 'city' then begin

	; x dir
	for i=1, dims[0]-1 do begin
		dImg[i,*] = min( [[[reform(dImg[i-1,*])+1]], [[reform(dImg[i,*])]]], DIM=3 )
	endfor
	for i=dims[0]-2, 0, -1 do begin
		dImg[i,*] = min( [[[reform(dImg[i+1,*])+1]], [[reform(dImg[i,*])]]], DIM=3 )
	endfor

	; y dir
	for j=1, dims[1]-1 do begin
		dImg[*,j] = min( [[[reform(dImg[*,j-1])+1]], [[reform(dImg[*,j])]]], DIM=3 )
	endfor
	for j=dims[1]-2, 0, -1 do begin
		dImg[*,j] = min( [[[reform(dImg[*,j+1])+1]], [[reform(dImg[*,j])]]], DIM=3 )
	endfor

endif else begin

	for j=1, dims[1]-2 do begin
		for i=1, dims[0]-2 do begin
			dImg[i,j] = min( [dImg[i-1,j]+d[0],     dImg[i,j], $
				              dImg[i-1,j-1]+d[1],   dImg[i,j-1]+d[0],  dImg[i+1,j-1]+d[1]] )
		endfor
	endfor

	for j=dims[1]-2, 1, -1 do begin
		for i=dims[0]-2, 1, -1 do begin
			dImg[i,j] = min( [dImg[i-1,j+1]+d[1], dImg[i,j+1]+d[0],  dImg[i+1,j+1]+d[1], $
									                dImg[i,j],         dImg[i+1,j]+d[0]])
		endfor
	endfor

endelse

if type eq 'chamfer' then dImg /= 3.0
return, dImg

end ; of dt