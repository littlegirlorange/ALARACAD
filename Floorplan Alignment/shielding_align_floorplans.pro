@'.\chamfer_match_2d_plus.pro'

pro shielding_align_floorplans

	DEF_DIR = 'M:\TB57a\Floor Plans\'

	fFile = dialog_pickfile( FILTER = '*.bmp', $
							PATH = DEF_DIR, $
							GET_PATH = inDir, $
							TITLE='Select the fixed floorplan image (.bmp)' )

	; Return if the user cancels or selects nothing
	if fFile eq '' then return
	fileBase = file_basename( fFile, '.bmp' )

	; Get image info
	result = query_image( fFile, info )
	if result eq 0 then begin
		void = dialog_message( 'Error loading fixed file', /ERROR )
		return
	endif

	; Read image
	image = read_image( fFile )
	if image[0] eq -1L then return

	; Convert from RGB to grayscale
	r = reform( image[0,*,*] )
	g = reform( image[1,*,*] )
	b = reform( image[2,*,*] )
	fImage = not byte( 0.299*float(r) + 0.587*float(g) + 0.114*float(b) )
	fMask = abs(r-b)

	mFile = dialog_pickfile( FILTER = '*.bmp', $
							PATH = inDir, $
							GET_PATH = inDir, $
							TITLE='Select the moving floorplan image (.bmp)' )

	; Return if the user cancels or selects nothing
	if mFile eq '' then return

	; Get image info
	result = query_image( mFile, info )
	if result eq 0 then begin
		void = dialog_message( 'Error loading moving file', /ERROR )
		return
	endif

	; Read image
	image = read_image( mFile )
	if image[0] eq -1L then return

	; Convert from RGB to grayscale
	r = reform( image[0,*,*] )
	g = reform( image[1,*,*] )
	b = reform( image[2,*,*] )
	mImage = not byte( 0.299*float(r) + 0.587*float(g) + 0.114*float(b) )
	mMask = abs(r-b)

	newMImage = chamfer_match_2d_plus( $
		IMG1=fMask, PIXDIMS1=[1,1], $
		IMG2=mMask, PIXDIMS2=[1,1], $
		LIMITS=[2,40,40,1.25], $
		/SIMPLEX, /CHAMFER, $
		/DISPLAY, /DEBUG, $
		TRANS_VALS=p )

	wFile = dialog_pickfile( FILTER = '*.bmp', $
							PATH = inDir, $
							GET_PATH = inDir, $
							TITLE='Select the floorplan image to transform (.bmp)' )
	; Return if the user cancels or selects nothing
	if wFile eq '' then return

	; Get image info
	result = query_image( mFile, info )
	if result eq 0 then begin
		void = dialog_message( 'Error loading new file', /ERROR )
		return
	endif

	; Read image
	image = read_image( wFile )
	if image[0] eq -1L then return

	; Convert from RGB to grayscale
	r = reform( image[0,*,*] )
	g = reform( image[1,*,*] )
	b = reform( image[2,*,*] )
	wImage = not byte( 0.299*float(r) + 0.587*float(g) + 0.114*float(b) )

	wImage = transform_image( wImage, ROT=[0,0,p[0]], TRANS=[p[1],p[2],0], SCALE=[p[3],p[3],1], MISSING=0 )
	r = transform_image( r, ROT=[0,0,p[0]], TRANS=[p[1],p[2],0], SCALE=[p[3],p[3],1], MISSING=255b )
	g = transform_image( g, ROT=[0,0,p[0]], TRANS=[p[1],p[2],0], SCALE=[p[3],p[3],1], MISSING=255b )
	b = transform_image( b, ROT=[0,0,p[0]], TRANS=[p[1],p[2],0], SCALE=[p[3],p[3],1], MISSING=255b )

	image = image * 0b
	image[0,*,*] = byte(r)
	image[1,*,*] = byte(g)
	image[2,*,*] = byte(b)
	dims = size( r, /DIM )

	window, 1, XSIZE=dims[0], YSIZE=dims[1] & tvscl, fImage-wImage

	print, p

	fileBase = file_basename( wFile, '.bmp' )
	outFile = inDir + fileBase + '_aligned.bmp'
	write_bmp, outFile, image

end