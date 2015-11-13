;--------------------------------------------------------------------
;
;    PURPOSE  Get the image data - stub
;
function shielding_guiGetBMPData, pInfo

	bHaveFile = 0b
	inDir = ''
	file = ''

	file = dialog_pickfile( FILTER = '*.bmp', $
							PATH = (*pInfo).workingDir, $
							GET_PATH = inDir, $
							TITLE='Select the floorplan image (.bmp)' )

	; Return if the user cancels or selects nothing
	if file eq '' then return, bHaveFile

	fileBase = file_basename( file, '.bmp' )

	; Get image info
	result = query_image( file, info )
	if result eq 0 then begin
		void = dialog_message( 'Error loading file', /ERROR )
		return, bHaveFile
	endif

	; Read image
	image = read_image( file )
	if image[0] eq -1L then return, bHaveFile

	; Convert from RGB to grayscale
	r = reform( image[0,*,*] )
	g = reform( image[1,*,*] )
	b = reform( image[2,*,*] )
	grayscaleImage = not byte( 0.299*float(r) + 0.587*float(g) + 0.114*float(b) )

	; Set state info
	(*pInfo).nPx = info.dimensions[0]
	(*pInfo).nPy = info.dimensions[1]
	*(*pInfo).pSeries0 = grayscaleImage
	(*pInfo).fileName = file

	return, 1

end ; of shielding_guiGetBMPData


;--------------------------------------------------------------------
;
;    PURPOSE  Replace the current floorplan
;			  New floorplan must have the same dimensions and scale
;			  as the previous.
;
function shielding_guiReplaceFloorplan, pInfo

	bHaveFile = 0b
	inDir = ''
	file = ''

	file = dialog_pickfile( FILTER = '*.bmp', $
							PATH = (*pInfo).workingDir, $
							GET_PATH = inDir, $
							TITLE='Select the floorplan image (.bmp)' )

	; Return if the user cancels or selects nothing
	if file eq '' then return, bHaveFile

	fileBase = file_basename( file, '.bmp' )

	; Get image info
	result = query_image( file, info )
	if result eq 0 then begin
		void = dialog_message( 'Error loading file', /ERROR )
		return, bHaveFile
	endif

	; Read image
	image = read_image( file )
	if image[0] eq -1L then return, bHaveFile

	; Convert from RGB to grayscale
	r = reform( image[0,*,*] )
	g = reform( image[1,*,*] )
	b = reform( image[2,*,*] )
	grayscaleImage = not byte( 0.299*float(r) + 0.587*float(g) + 0.114*float(b) )

	; Set state info
	if ( (*pInfo).nPx eq info.dimensions[0] ) and $
	   ( (*pInfo).nPy eq info.dimensions[1] ) then begin
		*(*pInfo).pSeries0 = grayscaleImage
		(*pInfo).fileName = file
		bHaveFile = 1b
	endif else begin
		void = dialog_message( /ERROR, 'Incorrect dimensions. Image not loaded.' )
	endelse

	return, bHaveFile

end ; of shielding_guiReplaceFloorplan


;--------------------------------------------------------------------
;
;	PURPOSE  Open saved ROI data
;
;	NOTE: The .sav file must contain the following variables:
;			oROIGroup	- IDLgrModel containing ROIs to add
;			oSymArray	- array of symbol objects (or null objects
;						  if there are no symbols), one entry for
;						  each ROI in oROIGroup
;			data		- table data array
;			uVal		- number of rows in the table
;
pro shielding_guiOpenROIs, $
	pInfo, $
	SOURCE=source, $
	SHIELD=shield, $
	HSHIELD=hShield, $
	REGION=region, $
	QUERY=query

	; Must specify one type and only one type of ROI
	if n_params() ne 1 then return

	if keyword_set( source ) then begin
		type = 'source'
		prefix = 'P'
		widget = (*pInfo).wSourceTable
	endif else if keyword_set( shield ) then begin
		type = 'shield'
		prefix = 'S'
		widget = (*pInfo).wShieldTable
	endif else if keyword_set( hShield ) then begin
		type = 'hshield'
		prefix = 'H'
		widget = (*pInfo).wHShieldTable
	endif else if keyword_set( region ) then begin
		type = 'region'
		prefix = 'R'
		widget = (*pInfo).wRegionTable
	endif else if keyword_set( query ) then begin
		type = 'query'
		prefix = 'Q'
	endif else begin
		return
	endelse

	; Remove old ROIs
	answer = dialog_message( 'Replace all '+type+ ' ROIs?', $
			/QUESTION, TITLE='Removing ROIs' )
	if answer eq 'No' then return

	oROIs = (*pInfo).oROIGroup->get( /ALL, COUNT=nROIs )

	for i=0, nROIs-1 do begin
		if obj_valid( oROIs[i] ) then begin
			oROIs[i]->getProperty, NAME=name
			if prefix eq (strsplit( name, '_', /EXTRACT))[0] then begin
				shielding_guiDeleteROI, pInfo, oROIs[i]
			endif
		endif
	endfor

	; Prompt for file
	inDir = ''
	inFile = ''
	inFile = dialog_pickfile( FILTER = '*' +type+ '_rois.sav', $
							  PATH = (*pInfo).workingDir, $
							  GET_PATH = inDir, $
							  TITLE="Select the IDL ROI .sav file" )

	; Return if the user cancels or selects nothing
	if inFile eq '' then return

	; Restore the file and return if we don't have any objects
	restore, inFile, RESTORED_OBJECTS=oRestored
	if not obj_valid( oROIGroup ) then return

	; Return if the current and original image dimensions and scale
	; are not the same
	widget_control, (*pInfo).wFloorplanScaleText, GET_VALUE=value
	if (fpscale ne float(value[0])) or $
	   (nPx ne (*pInfo).nPx ) or (nPy ne (*pInfo).nPy ) then begin
		void = dialog_message( /ERROR, 'Scales do not match. Returning' )
		obj_destroy, oRestored
		return
	endif

	; Get ROI objects from new ROI group
	oROIs = oROIGroup->get( /ALL, COUNT=nROIs )

	; Make sure the ROIs are of the right type
	bOk = 1b
	for iROI=0, nROIs-1 do begin
		oROIs[iROI]->getProperty, NAME=name
		if prefix ne (strsplit( name, '_', /EXTRACT))[0] then begin
			obj_destroy, oRestored
			return
		endif
	end
	if prefix ne 'Q' then begin
		if (where( strmatch( data[0,0:nROIs-1], prefix+'_*' ) eq 0 ))[0] ne -1L then begin
			obj_destroy, oRestored
			return
		endif
	endif

	; All's good.  Attach these ROIs
	for iROI=0, nROIs-1 do begin

		; Reattach symbols
		oROIs[iROI]->setProperty, SYMBOL=oSymArray[iROI]

		; Add to state ROI group
		oROIGroup->remove, oROIs[iROI]
		(*pInfo).oROIGroup->add, oROIs[iROI]

		; Create a display ROI and attach to the display
		shielding_guiAttachROI, pInfo, oROIs[iROI]

	endfor

	; Replace old table info
	if prefix ne 'Q' then begin
		widget_control, widget, $
				TABLE_YSIZE=uVal+1, SET_VALUE=data, SET_UVALUE=uVal
	endif

end ; of shielding_guiOpenROIs


;--------------------------------------------------------------------
;
;    PURPOSE  Open saved session (ROIs, tables, images, etc.)
;
function shielding_guiOpenSession, pInfo

	catch, err
	if err ne 0 then begin
		void = dialog_message( TITLE='Error opening session. Some data may be missing', !error_state.msg )
;		if n_elements( restored ) ne 0 then begin
;			for i=0, n_elements( restored )-1 do begin
;				obj_destroy, restored[i]
;			endfor
;		endif
		return, 0
	endif

	; Prompt for file
	inDir = ""
	inFile = ""
	inFile = dialog_pickfile( FILTER = "*.sav", $
							  PATH = (*pInfo).workingDir, $
							  GET_PATH = inDir, $
							  TITLE="Select the session file" )

	; Return if the user cancels or selects nothing
	if inFile eq "" then begin
		return, 0
	endif

	; Detach ROIs from the display
	shielding_guiDetachROIs, pInfo

	; Clear existing ROIs from the database
	oROIs = (*pInfo).oROIGroup->get( /ALL, COUNT=nROIs )
	(*pInfo).oROIGroup->remove, /ALL
	for iROI=0, nROIs-1 do begin
		oROIs[iROI]->getProperty, SYMBOL=oSym
		if obj_valid( oSym ) then obj_destroy, oSym
		obj_destroy, oROIs[iROI]
	endfor

	; Restore the file and return if we don't have any objects
	restore, inFile, /RELAXED_STRUCTURE, RESTORED=restored

	; Check for backwards compatibility (old versions saved oROIGroups)
	if obj_valid( oROIGroups ) then begin
		oROIGroup = oROIGroups->get( POSITION=0 )
		oROIGroups->remove, oROIGroup
		obj_destroy, oROIGroups
		oROIs = oROIGroup->get( /ALL, COUNT=nROIs )
		if size( oROIs, /DIM ) ne 0 then begin
			(*pInfo).oROIGroup->add, oROIs
		endif
		oROIGroup->remove, /ALL
		obj_destroy, oROIGroup
		oROIGroup = (*pInfo).oROIGroup
	endif

	; Replace symbols on point ROIs
	if obj_valid( oROIGroup ) then begin
		oROIs = oROIGroup->get( /ALL, COUNT=nROIs )
		if nROIs eq n_elements( oSymArray ) then begin
			for iROI=0, nROIs-1 do begin
				oROIs[iROI]->setProperty, SYMBOL=oSymArray[iROI]
			endfor
		endif
	endif

	; Update the state
	(*pInfo).filename = inFile
	(*pInfo).oROIGroup = oROIGroup
	*(*pInfo).pSeries0 = series0
	*(*pInfo).pSeries1 = series1
	fpDims = size( series0, /DIMENSIONS )
	(*pInfo).nPx = fpDims[0]
	(*pInfo).nPy = fpDims[1]
	dmDims = size( series1, /DIMENSIONS )

	; Set old scale (make backwards compatible - pre 080311 files will only
	; have one scale called scaleText for the floorplan.  Post 080311 files
	; will have 2 scales: fpScaleText for the floorplan and dmScaleText for the
	; dosemap)
	if not keyword_set( fpScaleText ) then fpScaleText = scaleText
	if not keyword_set( dmScaleText ) then dmScaleText = fpScaleText
	widget_control, (*pInfo).wFloorplanScaleText, SET_VALUE=fpScaleText
	widget_control, (*pInfo).wDosemapScaleText, SET_VALUE=dmScaleText

	; Resize shield table if it was saved before 060712
	sDims = size( sData, /DIMENSIONS )
	if sDims[0] ne 10 then begin
		eS = (*pInfo).eS
		newSData = strarr( 10, sDims[1] )
		if sDims[0] lt 8 then begin
			newSData[eS.name,*]			= sData[0,*] ; name
			newSData[eS.material,*] 	= sData[1,*] ; material
			newSData[eS.thickness,*]	= sData[2,*] ; thickness
			if sDims[0] eq 4 then begin
				newSData[eS.desc,*]		= sData[3,*] ; description
			endif
		endif else begin
			newSData[eS.name:eS.y2,*]	= sData[0:4,*]
			newSData[eS.h1,0:sDims[1]-2]	= make_array( sDims[1]-1, VALUE='0.0' )
			if keyword_set( shieldHeight ) then begin
				value = shieldHeight
			endif else if keyword_set( aboveDist ) then begin
				value = aboveDist
			endif else begin
				value = '3.81'
			endelse
			newSData[eS.h2,0:sDims[1]-2]	= make_array( sDims[1]-1, VALUE=value )
			newSData[eS.material:eS.desc,*] = sData[5:7,*]
		endelse
		sData = newSData
	endif

	; Add regions to region table if session was saved before 060712
	rDims = size( rData, /DIMENSIONS )
	if rDims[0] gt 0 then begin
		if rDims[0] ne 15 then begin
			eR = (*pInfo).eR
			newRData = strarr( 15, rDims[1] )
			newRData[eR.name:eR.maxDose,*]	= rData[0:11,*]
			newRData[eR.occ,0:rDims[1]-2]	= 1				; occupancy factor
			newRData[eR.effMaxDose,*]		= rData[11,*]	; effective dose
			newRData[eR.desc,*]				= rData[12,*]	; description
			rData = newRData
		endif
		widget_control, (*pInfo).wRegionTable, $
				TABLE_YSIZE=rUVal+1, SET_VALUE=rData, SET_UVALUE=rUVal
	endif

	; Change time from hours to mins if file was saved before 080612
	if pUVal gt 0 then begin
		info = file_info( inFile )
		fileDate = bin_date( systime( 0, info.mTime ) )
		julFileDate = julday( fileDate[1], fileDate[2], fileDate[0], fileDate[3], fileDate[4], fileDate[5] )
		julCutoffDate = julday( 6, 12, 2008, 0, 0, 0 )
		if julFileDate lt julCutoffDate then begin
			eP = (*pInfo).eP
			tus = strtrim( string( float(pData[eP.tu,0:pUVal-1]) * 60.0, FORMAT='(f8.1)' ), 2 )
			pData[eP.tu,0:pUVal-1] = tus
			tis = strtrim( string( float(pData[eP.ti,0:pUVal-1]) * 60.0, FORMAT='(f8.1)' ), 2 )
			pData[eP.ti,0:pUVal-1] = tis
		endif
	endif

	; Replace old table info
	widget_control, (*pInfo).wShieldTable, $
			TABLE_YSIZE=sUVal+1, SET_VALUE=sData, SET_UVALUE=sUVal
	widget_control, (*pInfo).wSourceTable, $
			TABLE_YSIZE=pUVal+1, SET_VALUE=pData, SET_UVALUE=pUVal

	; Add horizontal shielding info if it exists
	if n_elements( hData ) gt 0 then begin
		widget_control, (*pInfo).wHShieldTable, $
				TABLE_YSIZE=hUVal+1, SET_VALUE=hData, SET_UVALUE=hUVal
	endif

	; Set floor above/below GUI info
	if keyword_set( levelIndex ) then $
		widget_control, (*pInfo).wLevelList, SET_DROPLIST_SELECT=levelIndex
	if keyword_set( shieldHeight ) then $
		widget_control, (*pInfo).wShieldHeightText, SET_VALUE=shieldHeight
	if keyword_set( aboveDist ) then $
		widget_control, (*pInfo).wAboveDistText, SET_VALUE=aboveDist
	if keyword_set( aboveThick ) then $
		widget_control, (*pInfo).wAboveThickText, SET_VALUE=aboveThick
	if keyword_set( boxPoint ) then $
		widget_control, (*pInfo).wBoxPointText, SET_VALUE=boxPoint
	if keyword_set( boxThick ) then $
		widget_control, (*pInfo).wBoxThickText, SET_VALUE=boxThick
	if keyword_set( belowDist ) then $
		widget_control, (*pInfo).wBelowDistText, SET_VALUE=belowDist
	if keyword_set( belowThick ) then $
		widget_control, (*pInfo).wBelowThickText, SET_VALUE=belowThick
	if keyword_set( sourceHeight ) then $
		widget_control, (*pInfo).wSourceHeightText, SET_VALUE=sourceHeight
	if keyword_set( aboveTargetHeight ) then $
		widget_control, (*pInfo).wAboveTargetHeightText, SET_VALUE=aboveTargetHeight
	if keyword_set( belowTargetHeight ) then $
		widget_control, (*pInfo).wBelowTargetHeightText, SET_VALUE=belowTargetHeight

	; Attach ROIs to the display
	shielding_guiAttachROIs, pInfo

	shielding_guiSetROIColours, pInfo

	; Update the coordinate values in the tables according to the current scale
	shielding_guiUpdateMeasurements, pInfo

	return, 1

end ; of shielding_guiOpenSession