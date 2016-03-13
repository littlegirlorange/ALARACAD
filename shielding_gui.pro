;====================================================================
;
;	PROGRAM		shielding_gui
;
;	DESCRIPTION	Reads bitmap-format floorplan images on which the
;				user can locate and describe radioactive sources,
;				shielding structures, regional occupancy factors and
;				other facility features such as floor-to-floor
;				height. Calculates doses to all points on the floor-
;				plan and to the floors above and below, based
;				primarily on the guidelines proposed by Madsen et al
;				2006. Calculations account for broad beam attenuation
;				and radionuclide energy and decay. Dose maps can be
;				displayed in grayscale or colour to facilitate
;				hotspot detection. Figures, parameters and results
;				tables can be saved for report generation.
;
;	VERSION		See shielding_gui_modification_list.txt
;
;	REQUIRED	MKgrROI__define.pro
;	MODULES		undoInfo__define.pro
;				textBox.pro
;				shielding_gui_user_prefs.pro
;
;	WRITTEN BY	Maggie Kusano, May 9, 2008
;
;====================================================================

@'undoInfo__define'
@'MKgrROI__define'
@'hcolorbar__define'
@'textBox'
@'contour_mask'
@'calcThickness'
@'shielding_guiMenu'
@'shielding_guiFileOpen'
@'shielding_guiFileSave'
@'shielding_guiCalculate'
@'shielding_guiToolsUndoRedo'
@'shielding_guiToolsCopyPaste'
@'shielding_guiSetQueryData'
@'shielding_guiModeSelector'
@'number_formatter'
@'format_float'

;--------------------------------------------------------------------
;
;    PURPOSE   Update the displayed image
;
pro shielding_guiUpdateImages, pInfo

 	if n_elements( *(*pInfo).pSeries0 ) gt 1 then begin

		if ( n_elements( *(*pInfo).pSeries1 )  gt 1 ) and $
		   ( total( *(*pInfo).pSeries1 ) gt 0 ) then begin

			; We have a dose image to display on top of the floorplan
			data0 = bytscl( (*(*pInfo).pSeries0)[*,*], $
					TOP=(*pInfo).topClr )

			data1 = bytarr( 4, (*pInfo).nPx, (*pInfo).nPy )

			if (*pInfo).displayMode eq 'gray-all' then begin

				; Load the grayscale colour table
				loadct, 0, /SILENT
				tvlct, r, g, b, /GET
				r = reverse(r)
				g = reverse(g)
				b = reverse(b)
				img = *(*pInfo).pSeries1
				img = bytscl( alog10( img ), TOP=(*pInfo).topClr, MIN=0, MAX=6.0 )
				data1[0, *, *] = r[img]
				data1[1, *, *] = g[img]
				data1[2, *, *] = b[img]
				data1[3, *, *] = img

				blend = [2,4]
				ticks = 'E+' + strtrim( indgen(7), 2 )
				units = 'uSv'

				(*pInfo).oTransPalette->setProperty, RED=r, GREEN=g, BLUE=b
				(*pInfo).oCBar->setProperty, $
						PALETTE=(*pInfo).oTransPalette, $
						COLOR=[0,0,0], TITLE=units, $
						MAJOR=n_elements(ticks), MINOR=0, $
						TEXT=ticks, HIDE=0

				(*pInfo).oFloorplan->setProperty, DATA=data0
				(*pInfo).oDosemap->setProperty, DATA=data1, HIDE=0, $
						BLEND_FUNCTION=blend

			endif else if (*pInfo).displayMode eq 'gray-high' then begin

				; Load the grayscale colour table
				loadct, 0, /SILENT
				tvlct, r, g, b, /GET
				r = reverse(r)
				g = reverse(g)
				b = reverse(b)

				img = *(*pInfo).pSeries1
				img = (img gt (*pInfo).dmThresh) * img
				img = bytscl( alog10(img), TOP=(*pInfo).topClr, MIN=0.0, MAX=6.0 )
				data1[0, *, *] = r[img]
				data1[1, *, *] = g[img]
				data1[2, *, *] = b[img]
				data1[3, *, *] = img

				blend = [2,4]
				ticks = 'E+' + strtrim( indgen(7), 2 )
				units = 'uSv'

				cutoff = alog((*pInfo).dmThresh)/alog(1000000)*(*pInfo).topClr
				r[0:cutoff] = (*pInfo).topClr
				g[0:cutoff] = (*pInfo).topClr
				b[0:cutoff] = (*pInfo).topClr
				(*pInfo).oTransPalette->setProperty, RED=r, GREEN=g, BLUE=b
				(*pInfo).oCBar->setProperty, $
						PALETTE=(*pInfo).oTransPalette, $
						COLOR=[0,0,0], TITLE=units, $
						MAJOR=n_elements(ticks), MINOR=0, $
						TEXT=ticks, HIDE=0

				(*pInfo).oFloorplan->setProperty, DATA=data0
				(*pInfo).oDosemap->setProperty, DATA=data1, HIDE=0, $
						BLEND_FUNCTION=blend

			endif else if (*pInfo).displayMode eq 'gray-high+occ' then begin

				; Load the grayscale colour table
				loadct, 0, /SILENT
				tvlct, r, g, b, /GET
				r = reverse(r)
				g = reverse(g)
				b = reverse(b)

				; Generate an occupancy factor image
				widget_control, (*pInfo).wRegionTable, GET_VALUE=rData, GET_UVALUE=nRs
				ofImg	= fltarr( (*pInfo).nPx, (*pInfo).nPy )
				ofMask	= fltarr( (*pInfo).nPx, (*pInfo).nPy )

				oROIGroup = (*pInfo).oROIGroup
				nROIs = oROIGroup->count()

				if nROIs gt 0 then begin

					eR = (*pInfo).eR

					for iR=0, nRs-1 do begin

						name = rData[eR.name, iR]
						occ  = rData[eR.occ, iR]
						oROI = (*pInfo).oROIGroup->getByName( name )

						if not obj_valid( oROI ) then continue

						oROI->getProperty, HIDE=bHide

						if not bHide then begin

							mask = oROI->computeMask( $
									DIMENSIONS=[(*pInfo).nPx, (*pInfo).nPy], $
									MASK_RULE=2 )
							mask = float( mask gt 0 )
							img = mask * occ

							union = mask and ofMask
							unionOfImg = (union*ofImg) > (union*img)
							ofImg = img * ( mask and not union ) $
								  + ofImg * ( ofMask and not union ) $
								  + unionOfImg
							ofMask = ofMask or mask

						endif

					endfor

				endif

				img = *(*pInfo).pSeries1 * ofImg
				img = (img gt (*pInfo).dmThresh) * img
				img = bytscl( alog10(img), TOP=(*pInfo).topClr, MIN=0, MAX=6.0 )
				data1[0, *, *] = r[img]
				data1[1, *, *] = g[img]
				data1[2, *, *] = b[img]
				data1[3, *, *] = img

				blend = [2,4]
				ticks = 'E+' + strtrim( indgen(7), 2 )
				units = 'uSv'

				cutoff = alog((*pInfo).dmThresh)/alog(1000000)*(*pInfo).topClr
				r[0:cutoff] = (*pInfo).topClr
				g[0:cutoff] = (*pInfo).topClr
				b[0:cutoff] = (*pInfo).topClr

				(*pInfo).oTransPalette->setProperty, RED=r, GREEN=g, BLUE=b
				(*pInfo).oCBar->setProperty, $
						PALETTE=(*pInfo).oTransPalette, $
						COLOR=[0,0,0], TITLE=units, $
						MAJOR=n_elements(ticks), MINOR=0, $
						TEXT=ticks, HIDE=0

				(*pInfo).oFloorplan->setProperty, DATA=data0
				(*pInfo).oDosemap->setProperty, DATA=data1, HIDE=0, $
						BLEND_FUNCTION=blend

			endif else if (*pInfo).displayMode eq 'colour' then begin

				; Load the mac style (multicolour) colour table
				loadct, 25, /SILENT
				tvlct, 255, 255, 255, 0
				tvlct, r, g, b, /GET

				img = *(*pInfo).pSeries1
				img = bytscl( alog10(img), TOP=(*pInfo).topClr-1, MIN=0, MAX=6.0 )
				data1[0, *, *] = r[img]
				data1[1, *, *] = g[img]
				data1[2, *, *] = b[img]

				blendMask = bytarr( (*pInfo).nPx, (*pInfo).nPy )
				indices = where( (data0 lt 50), nIndices )
				if nIndices gt 0 then $
					blendMask[indices] = 255B
				indices = where( (data0 ge 50) and (img eq 0), nIndices )
				if nIndices gt 0 then $
					blendMask[indices] = 0B
				indices = where( (data0 gt 50) and (img ne 0), nIndices )
				if nIndices gt 0 then $
					blendMask[indices] = 100B
				data1[3, *, *] = blendMask
				blend = [3,4]

				ticks = 'E+' + strtrim( indgen(7), 2 )
				units = 'uSv'

				(*pInfo).oTransPalette->setProperty, RED=r, GREEN=g, BLUE=b
				(*pInfo).oCBar->setProperty, $
						PALETTE=(*pInfo).oTransPalette, $
						COLOR=[0,0,0], TITLE=units, $
						MAJOR=n_elements(ticks), MINOR=0, $
						TEXT=ticks, HIDE=0

				(*pInfo).oFloorplan->setProperty, DATA=data0
				(*pInfo).oDosemap->setProperty, DATA=data1, HIDE=0, $
						BLEND_FUNCTION=blend

			endif else if (*pInfo).displayMode eq 'colour-high' then begin

				; Load the mac style (multicolour) colour table
				loadct, 25, /SILENT
				tvlct, 255, 255, 255, 0
				tvlct, r, g, b, /GET

				img = *(*pInfo).pSeries1
				img = (img gt (*pInfo).dmThresh) * img
				img = bytscl( alog10(img), TOP=(*pInfo).topClr-1, MIN=0, MAX=6.0 )
				data1[0, *, *] = r[img]
				data1[1, *, *] = g[img]
				data1[2, *, *] = b[img]

				blendMask = bytarr( (*pInfo).nPx, (*pInfo).nPy )
				indices = where( (data0 lt 50), nIndices )
				if nIndices gt 0 then $
					blendMask[indices] = 255B
				indices = where( (data0 ge 50) and (img eq 0), nIndices )
				if nIndices gt 0 then $
					blendMask[indices] = 0B
				indices = where( (data0 gt 50) and (img ne 0), nIndices )
				if nIndices gt 0 then $
					blendMask[indices] = 100B
				data1[3, *, *] = blendMask
				blend = [3,4]

				ticks = 'E+' + strtrim( indgen(7), 2 )
				units = 'uSv'

				cutoff = alog((*pInfo).dmThresh)/alog(1000000)*(*pInfo).topClr
				r[0:cutoff] = (*pInfo).topClr
				g[0:cutoff] = (*pInfo).topClr
				b[0:cutoff] = (*pInfo).topClr

				(*pInfo).oTransPalette->setProperty, RED=r, GREEN=g, BLUE=b
				(*pInfo).oCBar->setProperty, $
						PALETTE=(*pInfo).oTransPalette, $
						COLOR=[0,0,0], TITLE=units, $
						MAJOR=n_elements(ticks), MINOR=0, $
						TEXT=ticks, HIDE=0

				(*pInfo).oFloorplan->setProperty, DATA=data0
				(*pInfo).oDosemap->setProperty, DATA=data1, HIDE=0, $
						BLEND_FUNCTION=blend

			endif else if (*pInfo).displayMode eq 'colour-high+occ' then begin

				; Load the mac style (multicolour) colour table
				loadct, 25, /SILENT
				tvlct, 255, 255, 255, 0
				tvlct, r, g, b, /GET

				; Generate an occupancy factor image
				widget_control, (*pInfo).wRegionTable, GET_VALUE=rData, GET_UVALUE=nRs
				ofImg	= fltarr( (*pInfo).nPx, (*pInfo).nPy )
				ofMask	= fltarr( (*pInfo).nPx, (*pInfo).nPy )
				doseImg = *(*pInfo).pSeries1

				oROIGroup = (*pInfo).oROIGroup
				nROIs = oROIGroup->count()

				if nROIs gt 0 then begin

					eR = (*pInfo).eR

					for iR=0, nRs-1 do begin

						name = rData[eR.name, iR]
						occ  = rData[eR.occ, iR]
						oROI = (*pInfo).oROIGroup->getByName( name )

						if obj_valid( oROI ) then begin

							mask = oROI->computeMask( $
									DIMENSIONS=[(*pInfo).nPx, (*pInfo).nPy], $
									MASK_RULE=2 )
							mask = float( mask gt 0 )
							img = mask * occ

							union = mask and ofMask
							unionOfImg = (union*ofImg) > (union*img)
							ofImg = img * ( mask and not union ) $
								  + ofImg * ( ofMask and not union ) $
								  + unionOfImg
							ofMask = ofMask or mask

						endif

					endfor

				endif

				img = *(*pInfo).pSeries1 * ofImg
				img = (img gt (*pInfo).dmThresh) * img
				img = bytscl( alog10(img), TOP=(*pInfo).topClr-1, MIN=0, MAX=6.0 )
				data1[0, *, *] = r[img]
				data1[1, *, *] = g[img]
				data1[2, *, *] = b[img]

				blendMask = bytarr( (*pInfo).nPx, (*pInfo).nPy )
				indices = where( (data0 lt 50), nIndices )
				if nIndices gt 0 then $
					blendMask[indices] = 255B
				indices = where( (data0 ge 50) and (img eq 0), nIndices )
				if nIndices gt 0 then $
					blendMask[indices] = 0B
				indices = where( (data0 gt 50) and (img ne 0), nIndices )
				if nIndices gt 0 then $
					blendMask[indices] = 100B
				data1[3, *, *] = blendMask
				blend = [3,4]

				ticks = 'E+' + strtrim( indgen(7), 2 )
				units = 'uSv'

				cutoff = alog((*pInfo).dmThresh)/alog(1000000)*(*pInfo).topClr
				r[0:cutoff] = (*pInfo).topClr
				g[0:cutoff] = (*pInfo).topClr
				b[0:cutoff] = (*pInfo).topClr

				(*pInfo).oTransPalette->setProperty, RED=r, GREEN=g, BLUE=b
				(*pInfo).oCBar->setProperty, $
						PALETTE=(*pInfo).oTransPalette, $
						COLOR=[0,0,0], TITLE=units, $
						MAJOR=n_elements(ticks), MINOR=0, $
						TEXT=ticks, HIDE=0

				(*pInfo).oFloorplan->setProperty, DATA=data0
				(*pInfo).oDosemap->setProperty, DATA=data1, HIDE=0, $
						BLEND_FUNCTION=blend

			endif else if (*pInfo).displayMode eq 'rois' then begin

				; Load the mac style (multicolour) colour table
				loadct, 25, /SILENT
				tvlct, 255, 255, 255, 0
				tvlct, r, g, b, /GET

				; Generate an occupancy factor image
				widget_control, (*pInfo).wRegionTable, GET_VALUE=rData, GET_UVALUE=nRs
				ofImg	= fltarr( (*pInfo).nPx, (*pInfo).nPy )
				ofMask	= fltarr( (*pInfo).nPx, (*pInfo).nPy )
				img		= fltarr( (*pInfo).nPx, (*pInfo).nPy )
				doseImg = *(*pInfo).pSeries1

				nROIs = (*pInfo).oROIGroup->count()

				if nROIs gt 0 then begin
					eR = (*pInfo).eR
					for iR=0, nRs-1 do begin
						name = rData[eR.name, iR]
						occ  = rData[eR.occ, iR]
						oROI = (*pInfo).oROIGroup->getByName( name )

						if obj_valid( oROI ) then begin

							rMask = oROI->computeMask( $
									DIMENSIONS=[(*pInfo).nPx, (*pInfo).nPy], $
									MASK_RULE=2 )
							rMask = float( rMask gt 0 )
							rOFImg = rMask * occ
							rShieldMask = ( rMask * rOFImg * doseImg ) gt (*pInfo).dmThresh
							if total( rShieldMask ) lt 3 then continue

							oSubROIGroup = contour_mask( rShieldMask, /ROIS )
							if not obj_valid( oSubROIGroup ) then continue
							nSubROIs = oSubROIGroup->count()

							for iSubROI=0, nSubROIs-1 do begin

								oSubROI = oSubROIGroup->get( POSITION=iSubROI )
								subMask = oSubROI->computeMask( $
										DIMENSIONS=[(*pInfo).nPx, (*pInfo).nPy], $
										MASK_RULE=2 )
								subMask = float( subMask gt 0 )
								subDoseImg = doseImg * subMask * rOFImg
								maxDose = max( subDoseImg )
								calcThickness, maxDose, 1, (*pInfo).dmThresh, LEAD=dLead ; in cm

								bOk = oSubROI->computeGeometry( CENTROID=centroid )
								oSubROI->getProperty, DATA=data
								oROI = obj_new( 'IDLgrROI', DATA=data, $
										COLOR=[0,0,255], STYLE=2, $
										NAME=strtrim( string( dLead, FORMAT='(F4.2)' ), 2 )+' cm' )
								oDispROI = obj_new( 'MKgrROI', DATA=data, $
										COLOR=[0,0,255], STYLE=2, THICK=(*pInfo).roiThick, $
										TEXT_SIZE=(*pInfo).textSize, $
										NAME=strtrim( string( dLead, FORMAT='(F4.2)' ), 2 )+' cm', $
										TEXT_ANCHOR=centroid[0:1] )

								(*pInfo).oROIGroup->add, oROI
								(*pInfo).oDispROIGroup->add, oDispROI

								img = (subMask * dLead) + (img * (not subMask))

							endfor

							obj_destroy, oSubROIGroup

						endif

					endfor

				endif
;===============================================


;				if nROIs gt 0 then begin
;
;					eR = (*pInfo).eR
;
;					for iR=0, nRs-1 do begin
;
;						name = rData[eR.name, iR]
;						occ  = rData[eR.occ, iR]
;						oROI = (*pInfo).oROIGroup->getByName( name )
;
;						if obj_valid( oROI ) then begin
;
;							rMask = oROI->computeMask( $
;									DIMENSIONS=[(*pInfo).nPx, (*pInfo).nPy], $
;									MASK_RULE=2 )
;							rMask = float( rMask gt 0 )
;							rOFImg = rMask * occ
;
;							union = rMask and ofMask
;							unionOfImg = (union*ofImg) > (union*rOFImg)
;							ofImg = rOFImg * ( rMask and not union ) $
;								  + ofImg * ( ofMask and not union ) $
;								  + unionOfImg
;							ofMask = ofMask or rMask
;
;						endif
;
;					endfor
;
;					for iR=0, nRs-1 do begin
;
;						name = rData[eR.name, iR]
;						occ  = rData[eR.occ, iR]
;						oROI = (*pInfo).oROIGroup->getByName( name )
;
;						if obj_valid( oROI ) then begin
;
;							rMask = oROI->computeMask( $
;									DIMENSIONS=[(*pInfo).nPx, (*pInfo).nPy], $
;									MASK_RULE=2 )
;							rMask = float( rMask gt 0 )
;							rShieldMask = ( rMask * ofImg * *(*pInfo).pSeries1 ) gt 50
;							if total( rShieldMask ) lt 3 then continue
;
;							oSubROIGroup = contour_mask( rShieldMask, /ROIS )
;							if not obj_valid( oSubROIGroup ) then continue
;							nSubROIs = oSubROIGroup->count()
;
;							for iSubROI=0, nSubROIs-1 do begin
;
;								oSubROI = oSubROIGroup->get( POSITION=iSubROI )
;								subMask = oSubROI->computeMask( $
;										DIMENSIONS=[(*pInfo).nPx, (*pInfo).nPy], $
;										MASK_RULE=2 )
;								subMask = float( subMask gt 0 )
;								subDoseImg = (*(*pInfo).pSeries1) * subMask * ofImg
;								maxDose = max( subDoseImg )
;								calcThickness, maxDose, 1, 50, LEAD=dLead ; in cm
;
;								bOk = oSubROI->computeGeometry( CENTROID=centroid )
;								oSubROI->getProperty, DATA=data
;								oROI = obj_new( 'IDLgrROI', DATA=data, $
;										COLOR=[0,0,255], STYLE=2, $
;										NAME=strtrim( string( dLead, FORMAT='(F4.2)' ), 2 )+' cm' )
;								oDispROI = obj_new( 'MKgrROI', DATA=data, $
;										COLOR=[0,0,255], STYLE=2, $
;										NAME=strtrim( string( dLead, FORMAT='(F4.2)' ), 2 )+' cm', $
;										TEXT_ANCHOR=centroid[0:1] )
;
;								(*pInfo).oROIGroup->add, oROI
;								(*pInfo).oDispROIGroup->add, oDispROI
;
;								img = (subMask * dLead) + (img * (not subMask))
;
;							endfor
;
;							obj_destroy, oSubROIGroup
;
;						endif
;
;					endfor
;
;				endif

				img = bytscl( img, TOP=(*pInfo).topClr-1, MIN=0, MAX=2.0 )

				data1[0, *, *] = r[img]
				data1[1, *, *] = g[img]
				data1[2, *, *] = b[img]

				blendMask = bytarr( (*pInfo).nPx, (*pInfo).nPy )
				leadIndices = where( img gt 0, nIndices )
				if nIndices gt 0 then $
					blendMask[leadIndices] = 1B
				data1[3, *, *] = blendMask * 200B

				blend = [3,4]
				ticks = strtrim( string( indgen(11)*0.2, FORMAT='(F3.1)' ), 2 )
				units = 'cm Pb'

				(*pInfo).oTransPalette->setProperty, RED=r, GREEN=g, BLUE=b
				(*pInfo).oCBar->setProperty, $
						PALETTE=(*pInfo).oTransPalette, $
						COLOR=[0,0,0], TITLE=units, $
						MAJOR=n_elements(ticks), MINOR=0, $
						TEXT=ticks, HIDE=0

				(*pInfo).oFloorplan->setProperty, DATA=data0
				(*pInfo).oDosemap->setProperty, DATA=data1, HIDE=0, $
						BLEND_FUNCTION=blend

			endif else if (*pInfo).displayMode eq 'none' then begin

				(*pInfo).oDosemap->setProperty, HIDE=1
				(*pInfo).oCBar->setProperty, HIDE=1

			endif

		endif else begin

			; We're only displaying the floorplan
			data0 = bytscl( (*(*pInfo).pSeries0)[*,*], $
					TOP=(*pInfo).topClr )
			(*pInfo).oFloorplan->setProperty, DATA=data0, HIDE=0
			(*pInfo).oDosemap->setProperty, HIDE=1
			(*pInfo).oCBar->setProperty, HIDE=1

		endelse

		(*pInfo).oWindow->draw, (*pInfo).oViewGroup

	endif

end ; shielding_guiUpdateImages


;--------------------------------------------------------------------
;
;    PURPOSE   Update the view
;
pro shielding_guiUpdateViews, pInfo

	; Recalculate viewplane according to zoom and pan
	nPx = (*pInfo).nPx
	nPy = (*pInfo).nPy
	vpSizeX = (*pInfo).vpSize[0]
	vpSizeY = (*pInfo).vpSize[1]
	ZF = (*pInfo).zoomFactor

	widget_control, (*pInfo).wFloorplanScaleText, GET_VALUE=value
	fpScale = float(value[0])

	imgWHRatio = float(nPx)/float(nPy)
	vpWHRatio = float(vpSizeX)/float(vpSizeY)

	if imgWHRatio gt vpWHRatio then begin

		; The image is wider than the viewport
		imgVp = [(*pInfo).cPoint[0]-nPx/(2*ZF), $	; x (img coords)
			  (*pInfo).cPoint[1]-nPy/(2*ZF), $ 		; y
			  nPx/ZF, $								; width
			  vpSizeY*(*pInfo).vp2imgScale[1]/ZF]	; height

	endif else begin

		; The image is taller than the viewport
		imgVp = [(*pInfo).cPoint[0]-nPx/(2*ZF), $	; x (img coords)
			  (*pInfo).cPoint[1]-nPy/(2*ZF), $		; y
			  vpSizeX*(*pInfo).vp2imgScale[0]/ZF, $	; width
			  nPy/ZF]								; height

	endelse

	(*pInfo).oView->setProperty, VIEWPLANE=imgVp

	shielding_guiUpdateRuler, pInfo
	(*pInfo).oWindow->draw, (*pInfo).oViewGroup

end ; shielding_guiUpdateViews


;--------------------------------------------------------------------
;
;    PURPOSE   Attach ROIs to the viewport
;
pro shielding_guiAttachROIs, $
	pInfo

	; Return if we don't have a valid ROI group or if we don't $
	; have any ROIs to add
	oROIGroup = (*pInfo).oROIGroup
	if obj_valid( oROIGroup ) then begin
		oROIs = oROIGroup->get( /ALL, COUNT=nROIs )
		if nROIs eq 0 then return
	endif else begin
		return
	endelse

	; Desensitize the bases during reconstruction
	widget_control, (*pInfo).barBase, SENSITIVE=0
	widget_control, (*pInfo).wSubBase, SENSITIVE=0

	; Copy ROIs and attach to the displays
	for i=0, nROIs-1 do begin
		shielding_guiAttachROI, pInfo, oROIs[i]
	endfor

	(*pInfo).oWindow->draw, (*pInfo).oViewGroup

	; Resensitze the bases when reconstruction is done
    widget_control, (*pInfo).barBase, SENSITIVE=1
    widget_control, (*pInfo).wSubBase, SENSITIVE=1

end ; shielding_guiAttachROIs


;--------------------------------------------------------------------
;
;    PURPOSE   Attach a ROI to the viewport
;
pro shielding_guiAttachROI, $
	pInfo, $
	oROI

	if not obj_valid( oROI ) then return

	; Desensitize the bases during reconstruction
	widget_control, (*pInfo).barBase, SENSITIVE=0
	widget_control, (*pInfo).wSubBase, SENSITIVE=0

	oROI->getProperty, NAME=name, DATA=data, $
			COLOR=color, SYMBOL=oSym, HIDE=hide

	oROIGroup = (*pInfo).oROIGroup
	oDispROIGroup = (*pInfo).oDispROIGroup
	bContained = oROIGroup->isContained( oROI, POS=pos )
	if not bContained then return

	; Destroy it if it's a maxROI
	if obj_valid( oSym ) then begin

		oSym->getProperty, DATA=symType
		if symType eq 7 then begin ; x
			oROIGroup->remove, oROI
			obj_destroy, oSym
			obj_destroy, oROI
			return
		endif

	endif

	oDispROI = obj_new( 'MKgrROI', NAME=name, $
			DATA=data, COLOR=color, SYMBOL=oSym, THICK=(*pInfo).roiThick, $
			TEXT_SIZE=(*pInfo).textSize, HIDE=hide, TEXT_HIDE=hide )
			oDispROIGroup->add, oDispROI, POS=pos

	; Rebuild maxROI if its a region
	prefix = (strsplit( name, '_', /EXTRACT ))[0]
	if prefix eq 'R' and total( *(*pInfo).pSeries1 ) gt 0 then begin
		shielding_guiFindMax, pInfo, oROI
	endif

	(*pInfo).oWindow->draw, (*pInfo).oViewGroup

	; Resensitze the bases when reconstruction is done
    widget_control, (*pInfo).barBase, SENSITIVE=1
    widget_control, (*pInfo).wSubBase, SENSITIVE=1

end ; shielding_guiAttachROI


;--------------------------------------------------------------------
;
;    PURPOSE   Detach ROIs from the viewport
;
pro shielding_guiDetachROIs, pInfo

	; Desensitize the bases during reconstruction
	widget_control, (*pInfo).barBase, SENSITIVE=0
	widget_control, (*pInfo).wSubBase, SENSITIVE=0

	; Abandon half drawn ROI
	shielding_guiAbandonROI, pInfo

	oDispROIGroup = (*pInfo).oDispROIGroup
	oDispCurROI = (*pInfo).oDispCurROI
	oVertexModel = (*pInfo).oVertexModel

	; Unselect ROIs
	if obj_valid( oDispCurROI ) then begin
		oDispCurROI->setProperty, COLOR=[255,0,0]
		oDispCurROI = obj_new()
	endif
	oVertexModel->setProperty, HIDE=1

	; Destroy maxROIs
	oROIGroup = (*pInfo).oROIGroup
	if obj_valid( oROIGroup ) then begin
		oROIs = oROIGroup->get( /ALL, COUNT=nROIs )
		for i=0, nROIs-1 do begin
			if obj_valid( oROIs[i] ) then begin
				oROIs[i]->getProperty, UVALUE=oMaxROI
				if obj_valid( oMaxROI ) then begin
					oMaxROI->getProperty, SYMBOL=oSym
					if obj_valid( oSym ) then obj_destroy, oSym
					oROIGroup->remove, oMaxROI
					obj_destroy, oMaxROI
				endif
			endif
		endfor
	endif

	; Remove ROIs
	oROIs = oDispROIGroup->get( /ALL, COUNT=nROIs )
	for i=0, nROIs-1 do begin
		(*pInfo).oModel->remove, oROIs[i]
		oDispROIGroup->remove, oROIs[i]
		obj_destroy, oROIs[i]
	endfor

	; Redraw
	(*pInfo).oWindow->draw, (*pInfo).oViewGroup

	(*pInfo).oCurROI = obj_new()
	(*pInfo).curVertIndex = -1L
	(*pInfo).curScrnCoords = [0,0]

	; Remove data from tables
	eS = (*pInfo).eS
	widget_control, (*pInfo).wShieldTable, GET_VALUE=data
	rows = where( data[eS.name,*] ne '', nRows )
	if nRows ne 0 then begin
		widget_control, (*pInfo).wShieldTable, $
				USE_TABLE_SELECT=[eS.name,rows[0],eS.name,rows[nRows-1]], $
				/DELETE_ROWS
	endif
	widget_control, (*pInfo).wShieldTable, SET_UVALUE=0

	eP = (*pInfo).eP
	widget_control, (*pInfo).wSourceTable, GET_VALUE=data
	rows = where( data[eP.name,*] ne '', nRows )
	if nRows ne 0 then begin
		widget_control, (*pInfo).wSourceTable, $
				USE_TABLE_SELECT=[eP.name,rows[0],eP.name,rows[nRows-1]], $
				/DELETE_ROWS
	endif
	widget_control, (*pInfo).wSourceTable, SET_UVALUE=0

	eR = (*pInfo).eR
	widget_control, (*pInfo).wRegionTable, GET_VALUE=data
	rows = where( data[eR.name,*] ne '', nRows )
	if nRows ne 0 then begin
		widget_control, (*pInfo).wRegionTable, $
				USE_TABLE_SELECT=[eR.name,rows[0],eR.name,rows[nRows-1]], $
				/DELETE_ROWS
	endif
	widget_control, (*pInfo).wRegionTable, SET_UVALUE=0

	; Resensitze the bases when reconstruction is done
    widget_control, (*pInfo).barBase, SENSITIVE=1
    widget_control, (*pInfo).wSubBase, SENSITIVE=1

end ; shielding_guiDetachROIs


;--------------------------------------------------------------------
;
;    PURPOSE  The scale has changed.  Update displayed measurements.
;
pro shielding_guiUpdateMeasurements, pInfo

	; Get new scale
	widget_control, (*pInfo).wFloorplanScaleText, GET_VALUE=value
	scale = float(value[0])

	; Get old data (scaled coordinates)
	widget_control, (*pInfo).wSourceTable, GET_VALUE=pData
	widget_control, (*pInfo).wShieldTable, GET_VALUE=sData
	widget_control, (*pInfo).wHShieldTable, GET_VALUE=hData
	widget_control, (*pInfo).wRegionTable, GET_VALUE=rData

	; Get ROI objects and their pixel coordinates
	oROIGroup = (*pInfo).oROIGroup
	if not obj_valid( oROIGroup ) then return
	oROIs = oROIGroup->get( /ALL, COUNT=nROIs )

	for iROI=0, nROIs-1 do begin

		oROIs[iROI]->getProperty, NAME=name, DATA=data
		coordsInM = data*scale
		strCoordsInM = format_float( coordsInM, DEC=2 )
		prefix = (strsplit( name, '_', /EXTRACT ))[0]

		case prefix of
		'P' : begin
			eP = (*pInfo).eP
			rows = where( pData[eP.name,*] eq name, nRows )
			for i=0, nRows-1 do begin
				widget_control, (*pInfo).wSourceTable, $
						USE_TABLE_SELECT=[eP.x,rows[i],eP.y,rows[i]], $
						SET_VALUE=[strCoordsInM[0],strCoordsInM[1]]
			endfor
		end ; 'P'
		'S' : begin
			eS = (*pInfo).eS
			rows = where( sData[eS.name,*] eq name, nRows )
			for i=0, nRows-1 do begin
				widget_control, (*pInfo).wShieldTable, $
						USE_TABLE_SELECT=[eS.x1,rows[i],eS.y2,rows[i]], $
						SET_VALUE=[strCoordsInM[0],strCoordsInM[1], $
								   strCoordsInM[3],strCoordsInM[4]]
			endfor
		end ; 'S'
		'H' : begin
			eH = (*pInfo).eH
			rows = where( hData[eH.name,*] eq name, nRows )
			for i=0, nRows-1 do begin
				widget_control, (*pInfo).wHShieldTable, $
						USE_TABLE_SELECT=[eH.x1,rows[i],eH.y4,rows[i]], $
						SET_VALUE=[strCoordsInM[0],strCoordsInM[1], $
								   strCoordsInM[3],strCoordsInM[4], $
								   strCoordsInM[6],strCoordsInM[7], $
								   strCoordsInM[9],strCoordsInM[10]]
			endfor
		end ; 'H'
		'R' : begin
			eR = (*pInfo).eR
			rows = where( rData[eR.name,*] eq name, nRows )
			for i=0, nRows-1 do begin
				widget_control, (*pInfo).wRegionTable, $
						USE_TABLE_SELECT=[eR.x1,rows[i],eR.y4,rows[i]], $
						SET_VALUE=[strCoordsInM[0],strCoordsInM[1], $
								   strCoordsInM[3],strCoordsInM[4], $
								   strCoordsInM[6],strCoordsInM[7], $
								   strCoordsInM[9],strCoordsInM[10]]
			endfor
		end ; 'R'
		else :
		endcase

	endfor

end ; of shielding_guiUpdateMeasurements


;--------------------------------------------------------------------
;
;    PURPOSE  Pop up a textbox with the length of the currently
;             selected ROI.
;
pro shielding_guiPrintLength, pInfo, oROI

	; Get current scale
	widget_control, (*pInfo).wFloorplanScaleText, GET_VALUE=value
	scale = float(value[0])

	oROI->getProperty, NAME=name, DATA=data
	prefix = (strsplit( name, '_', /EXTRACT ))[0]
	if prefix ne 'S' then return

	data *= scale
	length = sqrt( (data[0,0]-data[0,1])^2 + (data[1,0]-data[1,1])^2 )
	length = format_float( length, DECIMAL=2 )

	void = dialog_message( /INFO, TITLE=name, length + ' m' )

end ; of shielding_guiPrintLength


;--------------------------------------------------------------------
;
;    PURPOSE  Change the colour of a ROI
;
;pro shielding_guiSetROIColour, $
;	pInfo, $
;	oROI, $
;	COLOR=color
;
;	if not obj_valid( oROI ) then return
;	if n_elements( color ) eq 0 then return
;
;	; Get the corresponding display ROI
;	oROIGroup = (*pInfo).oROIGroup
;	bContained = oROIGroup->isContained( oROI, POSITION=pos )
;	if not bContained then return
;	oDispROI = (*pInfo).oDispROIGroup->get( POSITION=pos )
;
;	; Set the color
;	oROI->setProperty, COLOR=color
;	oDispROI->setProperty, COLOR=color
;
;	; Redisplay
;	(*pInfo).oWindow->draw, (*pInfo).oViewGroup
;
;end ; of shielding_guiSetROIColour


;--------------------------------------------------------------------
;
;    PURPOSE  Colour code all the ROIs on the image
;
pro shielding_guiSetROIColours, $
	pInfo

	oROIGroup = (*pInfo).oROIGroup
	oROIs = oROIGroup->get( /ALL, COUNT=nROIs )
	oDispROIs = (*pInfo).oDispROIGroup->get( /ALL, COUNT=nDispROIs )
	if nROIs ne nDispROIs then return

	; Get structural ROI table info
	widget_control, (*pInfo).wShieldTable, GET_VALUE=sTable
	widget_control, (*pInfo).wHShieldTable, GET_VALUE=hTable

	eS = (*pInfo).eS
	eH = (*pInfo).eH

	for i=0, nROIs-1 do begin

		oROIs[i]->getProperty, NAME=name, SYMBOL=oSym, UVALUE=oMaxROI, THICK=lineThick
		oDispROIs[i]->getProperty, UVALUE=oDispMaxROI, THICK=lineThick
		prefix = (strsplit( name, '_', /EXTRACT ))[0]
		color = 0

		case prefix of
			'P': begin
				color = [0,200,0]		; orange
			end
			'R': begin
				color = [0,0,255]		; blue
			end
			'S': begin
				rows = where( sTable[eS.name,*] eq name, nRows )
				if nRows eq 1 then begin
					material = sTable[eS.material,rows[0]]
					case material of
						'Lead': begin
						    color = [255,0,0] 		; red
						    thickness = float(sTable[eS.thickness, rows[0]])
						    if (*pInfo).modality eq 'PET' then begin
						        if (thickness lt 0.64) then begin ; < 1/4 inch
						            color = [255, 165, 0]   ; orange
						            lineThick = 2
						        endif else if (thickness ge 0.64) && (thickness lt 1.28) then begin ; 1/4 inch to <1/2 inch
						            color = [255, 140, 0]   ; dark orange
						            lineThick = 3
						        endif else if (thickness ge 1.28) && (thickness lt 2.54) then begin     ; 1/2 inch to <1 inch
						            color = [255, 69, 0]    ; orange red
						            lineThick = 4
						        endif else if (thickness ge 2.54) && (thickness lt 2.54*1.5) then begin     ; 1 inch to < 1.5 inches
						            color = [255, 0, 0]     ; red
						            lineThick = 5
						        endif else begin
						            color = [139, 0, 0]     ; dark red
						            lineThick = 6
						        endelse
						     endif else begin
						        if (thickness le 0.08) then begin ; <= 1/32 in
						            color = [255, 165, 0]   ; orange
						            lineThick = 2
						        endif else if (thickness gt 0.08) && (thickness le 0.16) then begin ; 1/16 in
						            color = [255, 140, 0]   ; dark orange
						            lineThick = 3
						        endif else if (thickness gt 0.16) && (thickness le 0.32) then begin ; 1/8 in
						            color = [255, 69, 0]    ; orange red
						            lineThick = 4
						        endif else if (thickness gt 0.32) && (thickness le 0.64) then begin ; 1/4 in
						            color = [255, 0, 0]     ; red
						            lineThick = 5
						        endif else if (thickness gt 0.64) && (thickness le 1.28) then begin ; 1/2 in
						            color = [139, 0, 0]     ; dark red
						            lineThick = 6
						        endif else if (thickness gt 1.28) && (thickness le 2.54) then begin ; 1 in
						            color = [139, 0, 0]     ; dark red
						            lineThick = 7
						        endif else begin
						            color = [128, 0, 0]     ; maroon
						            lineThick = 8
						        endelse
						    endelse
						endcase
						'Concrete':	color = [160,32,240]	; purple
						else:		color = [255,0,0]		; red by default
					endcase
				endif else begin
					; Multiple materials
					color = [255,192,203]	; pink
				endelse
			end
			'H': begin
				rows = where( hTable[eH.name,*] eq name, nRows )
				if nRows eq 1 then begin
					material = hTable[eH.material,rows[0]]
					case material of
						'Lead': 	color = [255,0,0] 		; red
						'Concrete':	color = [160,32,240]	; purple
						else:		color = [255,0,0]		; red by default
					endcase
				endif else begin
					; Multiple materials
					color = [255,192,203]	; pink
				endelse
			end
			else: color = [0,0,255] ; blue (no prefix->maxROI)
		endcase

		; Set the colour
		if n_elements( color ) gt 1 then begin
			oROIs[i]->setProperty, COLOR=color, THICK=lineThick
			if obj_valid( oMaxROI ) then begin
				oMaxROI->getProperty, SYMBOL=oSym
				oSym->setProperty, COLOR=color
				oMaxROI->setProperty, COLOR=color
			endif
			oDispROIs[i]->setProperty, COLOR=color, THICK=lineThick
			if obj_valid( oDispMaxROI ) then begin
				oDispMaxROI->getProperty, SYMBOL=oSym
				oSym->setProperty, COLOR=color
				oDispMaxROI->setProperty, COLOR=color
			endif
		endif

	endfor

end ; of shielding_guiSetROIColours


;--------------------------------------------------------------------
;
;    PURPOSE  Set the colour and thickness of the ROI based on type
;             (and material and thickness for shield ROIs)
;
pro shielding_guiSetROIColour, $
	pInfo, $
	oROI

	if not obj_valid( oROI ) then return

	; Get the corresponding display ROI
	oROIGroup = (*pInfo).oROIGroup
	bContained = oROIGroup->isContained( oROI, POSITION=pos )
	if not bContained then return
	oDispROI = (*pInfo).oDispROIGroup->get( POSITION=pos )

	; Get structural ROI table info
	widget_control, (*pInfo).wShieldTable, GET_VALUE=sTable
	widget_control, (*pInfo).wHShieldTable, GET_VALUE=hTable

	eS = (*pInfo).eS
	eH = (*pInfo).eH

    oROI->getProperty, NAME=name, SYMBOL=oSym, UVALUE=oMaxROI, THICK=lineThick, COLOR=color
    oDispROI->getProperty, UVALUE=oDispMaxROI, THICK=lineThick, COLOR=color
    prefix = (strsplit( name, '_', /EXTRACT ))[0]

    case prefix of
	    'P': begin
			color = [0,200,0]		; green
		end
		'R': begin
			color = [0,0,255]		; blue
		end
		'S': begin
			rows = where( sTable[eS.name,*] eq name, nRows )
			if nRows eq 1 then begin
				material = sTable[eS.material,rows[0]]
				case material of
					'Lead': begin
					    color = [255,0,0] 		; red
					    thickness = float(sTable[eS.thickness, rows[0]])
					    if (*pInfo).modality eq 'PET' then begin
					        if (thickness lt 0.64) then begin ; < 1/4 inch
					            color = [255, 165, 0]   ; orange
					            lineThick = 2
					        endif else if (thickness ge 0.64) && (thickness lt 1.28) then begin ; 1/4 inch to <1/2 inch
					            color = [255, 140, 0]   ; dark orange
					            lineThick = 3
					        endif else if (thickness ge 1.28) && (thickness lt 2.54) then begin     ; 1/2 inch to <1 inch
					            color = [255, 69, 0]    ; orange red
					            lineThick = 4
					        endif else if (thickness ge 2.54) && (thickness lt 2.54*1.5) then begin     ; 1 inch to < 1.5 inches
					            color = [255, 0, 0]     ; red
					            lineThick = 5
					        endif else begin
					            color = [139, 0, 0]     ; dark red
					            lineThick = 6
					        endelse
					     endif else begin
					        if (thickness le 0.08) then begin ; <= 1/32 in
					            color = [255, 165, 0]   ; orange
					            lineThick = 2
					        endif else if (thickness gt 0.08) && (thickness le 0.16) then begin ; 1/16 in
					            color = [255, 140, 0]   ; dark orange
					            lineThick = 3
					        endif else if (thickness gt 0.16) && (thickness le 0.32) then begin ; 1/8 in
					            color = [255, 69, 0]    ; orange red
					            lineThick = 4
					        endif else if (thickness gt 0.32) && (thickness le 0.64) then begin ; 1/4 in
					            color = [255, 0, 0]     ; red
					            lineThick = 5
					        endif else if (thickness gt 0.64) && (thickness le 1.28) then begin ; 1/2 in
					            color = [139, 0, 0]     ; dark red
					            lineThick = 6
					        endif else if (thickness gt 1.28) && (thickness le 2.54) then begin ; 1 in
					            color = [139, 0, 0]     ; dark red
					            lineThick = 7
					        endif else begin
					            color = [128, 0, 0]     ; maroon
					            lineThick = 8
					        endelse
					    endelse
					end
					'Concrete':	color = [160,32,240]	; purple
					else:		color = [255,0,0]		; red by default
				endcase
			endif else begin
				; Multiple materials
				color = [255,192,203]	; pink
			endelse
		end
		'H': begin
			rows = where( hTable[eH.name,*] eq name, nRows )
			if nRows eq 1 then begin
				material = hTable[eH.material,rows[0]]
				case material of
					'Lead': 	color = [255,0,0] 		; red
					'Concrete':	color = [160,32,240]	; purple
					else:		color = [255,0,0]		; red by default
				endcase
			endif else begin
				; Multiple materials
				color = [255,192,203]	; pink
			endelse
		end
		else: color = [0,0,255] ; blue (no prefix->maxROI)
	endcase

	; Set the colour
	if n_elements( color ) gt 1 then begin
		oROI->setProperty, COLOR=color, THICK=lineThick
		if obj_valid( oMaxROI ) then begin
			oMaxROI->getProperty, SYMBOL=oSym
			oSym->setProperty, COLOR=color
			oMaxROI->setProperty, COLOR=color
		endif
		oDispROI->setProperty, COLOR=color, THICK=lineThick
		if obj_valid( oDispMaxROI ) then begin
			oDispMaxROI->getProperty, SYMBOL=oSym
			oSym->setProperty, COLOR=color
			oDispMaxROI->setProperty, COLOR=color
		endif
	endif

	; Redisplay
	(*pInfo).oWindow->draw, (*pInfo).oViewGroup

end ; of shielding_guiSetROIColour


;--------------------------------------------------------------------
;
;    PURPOSE  Get object references to specified ROI type
;
function shielding_guiGetROIs, pInfo, $
	SOURCES		= sources, $
	SHIELDS		= shields, $
	HSHIELDS	= hShields, $
	REGIONS		= regions, $
	QUERY		= query, $
	NAMES		= names, $
	DESCRIPTIONS	= descs, $
	HIDE		= hides, $
	COUNT		= nROIs

	catch, err
	if err ne 0 then begin
		catch, /CANCEL
		nROIs = 0
		return, -1L
	endif

	nROIs = 0
	oAllROIs = (*pInfo).oROIGroup->get( /ALL, COUNT=nAllROIs )

	if keyword_set( sources ) then begin
		prefix = 'P'
	endif else if keyword_set( regions ) then begin
		prefix = 'R'
	endif else if keyword_set( shields ) then begin
		prefix = 'S'
	endif else if keyword_set( hShields ) then begin
		prefix = 'H'
	endif else if keyword_set( query ) then begin
		prefix = 'Q'
	endif

	for i=0, nAllROIs-1 do begin

		oAllROIs[i]->getProperty, NAME=name, DESC=desc, HIDE=hide
		type = (strsplit( name, '_', /EXTRACT ))[0]

		if type eq prefix then begin
			if n_elements(names) eq 0 then begin
				names = name
				descs = desc
				hides = hide
				oROIs = oAllROIs[i]
			endif else begin
				names = [names,name]
				descs = [descs,desc]
				hides = [hides,hide]
				oROIs = [oROIs,oAllROIs[i]]
			endelse
			nROIs++
		endif
	endfor
	if nROIs eq 0 then begin
		names = ''
		descs = ''
		oROIs = -1L
	endif

	return, oROIs

end ; of shielding_guiGetRois


;--------------------------------------------------------------------
;
;    PURPOSE  Handle a table event
;
pro shielding_guiTableEvent, $
	pInfo, $
	sEvent

	forward_function shielding_guiSetCurrentROI
	forward_function shielding_guiHandleSourceEntry
	forward_function shielding_guiHandleStructEntry
	forward_function shielding_guiHandleHShieldEntry
	forward_function shielding_guiHandleRegionEntry

	; Let the user manually edit ROI properties through this tabular
	; interface (all but the ROI name).  The Enter key must be pressed
	; in order to make changes permanent.  Otherwise, they are lost.

	print, sEvent.type
	if sEvent.type eq 0 then begin ; insert single character

		if sEvent.ch eq 13b then begin ; Enter key (commit changes)

			case sEvent.id of

				(*pInfo).wShieldTable: $
					bValid = shielding_guiHandleStructEntry( pInfo, sEvent )

				(*pInfo).wHShieldTable: $
					bValid = shielding_guiHandleHShieldEntry( pInfo, sEvent )

				(*pInfo).wRegionTable: $
					bValid = shielding_guiHandleRegionEntry( pInfo, sEvent )

				(*pInfo).wSourceTable: $
					bValid = shielding_guiHandleSourceEntry( pInfo, sEvent )

				else:

			endcase

			if bValid eq 0b then begin
				if (*pInfo).curCell[0] ne -1 then begin
					; Reset the value
					c = (*pInfo).curCell
					widget_control, sEvent.id, $
							USE_TABLE_SELECT=[c[0],c[1],c[0],c[1]], $
							SET_VALUE=(*pInfo).curCellData
				endif
			endif

			; Clear the old data
			(*pInfo).curCell = [-1,-1]
			(*pInfo).curCellData = ''

			bOk = shielding_guiSetCurrentROI( pInfo, /NONE )

		endif else begin ; any other key

			; Remember this cell just in case the user deselects the
			; cell instead of pressing Enter
			(*pInfo).curCell = [sEvent.x,sEvent.y]

		endelse

	endif else if ( sEvent.type eq 1 )  or $
			( sEvent.type eq 2 ) then begin ; insert multiple characters

		; Remember this cell just in case the user deselects the
		; cell instead of pressing Enter
		(*pInfo).curCell = [sEvent.x,sEvent.y]

	endif else if sEvent.type eq 3 then begin ; text selected

		; Don't let the user edit the name field
		if sEvent.x eq 0 then begin
			widget_control, sEvent.id, EDITABLE=0
		endif else begin
			widget_control, sEvent.id, EDITABLE=1
		endelse

	endif else if sEvent.type eq 4 then begin ; cell selected/deselected

		; Deselection
		if ( sEvent.sel_left eq -1 ) and ( sEvent.sel_right eq -1 ) and $
		   ( sEvent.sel_top eq -1 ) and ( sEvent.sel_bottom eq -1 ) then begin

			; Reset the data if the user did not press the Enter key
			; after editing the contents.  If the user did press Enter
			; curCell will be set to [-1,-1] and a reset will not be
			; performed.
			if (*pInfo).curCell[0] ne -1 then begin

				c = (*pInfo).curCell
				widget_control, sEvent.id, $
						USE_TABLE_SELECT=[c[0],c[1],c[0],c[1]], $
						SET_VALUE=(*pInfo).curCellData

				(*pInfo).curCell = [-1,-1]
				(*pInfo).curCellData = ''

			endif

			; Dehighlight the current ROI
			bOk = shielding_guiSetCurrentROI( pInfo, /NONE )

		; Selection
		endif else begin

			; Don't let the user edit the Name field
			if ( sEvent.sel_left le 0 ) and $
			   ( 0 le sEvent.sel_right ) then begin
				widget_control, sEvent.id, EDITABLE=0
			endif else begin
				widget_control, sEvent.id, EDITABLE=1
			endelse

			; Highlight the associated ROI
			widget_control, sEvent.id, GET_VALUE=table

			; Make sure event is in table
			dims = size(table, /DIM)
			if ( sEvent.sel_left gt dims[0]-1  ) or ( sEvent.sel_top gt dims[1]-1 ) then return

			name = table[0,sEvent.sel_top]
			oDispROIs = (*pInfo).oDispROIGroup->get( $
					/ALL, COUNT=nROIs )
			for i=0, nROIs-1 do begin
				oDispROIs[i]->getProperty, NAME=dispName
				if name eq dispName then begin
					oDispROI = oDispROIs[i]
					break
				endif
			endfor
			if obj_valid( oDispROI ) then begin
				bOk = shielding_guiSetCurrentROI( pInfo, oDispROI )
			endif

			; Remember this data so that we can reset it if the
			; user doesn't press Enter
			widget_control, sEvent.id, GET_VALUE=table
			(*pInfo).curCellData = table[sEvent.sel_left,sEvent.sel_top]

		endelse

	endif

end ; of shielding_guiTableEvent


;--------------------------------------------------------------------
;
;    PURPOSE  The struct table UI has changed.  Validate the user
;             input.  Reset the data if it is invalid.  Update any
;             affected ROIs on the VP.
;
function shielding_guiHandleStructEntry, $
	pInfo, $
	sEvent

@'shielding_gui_shield_specs'

	bValid = 1b

	; Catch type mismatches
	catch, err_status
	if err_status ne 0 then return, 0b

	; Get the new entry
	widget_control, sEvent.id, GET_VALUE=table
	entry = table[sEvent.x,sEvent.y]
	name = table[0,sEvent.y]

	eS = (*pInfo).eS

	; Column 0: name
	if sEvent.x eq eS.name then begin

		; Always invalid (can't change the name)
		bValid = 0b

	; Columns 1 & 3: xcoords
	endif else if ( sEvent.x eq eS.x1 ) or ( sEvent.x eq eS.x2 ) then begin

		; Make sure the new coordinate lies within the image
		strCoord = format_float( float(entry), DECIMAL=2 )
		coord = float( strCoord )
		widget_control, (*pInfo).wFloorplanScaleText, GET_VALUE=scale
		scale = float(scale[0])

		if ( 0 le coord ) and ( coord le (*pInfo).nPx * scale ) then begin
			rows = where( table[0,*] eq name, nRows )
			for i=0, nRows-1 do begin
				widget_control, sEvent.id, $
						USE_TABLE_SELECT=[sEvent.x,rows[i],sEvent.x,rows[i]], $
						SET_VALUE=strCoord
			endfor
			shielding_guiUpdateLineROI, pInfo, sEvent
		endif else begin
			bValid = 0b
		endelse

	; Columns 2 & 4: ycoords
	endif else if ( sEvent.x eq eS.y1 ) or ( sEvent.x eq eS.y2 ) then begin

		; Make sure the new coordinate lies within the image
		strCoord = format_float( float(entry), DECIMAL=2 )
		coord = float( strCoord )
		widget_control, (*pInfo).wFloorplanScaleText, GET_VALUE=scale
		scale = float(scale[0])

		if ( 0 le coord ) and ( coord le (*pInfo).nPy * scale ) then begin
			rows = where( table[0,*] eq name, nRows )
			for i=0, nRows-1 do begin
				widget_control, sEvent.id, $
						USE_TABLE_SELECT=[sEvent.x,rows[i],sEvent.x,rows[i]], $
						SET_VALUE=strCoord
			endfor
			shielding_guiUpdateLineROI, pInfo, sEvent
		endif else begin
			bValid = 0b
		endelse

	; Column 5: height above ground of the bottom of the shield
	endif else if sEvent.x eq eS.h1 then begin

		; Make sure the bottom is lower than the top
		if (float(entry) gt table[eS.h2,sEvent.y]) then bValid = 0b

	; Column 6: height above ground of the top of the shield
	endif else if sEvent.x eq eS.h2 then begin

		; Make sure the top is higher than the bottom
		if (float(entry) lt table[eS.h1,sEvent.y]) then bValid = 0b

	; Column 7: material
	endif else if sEvent.x eq eS.material then begin

		; Make sure the material is valid
		indices = where( materials eq entry, count )
		if count eq 0 then begin
			void = dialog_message( $
					'Invalid material. Material not changed.' )
			bValid = 0b
		endif else begin
			rows = where( table[0,*] eq name, nRows )
			if nRows eq 1 then begin
				; Change the colour of the ROI according to the new material
				case entry of
					'Lead': 	color = [255,  0,  0] ; red
					'Concrete':	color = [160, 32,240] ; purple
					'Iron':		color = [255,192,203] ; pink
					else:		color = [255,  0,  0] ; red by default
				endcase
			endif
			shielding_guiSetROIColour, pInfo, (*pInfo).oCurROI
		endelse

	endif

	return, bValid

end ; of shielding_guiHandleStructEntry


;--------------------------------------------------------------------
;
;    PURPOSE  The horiz. shield table UI has changed.  Validate the user
;             input.  Reset the data if it is invalid.  Update any
;             affected ROIs on the VP.
;
function shielding_guiHandleHShieldEntry, $
	pInfo, $
	sEvent

@'shielding_gui_shield_specs'

	bValid = 1b

	; Catch type mismatches
	catch, err_status
	if err_status ne 0 then return, 0b

	; Get the new entry
	widget_control, sEvent.id, GET_VALUE=table
	entry = table[sEvent.x,sEvent.y]
	name = table[0,sEvent.y]

	eH = (*pInfo).eH

	; Column 0: name
	if sEvent.x eq eH.name then begin

		; Always invalid (can't change the name)
		bValid = 0b

	; Columns 1, 3, 5, 7: xcoords
	endif else if (sEvent.x eq eH.x1) or (sEvent.x eq eH.x2) $
		or (sEvent.x eq eH.x3) or (sEvent.x eq eH.x4) then begin

		; Make sure the new coordinate lies within the image
		strCoord = format_float( float(entry), DECIMAL=2 )
		coord = float( strCoord )
		widget_control, (*pInfo).wFloorplanScaleText, GET_VALUE=scale
		scale = float(scale[0])

		if ( 0 le coord ) and ( coord le (*pInfo).nPx * scale ) then begin
			rows = where( table[0,*] eq name, nRows )
			for i=0, nRows-1 do begin
				widget_control, sEvent.id, $
						USE_TABLE_SELECT=[sEvent.x,rows[i],sEvent.x,rows[i]], $
						SET_VALUE=strCoord
			endfor
			shielding_guiUpdateHShieldROI, pInfo, sEvent
		endif else begin
			bValid = 0b
		endelse

	; Columns 2, 4, 6, 8: ycoords
	endif else if (sEvent.x eq eH.y1) or (sEvent.x eq eH.y2) $
		or (sEvent.x eq eH.y3) or (sEvent.x eq eH.y4) then begin

		; Make sure the new coordinate lies within the image
		strCoord = format_float( float(entry), DECIMAL=2 )
		coord = float( strCoord )
		widget_control, (*pInfo).wFloorplanScaleText, GET_VALUE=scale
		scale = float(scale[0])

		if ( 0 le coord ) and ( coord le (*pInfo).nPy * scale ) then begin
			rows = where( table[0,*] eq name, nRows )
			for i=0, nRows-1 do begin
				widget_control, sEvent.id, $
					USE_TABLE_SELECT=[sEvent.x,rows[i],sEvent.x,rows[i]], $
					SET_VALUE=strCoord
			endfor
			shielding_guiUpdateHShieldROI, pInfo, sEvent
		endif else begin
			bValid = 0b
		endelse

	; Column 9: height above ground
	endif else if sEvent.x eq eH.h then begin

	; Column 10: material
	endif else if sEvent.x eq eH.material then begin

		; Make sure the material is valid
		indices = where( materials eq entry, count )
		if count eq 0 then begin
			void = dialog_message( $
					'Invalid material. Material not changed.' )
			bValid = 0b
		endif else begin
			rows = where( table[0,*] eq name, nRows )
			if nRows eq 1 then begin
				; Change the colour of the ROI according to the new material
				case entry of
					'Lead':		color = [255,  0,  0] ; red
					'Concrete':	color = [160, 32,240] ; purple
					'Iron':		color = [255,192,203] ; pink
					else:		color = [255,  0,  0] ; red by default
				endcase
			endif
			shielding_guiSetROIColour, pInfo, (*pInfo).oCurROI
		endelse

	endif

	return, bValid

end ; of shielding_guiHandleHShieldEntry


;--------------------------------------------------------------------
;
;    PURPOSE  The region table UI has changed.  Validate the user
;             input.  Reset the data if it is invalid.  Update any
;             affected ROIs on the VP.
;
function shielding_guiHandleRegionEntry, $
	pInfo, $
	sEvent

	bValid = 1b

	; Catch type mismatches
	catch, err_status
	if err_status ne 0 then return, 0b

	; Get the new entry
	widget_control, sEvent.id, GET_VALUE=table
	entry = table[sEvent.x,sEvent.y]

	eR = (*pInfo).eR

	; Column 0: name
	if sEvent.x eq eR.name then begin

		; Always invalid (can't change the name)
		bValid = 0b

	; Columns 1,3,5,7: xcoords
	endif else if ( sEvent.x eq eR.x1 ) or ( sEvent.x eq eR.x2 ) or $
			( sEvent.x eq eR.x3 ) or ( sEvent.x eq eR.x4 ) then begin

		; Make sure the new coordinate lies within the image
		strCoord = format_float( float(entry), DECIMAL=2 )
		coord = float( strCoord )
		widget_control, (*pInfo).wFloorplanScaleText, GET_VALUE=scale
		scale = float(scale[0])

		if ( 0 le coord ) and ( coord le (*pInfo).nPx * scale ) then begin

			; Move the ROI on the image
			shielding_guiUpdateRegionROI, pInfo, sEvent

			; Move and recalculate the max ROI if we have a dose image
			if total( *(*pInfo).pSeries1 ) gt 0 then begin
				shielding_guiFindMax, pInfo, (*pInfo).oCurROI
			endif

		endif else begin

			bValid = 0b

		endelse

	; Columns 2,4,6,8: ycoords
	endif else if ( sEvent.x eq eR.y1 ) or ( sEvent.x eq eR.y2 ) or $
			( sEvent.x eq eR.y3 ) or ( sEvent.x eq eR.y4 ) then begin

		; Make sure the new coordinate lies within the image
		strCoord = format_float( float(entry), DECIMAL=2 )
		coord = float( strCoord )
		widget_control, (*pInfo).wFloorplanScaleText, GET_VALUE=scale
		scale = float(scale[0])

		if ( 0 le coord ) and ( coord le (*pInfo).nPy * scale ) then begin

			; Move the ROI on the image
			shielding_guiUpdateRegionROI, pInfo, sEvent

			; Move and recalculate the max ROI if we have a dose image
			if max( *(*pInfo).pSeries1 ) gt 0 then begin
				shielding_guiFindMax, pInfo, (*pInfo).oCurROI
			endif

		endif else begin

			bValid = 0b

		endelse

	; Column 12: occupancy factor
	endif else if ( sEvent.x eq eR.occ ) then begin

		occ = float(entry)
		if ( 0 le occ ) and ( occ le 1 ) then begin

			; Update the max dose
			if total( *(*pInfo).pSeries1 ) gt 0 then begin
				shielding_guiFindMax, pInfo, (*pInfo).oCurROI
			endif

		endif else begin

			bValid = 0b

		endelse

	; Columns 9,10,11: calculated max pixels coordinates and value
	endif else if ( sEvent.x eq eR.xMax ) or ( sEvent.x eq eR.yMax ) or $
			( sEvent.x eq eR.maxDose ) or ( sEvent.x eq eR.effMaxDose ) then begin

		; These values are calculated and should not be edited
		bValid = 0b

	endif

	if bValid eq 1b then shielding_guiUpdateImages, pInfo

	return, bValid

end ; of shielding_guiHandleRegionEntry


;--------------------------------------------------------------------
;
;    PURPOSE  The imaging table UI has changed.  Validate the user
;             input.  Reset the data if it is invalid.  Update any
;             affect ROIs on the VP.
;
function shielding_guiHandleSourceEntry, $
	pInfo, $
	sEvent

	if (*pInfo).modality eq 'PET' then begin
		@'shielding_gui_PET_tracer_specs'
	endif else begin
		@'shielding_gui_SPECT_tracer_specs'
	endelse

	bValid = 1b

	; Catch type mismatches
	catch, err_status
	if err_status ne 0 then begin
		heap_free, tracers
		return, 0b
	endif

	; Get the new entry
	widget_control, sEvent.id, GET_VALUE=table
	entry = table[sEvent.x,sEvent.y]
	name = table[0,sEvent.y]

	eP = (*pInfo).eP

	; Column 0: name
	if sEvent.x eq eP.name then begin

		; Always invalid (can't change the name)
		bValid = 0b

	; Column 1: xcoords
	endif else if sEvent.x eq eP.x then begin

		; Make sure the new coordinate lies within the image
		strCoord = format_float( float(entry), DECIMAL=2 )
		coord = float( strCoord )
		widget_control, (*pInfo).wFloorplanScaleText, GET_VALUE=scale
		scale = float(scale[0])

		if ( 0 le coord ) and ( coord le (*pInfo).nPx * scale ) then begin
			rows = where( table[0,*] eq name, nRows )
			for i=0, nRows-1 do begin
				widget_control, sEvent.id, $
						USE_TABLE_SELECT=[sEvent.x,rows[i],sEvent.x,rows[i]], $
						SET_VALUE=strCoord
			endfor
			shielding_guiUpdateSourceROI, pInfo, sEvent
		endif else begin
			bValid = 0b
		endelse

	; Column 2: ycoords
	endif else if sEvent.x eq eP.y then begin

		; Make sure the new coordinate lies within the image
		strCoord = format_float( float(entry), DECIMAL=2 )
		coord = float( strCoord )
		widget_control, (*pInfo).wFloorplanScaleText, GET_VALUE=scale
		scale = float(scale[0])

		if ( 0 le coord ) and ( coord le (*pInfo).nPy * scale ) then begin
			rows = where( table[0,*] eq name, nRows )
			for i=0, nRows-1 do begin
				widget_control, sEvent.id, $
						USE_TABLE_SELECT=[sEvent.x,rows[i],sEvent.x,rows[i]], $
						SET_VALUE=strCoord
			endfor
			shielding_guiUpdateSourceROI, pInfo, sEvent
		endif else begin
			bValid = 0b
		endelse

	; Column 3: tracer
	endif else if sEvent.x eq eP.tracer then begin

		; Make sure the tracer is valid
		indices = where( tracers.name eq entry, count )
		if count eq 0 then begin
			void = dialog_message( $
					'Invalid tracer entered. Tracer not changed.' )
			bValid = 0b
		endif

	endif

	heap_free, tracers
	return, bValid

end ; of shielding_guiHandleSourceEntry


;--------------------------------------------------------------------
;
;    PURPOSE  The table UI has been changed.  Update the ROI.
;
function shielding_guiSetROILocation, pInfo, LOCATION=imgCoords

	; Make sure the current ROI was set by SetCurrentROI
	if not obj_valid( (*pInfo).oCurROI ) then return, 0

	; Update the database and display ROI location
	(*pInfo).oCurROI->setProperty, DATA=imgCoords
	(*pInfo).oDispCurROI->setProperty, DATA=imgCoords

	; Redraw
	(*pInfo).oWindow->draw, (*pInfo).oViewGroup

	return, 1

end ; of shielding_guiSetROILocation


;--------------------------------------------------------------------
;
;    PURPOSE  The table UI has been changed.  Update the ROI.
;
pro shielding_guiUpdateSourceROI, pInfo, sEvent

	; Make sure the current ROI was set by SetCurrentROI
	if not obj_valid( (*pInfo).oCurROI ) then return

	; Get new scale
	widget_control, (*pInfo).wSourceTable, GET_VALUE=table

	eP = (*pInfo).eP

	if ( sEvent.x eq eP.x ) or ( sEvent.x eq eP.y ) then begin

		; Location changed
		widget_control, (*pInfo).wFloorplanScaleText, GET_VALUE=value
		scale = float( value[0] )
		imgCoords = table[eP.x:eP.y,sEvent.y]/scale

		bOk = shielding_guiSetROILocation( pInfo, LOCATION=imgCoords )

	endif

end ; of shielding_guiUpdateSourceROI


;--------------------------------------------------------------------
;
;    PURPOSE  The table UI has been changed.  Update the ROI.
;
pro shielding_guiUpdateLineROI, pInfo, sEvent

	; Make sure the current ROI was set by SetCurrentROI
	if not obj_valid( (*pInfo).oCurROI ) then return

	; Get new scale
	widget_control, (*pInfo).wShieldTable, GET_VALUE=table

	eS = (*pInfo).eS

	if ( sEvent.x ge eS.x1 ) and ( sEvent.x le eS.y2 ) then begin

		; Location changed
		widget_control, (*pInfo).wFloorplanScaleText, GET_VALUE=value
		scale = float( value[0] )
		imgCoords = [[table[eS.x1:eS.y1,sEvent.y]],$
					 [table[eS.x2:eS.y2,sEvent.y]]]/scale

		bOk = shielding_guiSetROILocation( pInfo, LOCATION=imgCoords )

	endif

end ; of shielding_guiUpdateLineROI


;--------------------------------------------------------------------
;
;    PURPOSE  The table UI has been changed.  Update the ROI.
;
pro shielding_guiUpdateHShieldROI, pInfo, sEvent

	; Make sure the current ROI was set by SetCurrentROI
	if not obj_valid( (*pInfo).oCurROI ) then return

	widget_control, (*pInfo).wHShieldTable, GET_VALUE=table

	eH = (*pInfo).eH

	if ( sEvent.x ge eH.x1 ) and ( sEvent.x le eH.y4 ) then begin

		; Location changed
		widget_control, (*pInfo).wFloorplanScaleText, GET_VALUE=value
		scale = float( value[0] )
		imgCoords = [[table[eH.x1:eH.y1,sEvent.y]],[table[eH.x2:eH.y2,sEvent.y]],$
					 [table[eH.x3:eH.y3,sEvent.y]],[table[eH.x4:eH.y4,sEvent.y]]]/scale

		bOk = shielding_guiSetROILocation( pInfo, LOCATION=imgCoords )

	endif

end ; of shielding_guiUpdateHShieldROI


;--------------------------------------------------------------------
;
;    PURPOSE  The table UI has been changed.  Update the ROI.
;
pro shielding_guiUpdateRegionROI, pInfo, sEvent

	; Make sure the current ROI was set by SetCurrentROI
	if not obj_valid( (*pInfo).oCurROI ) then return

	widget_control, (*pInfo).wRegionTable, GET_VALUE=table

	eR = (*pInfo).eR

	if ( sEvent.x ge eR.x1 ) and ( sEvent.x le eR.y4 ) then begin

		; Location changed
		widget_control, (*pInfo).wFloorplanScaleText, GET_VALUE=value
		scale = float( value[0] )
		imgCoords = [[table[eR.x1:eR.y1,sEvent.y]],[table[eR.x2:eR.y2,sEvent.y]],$
					 [table[eR.x3:eR.y3,sEvent.y]],[table[eR.x4:eR.y4,sEvent.y]]]/scale

		bOk = shielding_guiSetROILocation( pInfo, LOCATION=imgCoords )

	endif

end ; of shielding_guiUpdateRegionROI


;--------------------------------------------------------------------
;
;    PURPOSE  Update the viewport labels with the names of the files
;			  on display.
;
pro shielding_guiUpdateVPLabels, pInfo

	widget_control, (*pInfo).wLabel, SET_VALUE=(*pInfo).fileName

end ; of shielding_guiUpdateVPLabels


;--------------------------------------------------------------------
;
;    PURPOSE  Update info text
;
pro shielding_guiUpdateInfoText, pInfo, VALUE=value

	widget_control, (*pInfo).wInfoText, set_value=value

end ; of shielding_guiUpdateInfoText


;--------------------------------------------------------------------
;
;    PURPOSE  Convert from screen pixels to image/floorplan pixels
;
function shielding_guiScrn2ImgPix, $
	pInfo, $				; IN: TLB info
	scrnCoords				; IN: [x,y] in screen pixels

	imgCoords = fltarr(2)

	widget_control, (*pInfo).wFloorplanScaleText, GET_VALUE=value
	fpScale = float( value[0] )

	offsetX = (*pInfo).cPoint[0]-(*pInfo).nPx/(2*(*pInfo).zoomFactor)
	offsetY = (*pInfo).cPoint[1]-(*pInfo).nPy/(2*(*pInfo).zoomFactor)

	imgCoords[0] = float(scrnCoords[0]) * (*pInfo).vp2imgScale[0] / (*pInfo).zoomFactor $
			+ offsetX
	imgCoords[1] = float(scrnCoords[1]) * (*pInfo).vp2imgScale[1] / (*pInfo).zoomFactor $
			+ offsetY

	return, imgCoords

end ; of shielding_guiScrn2ImgPix


;--------------------------------------------------------------------
;
;    PURPOSE  Update the image pixel information text
;
pro shielding_guiUpdateImageInfo, $
	pInfo, $
	COORD=coord

	mCoord = $
			'x:--m, ' + $
			'y:--m, '

	dose = '--, '

	pixCoord = 'x:--pix, ' + $
			   'y:--pix, '

	widget_control, (*pInfo).wMeasureXValText, GET_VALUE=value
	originX = float( value[0] )
	widget_control, (*pInfo).wMeasureYValText, GET_VALUE=value
	originY = float( value[0] )
	widget_control, (*pInfo).wFloorplanScaleText, GET_VALUE=value
	fpScale = float( value[0] )

	dist = 'dist: [--,--]--m from [' + $
		   format_float( originX, DEC=2 ) + ',' + $
		   format_float( originY, DEC=2 ) + ']m'

	if keyword_set( coord ) then begin

		bEventInImage = $
		        coord[0] ge 0 and $
		        coord[1] ge 0 and $
		        coord[0] lt (*pInfo).nPx and $
		        coord[1] lt (*pInfo).nPy

		if bEventInImage then begin

			mCoord = $
					'x:' + format_float( coord[0]*fpScale, DEC=2 ) + 'm, ' + $
					'y:' + format_float( coord[1]*fpScale, DEC=2 ) + 'm, '

			pixCoord = $
					'x:' + strtrim( fix(coord[0]), 2 ) + 'pix, ' + $
					'y:' + strtrim( fix(coord[1]), 2 ) + 'pix, '

			dose = $
					'dose:' + format_float( (*(*pInfo).pSeries1)[coord[0],coord[1]], $
							DEC=2 ) + 'uSv, '

			x = coord[0]*fpScale-originX
			y = coord[1]*fpScale-originY
			dist = sqrt( x^2 + y^2 )

			dist = 'dist: [' + $
				   format_float( x, DEC=2 ) + ',' + $
				   format_float( y, DEC=2 ) + ']' + $
				   format_float( dist, DEC=2 ) + 'm from [' + $
				   format_float( originX, DEC=2 ) + ',' + $
				   format_float( originY, DEC=2 ) + ']m'
		endif

	endif

	widget_control, (*pInfo).wPixelInfoText, $
			SET_VALUE=(mCoord + pixCoord + dose + dist)

end ; of shielding_guiUpdateImageInfo


;--------------------------------------------------------------------
;
;    PURPOSE  Set the material and thickness of a shield
;
pro shielding_guiSetShieldSpecs, $
	pInfo, $
	oROI, $
	PROMPT=prompt, $
	MATERIAL=material, $
	THICKNESS=thickness, $
	HEIGHT1=h1, $
	HEIGHT2=h2, $
	DESCRIPTION=desc

	@'shielding_gui_shield_specs' ; for materials

	if not obj_valid( oROI ) then return
	oROI->getProperty, NAME=name, DATA=data
	if name eq '' then return

	; Check to see if this ROI already exists in the table
	widget_control, (*pInfo).wShieldTable, $
			GET_UVALUE=curRow, GET_VALUE=sTable
	nCols = (size( sTable, /DIMENSIONS ))[0]
	names = sTable[0,*]
	iRows = where( names eq name, nRows )
	if nRows ne 0 then begin
		iRow = iRows[nRows-1]+1 ; row where we'll insert this new data
	endif else begin
		iRow = curRow
	endelse

	eS = (*pInfo).eS

	if n_elements( material ) eq 0 then $
		material = 'Lead'
	if n_elements( thickness ) eq 0 then $
		thickness = '0.16' ; cm
	if n_elements( h1 ) eq 0 then $
		h1 = '0' ; m above ground
	if n_elements( h2 ) eq 0 then $
		widget_control, (*pInfo).wShieldHeightText, GET_VALUE=h2
	if n_elements( desc ) eq 0 then $
		desc = ''

	if keyword_set( prompt ) then begin

		; Pop up shield specification window
		dropLabel = 'Material: '
		dropValues = materials
		dropIndex = (where( dropValues eq material, count ))[0]
		if count eq 0 then dropIndex = 0
		textLabels = ['Thickness (cm): ', 'h1 (m): ', 'h2(m): ', 'Description: ']
		textValues = [thickness, h1, h2, desc]
		void = shielding_gui_prompt_box( $
				GROUP_LEADER=(*pInfo).wTopBase, $
				TITLE='Set structure ' + name + ' specifications', $
				DROP_LABEL=dropLabel, $
				DROP_VALUES=dropValues, $
				DROP_INDEX=dropIndex, $
				TEXT_LABELS=textLabels, $
				TEXT_VALUES=textValues, $
				XSIZE=10, $
				THE_INDEX=index, $
				THE_TEXT=texts, $
				CANCEL=bCancel )

		if not bCancel then begin
			material	= dropValues[index]
			thickness	= texts[0]
			h1			= texts[1]
			h2			= texts[2]
			desc		= texts[3]
		endif else begin
			material	= dropValues[dropIndex]
			thickness	= textValues[0]
			h1			= textValues[1]
			h2			= textValues[2]
			desc		= textValues[3]
		endelse

	endif

	; Add this new shield material to the table
	widget_control, (*pInfo).wFloorplanScaleText, GET_VALUE=value
	scale = float(value[0])
	data *= scale
	data = strtrim( string( data, FORMAT='(f8.2)' ), 2 )
	widget_control, (*pInfo).wShieldTable, $
			USE_TABLE_SELECT=[0,iRow,nCols-1,iRow], $
			/INSERT_ROWS
	widget_control, (*pInfo).wShieldTable, $
			USE_TABLE_SELECT=[0,iRow,nCols-1,iRow], $
			SET_VALUE=strtrim( [name, $
					  data[0], data[1], data[3], data[4], $
					  h1, h2, material, thickness, desc], 2), $
			SET_UVALUE=++curRow

	; Colour code ROI
	case material of
		'Lead':		color = [255,  0,  0]	; red
		'Concrete':	color = [160, 32,240]; purple
		'Iron':		color = [255,192,203]	; pink
		else:		color = [255,  0,  0]	; red by default
	endcase

	shielding_guiSetROIColour, pInfo, oROI

end ; of shielding_guiSetShieldSpecs


;--------------------------------------------------------------------
;
;    PURPOSE  Set the material and thickness of a horizontal shield
;
pro shielding_guiSetHShieldSpecs, $
	pInfo, $
	oROI, $
	PROMPT=prompt, $
	MATERIAL=material, $
	THICKNESS=thickness, $
	HEIGHT=h, $
	DESCRIPTION=desc

	@'shielding_gui_shield_specs' ; for materials

	if not obj_valid( oROI ) then return
	oROI->getProperty, NAME=name, DATA=data
	if name eq '' then return

	; Check to see if this ROI already exists in the table
	widget_control, (*pInfo).wHShieldTable, $
			GET_UVALUE=curRow, GET_VALUE=sTable
	nCols = (size( sTable, /DIMENSIONS ))[0]
	names = sTable[0,*]
	iRows = where( names eq name, nRows )
	if nRows ne 0 then begin
		iRow = iRows[nRows-1]+1 ; row where we'll insert this new data
	endif else begin
		iRow = curRow
	endelse

	eH = (*pInfo).eH

	if n_elements( material ) eq 0 then $
		material = 'Lead'
	if n_elements( thickness ) eq 0 then $
		thickness = '0.16' ; cm
	if n_elements( h ) eq 0 then $
		h = '0' ; m above ground
	if n_elements( desc ) eq 0 then $
		desc = ''

	if keyword_set( prompt ) then begin

		; Pop up shield specification window
		dropLabel = 'Material: '
		dropValues = materials
		dropIndex = (where( dropValues eq material, count ))[0]
		if count eq 0 then dropIndex = 0
		textLabels = ['Thickness (cm): ', 'h(m): ', 'Description: ']
		textValues = [thickness, h, desc]
		void = shielding_gui_prompt_box( $
				GROUP_LEADER=(*pInfo).wTopBase, $
				TITLE='Set structure ' + name + ' specifications', $
				DROP_LABEL=dropLabel, $
				DROP_VALUES=dropValues, $
				DROP_INDEX=dropIndex, $
				TEXT_LABELS=textLabels, $
				TEXT_VALUES=textValues, $
				XSIZE=10, $
				THE_INDEX=index, $
				THE_TEXT=texts, $
				CANCEL=bCancel )

		if not bCancel then begin
			material	= dropValues[index]
			thickness	= texts[0]
			h			= texts[1]
			desc		= texts[2]
		endif else begin
			material	= dropValues[dropIndex]
			thickness	= textValues[0]
			h			= textValues[1]
			desc		= textValues[2]
		endelse

	endif

	; Add this new shield material to the table
	widget_control, (*pInfo).wFloorplanScaleText, GET_VALUE=value
	scale = float(value[0])
	data *= scale
	data = strtrim( string( data, FORMAT='(f8.2)' ), 2 )
	widget_control, (*pInfo).wHShieldTable, $
			USE_TABLE_SELECT=[0,iRow,nCols-1,iRow], $
			/INSERT_ROWS
	widget_control, (*pInfo).wHShieldTable, $
			USE_TABLE_SELECT=[0,iRow,nCols-1,iRow], $
			SET_VALUE=strtrim( [name, $
					  data[0],data[1],data[3],data[4],$
					  data[6],data[7],data[9],data[10], $
					  h, material, thickness, desc], 2), $
			SET_UVALUE=++curRow

	; Colour code ROI
	case material of
		'Lead':		color = [255,  0,  0] ; red
		'Concrete':	color = [160, 32,240] ; purple
		'Iron':		color = [255,192,203] ; pink
		else:		color = [255,  0,  0] ; red by default
	endcase

	shielding_guiSetROIColour, pInfo, oROI

end ; of shielding_guiSetHShieldSpecs


;--------------------------------------------------------------------
;
;    PURPOSE  Set region specs
;
pro shielding_guiSetRegionSpecs, $
	pInfo, $
	oROI, $
	PROMPT=prompt, $
	OCCUPANCY=occ, $
	DESCRIPTION=desc

	if not obj_valid( oROI ) then return
	oROI->getProperty, NAME=name, DATA=data
	if name eq '' then return

	if n_elements( desc ) eq 0 then desc = ''
	if n_elements( occ ) eq 0 then occ = '1'

	if keyword_set( prompt ) then begin

		text = textBox( $
			   GROUP_LEADER=(*pInfo).wTopBase, $
			   TITLE='Set region ' + name + ' specifications', $
			   LABEL=['Description: ', 'Occupancy factor: '], $
			   VALUE=['', occ], $
			   CANCEL=bCancel )

		if not bCancel then begin
			desc	= text[0]
			occ		= text[1]
		endif else begin
			desc	= ''
			occ		= '1'
		endelse

	endif

	oROI->setProperty, DESC=desc

	; Fill in the table, leaving the max value stuff blank
	widget_control, (*pInfo).wFloorplanScaleText, GET_VALUE=value
	scale = float(value[0])
	data *= scale
	data = strtrim( string( data, FORMAT='(f8.2)' ), 2 )
	widget_control, (*pInfo).wRegionTable, $
			GET_UVALUE=curRow, GET_VALUE=table
	nCols = (size( table, /DIMENSIONS ))[0]

	widget_control, (*pInfo).wRegionTable, $
			USE_TABLE_SELECT=[0,curRow,nCols-1,curRow], $
			SET_VALUE=strtrim( [name, $
					  data[0],data[1],data[3],data[4],$
					  data[6],data[7],data[9],data[10], $
					  '', '', '', occ, '', desc], 2)
	widget_control, (*pInfo).wRegionTable, $
			/INSERT_ROWS, SET_UVALUE=++curRow

	; Calculate max pixel if we have a dose image
	if max( *(*pInfo).pSeries1 ) gt 0 then begin
		shielding_guiFindMax, pInfo, oROI
	endif

end ; of shielding_guiSetRegionSpecs



;--------------------------------------------------------------------
;
;    PURPOSE  Add an entire protocol to our source table
;
pro shielding_guiAddProtocol, $
	pInfo, $
	SOURCES=sources

	widget_control,  (*pInfo).wFloorplanScaleText, GET_VALUE=text
	scale = float(text[0])
	nSources = n_elements( sources )

	for i=0, nSources-1 do begin

		name = sources[i].point

		; Check to see where this ROI lies in the table
		widget_control, (*pInfo).wSourceTable, $
				GET_UVALUE=curRow, GET_VALUE=table
		nCols = (size( table, /DIMENSIONS ))[0]
		names = table[0,*]
		iRows = where( names eq name, nRows )
		if nRows ne 0 then begin
			iRow = iRows[nRows-1]+1 ; row where we'll insert this new data
			x = table[((*pInfo).eP).x,iRows[0]]
			y = table[((*pInfo).eP).y,iRows[0]]
		endif else begin
			iRow = curRow
			oROI = (*pInfo).oROIGroup->getByName( name )
			oROI->getProperty, DATA=data
			x = format_float( data[0]*scale )
			y = format_float( data[1]*scale )
		endelse

		; Add this to the table
		widget_control, (*pInfo).wSourceTable, $
				USE_TABLE_SELECT=[0,iRow,nCols-1,iRow], $
				/INSERT_ROWS
		if sources[i].desc ne '' then begin
			desc = strtrim( sources[i].protocol, 2 ) + ' - ' $
				 + strtrim( sources[i].desc, 2 )
		endif else begin
			desc = strtrim( sources[i].protocol, 2 )
		endelse
		widget_control, (*pInfo).wSourceTable, $
				USE_TABLE_SELECT=[0,iRow,nCols-1,iRow], $
				SET_VALUE=[strtrim(name,2), $
						format_float(x), format_float(y), $
						strtrim(sources[i].tracer,2), $
						trim_float(strtrim(sources[i].a0,2)), $
						strtrim(sources[i].t1,2), $
						strtrim(sources[i].t2,2), $
						strtrim(sources[i].na,2), $
						strtrim(sources[i].pv,2), $
						strtrim(sources[i].ss,2), $
						strtrim(desc,2)]
		widget_control, (*pInfo).wSourceTable, $
				SET_UVALUE=++curRow

	endfor

end ; of shielding_guiAddProtocol


;--------------------------------------------------------------------
;
;    PURPOSE  Add source point parameters
;
pro shielding_guiAddSourceSpecs, $
	pInfo, $
	oROI, $
	PROMPT=prompt, $	; set to prompt the user to enter values
	SOURCE_NAME=name, $	; roi name
	TRACER=tName, $		; radionuclide name
	A0=a0, $ 			; admin. activity (GBq)
	TU=tu, $ 			; uptake time (h)
	TI=ti, $ 			; imaging time (h)
	NA=na, $ 			; no. patients/year
	PV=pv, $ 			; patient voiding (%)
	SS=ss, $ 			; scanner shielding (%)
	DESCRIPTION=desc

	if n_elements( name ) eq 0 then return

	if (*pInfo).modality eq 'PET' then begin
		@'shielding_gui_PET_tracer_specs'
	endif else begin
		@'shielding_gui_SPECT_tracer_specs'
	endelse

	; Free memory in case of error
	catch, err_status
	if err_status ne 0 then begin
		heap_free, tracers
		return
	endif

	if not obj_valid( oROI ) then return
	oROI->getProperty, NAME=name, DATA=data
	if name eq '' then return

	; Check to see if this ROI already exists in the table
	widget_control, (*pInfo).wSourceTable, $
			GET_UVALUE=curRow, GET_VALUE=table
	nCols = (size( table, /DIMENSIONS ))[0]
	names = table[0,*]
	iRows = where( names eq name, nRows )
	if nRows ne 0 then begin
		iRow = iRows[nRows-1]+1 ; row where we'll insert this new data
	endif else begin
		iRow = curRow
	endelse

	; Set default values if we weren't provided with any
	if n_elements( tName ) eq 0 then $
		tName = tracers[0].name
	if n_elements( a0 ) eq 0 then $
		a0 = '0.37' ; GBq
	if n_elements( tu ) eq 0 then $
		tu = '0' ; min
	if n_elements( ti ) eq 0 then $
		ti = '60' ; min
	if n_elements( na ) eq 0 then $
		na = '500' ; patients/year
	if n_elements( pv ) eq 0 then $
		pv = '0' ; % volume excreted
	if n_elements( ss ) eq 0 then $
		ss = '0' ; % activity shielded
	if n_elements( desc ) eq 0 then $
		desc = ''

	if keyword_set( prompt ) then begin

		; Pop up tracer specification window
		dropLabel = 'Tracer: '
		dropValues = tracers.name
		dropIndex = (where( dropValues eq tName, count ))[0]
		if count eq 0 then dropIndex = 0
		textLabels = ['Admin. activity (GBq): ', $
					  't1 (min): ', $
					  't2 (min): ', $
					  'No. patients/year: ', $
					  'Patient voiding (%): ', $
					  'Scanner shielding (%): ', $
					  'Description: ']
		textValues = [a0, tu, ti, na, pv, ss, desc]

		void = shielding_gui_prompt_box( $
				GROUP_LEADER=(*pInfo).wTopBase, $
				TITLE='Set imaging point ' + name + ' specifications', $
				DROP_LABEL=dropLabel, $
				DROP_VALUES=dropValues, $
				DROP_INDEX=dropIndex, $
				TEXT_LABELS=textLabels, $
				TEXT_VALUES=textVAlues, $
				XSIZE=10, $
				THE_INDEX=index, $
				THE_TEXT=texts, $
				CANCEL=bCancel )

		if bCancel then return

		tName	= dropValues[index]
		a0 		= texts[0]
		tu		= texts[1]
		ti		= texts[2]
		na		= texts[3]
		pv		= texts[4]
		ss		= texts[5]
		desc	= texts[6]

	endif

	; Add this new ROI to the table
	widget_control, (*pInfo).wFloorplanScaleText, GET_VALUE=value
	scale = float(value[0])
	data *= scale
	data = strtrim( string( data, FORMAT='(f8.2)' ), 2 )
	widget_control, (*pInfo).wSourceTable, $
			USE_TABLE_SELECT=[0,iRow,nCols-1,iRow], $
			/INSERT_ROWS
	widget_control, (*pInfo).wSourceTable, $
			USE_TABLE_SELECT=[0,iRow,nCols-1,iRow], $
			SET_VALUE=strtrim([name, $
					  data[0], data[1], $
					  tName, a0, tu, ti, na, pv, ss, desc], 2)
	widget_control, (*pInfo).wSourceTable, $
			SET_UVALUE=++curRow

	heap_free, tracers

end ; of shielding_guiAddSourceSpecs


;--------------------------------------------------------------------
;
;    PURPOSE  Delete a row from one of the tables
;
pro shielding_guiTableDeleteRow, $
	table, $
	pInfo

	; Get the existing table data
	widget_control, table, GET_UVALUE=curRow, GET_VALUE=data
	nCols = (size( data, /DIMENSIONS ))[0]
	select = widget_info( table, /TABLE_SELECT )
	if select[3] eq curRow then return

	; Prompt to confirm delete
	array = strarr( select[3]-select[1]+2 )
	array[0] = 'Permanently delete: '
	for i=1, select[3]-select[1]+1 do begin
		array[i] = strjoin( data[0:(nCols-1),(select[1]+i-1)], ' ' )
	endfor
	answer = dialog_message( /QUESTION, array )

	if answer eq 'Yes' then begin
		widget_control, table, USE_TABLE_SELECT=select, $
				/DELETE_ROWS, $
				SET_UVALUE=(curRow-(select[3]-select[1]+1))
	endif

end ; of shielding_guiTableDeleteRow


;--------------------------------------------------------------------
;
;    PURPOSE  Insert a row in one of the tables
;
pro shielding_guiTableInsertRow, $
	table, $
	pInfo

	; Get the existing table data
	widget_control, table, GET_UVALUE=curRow, GET_VALUE=data
	nCols = (size( data, /DIMENSIONS ))[0]
	select = widget_info( table, /TABLE_SELECT )

	widget_control, table, $
			USE_TABLE_SELECT=[0,select[3],nCols-1,select[3]], $
			GET_VALUE=rowData
	widget_control, table, $
			USE_TABLE_SELECT=[0,select[3]+1,nCols-1,select[3]+1], $
			/INSERT_ROWS
	widget_control, table, $
			USE_TABLE_SELECT=[0,select[3]+1,nCols-1,select[3]+1], $
			SET_VALUE=rowData
	widget_control, table, $
			SET_UVALUE=++curRow

end ; of shielding_guiTableInsertRow


;--------------------------------------------------------------------
;
;    PURPOSE  Hide ROIs on image
;
pro shielding_guiHideROIs, $
	pInfo, $
	SOURCES=source, $
	SHIELDS=shield, $
	HSHIELDS=hshield, $
	REGIONS=region, $
	QUERY=query

	if keyword_set( source ) then type = 'P'
	if keyword_set( shield ) then type = 'S'
	if keyword_set( hshield ) then type = 'H'
	if keyword_set( region ) then type = 'R'
	if keyword_set( query ) then type = 'Q'
	if not keyword_set( hide ) then hide = 0

	oROIs = shielding_guiGetROIs( pInfo, SOURCES=source, SHIELDS=shield, $
			HSHIELDS=hShield, REGIONS=region, QUERY=query, $
			NAMES=names, HIDE=hide, COUNT=nROIs )
	bOk = shielding_guiHideBox( GROUP_LEADER=(*pInfo).wTopBase, NAMES=names, $
			HIDE=hide, CANCEL=bCancel )

	for i=0, nROIs-1 do begin

		oROIs[i]->setProperty, HIDE=hide[i]
		bContained = (*pInfo).oROIGroup->isContained( oROIs[i], POSITION=pos )
		oDispROI = (*pInfo).oDispROIGroup->get( POSITION=pos )
		if obj_valid( oDispROI ) then begin
			oDispROI->setProperty, HIDE=hide[i], TEXT_HIDE=hide[i]
			oDispROI->getProperty, UVALUE=oChildROI
			if obj_valid( oChildROI ) then begin
				oChildRoi->setProperty, HIDE=hide[i], TEXT_HIDE=hide[i]
			endif
		endif

	endfor

	; Redisplay
	(*pInfo).oWindow->draw, (*pInfo).oViewGroup

end ; of shielding_guiHideROIs


;--------------------------------------------------------------------
;
;    PURPOSE  Hide dose map
;
pro shielding_guiHideDoseMap, $
	pInfo, $
	HIDE=hide

	if not keyword_set( hide ) then hide = 0

	(*pInfo).oDosemap->setProperty, HIDE=hide
	(*pInfo).oCBar->setProperty, HIDE=hide

	; Redisplay
	(*pInfo).oWindow->draw, (*pInfo).oViewGroup

end ; of shielding_guiHideDoseMap


;--------------------------------------------------------------------
;
;    PURPOSE  Clear the query text window
;
pro shielding_guiClearQueryText, $
	pInfo, $
	ALL=all

	if keyword_set( all ) then begin

		answer = dialog_message( /QUESTION, $
				'Clear all text in query window? Data will be unrecoverable' )

		if answer eq 'Yes' then begin
			widget_control, (*pInfo).wQueryText, SET_VALUE=''
		endif

	endif else begin

		answer = dialog_message( /QUESTION, $
				'Clear highlighted text in query window?  Data will be unrecoverable' )

		if answer eq 'Yes' then begin
			widget_control, (*pInfo).wQueryText, /USE_TEXT_SELECT, SET_VALUE=''
		endif

	endelse

end ; of shielding_guiClearQueryText


;--------------------------------------------------------------------
;
;    PURPOSE  Set the pixel scale based on the user-input real-world
;				length of a line ROI
;
pro shielding_guiSetScale, $
	pInfo, $
	oROI, $
	SCALE=scale
	;Print 'set scale'
	if not obj_valid( oROI ) then return
	oROI->getProperty, NAME=name
	if name eq '' then return

	; Prompt for values if we weren't provided with any
	if n_elements( scale ) eq 0 then begin

		; Pop up shield specification window
		defaultLength = '1' ; m
		text = textBox( $
			   GROUP_LEADER=(*pInfo).wTopBase, $
			   TITLE='Set drawing scale', $
			   LABEL=['Length of line ROI (m): '], $
			   VALUE=[defaultLength], $
			   CANCEL=bCancel )

		if not bCancel then begin
			length = float( text[0] )
			oROI->getProperty, DATA=data
			pixLength = sqrt( (data[0,0]-data[0,1])^2 + (data[1,0]-data[1,1])^2 )
			if pixLength eq 0 then begin
				void = dialog_message( 'Invalid entry. Scale not set', /ERROR )
				return
			endif
			scale = length/pixLength
		endif else begin
			return
		endelse

	endif

	; Update UI
	widget_control, (*pInfo).wFloorplanScaleText, SET_VALUE=strtrim(scale,2)

end ; of shielding_guiSetScale


;--------------------------------------------------------------------
;
;    PURPOSE  Updates the ruler length based on the current floorplan
;				scale.
;
pro shielding_guiUpdateRuler, pInfo, REDRAW=redraw

	widget_control, (*pInfo).wFloorplanScaleText, GET_VALUE=scale
	scale = float(scale[0])
	(*pInfo).oCBar->getProperty, POSITION=pos
	normLen = (pos[2]-pos[0])/2.0
	len = normLen * (*pInfo).vpSize[0] *(*pInfo).vp2ImgScale[0]/(*pInfo).zoomFactor * scale

	tickText = format_float( indgen(3)*len/2.0 )
	(*pInfo).oRuler->setProperty, $
			POSITION=pos, COLOR=[0,0,0], $
			TEXT=tickText, HIDE=0

	if n_elements( redraw ) ne 0 then $
		(*pInfo).oWindow->draw, (*pInfo).oViewGroup

end ; of shielding_guiUpdateRuler


;--------------------------------------------------------------------
;
;    PURPOSE  Print distances between current uptake/imaging point
;			  and region maxima.
;
pro shielding_guiPrintDistances, $
	pInfo, $
	oROI

	if not obj_valid( oROI ) then return
	oROI->getProperty, NAME=name, DATA=data
	if name eq '' then return
	print, 'Distances from ', name, ' to max in region:'

	; Convert ROI coords from pixel values to m values
	widget_control, (*pInfo).wFloorplanScaleText, GET_VALUE=value
	scale = float(value[0])
	x0 = data[0]*scale
	y0 = data[1]*scale

	; Return if we don't have a valid ROI group or if we don't $
	; have any ROIs to add
	oROIGroup = (*pInfo).oROIGroup
	if obj_valid( oROIGroup ) then begin
		oROIs = oROIGroup->get( /ALL, COUNT=nROIs )
		if nROIs eq 0 then return
	endif else begin
		return
	endelse

	for i=0, nROIs-1 do begin

		; Find max ROIs
		if obj_valid( oROIs[i] ) then begin

			oMaxROI = obj_new()
			oROIs[i]->getProperty, NAME=name, UVALUE=oMaxROI

			if obj_valid( oMaxROI ) then begin

				oMaxROI->getProperty, DATA=data

				x1 = data[0]*scale
				y1 = data[1]*scale
				dist = sqrt( (x1-x0)^2 + (y1-y0)^2 )
				print, name, ' ', strtrim( dist, 2 ), ' m'

			endif

		endif

	endfor

end ; of shielding_guiPrintDistances


;--------------------------------------------------------------------
;
;    PURPOSE  Update all max ROIs (display and table)
;
pro shielding_guiUpdateMaxROIs, $
	pInfo

	widget_control, (*pInfo).wRegionTable, GET_VALUE=rData, GET_UVALUE=nRs

	if nRs eq 0 then return

	oROIGroup = (*pInfo).oROIGroup
	nROIs = oROIGroup->count()

	if nROIs gt 0 then begin

		eR = (*pInfo).eR

		for iR=0, nRs-1 do begin

			name = rData[eR.name, iR]
			oROI = (*pInfo).oROIGroup->getByName( name )

			if obj_valid( oROI ) then begin
				shielding_guiFindMax, pInfo, oROI
			endif

		endfor

	endif

end ; of shielding_guiUpdateMaxROIs


;--------------------------------------------------------------------
;
;    PURPOSE  Find and the max pixel in the given region
;
pro shielding_guiFindMax, $
	pInfo, $
	oROI

	; Return if we don't have a valid region or a dose image
	if not obj_valid( oROI ) then return
	if max( *(*pInfo).pSeries1 ) eq 0 then return

	; Get the corresponding display ROI
	oROIGroup = (*pInfo).oROIGroup
	bContained = oROIGroup->isContained( oROI, POSITION=pos )
	if not bContained then return
	oDispROI = (*pInfo).oDispROIGroup->get( POSITION=pos )
	oROI->getProperty, DATA=data, NAME=parentName, UVALUE=oOldROI, HIDE=hide
	oDispROI->getProperty, UVALUE=oDispOldROI

	; Generate a region mask and apply it to the dose image
	mask = oROI->computeMask( DIMENSIONS=[(*pInfo).nPx,(*pInfo).nPy], $
			MASK_RULE=2 )
	maskedDose = *(*pInfo).pSeries1 * ( mask ne 0 )
	maxValue = max( maskedDose )
	if maxValue eq 0 then begin
		bOk = oROI->computeGeometry( CENTROID=centroid )
		if bOk then begin
			maxCoords = [centroid[0],centroid[1]]
		endif else begin
			maxPixel = (where( mask ne 0 ))[0]
			maxCoords = array_indices( mask, maxPixel )
		endelse
	endif else begin
		maxPixel = (where( maskedDose eq maxValue, nPix ))[0]
		maxCoords = array_indices( mask, maxPixel )
	endelse
	widget_control, (*pInfo).wFloorplanScaleText, GET_VALUE=value
	fpScale = float( value[0] )
	widget_control, (*pInfo).wDosemapScaleText, GET_VALUE=value
	dmScale = float( value[0] )
;	offset = round( (dmScale - fpScale)/2.0/fpScale )
	strCoordsInM = format_float( (floor((maxCoords)*fpScale/dmScale) + 0.5)*dmScale )
	imgCoords = strCoordsInM/fpScale

	; Add this data to the table
	eR = (*pInfo).eR
	widget_control, (*pInfo).wRegionTable, GET_VALUE=rData
	rows = where( rData[0,*] eq parentName, nRows )
	for i=0, nRows-1 do begin
		widget_control, (*pInfo).wRegionTable, $
				USE_TABLE_SELECT=[eR.xMax,rows[i],eR.maxDose,rows[i]], $
				SET_VALUE=[strCoordsInM[0], strCoordsInM[1], $
						   strtrim( maxValue, 2 )]
		effDose = maxValue*rData[eR.occ,rows[i]]
		widget_control, (*pInfo).wRegionTable, $
				USE_TABLE_SELECT=[eR.effMaxDose,rows[i],eR.effMaxDose,rows[i]], $
				SET_VALUE=strtrim(effDose, 2)
	endfor

	; Destroy old max symbol/ROI objects
	if obj_valid( oOldROI ) then begin
		oROIGroup->remove, oOldROI
		oOldROI->getProperty, SYMBOL=oSym
		if obj_valid( oSym ) then obj_destroy, oSym
		obj_destroy, oOldROI
	endif
	if obj_valid( oDispOldROI ) then begin
		(*pInfo).oDispROIGroup->remove, oDispOldROI
		oDispOldROI->getProperty, SYMBOL=oSym
		if obj_valid( oSym ) then obj_destroy, oSym
		obj_destroy, oDispOldROI
	endif

	if (*pInfo).displayMode eq 'gray-all' then begin
		name = strtrim( round(maxValue), 2 ) + 'uSv'
	endif else if (*pInfo).displayMode eq 'gray-high' then begin
		name = strtrim( round(maxValue), 2 ) + 'uSv'
	endif else if (*pInfo).displayMode eq 'gray-high+occ' then begin
		name = strtrim( round(effDose), 2 ) + 'uSv'
	endif else if (*pInfo).displayMode eq 'colour' then begin
		name = strtrim( round(maxValue), 2 ) + 'uSv'
	endif else if (*pInfo).displayMode eq 'colour-high' then begin
		name = strtrim( round(maxValue), 2 ) + 'uSv'
	endif else if (*pInfo).displayMode eq 'colour-high+occ' then begin
		name = strtrim( round(effDose), 2 ) + 'uSv'
	endif else if (*pInfo).displayMode eq 'rois' then begin
		name = strtrim( round(effDose), 2 ) + 'uSv'
	endif else if (*pInfo).displayMode eq 'none' then begin
		return
	endif

	; Create symbol/ROI objects and link them to their parents
	oSymbol = obj_new( 'IDLgrSymbol', 7, SIZE=3, THICK=2 )

	oMaxROI = obj_new( 'IDLgrROI', NAME=name, DATA=imgCoords, STYLE=0, $
			SYMBOL=oSymbol, COLOR=[0,0,255], HIDE=hide )
	oROIGroup->add, oMaxROI

	oDispMaxROI = obj_new( 'MKgrROI', NAME=name, DATA=imgCoords, STYLE=0, $
			SYMBOL=oSymbol, COLOR=[0,0,255], HIDE=hide, TEXT_HIDE=hide, $
			THICK=(*pInfo).roiThick, TEXT_SIZE=(*pInfo).textSize )
	(*pInfo).oDispROIGroup->add, oDispMaxROI

	oROI->setProperty, UVALUE=oMaxROI
	oDispROI->setProperty, UVALUE=oDispMaxROI

	; Redraw
	(*pInfo).oWindow->draw, (*pInfo).oViewGroup

end ; of shielding_guiUpdateMax


;--------------------------------------------------------------------
;
;    PURPOSE  Clear floor ROIs from the display when the display
;			  mode changes
;
pro shielding_guiClearFloorROIs, $
	pInfo

	oROIs = (*pInfo).oROIGroup->get( /ALL )
	for iROI=0, n_elements( oROIs )-1 do begin
		oROIs[iROI]->getProperty, NAME=name
		if strmatch( name, '*cm' ) eq 1b then begin
			(*pInfo).oROIGroup->remove, oROIs[iROI]
			obj_destroy, oROIs[iROI]
		endif
	endfor

	oDispROIs = (*pInfo).oDispROIGroup->get( /ALL )
	for iROI=0, n_elements( oROIs )-1 do begin
		oDispROIs[iROI]->getProperty, NAME=name
		if strmatch( name, '*cm' ) eq 1b then begin
			(*pInfo).oDispROIGroup->remove, oDispROIs[iROI]
			obj_destroy, oDispROIs[iROI]
		endif
	endfor

	(*pInfo).oWindow->draw, (*pInfo).oViewGroup

end ; of shielding_guiClearFloorROIs


;--------------------------------------------------------------------
;
;	PURPOSE	Show/hide horizontal ROI fill
;
pro shielding_guiHFill, $
	pInfo, $
	NONE=none

	widget_control, (*pInfo).wHShieldTable, GET_VALUE=hData, GET_UVALUE=nHs
	if nHs eq 0 then return

	if keyword_set( none ) then begin

		obj_destroy, (*pInfo).oHPolyModel
		(*pInfo).oHPolyModel = obj_new( 'IDLgrModel' )
		(*pInfo).oModel->add, (*pInfo).oHPolyModel

	endif else begin

		for iH=0, nHs-1 do begin
			eH = (*pInfo).eH
			name = hData[eH.name, iH]
			oROI = (*pInfo).oROIGroup->getByName( name )
			if not obj_valid( oROI ) then continue
			oROI->getProperty, DATA=data
			oPolygon = obj_new( 'IDLgrPolygon', FILL_PATTERN=(*pInfo).oFill, $
					COLOR=[255,0,0], DATA=data )
			(*pInfo).oHPolyModel->add, oPolygon
		endfor

	endelse

	(*pInfo).oWindow->draw, (*pInfo).oViewGroup
end

;--------------------------------------------------------------------
;
;   PURPOSE	Determine whether two lines intersect
;
function shielding_guiLinesIntersect, $
	line1_coords, $
	line2_coords

	x11 = line1_coords[0,0]
	x12 = line1_coords[0,1]
	y11 = line1_coords[1,0]
	y12 = line1_coords[1,1]

	x21 = line2_coords[0,0]
	x22 = line2_coords[0,1]
	y21 = line2_coords[1,0]
	y22 = line2_coords[1,1]

	numA = (x22-x21)*(y11-y21)-(y22-y21)*(x11-x21)
	numB = (x12-x11)*(y11-y21)-(y12-y11)*(x11-x21)
	den  = (y22-y21)*(x12-x11)-(x22-x21)*(y12-y11)

	if den eq 0 then begin
		if ( numA eq 0 ) and ( numB eq 0 ) then begin
			return, 1 ; lines coincident
		endif else begin
			return, 0 ; lines parallel
		endelse
	endif else begin
		A = numA/den
		B = numB/den
		if ( 0 le A ) and ( A le 1 ) and $
		   ( 0 le B ) and ( B le 1 ) then begin
			return, 1 ; lines intersect
		endif else begin
			return, 0 ; lines do not intersect
		endelse
	endelse

end ; of shielding_guiLinesIntersect


;--------------------------------------------------------------------
;
;   PURPOSE	Get intersection of 2 lines
;			Note: Lines must intersect
;
function shielding_guiGetIntersect, $
	line1_coords, $
	line2_coords

	Ax = line1_coords[0,0]
	Bx = line1_coords[0,1]
	Ay = line1_coords[1,0]
	By = line1_coords[1,1]

	Cx = line2_coords[0,0]
	Dx = line2_coords[0,1]
	Cy = line2_coords[1,0]
	Dy = line2_coords[1,1]

	; (1) Translate the system so that point A is on the origin.
  	Bx-=Ax & By-=Ay
  	Cx-=Ax & Cy-=Ay
  	Dx-=Ax & Dy-=Ay

  	; Get the length of segment A-B.
  	distAB = sqrt(Bx*Bx+By*By)

  	; (2) Rotate the system so that point B is on the positive X axis.
  	theCos = Bx/distAB
  	theSin = By/distAB
  	newX = Cx*theCos+Cy*theSin
  	Cy = Cy*theCos-Cx*theSin
  	Cx = newX
  	newX = Dx*theCos+Dy*theSin
  	Dy = Dy*theCos-Dx*theSin
	Dx = newX

  	; (3) Get the position of the intersection point along line A-B.
  	ABpos=Dx+(Cx-Dx)*Dy/(Dy-Cy)

 	; (4) Apply the discovered position to line A-B in the original coordinate system.
  	xi = Ax+ABpos*theCos
  	yi = Ay+ABpos*theSin

  	return, [xi,yi]

end


;--------------------------------------------------------------------
;
;    PURPOSE  Reset last selected mode button
;
pro shielding_guiResetLastMode, $
	pInfo			; IN: TLB info

	case (*pInfo).mode of

		'zoom_in': begin
			widget_control, (*pInfo).wZoomInButton, $
					SET_VALUE='bitmaps\zoom_in.bmp', /BITMAP, $
					SET_BUTTON=0
		end ; zoom_in

		'pan': begin
			widget_control, (*pInfo).wPanButton, $
					SET_VALUE='bitmaps\pan.bmp', /BITMAP, $
					SET_BUTTON=0
		end ; pan

		'crosshairs_on': begin
			widget_control, (*pInfo).wCrosshairsButton, $
					SET_VALUE='bitmaps\crosshairs_on.bmp', /BITMAP, $
					SET_BUTTON=0
		end ; crosshairs_on

		'source_roi': begin
			widget_control, (*pInfo).wSourceROIButton, $
					SET_VALUE='bitmaps\source.bmp', /BITMAP, $
					SET_BUTTON=0
		end ; source_roi

		'line_roi': begin
			widget_control, (*pInfo).wLineROIButton, $
					SET_VALUE='bitmaps\line.bmp', /BITMAP, $
					SET_BUTTON=0
			shielding_guiAbandonROI, pInfo
		end ; line_ROI

		'right_roi': begin
			widget_control, (*pInfo).wRightROIButton, $
					SET_VALUE='bitmaps\right.bmp', /BITMAP, $
					SET_BUTTON=0
			shielding_guiAbandonROI, pInfo
		end ; right_ROI

		'h_roi': begin
			widget_control, (*pInfo).wHROIButton, $
				SET_VALUE='bitmaps\hshield.bmp', /BITMAP, $
				SET_BUTTON=0
			shielding_guiAbandonROI, pInfo
		end ; h_roi

		'rect_roi': begin
			widget_control, (*pInfo).wRectROIButton, $
					SET_VALUE='bitmaps\rectangle.bmp', /BITMAP, $
					SET_BUTTON=0
			shielding_guiAbandonROI, pInfo
		end ; rect_roi

		'query_roi': begin
			widget_control, (*pInfo).wQueryROIButton, $
					SET_VALUE='bitmaps\query.bmp', /BITMAP, $
					SET_BUTTON=0
		end ; query_roi

		'poly_roi': begin
			widget_control, (*pInfo).wPolyROIButton, $
					SET_VALUE='bitmaps\segpoly.bmp', /BITMAP, $
					SET_BUTTON=0
			shielding_guiAbandonROI, pInfo
		end ; poly_roi

		'free_roi': begin
			widget_control, (*pInfo).wFreeROIButton, $
					SET_VALUE='bitmaps\freepoly.bmp', /BITMAP, $
					SET_BUTTON=0
			shielding_guiAbandonROI, pInfo
		end ; free_roi

		'query': begin
			widget_control, (*pInfo).wQueryButton, $
					SET_VALUE='Add'
					SET_BUTTON=0
		end ; query

		'move_roi_vertex': begin
			widget_control, (*pInfo).wMoveROIVertexButton, $
					SET_VALUE='bitmaps\move_vertex.bmp', /BITMAP, $
					SET_BUTTON=0

			; Reset ROI colour and hide vertices
			if obj_valid( (*pInfo).oDispCurROI ) then begin
			    shielding_guiSetROIColour, pInfo, (*pInfo).oDispCurROI
				;(*pInfo).oDispCurROI->setProperty, COLOR=[255,0,0]
				(*pInfo).oDispCurROI = obj_new()
			endif
			(*pInfo).oVertexModel->setProperty, HIDE=1

			(*pInfo).oCurROI = obj_new()
			(*pInfo).curVertIndex = -1L
			(*pInfo).curScrnCoords = [0,0]
		end ; move_roi_vertex

		'extend_roi': begin
			widget_control, (*pInfo).wExtendROIButton, $
					SET_VALUE='bitmaps\extend.bmp', /BITMAP, $
					SET_BUTTON=0

			; Reset ROI colour and hide vertices
			if obj_valid( (*pInfo).oDispCurROI ) then begin
			    shielding_guiSetROIColour, pInfo, (*pInfo).oDispCurROI
				;(*pInfo).oDispCurROI->setProperty, COLOR=[255,0,0]
				(*pInfo).oDispCurROI = obj_new()
			endif
			(*pInfo).oVertexModel->setProperty, HIDE=1

			(*pInfo).oCurROI = obj_new()
			(*pInfo).curVertIndex = -1L
			(*pInfo).curScrnCoords = [0,0]

		end ; extend_roi

		'trim_roi': begin
			widget_control, (*pInfo).wTrimROIButton, $
					SET_VALUE='bitmaps\trim.bmp', /BITMAP, $
					SET_BUTTON=0

			; Reset ROI colour and hide vertices
			if obj_valid( (*pInfo).oDispCurROI ) then begin
			    shielding_guiSetROIColour, pInfo, (*pInfo).oDispCurROI
				;(*pInfo).oDispCurROI->setProperty, COLOR=[255,0,0]
				(*pInfo).oDispCurROI = obj_new()
			endif
			(*pInfo).oVertexModel->setProperty, HIDE=1


			(*pInfo).oCurROI = obj_new()
			(*pInfo).curVertIndex = -1L
			(*pInfo).curScrnCoords = [0,0]

		end ; trim_roi

		'move_roi': begin
			widget_control, (*pInfo).wMoveROIButton, $
					SET_VALUE='bitmaps\move_all.bmp', /BITMAP, $
					SET_BUTTON=0

			; Reset ROI colour and hide vertices
			if obj_valid( (*pInfo).oDispCurROI ) then begin
			    shielding_guiSetROIColour, pInfo, (*pInfo).oDispCurROI
				;(*pInfo).oDispCurROI->setProperty, COLOR=[255,0,0]
				(*pInfo).oDispCurROI = obj_new()
			endif
			(*pInfo).oVertexModel->setProperty, HIDE=1

			(*pInfo).oCurROI = obj_new()
			(*pInfo).curVertIndex = -1L
			(*pInfo).curScrnCoords = [0,0]
		end ; move_roi

		'delete_roi': begin
			widget_control, (*pInfo).wDeleteROIButton, $
					SET_VALUE='bitmaps\delete.bmp', /BITMAP, $
					SET_BUTTON=0
		end ; delete_roi

		'copy_roi': begin
			widget_control, (*pInfo).wCopyROIButton, $
					SET_VALUE='bitmaps\copy.bmp', /BITMAP, $
					SET_BUTTON=0, TOOLTIP='copy ROI'
			; Hide display ROIs
			shielding_guiCopyROIStop, pInfo
			; Disable paste button
			widget_control, (*pInfo).wPasteROIButton, $
					SENSITIVE=0

		end ; copy_roi

		else: return

	endcase

end ; of shielding_guiResetLastMode


;--------------------------------------------------------------------
;
;    PURPOSE  Keep last selected mode button on
;
pro shielding_guiKeepLastMode, $
	pInfo			; IN: TLB info

	case (*pInfo).mode of

		'source_roi': begin
			widget_control, (*pInfo).wSourceROIButton, $
					SET_VALUE='bitmaps\source_active.bmp', /BITMAP, $
					SET_BUTTON=1
			shielding_guiUpdateInfoText, pInfo, $
					VALUE='Left click to mark the location of a source.'
		end ; source_roi

		'line_roi': begin
			widget_control, (*pInfo).wLineROIButton, $
					SET_VALUE='bitmaps\line_active.bmp', /BITMAP, $
					SET_BUTTON=1
			shielding_guiUpdateInfoText, pInfo, $
					VALUE='Left click to mark the start and end points of the line ROI.'
		end ; line_roi

		'right_roi': begin
			widget_control, (*pInfo).wRightROIButton, $
					SET_VALUE='bitmaps\right_active.bmp', /BITMAP, $
					SET_BUTTON=1
			shielding_guiUpdateInfoText, pInfo, $
					VALUE='Left click to mark the start of the ROI.  Right click to mark the end.'
		end ; right_roi

		'h_roi': begin
			widget_control, (*pInfo).wHROIButton, $
					SET_VALUE='bitmaps\hshield_active.bmp', /BITMAP, $
					SET_BUTTON=1
			shielding_guiUpdateInfoText, pInfo, $
					VALUE='Left click to mark the start of the ROI.  Right click to mark the end.'
		end ; h_roi

		'rect_roi': begin
			widget_control, (*pInfo).wRectROIButton, $
					SET_VALUE='bitmaps\rectangle_active.bmp', /BITMAP, $
					SET_BUTTON=1
			shielding_guiUpdateInfoText, pInfo, $
					VALUE='Left click to mark the start of the ROI.  Right click to mark the end.'
		end ; rect_roi

		'query_roi': begin
			widget_control, (*pInfo).wQueryROIButton, $
					SET_VALUE='bitmaps\query_active.bmp', /BITMAP, $
					SET_BUTTON=1
			shielding_guiUpdateInfoText, pInfo, $
					VALUE='Left click to place a query point.'
		end ; query_roi

		'poly_roi': begin
			widget_control, (*pInfo).wPolyROIButton, $
					SET_VALUE='bitmaps\segpoly_active.bmp', /BITMAP, $
					SET_BUTTON=1
		end ; poly_roi

		'free_roi': begin
			widget_control, (*pInfo).wFreeROIButton, $
					SET_VALUE='bitmaps\freepoly_active.bmp', /BITMAP, $
					SET_BUTTON=1
		end ; free_roi

		'move_roi_vertex': begin
			widget_control, (*pInfo).wMoveROIVertexButton, $
					SET_VALUE='bitmaps\move_vertex_active.bmp', /BITMAP, $
					SET_BUTTON=1
			shielding_guiUpdateInfoText, pInfo, $
					VALUE='Left click and drag a vertex to change the shape of a ROI.'
		end ; move_roi_vertex

		'move_roi': begin
			widget_control, (*pInfo).wMoveROIButton, $
					SET_VALUE='bitmaps\move_all_active.bmp', /BITMAP, $
					SET_BUTTON=1
			shielding_guiUpdateInfoText, pInfo, $
					VALUE='Left click and drag a ROI to change the ROI location.'
		end ; move_roi

		'delete_roi': begin
			widget_control, (*pInfo).wDeleteROIButton, $
					SET_VALUE='bitmaps\delete_active.bmp', /BITMAP, $
					SET_BUTTON=1
			shielding_guiUpdateInfoText, pInfo, $
					VALUE='Left click on a ROI to select the region for deletion.'
		end ; delete_roi

		'copy_roi': begin
			widget_control, (*pInfo).wCopyROIButton, $
					SET_VALUE='bitmaps\copy_active.bmp', /BITMAP, $
					SET_BUTTON=1
		end ; copy_roi

		else: return

	endcase

end ; of shielding_guiKeepLastMode


;--------------------------------------------------------------------
;
;    PURPOSE  Initiate panning
;
pro shielding_guiPanStart, pInfo, sEvent

	; Get the current cursor location
	curScrnCoords = [sEvent.x,sEvent.y]
	(*pInfo).curScrnCoords = curScrnCoords

	print, "pan start = ", curScrnCoords

end ; of shielding_guiPanStart


;--------------------------------------------------------------------
;
;    PURPOSE  Update panning
;
pro shielding_guiPanMotion, pInfo, sEvent

	; Calculate the cursor transformation
	lastScrnCoords = (*pInfo).curScrnCoords
	curScrnCoords = [sEvent.x, sEvent.y]
	xformCoords = ( curScrnCoords - lastScrnCoords ) * $
			(*pInfo).vp2imgScale / (*pInfo).zoomFactor

	(*pInfo).cPoint[0] -= xformCoords[0]
	(*pInfo).cPoint[1] -= xformCoords[1]

	(*pInfo).curScrnCoords = curScrnCoords

	shielding_guiUpdateViews, pInfo

end ; of shielding_guiPanMotion


;--------------------------------------------------------------------
;
;    PURPOSE  Stop panning
;
pro shielding_guiPanStop, pInfo, sEvent

	; Calculate the cursor transformation
	lastScrnCoords = (*pInfo).curScrnCoords
	curScrnCoords = [sEvent.x, sEvent.y]
	xformCoords = ( curScrnCoords - lastScrnCoords ) * $
			(*pInfo).vp2imgScale / (*pInfo).zoomFactor

	(*pInfo).cPoint[0] -= xformCoords[0]
	(*pInfo).cPoint[1] -= xformCoords[1]

	(*pInfo).curScrnCoords = curScrnCoords

	shielding_guiUpdateViews, pInfo

end ; of shielding_guiPanStop


;--------------------------------------------------------------------
;
;    PURPOSE  Delete a half-drawn ROI from the display and memory
;
pro shielding_guiAbandonROI, pInfo

	; Discontinue and delete half-drawn ROI
	oROI = (*pInfo).oCurROI
	oDispROI = (*pInfo).oDispCurROI

	if obj_valid( oROI ) then begin

		; Check to see if we're in the middle of drawing a ROI
		bDelete = 0b
		oROI->getProperty, NAME=name, STYLE=style
		case (*pInfo).mode of
			'line_roi':  if name eq '' then bDelete = 1b
			'right_roi': if name eq '' then bDelete = 1b
			'free_roi':	 if style eq 1 then bDelete = 1b
			'poly_roi':	 if style eq 1 then bDelete = 1b
			else:
		endcase

		if bDelete then begin
			; Remove the ROI from the group
			oROIGroup = (*pInfo).oROIGroup
			if obj_valid( oROIGroup ) then oROIGroup->remove, oROI
			obj_destroy, oROI

			; Remove the display ROIs from the display
			if (*pInfo).oModel->isContained( oDispROI ) then begin
				(*pInfo).oModel->remove, oDispROI
				obj_destroy, oDispROI
				(*pInfo).oDispCurROI = obj_new()
				(*pInfo).oWindow->draw, (*pInfo).oViewGroup
			endif
		endif
	endif

end ; of shielding_guiAbandonROI


;--------------------------------------------------------------------
;
;    PURPOSE  Generate a unique ROI name
;
function shielding_guiGenerateROIName, $
	oROIGroup, $
	PREFIX=prefix

	if not keyword_set( prefix ) then prefix='roi'

	oROIs = oROIGroup->get( /ALL, COUNT=count )

	if count gt 0 then begin
		names = strarr(count)
		for i=0, count-1 do begin
			oROIs[i]->getProperty, NAME=name
			names[i] = name
        endfor
	endif

	bDone = 0b
	id = 0
	while not bDone do begin
		bDuplicate = 0b
		name = prefix + '_' + strtrim(id,2)
		for i=0, n_elements( names )-1 do begin
			if strupcase( strtrim(names[i],2) ) $
				eq strupcase( name ) then begin
                bDuplicate = 1b
            endif
		endfor
		if not bDuplicate then begin
            bDone = 1b
		end
		id = id + 1
	endwhile

    return, name
end

;--------------------------------------------------------------------
;
;    PURPOSE  Rename the current ROI
;
function shielding_guiRenameROI, pInfo, ROI=oROI

	oROI = (*pInfo).oCurROI
	oDispROI = (*pInfo).oDispCurROI
	if not obj_valid( oROI ) then return, 0b
	oROI->getProperty, NAME=name
	name = strtrim(name,2)
	type = (strsplit( name, '_', /EXTRACT ))[0]
	oROIGroup = (*pInfo).oROIGroup
	oROIs = oROIGroup->get( /ALL, COUNT=nROIs )

	; Prompt for new name
	bOk = 0b
	while not bOk do begin
		text = textBox( $
			   GROUP_LEADER=(*pInfo).wTopBase, $
			   TITLE='Enter new name for '+name, $
			   LABEL=['New name:'], $
			   VALUE=[name], $
			   CANCEL=bCancel )
		if bCancel then return, 0b
		if (strmid( text[0], 0, 1 ) ne type) or (strmid( text[0], 1, 1 ) ne '_') then begin
			void = dialog_message( 'Invalid prefix' )
			bOk = 0b
			continue
		endif
		newName = strtrim(text[0],2)

		; Check to see if this name is unique
		bDuplicate = 0b
		if nROIs gt 0 then begin
			for i=0, nROIs-1 do begin
				if oROIs[i] ne oROI then begin
					oROIs[i]->getProperty, NAME=roiName
					if strupcase( strtrim(roiName,2) ) eq strupcase( newName ) then begin
						bDuplicate = 1b
						break
					endif
				endif
	        endfor
		endif
		if bDuplicate then begin
			void = dialog_message( 'Name exists' )
			bOk = 0b
			continue
		endif else begin
			bOk = 1b
		endelse
	endwhile

	case type of
	'R': begin
		eR = (*pInfo).eR
		widget_control, (*pInfo).wRegionTable, GET_VALUE=value
		rows = where( value[eR.name,*] eq name, nRows )
		value[eR.name,rows] = newName
		widget_control, (*pInfo).wRegionTable, SET_VALUE=value
	end
	else: return, 0b
	endcase

	; Rename the ROIs and redisplay
	oROI->setProperty, NAME=newName
	oDispROI->setProperty, NAME=newName
	(*pInfo).oWindow->draw, (*pInfo).oViewGroup

    return, 1b

end ; of shielding_guiRenameROI


;--------------------------------------------------------------------
;
;    PURPOSE  Start drawing a new line ROI
;
pro shielding_guiLineROIStart, $
	pInfo, $
	imgCoords

	; Get Current ROI
	oROI = (*pInfo).oCurROI
	oDispROI = (*pInfo).oDispCurROI

	; Start building a new ROI if we don't have one
	if obj_valid( oROI ) eq 0 then begin

		; Create new ROI
		oROI = obj_new( 'IDLgrROI', COLOR=[255,0,0], STYLE=1 )
		(*pInfo).oCurROI = oROI

		; Create new display ROI
		oDispROI = obj_new( 'MKgrROI', COLOR=[255,0,0], STYLE=1, $
				THICK=(*pInfo).roiThick, TEXT_SIZE=(*pInfo).textSize )
		(*pInfo).oModel->add, oDispROI
		(*pInfo).oDispCurROI = oDispROI

	endif

	; Add this point to our current ROI
	; Make the start and end points the same
	oROI->appendData, [imgCoords[0], imgCoords[1]]
	oROI->appendData, [imgCoords[0], imgCoords[1]]

	; Add to our display ROI and redraw
	oDispROI->appendData, [imgCoords[0], imgCoords[1]]
	oDispROI->appendData, [imgCoords[0], imgCoords[1]]
	(*pInfo).oWindow->draw, (*pInfo).oViewGroup

end ; of shielding_guiLineROIStart


;--------------------------------------------------------------------
;
;    PURPOSE  Update movement of the end of a line ROI
;
pro shielding_guiLineROIMotion, $
	pInfo, $
	sEvent

	; Get current ROI
	oROI = (*pInfo).oCurROI
	if not obj_valid( oROI ) then return
	oDispROI = (*pInfo).oDispCurROI

	; Get cursor location in image coordinates
	imgCoords = shielding_guiScrn2ImgPix( pInfo, [sEvent.x,sEvent.y] )

	; Change the final point
	oROI->replaceData, [imgCoords[0], imgCoords[1]], START=1

	; Change the final point of our display ROI
	oDispROI->replaceData, [imgCoords[0], imgCoords[1]], START=1

	; Redisplay
	(*pInfo).oWindow->draw, (*pInfo).oViewGroup

end ; of shielding_guiLineROIMotion


;--------------------------------------------------------------------
;
;    PURPOSE  Complete the new line ROI
;
pro shielding_guiLineROIStop, pInfo, imgCoords

	; Get current ROI
	oROI = (*pInfo).oCurROI
	if not obj_valid( oROI ) then return
	oDispROI = (*pInfo).oDispCurROI

	; Add this point to our current ROI
	oROI->replaceData, [imgCoords[0], imgCoords[1]], START=1

	; Add to our display ROI
	oDispROI->replaceData, [imgCoords[0], imgCoords[1]], START=1

	; Name this ROI and display
	oROI->getProperty, DATA=data
	oROIGroup = (*pInfo).oROIGroup
	name = shielding_guiGenerateROIName( oROIGroup, PREFIX='S' )
	oROI->setProperty, NAME=name
	oDispROI->setProperty, NAME=name, TEXT_ANCHOR=data[0:1,0]

	; Add to the ROI group for this slice
	oROIGroup->add, oROI
	(*pInfo).oModel->remove, oDispROI
	(*pInfo).oDispROIGroup->add, oDispROI

	; Remove the reference to this object in the state
	(*pInfo).oCurROI = obj_new()
	(*pInfo).oDispCurROI = obj_new()


	; Redisplay
	(*pInfo).oWindow->draw, (*pInfo).oViewGroup

end ; of shielding_guiLineROIStop


;--------------------------------------------------------------------
;
;    PURPOSE  Start drawing a new horizontal or vertical line ROI
;
pro shielding_guiRightROIStart, $
	pInfo, $
	imgCoords

	; Get Current ROI
	oROI = (*pInfo).oCurROI
	oDispROI = (*pInfo).oDispCurROI

	; Start building a new ROI if we don't have one
	if obj_valid( oROI ) eq 0 then begin

		; Create new ROI
		oROI = obj_new( 'IDLgrROI', COLOR=[255,0,0], STYLE=1 )
		(*pInfo).oCurROI = oROI

		; Create new display ROI
		oDispROI = obj_new( 'MKgrROI', COLOR=[255,0,0], STYLE=1, $
				THICK=(*pInfo).roiThick, TEXT_SIZE=(*pInfo).textSize )
		(*pInfo).oModel->add, oDispROI
		(*pInfo).oDispCurROI = oDispROI

	endif

	; Make the start point equal to the end point
	oROI->appendData, [imgCoords[0], imgCoords[1]]
	oROI->appendData, [imgCoords[0], imgCoords[1]]

	; Add to our display ROIs and redraw
	oDispROI->appendData, [imgCoords[0], imgCoords[1]]
	oDispROI->appendData, [imgCoords[0], imgCoords[1]]
	(*pInfo).oWindow->draw, (*pInfo).oViewGroup

end ; of shielding_guiRightROIStart


;--------------------------------------------------------------------
;
;    PURPOSE  Update movement of the end of a horizontal or vertical line ROI
;
pro shielding_guiRightROIMotion, $
	pInfo, $
	sEvent

	; Get current ROI
	oROI = (*pInfo).oCurROI
	if not obj_valid( oROI ) then return
	oDispROI = (*pInfo).oDispCurROI

	; Get cursor location in image coordinates
	imgCoords = shielding_guiScrn2ImgPix( pInfo, [sEvent.x,sEvent.y] )

	; Get the first coord and determine whether
	; we're drawing a horizontal or vertical ROI
	oROI->getProperty, DATA=data
	xLenSq = (data[0]-imgCoords[0])^2
	yLenSq = (data[1]-imgCoords[1])^2

	if xLenSq gt yLenSq then begin ; horizontal line
		imgCoords = [imgCoords[0],data[1]]
	endif else begin
		imgCoords = [data[0],imgCoords[1]]
	endelse

	; Change the final point
	oROI->replaceData, [imgCoords[0], imgCoords[1]], START=1

	; Change the final point of our display ROIs
	oDispROI->replaceData, [imgCoords[0], imgCoords[1]], START=1

	; Redisplay
	(*pInfo).oWindow->draw, (*pInfo).oViewGroup

end ; of shielding_guiRightROIMotion


;--------------------------------------------------------------------
;
;    PURPOSE  Complete the new horizontal or vertical line ROI
;
pro shielding_guiRightROIStop, $
	pInfo, $
	imgCoords

	; Get current ROI
	oROI = (*pInfo).oCurROI
	if not obj_valid( oROI ) then return
	oDispROI = (*pInfo).oDispCurROI

	; Add this point to our current ROI
	oROI->replaceData, [imgCoords[0], imgCoords[1]], START=1

	; Add to our display ROI
	oDispROI->replaceData, [imgCoords[0], imgCoords[1]], START=1

	; Name this ROI and display
	oROIGroup = (*pInfo).oROIGroup
	oROI->getProperty, DATA=data
	name = shielding_guiGenerateROIName( oROIGroup, PREFIX='S' )
	oROI->setProperty, NAME=name
	oDispROI->setProperty, NAME=name, TEXT_ANCHOR=data[0:1,0]

	; Add to the ROI group for this slice
	oROIGroup->add, oROI
	(*pInfo).oModel->remove, oDispROI
	(*pInfo).oDispROIGroup->add, oDispROI

	; Remove the reference to this object in the state
	(*pInfo).oCurROI = obj_new()
	(*pInfo).oDispCurROI = obj_new()

	; Redisplay
	(*pInfo).oWindow->draw, (*pInfo).oViewGroup

end ; of shielding_guiRightROIStop


;--------------------------------------------------------------------
;
;    PURPOSE  Start drawing a new rectangular ROI
;
pro shielding_guiRectROIStart, $
	pInfo, $
	imgCoords

	; Get Current ROI
	oROI = (*pInfo).oCurROI
	oDispROI = (*pInfo).oDispCurROI

	; Start building a new ROI if we don't have one
	if obj_valid( oROI ) eq 0 then begin

		; Create new ROI
		oROI = obj_new( 'IDLgrROI', COLOR=[0,0,255], STYLE=2 )
		(*pInfo).oCurROI = oROI

		; Create new display ROI
		oDispROI = obj_new( 'MKgrROI', COLOR=[0,0,255], STYLE=2, $
				THICK=(*pInfo).roiThick, TEXT_SIZE=(*pInfo).textSize )
		(*pInfo).oModel->add, oDispROI
		(*pInfo).oDispCurROI = oDispROI

	endif

	; Add four corners, temporarily all at the same starting point
	oROI->setProperty, DATA=[ [imgCoords[0], imgCoords[1]], $
			[imgCoords[0], imgCoords[1]], $
			[imgCoords[0], imgCoords[1]], $
			[imgCoords[0], imgCoords[1]] ]

	; Add to our display ROI and redraw
	oDispROI->setProperty, DATA=[ [imgCoords[0], imgCoords[1]], $
			[imgCoords[0], imgCoords[1]], $
			[imgCoords[0], imgCoords[1]], $
			[imgCoords[0], imgCoords[1]] ]
	(*pInfo).oWindow->draw, (*pInfo).oViewGroup

end ; of shielding_guiRectROIStart


;--------------------------------------------------------------------
;
;    PURPOSE  Update the size of the new rectangular ROI
;
pro shielding_guiRectROIMotion, $
	pInfo, $
	sEvent

	; Get current ROI
	oROI = (*pInfo).oCurROI
	if not obj_valid( oROI ) then return
	oDispROI = (*pInfo).oDispCurROI

	; Get cursor location in image coordinates
	imgCoords = shielding_guiScrn2ImgPix( pInfo, [sEvent.x,sEvent.y] )

	; Get the coordinates of the first vertex
	oROI->getProperty, DATA=data

	; Update the variable vertices
	oROI->replaceData, $
			[ [data[0], data[1]], $
			  [imgCoords[0], data[1]], $
			  [imgCoords[0], imgCoords[1]], $
			  [data[0], imgCoords[1]] ]

	; Change the final point of our display ROIs
	oDispROI->replaceData, $
			[ [data[0], data[1]], $
			  [imgCoords[0], data[1]], $
			  [imgCoords[0], imgCoords[1]], $
			  [data[0], imgCoords[1]] ]

	; Redisplay
	(*pInfo).oWindow->draw, (*pInfo).oViewGroup

end ; of shielding_guiRectROIMotion


;--------------------------------------------------------------------
;
;    PURPOSE  Complete the new rectangular ROI
;
pro shielding_guiRectROIStop, $
	pInfo, $
	sEvent

	; Get current ROI
	oROI = (*pInfo).oCurROI
	if not obj_valid( oROI ) then return
	oDispROI = (*pInfo).oDispCurROI

	; Get cursor location in image coordinates
	imgCoords = shielding_guiScrn2ImgPix( pInfo, [sEvent.x,sEvent.y] )

	; Get the coordinates of the first vertex
	oROI->getProperty, DATA=data

	; Update the variable vertices
	oROI->replaceData, $
			[ [data[0], data[1]], $
			  [imgCoords[0], data[1]], $
			  [imgCoords[0], imgCoords[1]], $
			  [data[0], imgCoords[1]] ]

	; Change the final point of our display ROIs
	oDispROI->replaceData, $
			[ [data[0], data[1]], $
			  [imgCoords[0], data[1]], $
			  [imgCoords[0], imgCoords[1]], $
			  [data[0], imgCoords[1]] ]

	; Name this ROI and display
	oROIGroup = (*pInfo).oROIGroup
	oROI->getProperty, DATA=data
	if (*pInfo).mode eq 'h_roi' then begin
		prefix = 'H'
		color = [255,0,0]
	endif else begin
		prefix = 'R'
		color = [0,0,255]
	endelse
	name = shielding_guiGenerateROIName( oROIGroup, PREFIX=prefix )
	oROI->setProperty, NAME=name, COLOR=color
	oDispROI->setProperty, NAME=name, TEXT_ANCHOR=data[0:1,0], COLOR=color

	; Add to the ROI group for this slice
	oROIGroup->add, oROI
	(*pInfo).oModel->remove, oDispROI
	(*pInfo).oDispROIGroup->add, oDispROI

	; Remove the reference to this object in the state
	(*pInfo).oCurROI = obj_new()
	(*pInfo).oDispCurROI = obj_new()

	; Redisplay
	(*pInfo).oWindow->draw, (*pInfo).oViewGroup

end ; of shielding_guiRectROIStop



;--------------------------------------------------------------------
;
;    PURPOSE  Draw a new source point ROI
;
function shielding_guiAddSourcePoint, $
	pInfo, $
	imgCoords

	; Get Current ROI
	oROI = (*pInfo).oCurROI
	oDispROI = (*pInfo).oDispCurROI

	; Start building a new ROI if we don't have one
	if obj_valid( oROI ) eq 0 then begin

		; Create new ROI
		oSymbol = obj_new( 'IDLgrSymbol', 5, SIZE=5 )
		oROI = obj_new( 'IDLgrROI', DATA=imgCoords, $
				COLOR=[0,200,0], STYLE=0, SYMBOL=oSymbol ) ; point
		oDispROI = obj_new( 'MKgrROI', DATA=imgCoords, $
				COLOR=[0,200,0], STYLE=0, SYMBOL=oSYMBOL, $
				THICK=(*pInfo).roiThick, TEXT_SIZE=(*pInfo).textSize )

		; Add this to this group
		oROIGroup = (*pInfo).oROIGroup
		oROIGroup->add, oROI
		(*pInfo).oDispROIGroup->add, oDispROI

		; Name this ROI (must do this after determining the group so that
		; we can make sure we don't repeat a name)
		name = shielding_guiGenerateROIName( oROIGroup, PREFIX='P' )
		oROI->setProperty, NAME=name
		oDispROI->setProperty, NAME=name

		; Display
		(*pInfo).oWindow->draw, (*pInfo).oViewGroup

	endif

	return, oROI

end ; of shielding_guiAddSourcePoint


;--------------------------------------------------------------------
;
;    PURPOSE  Draw a new query point ROI
;
pro shielding_guiAddQueryPoint, $
	pInfo, $
	imgCoords

	; Get Current ROI
	oROI = (*pInfo).oCurROI
	oDispROI = (*pInfo).oDispCurROI

	; Start building a new ROI if we don't have one
	if obj_valid( oROI ) eq 0 then begin

		; Create new ROI
		oSymbol = obj_new( 'IDLgrSymbol', 5, SIZE=5 )
		oROI = obj_new( 'IDLgrROI', DATA=imgCoords, $
				COLOR=[0,0,255], STYLE=0, SYMBOL=oSymbol ) ; point
		oDispROI = obj_new( 'MKgrROI', DATA=imgCoords, $
				COLOR=[0,0,255], STYLE=0, SYMBOL=oSYMBOL, $
				THICK=(*pInfo).roiThick, TEXT_SIZE=(*pInfo).textSize )

		; Add this to this group
		oROIGroup = (*pInfo).oROIGroup
		oROIGroup->add, oROI
		(*pInfo).oDispROIGroup->add, oDispROI

		; Name this ROI (must do this after determining the group so that
		; we can make sure we don't repeat a name)
		name = shielding_guiGenerateROIName( oROIGroup, PREFIX='Q' )
		oROI->setProperty, NAME=name
		oDispROI->setProperty, NAME=name

		; Display
		(*pInfo).oWindow->draw, (*pInfo).oViewGroup

		shielding_guiSetQueryData, pInfo, oROI, /PROMPT

	endif

end ; of shielding_guiAddQueryPoint


;--------------------------------------------------------------------
;
;    PURPOSE  Get the selected S ROI from the event structure
;
function shielding_guiGetSelectedSROI, pInfo, sEvent

	; Get the selected object from the event structure
	oSelArray = (*pInfo).oWindow->select( (*pInfo).oView, $
			DIMENSIONS=[10,10], [sEvent.x, sEvent.y] )

	; Return an empty object if the user didn't select a ROI
	for i=0, n_elements( oSelArray )-1 do begin

		selType = size( oSelArray[i], /TYPE )
		if selType eq 11 then begin
			if obj_isa( oSelArray[i], 'MKgrROI' ) then begin
				oSelArray[i]->getProperty, NAME=name
;				prefix = (strsplit( name, '_', /EXTRACT ))[0]
;				if prefix eq 'S' then begin
					return, oSelArray[i]
;				endif
			endif
		endif

	endfor

	return, obj_new()

end ; of shielding_guiGetSelectedSROI


;--------------------------------------------------------------------
;
;    PURPOSE  Get coordinates of the nearest ROI vertex (in image
;			  space)
;
function shielding_guiGetSnapCoords, pInfo, sEvent

	catch, err
	if err ne 0 then return, -1L

	; Get the nearest S ROI
	oROI = shielding_guiGetSelectedSROI( pInfo, sEvent )
	if not obj_valid( oROI ) then return, -1L

	; Get the nearest S ROI vertex
	vertIndex = oROI->pickVertex( (*pInfo).oWindow, $
			(*pInfo).oView, [sEvent.x, sEvent.y] )

	if vertIndex ge 0 then begin

		oROI->getProperty, DATA=data
		newCoords = data[*,vertIndex]
		return, newCoords

	endif

	return, -1L

end ; of shielding_guiGetSnapCoords



;--------------------------------------------------------------------
;
;    PURPOSE  Copy a ROI object
;
function copyROI, oROI

	if not obj_valid( oROI ) then return, obj_new()

	oROI->getProperty, NAME=name, DATA=data, COLOR=color, $
			LINESTYLE=linestyle, STYLE=style
	return, obj_new( 'MKgrROI', NAME=name, DATA=data, COLOR=color, $
			LINESTYLE=linestyle, STYLE=style, $
			THICK=(*pInfo).roiThick, TEXT_SIZE=(*pInfo).textSize )

end ; of copyROI


;--------------------------------------------------------------------
;
;    PURPOSE  Start moving a ROI vertex

pro shielding_guiMoveROIVertexStart, pInfo, sEvent

	if not obj_valid( (*pInfo).oCurROI ) then return

	; Pick the nearest ROI vertex
	vertIndex = (*pInfo).oDispCurROI->pickVertex( (*pInfo).oWindow, $
			(*pInfo).oView, [sEvent.x, sEvent.y] )

	if vertIndex ge 0 then begin

		; Show the vertex
		(*pInfo).oDispCurROI->getProperty, DATA=vertData
		(*pInfo).oVertexModel->setProperty, HIDE=0
		(*pInfo).oVertexModel->reset
		selVert = vertData[*,vertIndex]
		(*pInfo).oVertexModel->translate, selVert[0], $
				selVert[1], selVert[2]

		; Redisplay
		(*pInfo).oWindow->draw, (*pInfo).oViewGroup

		; Calculate the current cursor location
		curCoords = shielding_guiScrn2ImgPix( pInfo, [sEvent.x,sEvent.y] )

		; Set the state values
		(*pInfo).curVertIndex = vertIndex
		(*pInfo).curScrnCoords = curCoords

	endif

end ; of shielding_guiMoveROIVertexStart


;--------------------------------------------------------------------
;
;    PURPOSE  Update movement of a ROI vertex
;
pro shielding_guiMoveROIVertexMotion, pInfo, sEvent

	; Get current display and database ROIs
	oDispROI = (*pInfo).oDispCurROI
	oROI = (*pInfo).oCurROI
	vertIndex = (*pInfo).curVertIndex
	lastCurCoords = (*pInfo).curScrnCoords

	if obj_valid( oROI ) eq 0 then return

	; Calculate the vertex transformation
	curScrnCoords = shielding_guiScrn2ImgPix( pInfo, [sEvent.x,sEvent.y] )
	xformCoords = curScrnCoords - lastCurCoords
	(*pInfo).curScrnCoords = curScrnCoords

	; Determine the type of ROI
	oROI->getProperty, NAME=name, DATA=data, N_VERTS=nVerts
	prefix = (strsplit( name, '_', /EXTRACT ))[0]

	if (prefix eq 'R') or (prefix eq 'H') then begin

		; We're moving the vertex of a rectangle.  Find the affected
		; neighbouring vertices.
		curVert = data[*,vertIndex]
		if vertIndex eq (nVerts-1) then begin
			befIndex = vertIndex-1
			aftIndex = 0
		endif else if vertIndex eq 0 then begin
			befIndex = nVerts-1
			aftIndex = vertIndex+1
		endif else begin
			befIndex = vertIndex-1
			aftIndex = vertIndex+1
		endelse

		; Determine which directions in which to move the neighbouring
		; vertices
		if curVert[0] eq data[0,befIndex] then begin
			curVert = [ data[0,vertIndex] + xformCoords[0], $
						data[1,vertIndex] + xformCoords[1] ]
			befVert = [ data[0,befIndex] + xformCoords[0], $
						data[1,befIndex] ]
			aftVert = [ data[0,aftIndex], $
						data[1,aftIndex] + xformCoords[1] ]
		endif else begin
			curVert = [ data[0,vertIndex] + xformCoords[0], $
						data[1,vertIndex] + xformCoords[1] ]
			befVert = [ data[0,befIndex], $
						data[1,befIndex] + xformCoords[1] ]
			aftVert = [ data[0,aftIndex] + xformCoords[0], $
						data[1,aftIndex] ]
		endelse

		; Update the database and display ROIs
		oROI->replaceData, befVert[0], befVert[1], START=befIndex
		oROI->replaceData, curVert[0], curVert[1], START=vertIndex
		oROI->replaceData, aftVert[0], aftVert[1], START=aftIndex

		oDispROI->replaceData, befVert[0], befVert[1], START=befIndex
		oDispROI->replaceData, curVert[0], curVert[1], START=vertIndex
		oDispROI->replaceData, aftVert[0], aftVert[1], START=aftIndex

	endif else if prefix eq 'S' then begin

		; We're moving the vertex of a line ROI.  Determine whether this is
		; a free line or a right line.
		curVert = data[*,vertIndex]
		if vertIndex eq 0 then begin
			othIndex = vertIndex+1
		endif else begin
			othIndex = vertIndex-1
		endelse
		othVert = data[*,othIndex]

		if curVert[0] eq othVert[0] then begin

			; This is a vertical right ROI.  Only allow motion in the
			; y-direction.
			xformCoords = [ 0.0, xformCoords[1] ]

		endif else if curVert[1] eq othVert[1] then begin

			; This is a vertical right ROI.  Only allow motion in the
			; y-direction.
			xformCoords = [ xformCoords[0], 0.0 ]

		endif

		curVert = curVert + xformCoords

		; Update the database and display ROIs
		oROI->replaceData, curVert[0], curVert[1], START=vertIndex
		oDispROI->replaceData, curVert[0], curVert[1], START=vertIndex

	endif else begin

		curVert = data[*,vertIndex]
		curVert = curVert + xformCoords

		; Update the database and display ROIs
		oROI->replaceData, curVert[0], curVert[1], START=vertIndex
		oDispROI->replaceData, curVert[0], curVert[1], START=vertIndex

	end

	; Update the displayed vertex
	(*pInfo).oVertexModel->setProperty, HIDE=0
	(*pInfo).oVertexModel->translate, xformCoords[0], xformCoords[1], 0
	(*pInfo).oWindow->draw, (*pInfo).oViewGroup

	; Update UI information if it's an uptake or imaging ROI
	oROI->getProperty, NAME=name, DATA=data
	widget_control, (*pInfo).wFloorplanScaleText, GET_VALUE=scale
	scale = float(scale[0])
	data *= scale
	data = format_float( data, DEC=2 )
	prefix = (strsplit( name, '_', /EXTRACT ))[0]

	case prefix of
	'P' : begin
		eP = (*pInfo).eP
		widget_control, (*pInfo).wSourceTable, GET_VALUE=value
		rows = where( value[0,*] eq name, nRows )
		for i=0, nRows-1 do begin
			widget_control, (*pInfo).wSourceTable, $
					USE_TABLE_SELECT=[eP.x,rows[i],eP.y,rows[i]], $
					SET_VALUE=[data[0],data[1]]
		endfor
	end
	'S' : begin
		eS = (*pInfo).eS
		widget_control, (*pInfo).wShieldTable, GET_VALUE=value
		rows = where( value[0,*] eq name, nRows )
		for i=0, nRows-1 do begin
			widget_control, (*pInfo).wShieldTable, $
					USE_TABLE_SELECT=[eS.x1,rows[i],eS.y2,rows[i]], $
					SET_VALUE=[data[0],data[1],data[3],data[4]]
		endfor
	end
	'H' : begin
		eH = (*pInfo).eH
		widget_control, (*pInfo).wHShieldTable, GET_VALUE=value
		rows = where( value[0,*] eq name, nRows )
		for i=0, nRows-1 do begin
			widget_control, (*pInfo).wHShieldTable, $
					USE_TABLE_SELECT=[eH.x1,rows[i],eH.y4,rows[i]], $
					SET_VALUE=[data[0],data[1],data[3],data[4], $
					data[6],data[7],data[9],data[10]]
		endfor
	end
	'R' : begin
		eR = (*pInfo).eR
		widget_control, (*pInfo).wRegionTable, GET_VALUE=value
		rows = where( value[0,*] eq name, nRows )
		for i=0, nRows-1 do begin
			widget_control, (*pInfo).wRegionTable, $
					USE_TABLE_SELECT=[eR.x1,rows[i],eR.y4,rows[i]], $
					SET_VALUE=[data[0],data[1],data[3],data[4],$
					data[6],data[7],data[9],data[10]]
		endfor
	end
	else :
	endcase

end ; of shielding_guiMoveROIVertexMotion


;--------------------------------------------------------------------
;
;    PURPOSE  Complete movement of a ROI vertex
;
pro shielding_guiMoveROIVertexStop, pInfo, sEvent

	; Get current display and database ROIs
	oROI = (*pInfo).oCurROI

	; Recalculate max pixel if this is a region ROI
	oROI->getProperty, NAME=name
	prefix = (strsplit( name, '_', /EXTRACT ))[0]

	case prefix of
	'R' : begin
		if max( *(*pInfo).pSeries1 ) gt 0 then begin
			shielding_guiFindMax, pInfo, oROI
		endif
	end
	else :
	endcase

end ; of shielding_guiMoveROIVertexStop


;--------------------------------------------------------------------
;
;    PURPOSE  Remember this vertex
;
pro shielding_guiExtendTrimStart, pInfo, sEvent

	if not obj_valid( (*pInfo).oCurROI ) then return

	; Pick the nearest ROI vertex
	vertIndex = (*pInfo).oDispCurROI->pickVertex( (*pInfo).oWindow, $
			(*pInfo).oView, [sEvent.x, sEvent.y] )

	if vertIndex ge 0 then begin

		; Show the vertex
		(*pInfo).oDispCurROI->getProperty, DATA=vertData
		(*pInfo).oVertexModel->setProperty, HIDE=0
		(*pInfo).oVertexModel->reset
		selVert = vertData[*,vertIndex]
		(*pInfo).oVertexModel->translate, selVert[0], $
				selVert[1], selVert[2]

		; Redisplay
		(*pInfo).oWindow->draw, (*pInfo).oViewGroup

		; Calculate the current cursor location
		curCoords = shielding_guiScrn2ImgPix( pInfo, [sEvent.x,sEvent.y] )

		; Set the state values
		(*pInfo).curVertIndex = vertIndex
		(*pInfo).curScrnCoords = curCoords

	endif

end ; of shielding_guiExtendTrimStart


;--------------------------------------------------------------------
;
;    PURPOSE  Complete extension of a shield ROI
;
pro shielding_guiExtendTrimStop, pInfo, oEndROI

	; Get current display and database ROIs
	oDispROI = (*pInfo).oDispCurROI
	oROI = (*pInfo).oCurROI
	vertIndex = (*pInfo).curVertIndex

	if obj_valid( (*pInfo).oCurROI ) eq 0 then return
	if obj_valid( oEndROI ) eq 0 then return

	(*pInfo).oCurROI->getProperty, DATA=data1, NAME=name
	oEndROI->getProperty, DATA=data2
	coords = shielding_guiGetIntersect( data1, data2 )

	widget_control, (*pInfo).wFloorplanScaleText, GET_VALUE=scale
	scale = float(scale[0])

	if (coords[0] le (*pInfo).nPx) and (coords[1] le (*pInfo).nPy) then begin

		(*pInfo).oDispCurROI->replaceData, START=vertIndex, FINISH=vertIndex, coords
		(*pInfo).oCurROI->replaceData, START=vertIndex, FINISH=vertIndex, coords

		; Update table
		eS = (*pInfo).eS
		(*pInfo).oCurROI->getProperty, DATA=data
		data *= scale
		data = format_float( data, DEC=2 )
		widget_control, (*pInfo).wShieldTable, GET_VALUE=value
		rows = where( value[eS.name,*] eq name, nRows )
		for i=0, nRows-1 do begin
			widget_control, (*pInfo).wShieldTable, $
					USE_TABLE_SELECT=[eS.x1,rows[i],eS.y2,rows[i]], $
					SET_VALUE=[data[0],data[1],data[3],data[4]]
		endfor

	endif

	; Reset ROI colour and hide vertices
	(*pInfo).oCurROI->getProperty, COLOR=color
	(*pInfo).oDispCurROI->setProperty, COLOR=color
	(*pInfo).oDispCurROI = obj_new()
	(*pInfo).oVertexModel->setProperty, HIDE=1
	(*pInfo).oCurROI = obj_new()
	(*pInfo).curVertIndex = -1L
	(*pInfo).curScrnCoords = [0,0]

end ; of shielding_guiExtendTrimStop


;--------------------------------------------------------------------
;
;    PURPOSE  Start moving a entire ROI

pro shielding_guiMoveROIStart, pInfo, sEvent

	if not obj_valid( (*pInfo).oCurROI ) then return

	; Calculate the vertex transformation
	curCoords = shielding_guiScrn2ImgPix( pInfo, [sEvent.x,sEvent.y] )

	; Highlight the entire ROI
	(*pInfo).oDispCurROI->setProperty, COLOR=[0,255,0]

	; Redisplay
	(*pInfo).oWindow->draw, (*pInfo).oViewGroup


	(*pInfo).curScrnCoords = curCoords

end ; of shielding_guiMoveROIStart


;--------------------------------------------------------------------
;
;    PURPOSE  Update movement of a ROI
;
pro shielding_guiMoveROIMotion, pInfo, sEvent

	; Get current display and database ROIs
	oDispROI = (*pInfo).oDispCurROI
	oROI = (*pInfo).oCurROI
	lastCoords = (*pInfo).curScrnCoords

	if obj_valid( oROI ) eq 0 then return

	; Calculate the vertex transformation
	curCoords = shielding_guiScrn2ImgPix( pInfo, [sEvent.x,sEvent.y] )
	xformCoords = curCoords - lastCoords
	(*pInfo).curScrnCoords = curCoords

	; Update the display ROI
	oDispROI->translate, xformCoords[0], xformCoords[1], 0
	(*pInfo).oWindow->draw, (*pInfo).oViewGroup

	; Update the database ROI
	oROI->translate, xformCoords[0], xformCoords[1], 0

	; Update UI information if it's an uptake or imaging ROI
	oROI->getProperty, NAME=name, DATA=data
	widget_control, (*pInfo).wFloorplanScaleText, GET_VALUE=scale
	scale = float(scale[0])
	data *= scale
	data = format_float( data, DEC=2 )
	prefix = (strsplit( name, '_', /EXTRACT ))[0]

	case prefix of
	'P' : begin
		eP = (*pInfo).eP
		widget_control, (*pInfo).wSourceTable, GET_VALUE=value
		rows = where( value[eP.name,*] eq name, nRows )
		for i=0, nRows-1 do begin
			widget_control, (*pInfo).wSourceTable, $
					USE_TABLE_SELECT=[eP.x,rows[i],eP.y,rows[i]], $
					SET_VALUE=[data[0],data[1]]
		endfor
	end
	'S' : begin
		eS = (*pInfo).eS
		widget_control, (*pInfo).wShieldTable, GET_VALUE=value
		rows = where( value[eS.name,*] eq name, nRows )
		for i=0, nRows-1 do begin
			widget_control, (*pInfo).wShieldTable, $
					USE_TABLE_SELECT=[eS.x1,rows[i],eS.y2,rows[i]], $
					SET_VALUE=[data[0],data[1],data[3],data[4]]
		endfor
	end
	'H' : begin
		eH = (*pInfo).eH
		widget_control, (*pInfo).wHShieldTable, GET_VALUE=value
		rows = where( value[eH.name,*] eq name, nRows )
		for i=0, nRows-1 do begin
			widget_control, (*pInfo).wHShieldTable, $
					USE_TABLE_SELECT=[eH.x1,rows[i],eH.y4,rows[i]], $
					SET_VALUE=[data[0],data[1],data[3],data[4], $
					data[6],data[7],data[9], data[10]]
		endfor
	end
	'R' : begin
		eR = (*pInfo).eR
		widget_control, (*pInfo).wRegionTable, GET_VALUE=value
		rows = where( value[eR.name,*] eq name, nRows )
		for i=0, nRows-1 do begin
			widget_control, (*pInfo).wRegionTable, $
					USE_TABLE_SELECT=[eR.x1,rows[i],eR.y4,rows[i]], $
					SET_VALUE=[data[0],data[1],data[3],data[4], $
					data[6],data[7],data[9],data[10]]
		endfor
	end
	else :
	endcase

end ; of shielding_guiMoveROIMotion


;--------------------------------------------------------------------
;
;    PURPOSE  Complete movement of a ROI
;
pro shielding_guiMoveROIStop, pInfo, sEvent

	; Get current display and database ROIs
	oDispROI = (*pInfo).oDispCurROI
	oROI = (*pInfo).oCurROI
	lastCoords = (*pInfo).curScrnCoords

	if obj_valid( oROI ) eq 0 then return

	; Calculate the vertex transformation
	curCoords = shielding_guiScrn2ImgPix( pInfo, [sEvent.x,sEvent.y] )
	xformCoords = curCoords - lastCoords

	; Update the display ROI
	oDispROI->translate, xformCoords[0], xformCoords[1], 0
	(*pInfo).oWindow->draw, (*pInfo).oViewGroup

	; Update the database ROI
	oROI->translate, xformCoords[0], xformCoords[1], 0

	; Update UI information if it's an uptake or imaging ROI
	oROI->getProperty, NAME=name, DATA=data
	widget_control, (*pInfo).wFloorplanScaleText, GET_VALUE=scale
	scale = float(scale[0])
	data *= scale
	data = format_float( data, DEC=2 )
	prefix = (strsplit( name, '_', /EXTRACT ))[0]

	case prefix of
	'P' : begin
		eP = (*pInfo).eP
		widget_control, (*pInfo).wSourceTable, GET_VALUE=value
		rows = where( value[eP.name,*] eq name, nRows )
		for i=0, nRows-1 do begin
			widget_control, (*pInfo).wSourceTable, $
					USE_TABLE_SELECT=[eP.x,rows[i],eP.y,rows[i]], $
					SET_VALUE=[data[0],data[1]]
		endfor
	end
	'S' : begin
		eS = (*pInfo).eS
		widget_control, (*pInfo).wShieldTable, GET_VALUE=value
		rows = where( value[eS.name,*] eq name, nRows )
		for i=0, nRows-1 do begin
			widget_control, (*pInfo).wShieldTable, $
					USE_TABLE_SELECT=[eS.x1,rows[i],eS.y2,rows[i]], $
					SET_VALUE=[data[0],data[1],data[3],data[4]]
		endfor
	end
	'H' : begin
		eH = (*pInfo).eH
		widget_control, (*pInfo).wHShieldTable, GET_VALUE=value
		rows = where( value[eH.name,*] eq name, nRows )
		for i=0, nRows-1 do begin
			widget_control, (*pInfo).wHShieldTable, $
					USE_TABLE_SELECT=[eH.x1,rows[i],eH.y4,rows[i]], $
					SET_VALUE=[data[0],data[1],data[3],data[4], $
					data[6],data[7],data[9],data[10]]
		endfor
	end
	'R' : begin
		eR = (*pInfo).eR
		if total( *(*pInfo).pSeries1 ) gt 0 then begin
			shielding_guiFindMax, pInfo, oROI
		endif
		widget_control, (*pInfo).wRegionTable, GET_VALUE=value
		rows = where( value[eR.name,*] eq name, nRows )
		for i=0, nRows-1 do begin
			widget_control, (*pInfo).wRegionTable, $
					USE_TABLE_SELECT=[eR.x1,rows[i],eR.y4,rows[i]], $
					SET_VALUE=[data[0],data[1],data[3],data[4], $
					data[6],data[7],data[9],data[10]]
		endfor
	end
	else :
	endcase

end ; of shielding_guiMoveROIStop


;--------------------------------------------------------------------
;
;    PURPOSE  Delete a ROI from the viewport(s) and ROI array
;
pro shielding_guiDeleteROI, pInfo, oROI

	if not obj_valid( oROI ) then return
;	oDispROI = (*pInfo).oDispCurROI
	oROIGroup = (*pInfo).oROIGroup
	bContained = oROIGroup->isContained( oROI, POSITION=pos )
	if not bContained then return
	oDispROI = (*pInfo).oDispROIGroup->get( POSITION=pos )

	; Delete UI information if it's an uptake, imaging or shield ROI
	oROI->getProperty, NAME=name

	widget_control, (*pInfo).wSourceTable, GET_VALUE=data, GET_UVALUE=curRow
	rows = where( data[0,*] eq name, nRows )
	notRows = where( data[0,*] ne name, nNotRows )
	if (nRows ne 0) and (nNotRows ne 0) then begin
		tmpData=data[*,[notRows]]
		data = tmpData
		tmpData = 0
		widget_control, (*pInfo).wSourceTable, SET_VALUE=data, SET_UVALUE=curRow-nRows
	endif
;	if nRows ne 0 then begin
;		; Delete this data row
;		widget_control, (*pInfo).wSourceTable, GET_UVALUE=curRow
;		widget_control, (*pInfo).wSourceTable, $
;				USE_TABLE_SELECT=[0,rows[0],0,rows[nRows-1]], $
;				/DELETE_ROWS, $
;				SET_UVALUE=(curRow-nRows)
;	endif

	widget_control, (*pInfo).wShieldTable, GET_VALUE=data
	rows = where( data[0,*] eq name, nRows )
	if nRows ne 0 then begin
		; Delete this data row
		widget_control, (*pInfo).wShieldTable, GET_UVALUE=curRow
		widget_control, (*pInfo).wShieldTable, $
				USE_TABLE_SELECT=[0,rows[0],0,rows[nRows-1]], $
				/DELETE_ROWS, $
				SET_UVALUE=(curRow-nRows)
	endif

	widget_control, (*pInfo).wHShieldTable, GET_VALUE=data
	rows = where(data[0,*] eq name, nRows )
	if nRows ne 0 then begin
		; Delete these data rows
		widget_control, (*pInfo).wHShieldTable, GET_UVALUE=curRow
		widget_control, (*pInfo).wHShieldTable, $
				USE_TABLE_SELECT=[0,rows[0],0,rows[nRows-1]], $
				/DELETE_ROWS, $
				SET_UVALUE=(curRow-nRows)
	endif

	widget_control, (*pInfo).wRegionTable, GET_VALUE=data
	rows = where( data[0,*] eq name, nRows )
	if nRows then begin
		; Delete these data rows
		widget_control, (*pInfo).wRegionTable, GET_UVALUE=curRow
		widget_control, (*pInfo).wRegionTable, $
				USE_TABLE_SELECT=[0,rows[0],0,rows[nRows-1]], $
				/DELETE_ROWS, $
				SET_UVALUE=(curRow-nRows)
	endif

	; Get attached objects
	oROI->getProperty, SYMBOL=oSym, UVALUE=oMaxROI
	oDispROI->getProperty, SYMBOL=oDispSym, UVALUE=oDispMaxROI

	; Delete symbol objects, if this is a point ROI or
	if obj_valid( oSym ) then obj_destroy, oSym
	if obj_valid( oDispSym ) then obj_destroy, oDispSym

	; Delete symbol/ROI objects if this is a region ROI
	if obj_valid( oMaxROI ) then begin
		oMaxROI->getProperty, SYMBOL=oSym
		if obj_valid( oSym ) then obj_destroy, oSym
		oROIGroup->remove, oMaxROI
		obj_destroy, oMaxROI
	endif
	if obj_valid( oDispMaxROI ) then begin
		oDispMaxROI->getProperty, SYMBOL=oSym
		if obj_valid( oSym ) then obj_destroy, oSym
		(*pInfo).oDispROIGroup->remove, oDispMaxROI
		obj_destroy, oDispMaxROI
	endif

	; Delete the ROI from the ROI group for this slice
	oROIGroup->remove, oROI
	obj_destroy, oROI

	; Delete the ROI from the display
	(*pInfo).oDispROIGroup->remove, oDispROI
	(*pInfo).oModel->remove, oDispROI
	obj_destroy, oDispROI

	; Redisplay
	(*pInfo).oWindow->draw, (*pInfo).oViewGroup

end ; of shielding_guiDeleteROI


;--------------------------------------------------------------------
;
;    PURPOSE  Update ROI buttons after a ROI event
;
pro shielding_guiUpdateROIButtons, pInfo

	oROIGroup = (*pInfo).oROIGroup

	if obj_valid( oROIGroup ) then begin

		bSensitive = 0b
		bPasteSensitive = 0b
		(*pInfo).oDispCopyROI->getProperty, HIDE=bHide
		if bHide eq 0L then bPasteSensitive = 1b
		if oROIGroup->count() gt 0 then begin
			; Enable move, delete, copy and leave paste as it is
			bSensitive = 1b
		endif else begin
			; No ROIs
			; Disable move and delete
			; Enable copy and paste if we're in copy mode and we have a
			; valid ROI on the clipboard (i.e. a copy ROI is displayed)
			case (*pInfo).mode of
				'move_roi_vertex':
				'move_roi':
				'delete_roi': begin
					; Stop move and delete
					widget_control, (*pInfo).wMoveROIVertexButton, $
							SET_VALUE='bitmaps\move_vertex.bmp', /BITMAP, $
							SET_BUTTON=0
					widget_control, (*pInfo).wMoveROIButton, $
							SET_VALUE='bitmaps\move_all.bmp', /BITMAP, $
							SET_BUTTON=0
					widget_control, (*pInfo).wDeleteROIButton, $
							SET_VALUE='bitmaps\delete.bmp', /BITMAP, $
							SET_BUTTON=0
					(*pInfo).mode = 'none'
					bPasteSensitive = 0b
				end
				'copy_roi': begin
					bPasteSensitive = bPasteSensitive
				end
				else : begin
					bPasteSensitive = 0b
				end
			endcase
		endelse

		; Enable/disable move and delete buttons
		widget_control, (*pInfo).wMoveROIVertexButton, $
				SENSITIVE=bSensitive
		widget_control, (*pInfo).wMoveROIButton, $
				SENSITIVE=bSensitive
		widget_control, (*pInfo).wExtendROIButton, $
				SENSITIVE=bSensitive
		widget_control, (*pInfo).wTrimROIButton, $
				SENSITIVE=bSensitive
		widget_control, (*pInfo).wDeleteROIButton, $
				SENSITIVE=bSensitive
		widget_control, (*pInfo).wCopyROIButton, $
				SENSITIVE=bSensitive
		widget_control, (*pInfo).wPasteROIButton, $
				SENSITIVE=bPasteSensitive

	endif

end ; of shielding_guiUpdateROIButtons


;--------------------------------------------------------------------
;
;    PURPOSE  Get the selected ROI from the event structure
;
function shielding_guiGetSelectedROI, pInfo, sEvent

	; Get the selected object from the event structure
	oSelArray = (*pInfo).oWindow->select( (*pInfo).oView, $
			DIMENSIONS=[10,10], [sEvent.x, sEvent.y] )

	; Return an empty object if the user didn't select a ROI
	for i=0, n_elements( oSelArray )-1 do begin

		selType = size( oSelArray[i], /TYPE )
		if selType eq 11 then begin
			if obj_isa( oSelArray[i], 'MKgrROI' ) then begin
				return, oSelArray[i]
			endif
		endif

	endfor

	return, obj_new()

end ; of shielding_guiGetSelectedROI


;--------------------------------------------------------------------
;
;    PURPOSE  Set the current ROI based on the currently selected
;			  graphical ROI
;
function shielding_guiSetCurrentROI, pInfo, oInROI, NONE=none

	; Reset previously selected ROIs
	shielding_guiAbandonROI, pInfo
	if obj_valid( (*pInfo).oCurROI ) then begin
		(*pInfo).oCurROI->getProperty, COLOR=color
		(*pInfo).oCurROI = obj_new()
	endif

	if obj_valid( (*pInfo).oDispCurROI ) then begin
		(*pInfo).oDispCurROI->setProperty, COLOR=color
		(*pInfo).oDispCurROI = obj_new()
		(*pInfo).oVertexModel->setProperty, HIDE=1
		(*pInfo).oWindow->draw, (*pInfo).oViewGroup
	endif

	if obj_valid( oInROI ) eq 0 then return, 0

	; Get the database ROI
	if obj_isa( oInROI, 'MKgrROI' ) then begin
		oDispROI = oInROI
		bContained = (*pInfo).oDispROIGroup->isContained( oDispROI, POSITION=pos )
		oROI = (*pInfo).oROIGroup->get( POSITION=pos )
	endif else begin
		oROI = oInROI
		bContained = (*pInfo).oROIGroup->isContained( oROI, POSITION=pos )
		oDispROI = (*pInfo).oDispROIGroup->get( POSITION=pos )
	endelse

	; Check - delete all references to this ROI if it's no longer valid
	if not obj_valid( oROI ) then begin
		shielding_guiDeleteROI, pInfo, oROI
		shielding_guiClearUndoRedoROI, pInfo
		shielding_guiUpdateROIButtons, pInfo
		return, 0
	endif

	; Highlight selected ROI and redisplay
	oDispROI->setProperty, COLOR=[0,255,0]
	(*pInfo).oWindow->draw, (*pInfo).oViewGroup

	; Set the state values
	(*pInfo).oDispCurROI = oDispROI
	(*pInfo).oCurROI = oROI
	(*pInfo).curVertIndex = -1L
	(*pInfo).curScrnCoords = [0.0,0.0]

	oROI->getProperty, name=name
	oDispROI->getProperty, name=nametoo
	print, "db roi is " + name + " disp roi is " + nametoo
	return, 1

end ; of shielding_guiSetCurrentROI


;--------------------------------------------------------------------
;
;    PURPOSE  Change ROI properties
;
pro shielding_guiFormatROIs, $
	pInfo, $
	THICK=thick, $
	TEXT_SIZE=textSize

	if n_elements( thick ) ne 0 then (*pInfo).roiThick = thick
	if n_elements( textSize ) ne 0 then (*pInfo).textSize = textSize

	if not obj_valid( (*pInfo).oDispROIGroup ) then return
	oROIs = (*pInfo).oDispROIGroup->get( /ALL, COUNT=nROIs )
	if nROIs eq 0 then return

	for i=0, nROIs-1 do begin
		if n_elements( thick ) ne 0 then $
			oROIs[i]->setProperty, THICK=thick
		if n_elements( textSize ) ne 0 then $
			oROIs[i]->setProperty, TEXT_SIZE=textSize
	endfor

	; Redisplay
	(*pInfo).oWindow->draw, (*pInfo).oViewGroup

end ; of shielding_guiShiftTLHC


;--------------------------------------------------------------------
;
;    PURPOSE  Set TLHC of view
;
pro shielding_guiShiftTLHC, pInfo, x, y

	(*pInfo).cPoint[0] -= x
	(*pInfo).cPoint[1] -= y

	shielding_guiUpdateViews, pInfo

end ; of shielding_guiShiftTLHC


;--------------------------------------------------------------------
;
;    PURPOSE  Move the colorbar
;
pro shielding_guiShiftCBar, pInfo, x, y

	; x and y should be in normalized coordinates.  Bark an error if
	; they are not within +/-1
	if (abs(x) gt 1) or (abs(y) gt 1) then begin
		void = dialog_message( /ERROR, 'Coordinates must be between -1 and 1')
		return
	endif

	(*pInfo).oCBar->getProperty, POSITION=pos
	w = pos[2]-pos[0]
	h = pos[3]-pos[1]
	(*pInfo).oCBar->setProperty, POSITION=[x,y,x+w,y+h]
	(*pInfo).oRuler->setProperty, POSITION=[x,y,x+w,y+h]

	(*pInfo).oWindow->draw, (*pInfo).oViewGroup

end ; of shielding_guiShiftCBar


;--------------------------------------------------------------------
;
;    PURPOSE  Set the compass properties
;
pro shielding_guiSetCompass, $
	pInfo, $
	POSITION=position, $
	NORTH=north, $
	COLOR=color

	if n_elements( position ) ne 0 then begin
		; x and y should be in normalized coordinates.  Bark an error if
		; they are not within +/-1
		if (abs(position[0]) gt 1) or (abs(position[1]) gt 1) then begin
			void = dialog_message( /ERROR, 'Coordinates must be between -1 and 1')
			return
		endif else begin
			(*pInfo).oCompass->setProperty, POSITION=position
		endelse
	endif
	if n_elements( north ) ne 0 then begin
		if (north lt 0) or (north gt 3) then begin
			void = dialog_message( /ERROR, 'North must be between 0 and 3')
			return
		endif else begin
			(*pInfo).oCompass->setProperty, NORTH=north
		endelse
	endif
	if n_elements( color ) eq 3 then begin
		if (max( color ) gt 255b) or (min( color ) lt 0b) then begin
			void = dialog_message( /ERROR, 'Invalid color' )
			return
		endif else begin
			(*pInfo).oCompass->setProperty, COLOR=color
		endelse
	endif else begin
		void = dialog_message( /ERROR, 'Invalid color' )
		return
	endelse

	(*pInfo).oWindow->draw, (*pInfo).oViewGroup

end ; of shielding_guiShiftCompass


;--------------------------------------------------------------------
;
;    PURPOSE  Main event handler
;
pro shielding_guiEvent, $
    sEvent        ; IN: event structure

	; Get the top level base user value
    widget_control, sEvent.top, GET_UVALUE=pInfo

	; Quit the application using the close box.
	if tag_names( sEvent, /STRUCTURE_NAME ) eq $
		'WIDGET_KILL_REQUEST' then begin
		; Check to make sure the user doesn't want to save
		; before exiting
		answer = dialog_message( 'Save session before exiting?', $
				/QUESTION, /CANCEL, TITLE='Quitting application' )
		if answer eq 'Cancel' then begin
			return
		endif else if answer eq 'Yes' then begin
			shielding_guiSaveSession, pInfo
		endif
		widget_control, sEvent.top, /DESTROY
		return
	endif

	forward_function shielding_guiMenuChoice

	; Branch according to the event ID
	; (the widget that created that event)
	case sEvent.id of

		(*pInfo).wZoomInButton : begin

			; Just zoom (don't change the current mode)
			(*pInfo).zoomFactor *= 1.5
			shielding_guiUpdateViews, pInfo

		end

		(*pInfo).wZoomOutButton : begin

			; Just zoom out (don't change the current mode)
			if (*pInfo).zoomFactor le 1 then begin
				(*pInfo).zoomFactor = 1
			endif else begin
				(*pInfo).zoomFactor /= 1.5
			endelse
			shielding_guiUpdateViews, pInfo

		end

		(*pInfo).wPanButton : begin

			; Reset last mode and set new mode
			shielding_guiResetLastMode, pInfo
			(*pInfo).mode = 'pan'
			widget_control, (*pInfo).wPanButton, $
					SET_VALUE='bitmaps\pan_active.bmp', /BITMAP, $
					SET_BUTTON=1

			; Update info text
			shielding_guiUpdateInfoText, pInfo, $
					VALUE='Left click and drag an image to pan. ' + $
					'Press the recentre button to recentre the image(s).'

			; Wait for user interaction...

		end

		(*pInfo).wRecentreButton : begin

			; Reset last mode and set new mode
			shielding_guiResetLastMode, pInfo
			(*pInfo).mode = 'none'

			; Update info text
			shielding_guiUpdateInfoText, pInfo, VALUE=''

			; Reset image centre and redraw
			(*pInfo).cPoint[0] = fix( (*pInfo).nPx/2 )
			(*pInfo).cPoint[1] = fix( (*pInfo).nPy/2 )

			; Reset scale factor to 1 and redraw
			(*pInfo).zoomFactor = 1

			shielding_guiUpdateViews, pInfo

		end

		(*pInfo).wCrosshairsButton : begin

			bSet = widget_info( (*pInfo).wCrosshairsButton, /BUTTON_SET )

			if bSet then begin
				; Set the bitmap to active and show the crosshairs
				widget_control, (*pInfo).wCrosshairsButton, $
						SET_VALUE='bitmaps\crosshairs_on.bmp', /BITMAP, $
						SET_BUTTON=1

				(*pInfo).oWindow->setCurrentCursor, IMAGE=lonarr(16)
				(*pInfo).oXAxis->setProperty, HIDE=0, $
						LOCATION=[(*pInfo).cPoint[0],(*pInfo).cPoint[1],0], $
						RANGE=[0,(*pInfo).nPx]
				(*pInfo).oYAxis->setProperty, HIDE=0, $
						LOCATION=[(*pInfo).cPoint[0],(*pInfo).cPoint[1],0], $
						RANGE=[0,(*pInfo).nPy]
				(*pInfo).oWindow->draw, (*pInfo).oViewGroup
			endif else begin
				; Unset the bitmap and hide the crosshairs
				widget_control, (*pInfo).wCrosshairsButton, $
						SET_VALUE='bitmaps\crosshairs_off.bmp', /BITMAP, $
						SET_BUTTON=0

				(*pInfo).oWindow->setCurrentCursor, 'CROSSHAIR'
				(*pInfo).oXAxis->setProperty, /HIDE
				(*pInfo).oYAxis->setProperty, /HIDE
				(*pInfo).oWindow->draw, (*pInfo).oViewGroup
			endelse

		end

		(*pInfo).wSourceROIButton : begin

			; Reset last mode and set new mode
			shielding_guiResetLastMode, pInfo
			(*pInfo).mode = 'source_roi'
			widget_control, (*pInfo).wSourceROIButton, $
					SET_VALUE='bitmaps\source_active.bmp', /BITMAP, $
					SET_BUTTON=1

			; Update info text
			shielding_guiUpdateInfoText, pInfo, $
					VALUE='Left click to mark the location of a source.'

			; Wait for the user to do something...

		end

		(*pInfo).wLineROIButton : begin

			; Reset last mode and set new mode
			shielding_guiResetLastMode, pInfo
			(*pInfo).mode = 'line_roi'
			widget_control, (*pInfo).wLineROIButton, $
					SET_VALUE='bitmaps\line_active.bmp', /BITMAP, $
					SET_BUTTON=1

			; Update info text
			shielding_guiUpdateInfoText, pInfo, $
					VALUE='Left click to mark the start and end points of the line ROI.'

			; Wait for the user to start drawing

		end

		(*pInfo).wRightROIButton : begin

			; Reset last mode and set new mode
			shielding_guiResetLastMode, pInfo
			(*pInfo).mode = 'right_roi'
			widget_control, (*pInfo).wRightROIButton, $
					SET_VALUE='bitmaps\right_active.bmp', /BITMAP, $
					SET_BUTTON=1

			; Update info text
			shielding_guiUpdateInfoText, pInfo, $
					VALUE='Left click to mark the start of the ROI.  Right click to mark the end.'

			; Wait for the user to start drawing

		end

		(*pInfo).wHROIButton : begin

			; Reset last mode and set new mode
			shielding_guiResetLastMode, pInfo
			(*pInfo).mode = 'h_roi'
			widget_control, (*pInfo).wHROIButton, $
					SET_VALUE='bitmaps\hshield_active.bmp', /BITMAP, $
					SET_BUTTON=1

			; Update info text
			shielding_guiUpdateInfoText, pInfo, $
					VALUE='Left click to mark the start of the ROI. Right click to mark the end.'

			; Wait for the user to start drawing

		end

		(*pInfo).wRectROIButton : begin

			; Reset last mode and set new mode
			shielding_guiResetLastMode, pInfo
			(*pInfo).mode = 'rect_roi'
			widget_control, (*pInfo).wRectROIButton, $
					SET_VALUE='bitmaps\rectangle_active.bmp', /BITMAP, $
					SET_BUTTON=1

			; Update info text
			shielding_guiUpdateInfoText, pInfo, $
					VALUE='Left click to mark the start of the ROI.  Right click to mark the end.'

			; Wait for the user to start drawing

		end

		(*pInfo).wQueryROIButton : begin

			; Reset last mode and set new mode
			shielding_guiResetLastMode, pInfo
			(*pInfo).mode = 'query_roi'
			widget_control, (*pInfo).wQueryROIButton, $
					SET_VALUE='bitmaps\query_active.bmp', /BITMAP, $
					SET_BUTTON=1

			; Update info text
			shielding_guiUpdateInfoText, pInfo, $
					VALUE='Left click to place a query point.'

			; Wait for the user to do something...

		end

		(*pInfo).wSnapROIButton : begin

			bSet = widget_info( (*pInfo).wSnapROIButton, /BUTTON_SET )
			if bSet then begin
				widget_control, (*pInfo).wSnapROIButton, $
						SET_VALUE='bitmaps\snap_active.bmp', /BITMAP, $
						SET_BUTTON=1
			endif else begin
				widget_control, (*pInfo).wSnapROIButton, $
						SET_VALUE='bitmaps\snap.bmp', /BITMAP, $
						SET_BUTTON=0
			endelse

		end

		(*pInfo).wUndoROIButton : begin

			; Don't change the last mode, just undo and
			; reset the last mode button to active
			shielding_guiKeepLastMode, pInfo

			; Undo the last change and update display
			shielding_guiUndoROI, pInfo
			shielding_guiUpdateROIButtons, pInfo

		end

		(*pInfo).wRedoROIButton : begin

			; Don't change the last mode, just redo and
			; reset the last mode button to active
			shielding_guiKeepLastMode, pInfo

			; Redo the last change and update the display
			shielding_guiRedoROI, pInfo
			shielding_guiUpdateROIButtons, pInfo

		end

		(*pInfo).wMoveROIVertexButton : begin

			; Reset last mode and set new mode
			shielding_guiResetLastMode, pInfo
			(*pInfo).mode = 'move_roi_vertex'
			widget_control, (*pInfo).wMoveROIVertexButton, $
					SET_VALUE='bitmaps\move_vertex_active.bmp', /BITMAP, $
					SET_BUTTON=1

			; Update info text
			shielding_guiUpdateInfoText, pInfo, $
					VALUE='Left click and drag a vertex to change the shape of a ROI.'

			; Wait for the user to select a ROI/vertex

		end

		(*pInfo).wExtendROIButton : begin

			shielding_guiResetLastMode, pInfo
			(*pInfo).mode = 'extend_roi'
			widget_control, (*pInfo).wExtendROIButton, $
					SET_VALUE='bitmaps\extend_active.bmp', /BITMAP, $
					SET_BUTTON=1

			; Update info text
			shielding_guiUpdateInfoText, pInfo, $
					VALUE='Left click to select vertex of line ROI to extend.'

			; Wait for the user to select a ROI/vertex

		end

		(*pInfo).wTrimROIButton : begin

			shielding_guiResetLastmode, pInfo
			(*pInfo).mode = 'trim_roi'
			widget_control, (*pInfo).wTrimROIButton, $
					SET_VALUE='bitmaps\trim_active.bmp', /BITMAP, $
					SET_BUTTON=1

			; Update info text
			shielding_guiUpdateInfoText, pInfo, $
					VALUE='Left click to select line ROI to trim.'

			; Wait for the user to select a ROI

		end


		(*pInfo).wMoveROIButton : begin

			; Reset last mode and set new mode
			shielding_guiResetLastMode, pInfo
			(*pInfo).mode = 'move_roi'
			widget_control, (*pInfo).wMoveROIButton, $
					SET_VALUE='bitmaps\move_all_active.bmp', /BITMAP, $
					SET_BUTTON=1

			; Update info text
			shielding_guiUpdateInfoText, pInfo, $
					VALUE='Left click and drag a ROI to change the ROI location.'

			; Wait for the user to select a ROI

		end

		(*pInfo).wDeleteROIButton : begin

			; Reset last mode and set new mode
			shielding_guiResetLastMode, pInfo
			(*pInfo).mode = 'delete_roi'
			widget_control, (*pInfo).wDeleteROIButton, $
					SET_VALUE='bitmaps\delete_active.bmp', /BITMAP, $
					SET_BUTTON=1

			; Update info text
			shielding_guiUpdateInfoText, pInfo, $
					VALUE='Left click on a ROI to select the region for deletion.'

			; Wait for the user to select the ROI

		end

		(*pInfo).wCopyROIButton : begin

			; Reset last mode
			shielding_guiResetLastMode, pInfo

			if (*pInfo).mode eq 'copy_roi' then begin

				; Set mode to none
				(*pInfo).mode = 'none'
				widget_control, (*pInfo).wPasteROIButton, $
						SENSITIVE=0

				; Update info text
				shielding_guiUpdateInfoText, pInfo, VALUE=''

				; Stop copy/paste
				shielding_guiCopyROIStop, pInfo


			endif else begin

				; Set mode to copy_roi
				(*pInfo).mode = 'copy_roi'
				widget_control, (*pInfo).wCopyROIButton, $
						SET_VALUE='bitmaps\copy_active.bmp', /BITMAP, $
						SET_BUTTON=0, $
						TOOLTIP='stop copy/paste ROI'

				shielding_guiUpdateInfoText, pInfo, $
						VALUE='Left click on a ROI to copy the region ' + $
						'to the clipboard. Press the paste button or ' + $
						'right click on an image and select ''paste'' ' + $
						'to paste the ROI on an image.  Press the stop ' + $
						'copy/paste button or select a different ' + $
						'operation to exit this mode.'

				; Wait for the user to select a ROI to copy

			endelse

		end

		(*pInfo).wPasteROIButton : begin

			; Unset the paste button and reset the copy button
			widget_control, (*pInfo).wPasteROIButton, $
					SET_BUTTON=0

			if (*pInfo).mode eq 'copy_roi' then begin

				shielding_guiPasteROI, pInfo
				shielding_guiUpdateROIButtons, pInfo

			endif

		end

		(*pInfo).wCalcThicknessButton : begin

			; Prompt user for input values
			text = textBox( $
				   GROUP_LEADER=(*pInfo).wTopBase, $
				   TITLE='Enter shielding parameters', $
				   LABEL=['Dose (uSv): ', 'Occupancy factor: ', $
				   		  'Allowable dose (uSv): '], $
				   VALUE=['1000', '1.0', '50'], $
				   CANCEL=bCancel )

			if bCancel then return

			d1	= float( text[0] )
			occ	= float( text[1] )
			d2	= float( text[2] )

			if (*pInfo).modality eq 'PET' then begin

				calcThickness, d1, occ, d2, ENERGY=511, TF=tf, LEAD=lead, CONCRETE=concrete

				; Display output
				text = ['To reduce ' + strtrim(d1,2) $
						+ ' uSv to ' + strtrim(d2*occ,2) + ' uSv (TF = ' $
						+ strtrim(tf,2) + ')', $
						+ 'for 511 keV photons:', $
						'  ' + strtrim(lead,2) + ' cm lead', $
						'  ' + strtrim(concrete,2) + ' cm concrete']

			endif else begin ; SPECT

				calcThickness, d1, occ, d2, ENERGY=140, TF=tf, LEAD=lead, CONCRETE=concrete

				; Display output
				text = ['To reduce ' + strtrim(d1,2) $
						+ ' uSv to ' + strtrim(d2*occ,2) + ' uSv (TF = ' $
						+ strtrim(tf,2) + ')', $
						+ 'for 140 keV photons:', $
						'  ' + strtrim(lead,2) + ' cm lead', $
						'  ' + strtrim(concrete,2) + ' cm concrete']

			endelse

			void = dialog_message( /INFO, TITLE='Shielding requirements', $
					text )

		end

		(*pInfo).wProtocolButton: begin

			oPoints = shielding_guiGetROIs( pInfo, /SOURCES, NAMES=names, $
					DESC=descs, COUNT=nPoints )
			if nPoints eq 0 then begin
				void = dialog_message( /ERROR, 'No source points defined' )
				return
			endif
			bOk = shielding_guiNewProtocol( PARENT=(*pInfo).wTopBase, $
					MODALITY=(*pInfo).modality, POINTS=names, DESC=descs, $
					SOURCES=sources, CANCEL=bCancel )
			if bCancel then return
			shielding_guiAddProtocol, pInfo, SOURCES=sources

		end

		(*pInfo).wMeasurePickButton: begin

			if widget_info( (*pInfo).wMeasurePickButton, /BUTTON_SET ) then begin

				widget_control, (*pInfo).wMeasurePickButton, $
						SET_VALUE='bitmaps\arrow_active.bmp', /BITMAP, $
						SET_BUTTON=1
				shielding_guiUpdateInfoText, pInfo, $
						VALUE='Left click to select the measurement origin.'

				; Wait for the user to select the point

			endif else begin

				widget_control, (*pInfo).wMeasurePickButton, $
						SET_VALUE='bitmaps\arrow.bmp', /BITMAP, $
						SET_BUTTON=0
				shielding_guiUpdateInfoText, pInfo, $
						VALUE=''
			endelse

		end ; measure

		(*pInfo).wFloorplanScaleText: begin

			if sEvent.type lt 3 then begin
				shielding_guiUpdateMeasurements, pInfo
			endif

		end

		(*pInfo).wDeleteSourceButton: begin

			; Reset last mode and set mode to none
			shielding_guiResetLastMode, pInfo
			(*pInfo).mode = 'none'

			shielding_guiTableDeleteRow, (*pInfo).wSourceTable, pInfo

		end

		(*pInfo).wHideSourcesButton: begin

			shielding_guiHideROIs, pInfo, /SOURCE

		end

		(*pInfo).wSourceTable: begin

			shielding_guiTableEvent, pInfo, sEvent

		end

		(*pInfo).wShieldTable: begin

			shielding_guiTableEvent, pInfo, sEvent

		end

;		(*pInfo).wInsertShieldButton: begin
;
;			; Reset last mode and set mode to none
;			shielding_guiResetLastMode, pInfo
;			(*pInfo).mode = 'none'
;
;			shielding_guiTableInsertRow, (*pInfo).wShieldTable, pInfo
;
;		end

		(*pInfo).wDeleteShieldButton: begin

			; Reset last mode and set mode to none
			shielding_guiResetLastMode, pInfo
			(*pInfo).mode = 'none'

			shielding_guiTableDeleteRow, (*pInfo).wShieldTable, pInfo

		end

		(*pInfo).wHideShieldsButton: begin

			shielding_guiHideROIs, pInfo, /SHIELD

		end

		(*pInfo).wHShieldTable: begin

			shielding_guiTableEvent, pInfo, sEvent

		end

;		(*pInfo).wInsertHShieldButton: begin
;
;			; Reset last mode and set mode to none
;			shielding_guiResetLastMode, pInfo
;			(*pInfo).mode = 'none'
;
;			shielding_guiTableInsertRow, (*pInfo).wHShieldTable, pInfo
;
;		end

		(*pInfo).wDeleteHShieldButton: begin

			; Reset last mode and set mode to none
			shielding_guiResetLastMode, pInfo
			(*pInfo).mode = 'none'

			shielding_guiTableDeleteRow, (*pInfo).wHShieldTable, pInfo

		end

		(*pInfo).wHideHShieldsButton: begin

			shielding_guiHideROIs, pInfo, /HSHIELD

		end

		(*pInfo).wRegionTable: begin

			shielding_guiTableEvent, pInfo, sEvent

		end

		(*pInfo).wDeleteRegionButton: begin

			; Reset last mode and set mode to none
			shielding_guiResetLastMode, pInfo
			(*pInfo).mode = 'none'

			shielding_guiTableDeleteRow, (*pInfo).wRegionTable, pInfo

		end

		(*pInfo).wHideRegionsButton: begin

			shielding_guiHideROIs, pInfo, /REGIONS

		end

		(*pInfo).wCalcRegionsButton: begin

			; Reset last mode
			shielding_guiResetLastMode, pInfo

			shielding_guiCalculateRegions, pInfo

			; Update dose map scale
			widget_control, (*pInfo).wResolutionText, GET_VALUE=value
			widget_control, (*pInfo).wDosemapScaleText, SET_VALUE=value

			; Rebuild maxROIs and update region table
			oROIs = (*pInfo).oROIGroup->get( /ALL, COUNT=nROIs )
			for iROI=0, nROIs-1 do begin
				if obj_valid( oROIs[iROI] ) then begin
					oROIs[iROI]->getProperty, NAME=name
					prefix = (strsplit( name, '_', /EXTRACT ))[0]
					if prefix eq 'R' and $
					   total( *(*pInfo).pSeries1 ) gt 0 then begin
						shielding_guiFindMax, pInfo, oROIs[iROI]
					endif
				endif
			endfor

			; Update views and redisplay
			shielding_guiUpdateImages, pInfo
			shielding_guiUpdateViews, pInfo

		end

		(*pInfo).wCalculateButton: begin

			; Reset last mode
			shielding_guiResetLastMode, pInfo

			shielding_guiCalculate, pInfo

			; Update dose map scale
			widget_control, (*pInfo).wResolutionText, GET_VALUE=value
			widget_control, (*pInfo).wDosemapScaleText, SET_VALUE=value

			; Rebuild maxROIs and update region table
			oROIs = (*pInfo).oROIGroup->get( /ALL, COUNT=nROIs )
			for iROI=0, nROIs-1 do begin
				if obj_valid( oROIs[iROI] ) then begin
					oROIs[iROI]->getProperty, NAME=name
					prefix = (strsplit( name, '_', /EXTRACT ))[0]
					if prefix eq 'R' and $
					   total( *(*pInfo).pSeries1 ) gt 0 then begin
						shielding_guiFindMax, pInfo, oROIs[iROI]
					endif
				endif
			endfor

			; Update views and redisplay
			shielding_guiUpdateImages, pInfo
			shielding_guiUpdateViews, pInfo

			; Save the session temporarily, just in case
;			julian = systime( /JULIAN )
;			caldat, julian, month, day, year, hour, minute, second
;			suffix = string( year, month, day, hour, minute, second, $
;					FORMAT='(I4, 5I2)' )
;			suffix = strjoin( strsplit( suffix, ' ', /EXTRACT ), '0' )
;			filename = (*pInfo).tmpDir $
;					 + suffix + '_session.sav'
;			shielding_guiSaveSession, pInfo, FILENAME=filename

		end

;		(*pInfo).wCalcDoseRateButton: begin
;
;			; Reset last mode
;			shielding_guiResetLastMode, pInfo
;
;			shielding_guiCalculateDoseRate, pInfo
;
;			; Update dose map scale
;			widget_control, (*pInfo).wResolutionText, GET_VALUE=value
;			widget_control, (*pInfo).wDosemapScaleText, SET_VALUE=value
;
;			; Rebuild maxROIs and update region table
;			oROIs = (*pInfo).oROIGroup->get( /ALL, COUNT=nROIs )
;			for iROI=0, nROIs-1 do begin
;				if obj_valid( oROIs[iROI] ) then begin
;					oROIs[iROI]->getProperty, NAME=name
;					prefix = (strsplit( name, '_', /EXTRACT ))[0]
;					if prefix eq 'R' and $
;					   total( *(*pInfo).pSeries1 ) gt 0 then begin
;						shielding_guiFindMax, pInfo, oROIs[iROI]
;					endif
;				endif
;			endfor
;
;			; Update views and redisplay
;			shielding_guiUpdateImages, pInfo
;			shielding_guiUpdateViews, pInfo
;
;		end

		(*pInfo).wHideQueryButton: begin

			shielding_guiHideROIs, pInfo, /QUERY

		end

		(*pInfo).wClearQueryButton: begin

			shielding_guiClearQueryText, pInfo

		end

		(*pInfo).wClearAllQueryButton: begin

			shielding_guiClearQueryText, pInfo, /ALL

		end

        (*pInfo).wDraw: begin

			if sEvent.type eq 0 then begin ; Button press

				if sEvent.press eq 1 then begin ; left button pressed

					; Check to see if we're picking a measuring tape origin
					if widget_info( (*pInfo).wMeasurePickButton, /BUTTON_SET ) then begin

						; Snap to the nearest ROI if snap is on
						if widget_info( (*pInfo).wSnapROIButton, /BUTTON_SET ) then begin
							coords = shielding_guiGetSnapCoords( pInfo, sEvent )
							if n_elements( coords ) eq 1 then begin ; no object nearby
								coords = shielding_guiScrn2ImgPix( pInfo, [sEvent.x, sEvent.y] )
							endif
						endif else begin
							coords = shielding_guiScrn2ImgPix( pInfo, [sEvent.x, sEvent.y] )
						endelse

						; Set the GUI
						widget_control, (*pInfo).wFloorplanScaleText, GET_VALUE=value
						fpScale = float(value[0])
						coords *= fpScale
						widget_control, (*pInfo).wMeasureXValText, $
								SET_VALUE=strtrim( string( coords[0], FORMAT='(f8.2)' ), 2 )
						widget_control, (*pInfo).wMeasureYValText, $
								SET_VALUE=strtrim( string( coords[1], FORMAT='(f8.2)' ), 2 )

						; Turn the pick button off
						widget_control, (*pInfo).wMeasurePickButton, $
								SET_VALUE='bitmaps\arrow.bmp', SET_BUTTON=0
						shielding_guiUpdateInfoText, pInfo, VALUE=''
						return

					endif

					if sEvent.modifiers eq 1 then begin
						shielding_guiPanStart, pInfo, sEvent
						(*pInfo).bButtonDown = 1b
						return
					endif

					case (*pInfo).mode of

						'none' : begin

							; Unset current ROI
							if obj_valid( (*pInfo).oCurROI ) then begin
								bOk = shielding_guiSetCurrentROI( pInfo, /NONE )
							endif

						end ; 'none'

						'pan' : begin

							shielding_guiPanStart, pInfo, sEvent

						end ; 'pan'

						'crosshairs_on' : begin

				            ;  Update slice location before zoom
							imgCoords = shielding_guiScrn2ImgPix( pInfo, $
									[sEvent.x,sEvent.y] )

							; Drop axes
							(*pInfo).oXAxis->setProperty, $
									LOCATION=[imgCoords[0],imgCoords[1]], $
									RANGE=[0,(*pInfo).nPx]
							(*pInfo).oYAxis->setProperty, $
									LOCATION=[imgCoords[0],imgCoords[1]], $
									RANGE=[0,(*pInfo).nPy]
							(*pInfo).oXAxis->setProperty, HIDE=0
							(*pInfo).oYAxis->setProperty, HIDE=0
							(*pInfo).oWindow->draw, (*pInfo).oViewGroup

						end ; 'crosshairs_on'

						'source_roi': begin

								imgCoords = shielding_guiScrn2ImgPix( pInfo, $
										[sEvent.x, sEvent.y] )

								oROI = shielding_guiAddSourcePoint( pInfo, imgCoords )
								text = textBox( $
										GROUP_LEADER=(*pInfo).wTopBase, $
										TITLE='New source location', $
										LABEL=['Description: '], $
										VALUE=[''], $
										CANCEL=bCancel )
								if bCancel then text = ['']
								oROI->setProperty, DESC=text[0]
								bOk = shielding_guiSetCurrentROI( pInfo, /NONE )
								shielding_guiUpdateROIButtons, pInfo


						end ; 'source_roi'

						'line_roi' : begin

							if not obj_valid( (*pInfo).oCurROI ) then begin

								; Start drawing a new line ROI
								imgCoords = shielding_guiScrn2ImgPix( pInfo, $
										[sEvent.x,sEvent.y] )

								shielding_guiLineROIStart, pInfo, imgCoords

							end

						end ; 'line_roi'

						'right_roi' : begin

							if not obj_valid( (*pInfo).oCurROI ) then begin

								scrnCoords = [sEvent.x, sEvent.y]
								bSnap = widget_info( (*pInfo).wSnapROIButton, /BUTTON_SET )
								if bSnap then begin
									imgCoords = shielding_guiGetSnapCoords( pInfo, sEvent )
									if imgCoords[0] eq -1L then begin
										imgCoords = shielding_guiScrn2ImgPix( pInfo, scrnCoords )
									endif
								endif else begin
									imgCoords = shielding_guiScrn2ImgPix( pInfo, scrnCoords )
								endelse

								; Start drawing a new line ROI
								shielding_guiRightROIStart, pInfo, imgCoords

							end

						end ; 'right_roi'

						'h_roi' : begin

							if obj_valid( (*pInfo).oCurROI ) then begin

								; Return if this is already a complete ROI
								(*pInfo).oCurROI->getProperty, STYLE=style
								if style eq 2 then break

								; Save this state
								shielding_guiSaveUndoROI, pInfo, $
										ACTION=(*pInfo).mode, OROI=(*pInfo).oCurROI

							endif

							; Add tis location to our growing ROI
							imgCoords = shielding_guiScrn2ImgPix( pInfo, $
									[sEvent.x,sEvent.y] )

							shielding_guiRectROIStart, pInfo, imgCoords

						end ; 'h_roi'

						'rect_roi' : begin

							if obj_valid( (*pInfo).oCurROI ) then begin

								; Return if this is already a complete ROI
								(*pInfo).oCurROI->getProperty, STYLE=style
								if style eq 2 then break

								; Save this state
								shielding_guiSaveUndoROI, pInfo, ACTION='draw', OROI=(*pInfo).oCurROI

							endif

							; Add this location to our growing ROI
							imgCoords = shielding_guiScrn2ImgPix( pInfo, $
									[sEvent.x,sEvent.y] )

							shielding_guiRectROIStart, pInfo, imgCoords

						end ; 'rect_roi'

						'query_roi' : begin

							imgCoords = shielding_guiScrn2ImgPix( pInfo, $
									[sEvent.x, sEvent.y] )

							shielding_guiAddQueryPoint, pInfo, imgCoords
							shielding_guiUpdateROIButtons, pInfo

						end ; query

						'move_roi_vertex' : begin

							; Get the ROI from the local objects
							oDispROI = shielding_guiGetSelectedROI( pInfo, sEvent )

							if obj_valid( oDispROI ) then begin

								; Highlight the ROI and move it
								bOk = shielding_guiSetCurrentROI( pInfo, oDispROI )
										shielding_guiMoveROIVertexStart, pInfo, sEvent

								; Save this state
								shielding_guiSaveUndoROI, pInfo, $
										ACTION=(*pInfo).mode, OROI=(*pInfo).oCurROI

							endif

						end ; 'move_roi_vertex'

						'extend_roi' : begin

							; Get the ROI from the local objects
							oDispROI = shielding_guiGetSelectedROI( pInfo, sEvent )

							if not obj_valid( oDispROI ) then return
							oDispROI->getProperty, NAME=name
							prefix = (strsplit( name, '_', /EXTRACT ))[0]
							if prefix ne 'S' then return

							if (*pInfo).curVertIndex eq -1L then begin

								; We're selecting the ROI to extend
								bOk = shielding_guiSetCurrentROI( pInfo, oDispROI )
								shielding_guiExtendTrimStart, pInfo, sEvent

								shielding_guiSaveUndoROI, pInfo, $
										ACTION=(*pInfo).mode, OROI=(*pInfo).oCurROI

								shielding_guiUpdateInfoText, pInfo, $
										VALUE='Left click on line ROI to extend to.'

							endif else begin

								; We're selecting the ROI to extend to
								if not obj_valid( (*pInfo).oCurROI ) then return
								shielding_guiExtendTrimStop, pInfo, oDispROI
								bOk = shielding_guiSetCurrentROI( pInfo, /NONE )

								shielding_guiUpdateInfoText, pInfo, VALUE=''

							endelse

						end ; 'extend_roi'

						'trim_roi' : begin

							; Get the ROI from the local objects
							oDispROI = shielding_guiGetSelectedROI( pInfo, sEvent )

							if not obj_valid( oDispROI ) then return
							oDispROI->getProperty, NAME=name
							prefix = (strsplit( name, '_', /EXTRACT ))[0]
							if prefix ne 'S' then return

							if (*pInfo).curVertIndex eq -1L then begin

								; We're selecting the ROI to trim
								bOk = shielding_guiSetCurrentROI( pInfo, oDispROI )
								shielding_guiExtendTrimStart, pInfo, sEvent

								shielding_guiSaveUndoROI, pInfo, $
										ACTION=(*pInfo).mode, OROI=(*pInfo).oCurROI

								shielding_guiUpdateInfoText, pInfo, $
										VALUE='Left click on line ROI to trim to.'

							endif else begin

								; We're selecting the ROI to extend to
								if not obj_valid( (*pInfo).oCurROI ) then return
								shielding_guiExtendTrimStop, pInfo, oDispROI
								bOk = shielding_guiSetCurrentROI( pInfo, /NONE )

								shielding_guiUpdateInfoText, pInfo, VALUE=''

							endelse

						end ; 'trim_roi'

						'move_roi' : begin

							; Get the selected ROI
							oDispROI = shielding_guiGetSelectedROI( pInfo, sEvent )

							if obj_valid( oDispROI ) then begin

								; Highlight the ROI and move it
								bOk = shielding_guiSetCurrentROI( pInfo, oDispROI )
								shielding_guiMoveROIStart, pInfo, sEvent

								; Save this state
								shielding_guiSaveUndoROI, pInfo, $
										ACTION=(*pInfo).mode, OROI=(*pInfo).oCurROI

							endif

						end ; 'move_roi'

						'delete_roi' : begin

							; Get the ROI from the local objects and set as current
							oDispROI = shielding_guiGetSelectedROI( pInfo, sEvent )

							if obj_valid( oDispROI ) then begin

								bOk = shielding_guiSetCurrentROI( pInfo, oDispROI )

								if bOk then begin

									; Pop up question dialog
									answer = dialog_message( 'Permanently delete ROI?', $
											/QUESTION, TITLE='Delete ROI', $
											DIALOG_PARENT=wTopBase )

									if answer eq 'Yes' then begin

										; Remember this ROI for undo
										oROI = (*pInfo).oCurROI
										shielding_guiSaveUndoROI, pInfo, $
												ACTION=(*pInfo).mode, OROI=oROI

										; Delete the ROI
										shielding_guiDeleteROI, pInfo, oROI

										; Update ROI buttons
										shielding_guiUpdateROIButtons, pInfo

									endif

									bOk = shielding_guiSetCurrentROI( pInfo, /NONE )

								endif

							endif

						end ; delete_roi

						'copy_roi' : begin

							; Get the ROI from the local objects
							oDispROI = shielding_guiGetSelectedROI( pInfo, sEvent )

							if obj_valid( oDispROI ) then begin

								; Copy the properties of the ROI to the state
								shielding_guiCopyROI, pInfo, oDispROI

								; Enable the paste button
								widget_control, (*pInfo).wPasteROIButton, SENSITIVE=1

							endif

						end ; copy_roi

						else: break

					endcase

				endif ; sEvent.press eq 1

				; Display context menu if we're not in the middle of drawing a ROI
				if sEvent.press eq 4 then begin ; right mouse button press

					if ( ( (*pInfo).mode eq 'line_roi' ) or $
						 ( (*pInfo).mode eq 'right_roi' ) or $
						 ( (*pInfo).mode eq 'h_roi' ) or $
						 ( (*pInfo).mode eq 'rect_roi' ) or $
						 ( (*pInfo).mode eq 'poly_roi' ) or $
						 ( (*pInfo).mode eq 'free_roi' ) and $
						 ( not obj_valid( (*pInfo).oCurROI ) ) ) or $
					   ( ( (*pInfo).mode ne 'line_roi' ) and $
						 ( (*pInfo).mode ne 'right_roi' ) and $
						 ( (*pInfo).mode ne 'h_roi' ) and $
						 ( (*pInfo).mode ne 'rect_roi' ) and $
						 ( (*pInfo).mode ne 'poly_roi' ) and $
						 ( (*pInfo).mode ne 'free_roi' ) ) then begin

						; See if we're on a ROI
						oROI = shielding_guiGetSelectedROI( pInfo, sEvent )
						if obj_valid( oROI ) then begin

							; See if the ROI is complete and therefore has a name
							oROI->getProperty, NAME=name
							if name ne '' then begin

								prefix = (strsplit( name, '_', /EXTRACT ))[0]

								case (*pInfo).mode of

								'copy_roi' : begin

									; Pop up the paste context menu if we have something
									; on the clipboard otherwise display the regular ROI
									; context menu
									bPasteSensitive = 0b
									(*pInfo).oDispCopyROIs[0]->getProperty, HIDE=bHide

									if bHide eq 0L then begin
										; Pop up paste context menu
										widget_displaycontextmenu, sEvent.id, $
												sEvent.x, sEvent.y, $
												(*pInfo).wROIPasteContextMenu
									endif else begin
										; Set this is as the current ROI
										bOk = shielding_guiSetCurrentROI( pInfo, oROI )
										if not bOk then break

										if ( prefix eq 'P' ) or $
										   ( prefix eq 'Q' ) then begin
											; Pop up the source context menu
											widget_displaycontextmenu, sEvent.id, $
													sEvent.x, sEvent.y, $
													(*pInfo).wSourceContextMenu
										endif else if prefix eq 'S' then begin
											; Pop up the structure context menu
											widget_displaycontextmenu, sEvent.id, $
													sEvent.x, sEvent.y, $
													(*pInfo).wShieldContextMenu
										endif else begin
											bOk = shielding_guiSetCurrentROI( pInfo, /NONE )
										endelse

									endelse

								end ; 'copy_roi'

								else : begin

									; Reset the last mode
									shielding_guiResetLastMode, pInfo
									(*pInfo).mode = 'none'

									; Update info text
									shielding_guiUpdateInfoText, pInfo, VALUE=''

									bOk = shielding_guiSetCurrentROI( pInfo, oROI )
									if not bOk then break

									if ( prefix eq 'P' ) then begin
										; Pop up the source context menu
										widget_displaycontextmenu, sEvent.id, $
												sEvent.x, sEvent.y, $
												(*pInfo).wSourceContextMenu
									endif else if prefix eq 'S' then begin
										; Pop up the structure context menu
										widget_displaycontextmenu, sEvent.id, $
												sEvent.x, sEvent.y, $
												(*pInfo).wShieldContextMenu
									endif else if prefix eq 'Q' then begin
										; Pop up the query point context menu
										widget_displaycontextmenu, sEvent.id, $
												sEvent.x, sEvent.y, $
												(*pInfo).wQueryContextMenu
									endif else if prefix eq 'R' then begin
										; Pop up the region context menu
										widget_displaycontextmenu, sEvent.id, $
												sEvent.x, sEvent.y, $
												(*pInfo).wRegionContextMenu
									endif else begin
										bOk = shielding_guiSetCurrentROI( pInfo, /NONE )
									endelse

								end ; else

								endcase

							endif

						endif

					endif

				endif ; right mouse button press

				(*pInfo).bButtonDown = sEvent.clicks

			endif else if sEvent.type eq 1 then begin ; Button release

				if sEvent.modifiers eq 1 then begin
					shielding_guiPanStop, pInfo, sEvent
					(*pInfo).bButtonDown = 0b
					return
				endif

				case (*pInfo).mode of

					'pan' : begin

						shielding_guiPanStop, pInfo, sEvent

					end ; 'pan'

					'source_roi' : begin

						; Nothing to do here
						break

					end

					'line_roi' : begin

						; Looking for right mouse button up
						if sEvent.release ne 4 then break

						; Complete the ROI
						imgCoords = shielding_guiScrn2ImgPix( pInfo, $
								[sEvent.x,sEvent.y] )

						oROI = (*pInfo).oCurROI
						shielding_guiLineROIStop, pInfo, imgCoords
						shielding_guiUpdateROIButtons, pInfo

						; Get the specs for this shield from the user
						shielding_guiSetShieldSpecs, pInfo, oROI, /PROMPT

						bOk = shielding_guiSetCurrentROI( pInfo, /NONE )

					end ; of 'line_roi'

					'right_roi' : begin

						; Looking for right mouse button up
						if sEvent.release ne 4 then break

						; Return if we don't have a current ROI
						oROI = (*pInfo).oCurROI
						if not obj_valid( oROI ) then break

						; Complete the ROI
						imgCoords = shielding_guiScrn2ImgPix( pInfo, $
								[sEvent.x,sEvent.y] )

						; Get the first coord and determine whether
						; we're drawing a horizontal or vertical ROI
						oROI->getProperty, DATA=data
						xLenSq = (data[0]-imgCoords[0])^2
						yLenSq = (data[1]-imgCoords[1])^2

						if xLenSq gt yLenSq then begin ; horizontal line
							imgCoords = [imgCoords[0],data[1]]
						endif else begin
							imgCoords = [data[0],imgCoords[1]]
						endelse

						shielding_guiRightROIStop, pInfo, imgCoords
						shielding_guiUpdateROIButtons, pInfo

						; Get the specs for this shield from the user
						shielding_guiSetShieldSpecs, pInfo, oROI, /PROMPT

						bOk = shielding_guiSetCurrentROI( pInfo, /NONE )

					end ; 'right_roi'

					'h_roi' : begin

						; Looking for right mouse button up
						if sEvent.release ne 4 then break

						; Return if we don't have a current ROI
						oROI = (*pInfo).oCurROI
						if not obj_valid( oROI ) then break

						shielding_guiRectROIStop, pInfo, sEvent
						shielding_guiClearUndoRedoROI, pInfo
						shielding_guiUpdateROIButtons, pInfo

						; Add specs for this region to the table
						shielding_guiSetHShieldSpecs, pInfo, oROI, /PROMPT

						bOk = shielding_guiSetCurrentROI( pInfo, /NONE )

					end ; 'h_roi'

					'rect_roi' : begin

						; Looking for right mouse button up
						if sEvent.release ne 4 then break

						; Return if we don't have a current ROI
						oROI = (*pInfo).oCurROI
						if not obj_valid( oROI ) then break

						shielding_guiRectROIStop, pInfo, sEvent
						shielding_guiClearUndoRedoROI, pInfo
						shielding_guiUpdateROIButtons, pInfo

						; Add specs for this region to the table
						shielding_guiSetRegionSpecs, pInfo, oROI, /PROMPT

						bOk = shielding_guiSetCurrentROI( pInfo, /NONE )

					end ; 'rect_roi'

					'query_roi' : begin

						; Nothing to do
						break

					end ; 'query_roi'

					'move_roi_vertex' : begin

						; Looking for left mouse button up
						if sEvent.release ne 1 then break

						; Move the ROI vertex
						shielding_guiMoveROIVertexStop, pInfo, sEvent

						bOk = shielding_guiSetCurrentROI( pInfo, /NONE )

					end ; 'move_roi_vertex'

					'move_roi' : begin

						; Looking for left mouse button up
						if sEvent.release ne 1 then break

						; Stop moving the ROI
						shielding_guiMoveROIStop, pInfo, sEvent

						bOk = shielding_guiSetCurrentROI( pInfo, /NONE )

					end ; 'move_roi'

					else: break

				endcase

				(*pInfo).bButtonDown = 0b

			endif else if sEvent.type eq 2 then begin ; Motion

				if sEvent.modifiers eq 1 then begin
					if not (*pInfo).bButtonDown then break
					shielding_guiPanMotion, pInfo, sEvent
				endif

				case (*pInfo).mode of

					'pan' : begin

						if not (*pInfo).bButtonDown then break
						; Move image
						shielding_guiPanMotion, pInfo, sEvent

					end ; 'pan'

					'source_roi' : begin

						; Nothing to do here
						break

					end ; 'source_roi'

					'line_roi' : begin

						oROI = (*pInfo).oCurROI
						if not obj_valid( oROI ) then break

						; Move the end point of the ROI
						shielding_guiLineROIMotion, pInfo, sEvent

					end ; 'line_roi'

					'right_roi' : begin

						oROI = (*pInfo).oCurROI
						if not obj_valid( oROI ) then break

						; Move the end point of the ROI
						shielding_guiRightROIMotion, pInfo, sEvent

					end ; 'right_roi'

					'h_roi' : begin

						oROI = (*pInfo).oCurROI
						if not obj_valid( oROI ) then break

						; Move the end point of the ROI
						shielding_guiRectROIMotion, pInfo, sEvent

					end ; 'h_roi'

					'rect_roi' : begin

						oROI = (*pInfo).oCurROI
						if not obj_valid( oROI ) then break

						; Move the end point of the ROI
						shielding_guiRectROIMotion, pInfo, sEvent

					end ; 'rect_roi'

					'query_roi' : begin

						; Nothing to do
						break

					end

					'move_roi_vertex' : begin

						if not (*pInfo).bButtonDown then break

						oROI = (*pInfo).oCurROI
						if not obj_valid( oROI ) then break

						; Move the ROI
						shielding_guiMoveROIVertexMotion, pInfo, sEvent

					end ; 'move_roi_vertex'

					'move_roi' : begin

						if not (*pInfo).bButtonDown then break

						oROI = (*pInfo).oCurROI
						if not obj_valid( oROI ) then break

						; Move the ROI
						shielding_guiMoveROIMotion, pInfo, sEvent

					end ; 'move_roi'

					'free_roi' : begin

						oROI = (*pInfo).oCurROI
						if not obj_valid( oROI ) then break

						; Save this state (button down or up)
						shielding_guiSaveUndoROI, pInfo, $
								ACTION=(*pInfo).mode, OROI=(*pInfo).oCurROI

						if (*pInfo).bButtonDown then begin

							; Draw the ROI
							shielding_guiFreeROIMotion, pInfo, sEvent

						endif

					end ; 'free_roi'

					else: ; nothing

				endcase

				; Update image info text
				imgCoords = shielding_guiScrn2ImgPix( pInfo, $
						[sEvent.x,sEvent.y] )

				shielding_guiUpdateImageInfo, pInfo, $
						COORD=[imgCoords[0],imgCoords[1]]

				; Update crosshair location
				(*pInfo).oXAxis->setProperty, $
						LOCATION=[imgCoords[0],imgCoords[1],0], $
						RANGE=[0,(*pInfo).nPx]
				(*pInfo).oYAxis->setProperty, $
						LOCATION=[imgCoords[0],imgCoords[1],0], $
						RANGE=[0,(*pInfo).nPy]
				(*pInfo).oWindow->draw, (*pInfo).oViewGroup

			endif ; main draw widget

		endcase ; wDraw

		else: begin

			; Must be a menu button
            ; Get the user value of the button
            widget_control, sEvent.id, GET_UVALUE=uv

			; Return if this event doesn't have a user value
			; (i.e., it's not defined)
			if keyword_set( uv ) eq 0 then return

            uv1 = strtok( uv, "|", /EXTRACT )

            ;  Branch to the appropriate button event.
            ;
            case uv1[0] of

				'Copy ROI' : begin

;					; Reset the last mode
;					shielding_guiResetLastMode, pInfo
;					(*pInfo).mode = 'none'
;
;					; Update info text
;					shielding_guiUpdateInfoText, pInfo, VALUE=''

					oROI = (*pInfo).oCurROI
					if not obj_valid( oROI ) then break

					; Set this mode
					(*pInfo).mode = 'copy_roi'

					; Set the bitmap to active
					widget_control, (*pInfo).wCopyROIButton, $
							SET_VALUE='bitmaps\copy_active.bmp', /BITMAP, $
							SET_BUTTON=0, $
							TOOLTIP='stop copy/paste ROI'

					; Update info text
					shielding_guiUpdateInfoText, pInfo, $
							VALUE='Left click on a ROI to copy the region ' + $
							'to the clipboard. Press the paste button or ' + $
							'right click on an image and select ''paste'' ' + $
							'to paste the ROI on an image.  Press the stop ' + $
							'copy/paste button or select a different ' + $
							'operation to exit this mode.'

					; Copy the currently selected ROI
					shielding_guiCopyROI, pInfo, (*pInfo).oDispCurROI

					; Enable the paste button
					widget_control, (*pInfo).wPasteROIButton, SENSITIVE=1

				end ; copy_roi

				'Paste ROI' : begin

					; Unset the paste button and reset the copy button
					widget_control, (*pInfo).wPasteROIButton, $
							SET_BUTTON=0

					if (*pInfo).mode eq 'copy_roi' then begin

						shielding_guiPasteROI, pInfo
						shielding_guiUpdateROIButtons, pInfo

					endif

				end; paste_roi

				'Delete ROI' : begin

					; Reset the last mode
					shielding_guiResetLastMode, pInfo
					(*pInfo).mode = 'none'

					; Update info text
					shielding_guiUpdateInfoText, pInfo, VALUE=''

					oROI = (*pInfo).oCurROI
					if not obj_valid( oROI ) then break

					; Pop up question dialog
					answer = dialog_message( 'Permanently delete ROI?', $
							/QUESTION, TITLE='Delete ROI', $
							DIALOG_PARENT=wTopBase )

					if answer eq 'Yes' then begin

						shielding_guiDeleteROI, pInfo, oROI

						; Clear undo/redo and update ROI buttons
						shielding_guiClearUndoRedoROI, pInfo
						shielding_guiUpdateROIButtons, pInfo

					endif

					bOk = shielding_guiSetCurrentROI( pInfo, /NONE )

				end ; 'Delete'

				'Recalculate' : begin

					; Reset the last mode
					shielding_guiResetLastMode, pInfo
					(*pInfo).mode = 'none'

					; Update info text
					shielding_guiUpdateInfoText, pInfo, VALUE=''

					oROI = (*pInfo).oCurROI
					if not obj_valid( oROI ) then break

					shielding_guiSetQueryData, pInfo, oROI, /PROMPT

					; Unset current ROI
					bOk = shielding_guiSetCurrentROI( pInfo, /NONE )

				end ; 'Recalculate'

				'Change description' : begin

					; Reset the last mode
					shielding_guiResetLastMode, pInfo
					(*pInfo).mode = 'none'

					; Update info text
					shielding_guiUpdateInfoText, pInfo, VALUE=''

					; Get the selected ROI
					oROI = (*pInfo).oCurROI
					if not obj_valid( oROI ) then break

					oROI->getProperty, NAME=name, DESC=desc
					text = textbox( $
							GROUP_LEADER=(*pInfo).wTopBase, $
							TITLE=strtrim( name, 2 )+' description', $
							LABEL=['Description: '], $
							VALUE=[desc], $
							CANCEL=bCancel )
					if bCancel then return
					oROI->setProperty, DESC=text[0]

					; Unset current ROI
					bOk = shielding_guiSetCurrentROI( pInfo, /NONE )

				end ; 'New description'


				'Add specs' : begin

					; Reset the last mode
					shielding_guiResetLastMode, pInfo
					(*pInfo).mode = 'none'

					; Update info text
					shielding_guiUpdateInfoText, pInfo, VALUE=''

					; Get the selected ROI
					oROI = (*pInfo).oCurROI
					if not obj_valid( oROI ) then break

					oROI->getProperty, NAME=name
					prefix = (strsplit( name, '_', /EXTRACT))[0]

					; Prompt the user to input values
					case prefix of

						'P' : shielding_guiAddSourceSpecs, pInfo, oROI, /PROMPT
						'S' : shielding_guiSetShieldSpecs, pInfo, oROI, /PROMPT
						'H' : shielding_guiSetHShieldSpecs, pInfo, oROI, /PROMP
						else:

					endcase

					; Unset current ROI
					bOk = shielding_guiSetCurrentROI( pInfo, /NONE )

				end ; 'Add specs'


				'Print distances' : begin

					; Reset the last mode
					shielding_guiResetLastMode, pInfo
					(*pInfo).mode = 'none'

					; Update info text
					shielding_guiUpdateInfoText, pInfo, VALUE=''

					; Get the selected ROI
					oROI = (*pInfo).oCurROI
					if not obj_valid( oROI ) then break

					oROI->getProperty, NAME=name
					prefix = (strsplit( name, '_', /EXTRACT))[0]

					if prefix eq 'P' then begin

						shielding_guiPrintDistances, pInfo, oROI

					endif

					; Unset current ROI
					bOk = shielding_guiSetCurrentROI( pInfo, /NONE )

				end ; 'Print distances'

				'Set scale' : begin

					; Reset the last mode and set the current mode to none
					shielding_guiResetLastMode, pInfo
					(*pInfo).mode = 'none'

					; Update info text
					shielding_guiUpdateInfoText, pInfo, VALUE='Scale modified'

					; Get the selected ROI
					oROI = (*pInfo).oCurROI
					if not obj_valid( oROI ) then break

					; Prompt the user to input values
					shielding_guiSetScale, pInfo, oROI

					; Update measurement tables
					shielding_guiUpdateMeasurements, pInfo

;	                shielding_guiUpdateImages, pInfo
	                shielding_guiUpdateViews, pInfo

					; Unset current ROI
					bOk = shielding_guiSetCurrentROI( pInfo, /NONE )

				end ; 'Set scale'

				'Print length' : begin

					; Get the selected ROI
					oROI = (*pInfo).oCurROI
					if not obj_valid( oROI ) then break

					; Prompt the user to input values
					shielding_guiPrintLength, pInfo, oROI

					; Unset current ROI
					bOk = shielding_guiSetCurrentROI( pInfo, /NONE )

				end ; 'Set scale'

				'Find max pixel' : begin

					; Reset the last mode and set the current mode to none
					shielding_guiResetLastMode, pInfo
					(*pInfo).mode = 'none'

					; Get the selected ROI
					oROI= (*pInfo).oCurROI
					if not obj_valid( oROI ) then break
					oROI->getProperty, name=name
					print, name

					; Find the max pixel and display
					shielding_guiFindMax, pInfo, oROI

					; Unset current ROI
					bOk = shielding_guiSetCurrentROI( pInfo, /NONE )

				end ; 'Find max pixel'

				'Rename ROI' : begin

					; ; Reset the last mode and set the current mode to none
					shielding_guiResetLastMode, pInfo
					(*pInfo).mode = 'none'

					; Get the selected ROI
					oROI = (*pInfo).oCurROI
					if not obj_valid( oROI ) then return

					bOk = shielding_guiRenameROI( pInfo, ROI=oROI )

					; Unset current ROI
					bOk = shielding_guiSetcurrentROI( pInfo, /NONE )

				end; 'Rename'

                'File': case uv1[1] of

                    'Open': case uv1[2] of

                    	'Floorplan (.bmp)' : begin

							; Prompt to save ROIs if we have ROIs to save
							oROIGroup = (*pInfo).oROIGroup
							nROIs = oROIGroup->count()
							if nROIs gt 0 then begin
								answer = dialog_message( 'Save ROIs before clearing?', $
										/QUESTION, TITLE='Clearing ROIs', /CANCEL )
								if answer eq 'Cancel' then return
								if answer eq 'Yes' then shielding_guiSaveROIs, pInfo
							endif

							; Load bitmap image
							bHaveFile = shielding_guiGetBMPData( pInfo )
							if bHaveFile eq 0b then return

							; Update viewport labels
							shielding_guiUpdateVPLabels, pInfo

							; Reset zoom
							(*pInfo).zoomFactor = 1

							; Reset mode
							shielding_guiResetLastMode, pInfo
							(*pInfo).mode = 'none'

							; Update the info text
							shielding_guiUpdateInfoText, pInfo, VALUE='Ready'

							; Destroy old ROIs, if any
							shielding_guiDetachROIs, pInfo
							oROIs = (*pInfo).oROIGroup->get( /ALL, COUNT=nROIs )
							(*pInfo).oROIGroup->remove, /ALL
							for iROI=0, nROIs-1 do begin
								oROIs[iROI]->getProperty, SYMBOL=oSym
								if obj_valid( oSym ) then obj_destroy, oSym
								obj_destroy, oROIs[iROI]
							endfor

							; Prepare for new ROIs
							shielding_guiClearUndoRedoROI, pInfo

							; Calculate dosemap dimensions
							nPx 	= (*pInfo).nPx
							nPy 	= (*pInfo).nPy
							vpSize	= (*pInfo).vpSize
							widget_control, (*pInfo).wDosemapScaleText, GET_VALUE=value
							dmScale = float(value)
							widget_control, (*pInfo).wFloorplanScaleText, GET_VALUE=value
							imgScale = float(value)

							; Calculate viewport pixel dimensions based on dataset size
							; (assumes square pixels in x,y)
							imgWHRatio = float(nPx)/float(nPy)
							vpWHRatio = float(vpSize[0])/float(vpSize[1])

							if imgWHRatio gt vpWHRatio then begin

								(*pInfo).vp2imgScale[0] = float(nPx)/vpSize[0]
								(*pInfo).vp2imgScale[1] = (*pInfo).vp2imgScale[0]

							endif else begin

								(*pInfo).vp2imgScale[1] = float(nPy)/vpSize[1]
								(*pInfo).vp2imgScale[0] = (*pInfo).vp2imgScale[1]

							endelse

							; Clear dosemap
							*(*pInfo).pSeries1 = fltarr( (*pInfo).nPx, (*pInfo).nPy )

	                        ; Create views
                        	(*pInfo).cPoint = size( *(*pInfo).pSeries0, /DIMENSIONS ) / 2

							; Display images
	                        shielding_guiUpdateImages, pInfo
	                        shielding_guiUpdateViews, pInfo

							; Enable button features
							widget_control, (*pInfo).wButtonBase, SENSITIVE=1
							shielding_guiUpdateROIButtons, pInfo

							; Enable motion tracking on draw windows
							widget_control, (*pInfo).wDraw, SENSITIVE=1

                    	endcase

                    	'Replacement floorplan (.bmp)' : begin

							; Load bitmap image
							bHaveFile = shielding_guiReplaceFloorplan( pInfo )
							if bHaveFile eq 0b then return

							; Update viewport labels
							shielding_guiUpdateVPLabels, pInfo

							; Display images
	                        shielding_guiUpdateImages, pInfo
	                        shielding_guiUpdateViews, pInfo

                    	endcase

 						'ROIs (.sav)' : begin

							; Make sure we have image data first
							if n_elements( *(*pInfo).pSeries0 ) le 1 then begin
								; Warn and return
								void = dialog_message( 'Must load floorplan first', $
										TITLE='ROIs not loaded' )
								break
							endif

							case uv1[3] of
							'Sources (P_*)' : $
								shielding_guiOpenROIs, pInfo, /SOURCE
							'Shields (S_*)' : $
								shielding_guiOpenROIs, pInfo, /SHIELD
							'Horizontal shields (H_*)' : $
								shielding_guiOpenROIs, pInfo, /HSHIELD
							'Regions (R_*)' : $
								shielding_guiOpenROIs, pInfo, /REGION
							'Queries (Q_*)' : $
								shielding_guiOpenROIs, pInfo, /QUERY
							else:

							endcase

							shielding_guiUpdateROIButtons, pInfo

						end

						'Dosemap (.img)' : begin

							; Make sure we have a floorplan first
							if n_elements( *(*pInfo).pSeries0 ) gt 1 then begin
								; Load image
								bOk = shielding_guiOpenDosemap( pInfo )
								if bOk then shielding_guiUpdateImages, pInfo
								shielding_guiUpdateROIButtons, pInfo
							endif else begin
								; Warn and return
								void = dialog_message( 'Must load floorplan first', $
										TITLE='Dose image not loaded' )
							endelse
						end

						'Session (.sav)' : begin

							; Prompt to save ROIs if we have ROIs to save
							oROIGroup = (*pInfo).oROIGroup
							if obj_valid( oROIGroup ) then begin
								nROIs = oROIGroup->count()
								if nROIs gt 0 then begin
									answer = dialog_message( 'Save ROIs before clearing?', $
											/QUESTION, /CANCEL, TITLE='Clearing ROIs' )
									if answer eq 'Cancel' then return
									if answer eq 'Yes' then shielding_guiSaveROIs, pInfo
								endif

								; Destroy old ROIs, if any
								shielding_guiDetachROIs, pInfo
								oROIs = (*pInfo).oROIGroup->get( /ALL, COUNT=nROIs )
								(*pInfo).oROIGroup->remove, /ALL
								for iROI=0, nROIs-1 do begin
									oROIs[iROI]->getProperty, SYMBOL=oSym
									if obj_valid( oSym ) then obj_destroy, oSym
									obj_destroy, oROIs[iROI]
								endfor
							endif

							; Prepare for new ROIs
							shielding_guiClearUndoRedoROI, pInfo

							; Load CT background
							bHaveFile = shielding_guiOpenSession( pInfo )
							if bHaveFile eq 0b then begin
								(*pInfo).oWindow->erase, COLOR=0
								return
							end

							; Update viewport labels
							shielding_guiUpdateVPLabels, pInfo

							; Reset zoom
							(*pInfo).zoomFactor = 1

							; Reset mode
							shielding_guiResetLastMode, pInfo
							(*pInfo).mode = 'none'

							; Update info text
							shielding_guiUpdateInfoText, pInfo, VALUE='Ready'

							; Calculate dosemap dimensions
							nPx 	= (*pInfo).nPx
							nPy 	= (*pInfo).nPy
							vpSize	= (*pInfo).vpSize

							; Calculate viewport pixel dimensions based on dataset size
							; (assumes square pixels in x,y)
							imgWHRatio = float(nPx)/float(nPy)
							vpWHRatio = float(vpSize[0])/float(vpSize[1])

							if imgWHRatio gt vpWHRatio then begin

								(*pInfo).vp2imgScale[0] = float(nPx)/vpSize[0]
								(*pInfo).vp2imgScale[1] = (*pInfo).vp2imgScale[0]

							endif else begin

								(*pInfo).vp2imgScale[1] = float(nPy)/vpSize[1]
								(*pInfo).vp2imgScale[0] = (*pInfo).vp2imgScale[1]

							endelse

	                        ; Create views
                        	(*pInfo).cPoint = size( *(*pInfo).pSeries0, /DIMENSIONS ) / 2

	                        shielding_guiUpdateImages, pInfo
	                        shielding_guiUpdateViews, pInfo

							; Enable button features
							widget_control, (*pInfo).wButtonBase, SENSITIVE=1
							shielding_guiUpdateROIButtons, pInfo

							; Enable motion tracking on first draw window
							widget_control, (*pInfo).wDraw, SENSITIVE=1
						end

                	endcase ; of uv1[2] (File)

					'Add' : case uv1[2] of

 						'ROIs (.sav)' : begin

							; Make sure we have image data first
							if n_elements( *(*pInfo).pSeries0 ) le 1 then begin
								; Warn and return
								void = dialog_message( 'Must load floorplan first', $
										TITLE='ROIs not loaded' )
								break
							endif

							case uv1[3] of
							'Sources (P_*)' : $
								shielding_guiAddROIs, pInfo, /SOURCE
							'Shields (S_*)' : $
								shielding_guiAddROIs, pInfo, /SHIELD
							'Horizontal shields (H_*)' : $
								shielding_guiAddROIs, pInfo, /HSHIELD
							'Regions (R_*)' : $
								shielding_guiAddROIs, pInfo, /REGION
							'Queries (Q_*)' : $
								shielding_guiAddROIs, pInfo, /QUERY
							else:

							endcase

							shielding_guiUpdateROIButtons, pInfo

						end

						'Protocols (.txt)' : begin

							; Make sure we have source points first
							pRois = shielding_guiGetROIs( pInfo, /SOURCES, COUNT=nPs )
							if nPs eq 0 then begin
								void = dialog_message( 'Must add source ROIs first', $
										TITLE='Protocols not loaded' )
								return
							endif else begin
								shielding_guiOpenSources, pInfo
							endelse

						end

						'Dosemap (.img)' : begin
							bOk = shielding_guiAddDosemap( pInfo )
							if bOk then shielding_guiUpdateImages, pInfo
						end

					endcase ; of uv1[2] (Add)

					'Save' : case uv1[2] of

						'Source table (.txt)' : begin
							shielding_guiSaveSourceTable, pInfo
						end

						'Source-region table (.txt)' : begin
							shielding_guiSaveSourceRegionTable, pInfo
						end
						'Dose table (.txt)' : begin
							shielding_guiSaveDoseTable, pInfo
						end

						'Source-query table (.txt)' : begin
							shielding_guiSaveSourceQueryTable, pInfo
						end
						'Query dose table (.txt)' : begin
							shielding_guiSaveQueryDoseTable, pInfo
						end
						'Shield table (.txt)' : begin
							shielding_guiSaveShieldTable, pInfo
						end

						'Horizontal shield table (.txt)' : begin
							shielding_guiSaveHShieldTable, pInfo
						end

						'All tables (.txt)' : begin
							shielding_guiSaveSourceRegionTable, pInfo
							shielding_guiSaveDoseTable, pInfo
							shielding_guiSaveShieldTable, pInfo
							shielding_guiSaveHShieldTable, pInfo
						end

                    	'ROIs (.sav)' : case uv1[3] of

							'Sources (P_*)' : $
								shielding_guiSaveROIs, pInfo, /SOURCE
							'Shields (S_*)' : $
								shielding_guiSaveROIs, pInfo, /SHIELD
							'Horizontal shields (H_*)' : $
								shielding_guiSaveROIs, pInfo, /HSHIELD
							'Regions (R_*)' : $
								shielding_guiSaveROIs, pInfo, /REGION
							'Queries (Q_*)' : $
								shielding_guiSaveROIs, pInfo, /QUERY
							else:

						end

						'Dosemap (.img)' : begin
							if total( *(*pInfo).pSeries1 ) gt 0 then begin
								shielding_guiSaveDoseImage, pInfo
							endif else begin
								; Warn and return
								void = dialog_message( 'No dose image to save' )
							endelse
						end

						'Session (.sav)' : begin
							shielding_guiSaveSession, pInfo
						end

						else :

					endcase ; of uv1[2] (Save)

                    'Quit': begin

						; Check to make sure the user doesn't want to save
						; before exiting
						answer = dialog_message( 'Save session before exiting?', $
								/QUESTION, /CANCEL, TITLE='Quitting application' )
						if answer eq 'Cancel' then begin
							return
						endif else if answer eq 'Yes' then begin
							shielding_guiSaveSession, pInfo
						endif

						widget_control, sEvent.top, /DESTROY
						return

                    endcase

					else:

            	endcase ; of uv1[1] (File)

				'Edit': case uv1[1] of

					'Replace': case uv1[2] of

						'Sources (P_*)' : $
							sheilding_guiOpenROIs, pInfo, /SOURCE
						'Shields (S_*)' : $
							shielding_guiOpenROIs, pInfo, /SHIELD
						'Horizontal shields (H_*)' : $
							shielding_guiOpenROIs, pInfo, /HSHIELD
						'Regions (R_*)' : $
							shielding_guiOpenROIs, pInfo, /REGION
						else:

					endcase ; of uv1[2] (Replace)

					else:

				endcase	; if uv1[1] (Edit)

				'Format': case uv1[1] of

					'ROIs': begin

						oDispROIGroup = (*pInfo).oDispROIGroup
						if not obj_valid( oDispROIGroup ) then return
						oROIs = oDispROIGroup->get( /ALL, COUNT=nROIs )
						if nROIs eq 0 then return
						oROIs[0]->getProperty, THICK=thick, TEXT_SIZE=textSize
						text = textBox( $
								GROUP_LEADER=(*pInfo).wTopBase, $
								TITLE='ROI properties', $
								LABEL=['Line thickness (1-10, default=1): ', 'Text size (1-10, default=1): '], $
								VALUE=[string(thick), string(textSize)], $
								CANCEL=bCancel )
						if bCancel then return

						shielding_guiFormatROIs, pInfo, THICK=float(text[0]), TEXT_SIZE=float(text[1])

					endcase ; of uv1[2] (ROIs)

					else:

				endcase	; if uv1[1] (Format)

				'View': case uv1[1] of

					'Shift TLHC' : begin

					  	text = textBox( $
					   			GROUP_LEADER=(*pInfo).wTopBase, $
					   			TITLE='Shift view', $
					   			LABEL=['X (pixels): ', 'Y (pixels): '], $
					   			VALUE=['0', '0'], $
					   			CANCEL=bCancel )
						if bCancel then break

						shielding_guiShiftTLHC, pInfo, fix(text[0]), fix(text[1])

					endcase

					'Adjust compass' : begin

						(*pInfo).oCompass->getProperty, POSITION=pos, COLOR=color, $
								NORTH=north
						pos = strtrim( string( pos, FORMAT='(F8.3)' ), 2 )
						north = strtrim( north, 2 )
						color = strjoin( strtrim( string( color, FORMAT='(I3)' ), 2 ), ',' )
						text = textbox( $
								GROUP_LEADER=(*pInfo).wTopBase, $
								TITLE='Compass properties', $
								LABEL=['x position [-1.0 to 1.0]: ', $
										'y position [-1.0 to 1.0]: ', $
										'north [0:top, 1:right, 2:bottom, 3:left]: ', $
										'color [r, g, b]: '], $
								VALUE=[pos[0], $
										pos[1], $
										north, $
										color], $
								CANCEL=bCancel )
						if bCancel then return
						pos = float( [text[0],text[1]] )
						north = fix( text[2] )
						color = fix( strsplit( text[3], ',', /EXTRACT ) )

						shielding_guiSetCompass, pInfo, POSITION=pos, NORTH=north, $
								COLOR=color

					end

					'Shift colorbar' : begin

						(*pInfo).oCBar->getProperty, POSITION=pos
						pos = strtrim( float(pos), 2 )
						text = textBox( $
									GROUP_LEADER=(*pInfo).wTopBase, $
									TITLE='Colorbar position (normalized)', $
									LABEL=['X: ', 'Y: '], $
									VALUE=[pos[0], pos[1]], $
									CANCEL=bCancel )
						if bCancel then return

						shielding_guiShiftCBar, pInfo, float(text[0]), float(text[1] )

					endcase

					'Dose map': case uv1[2] of

						'Set threshold' : begin
							text = textBox( $
									GROUP_LEADER=(*pInfo).wTopBase, $
									TITLE='Set dosemap threshold', $
									LABEL=['Threshold (uSv):'], $
									VALUE=[strtrim( string( (*pInfo).dmThresh, FORMAT='(f8.1)' ), 2 )], $
									CANCEL=bCancel )
							if bCancel then return
							if text[0] ne '' then begin
								(*pInfo).dmThresh = float( text[0] )
								if ((*pInfo).displayMode eq 'gray-high') or $
								   ((*pInfo).displayMode eq 'gray-high+occ') or $
								   ((*pInfo).displayMode eq 'colour-high') or $
								   ((*pInfo).displayMode eq 'colour-high+occ') then begin
								   	shielding_guiUpdateImages, pInfo
								endif else if ((*pInfo).displaymode eq 'rois') then begin
									shielding_guiClearFloorROIs, pInfo
								    shielding_guiUpdateImages, pInfo
								endif
							endif
						end

                    	'Grayscale' : begin
                    		if (*pInfo).displayMode ne 'gray-all' then begin
                    			if (*pInfo).displayMode eq 'rois' then $
                    				shielding_guiClearFloorROIs, pInfo
	                    		(*pInfo).displayMode = 'gray-all'
	                    		shielding_guiUpdateImages, pInfo
	                    		shielding_guiUpdateMaxROIs, pInfo
	                    	endif
						end

                    	'Grayscale > thresh' : begin
                    		if (*pInfo).displayMode ne 'gray-high' then begin
                    			if (*pInfo).displayMode eq 'rois' then $
                    				shielding_guiClearFloorROIs, pInfo
                    			(*pInfo).displayMode = 'gray-high'
	                    		shielding_guiUpdateImages, pInfo
	                    		shielding_guiUpdateMaxROIs, pInfo
	                    	endif
						end

                    	'Grayscale > thresh + occ' : begin
                    		if (*pInfo).displayMode ne 'gray-high+occ' then begin
                    			if (*pInfo).displayMode eq 'rois' then $
                    				shielding_guiClearFloorROIs, pInfo
                    			(*pInfo).displayMode = 'gray-high+occ'
	                    		shielding_guiUpdateImages, pInfo
	                    		shielding_guiUpdateMaxROIs, pInfo
	                    	endif
						end

						'Colour': begin
							if (*pInfo).displayMode ne 'colour' then begin
                    			if (*pInfo).displayMode eq 'rois' then $
                    				shielding_guiClearFloorROIs, pInfo
								(*pInfo).displayMode = 'colour'
								shielding_guiUpdateImages, pInfo
								shielding_guiUpdateMaxROIs, pInfo
							endif
						end

						'Colour > thresh': begin
							if (*pInfo).displayMode ne 'colour-high' then begin
                    			if (*pInfo).displayMode eq 'rois' then $
                    				shielding_guiClearFloorROIs, pInfo
								(*pInfo).displayMode = 'colour-high'
								shielding_guiUpdateImages, pInfo
								shielding_guiUpdateMaxROIs, pInfo
							endif
						end

						'Colour > thresh + occ': begin
							if (*pInfo).displayMode ne 'colour-high+occ' then begin
                    			if (*pInfo).displayMode eq 'rois' then $
                    				shielding_guiClearFloorROIs, pInfo
								(*pInfo).displayMode = 'colour-high+occ'
								shielding_guiUpdateImages, pInfo
								shielding_guiUpdateMaxROIs, pInfo
							endif
						end

						'Floor rois': begin
							if (*pInfo).displayMode ne 'rois' then begin
								(*pInfo).displayMode = 'rois'
								shielding_guiUpdateImages, pInfo
								shielding_guiUpdateMaxROIs, pInfo
							endif
						end

						'None' : begin
							if (*pInfo).displayMode ne 'none' then begin
                    			if (*pInfo).displayMode eq 'rois' then $
                    				shielding_guiClearFloorROIs, pInfo
								(*pInfo).displayMode = 'none'
								shielding_guiUpdateImages, pInfo
								shielding_guiUpdateMaxROIs, pInfo
							endif
						end

						else:

					endcase

					'Horizontal rois': case uv1[2] of
						'Fill': begin
							; Clear old, create new
							shielding_guiHFill, pInfo, /NONE
							shielding_guiHFill, pInfo
						end
						'No fill': begin
							; Clear
							shielding_guiHFill, pInfo, /NONE
						end
						else:
					endcase

					else:

				endcase

				else:

        	endcase         ;  of else

    	endcase             ;  of sEvent.id

	end                     ;  of event handler

end

;--------------------------------------------------------------------
;
;    PURPOSE  Cleanup procedure.
;
pro shielding_guiCleanup, tlb     ;  IN: top level base identifier

	; Get the top level base user value
	widget_control, tlb, GET_UVALUE=pInfo, /NO_COPY

	; Restore the previous colour table
    tvlct, (*pInfo).colourTable

	; Map the group leader base if it exists
	if widget_info( (*pInfo).groupBase, /VALID_ID ) then $
		 widget_control, (*pInfo).groupBase, /MAP

	for i=0, n_tags(*pInfo)-1 do begin
		case size( (*pInfo).(i), /TNAME ) of
			'POINTER':	ptr_free, (*pInfo).(i)
            'OBJREF':	obj_destroy, (*pInfo).(i)
			else:
		endcase
    endfor

	ptr_free, pInfo

end ; of shielding_guiCleanup

;--------------------------------------------------------------------
;
;    PURPOSE  Main program
;
pro shielding_gui, $
    vpSizePn,  $		; IN: (opt) image size vector
    GROUP=group, $		; IN: (opt) group identifier
    RECORD_TO_FILENAME = record_to_filename, $
    APPTLB = appTLB		; OUT: (opt) TLB of this application

	; Get the user preferences
	@'shielding_gui_user_prefs'
	modalities = ['PET', 'SPECT']
	text = shielding_gui_mode_selector( TITLE='Select', $
			DROP_LABEL='Modality: ', DROP_VALUES=modalities, $
			THE_INDEX=index, XSIZE=120, CANCEL=bCancel )
	if bCancel then return
	pref_modality = modalities[index]

    ; Check the validity of the group identifier
	nGroups = n_elements( group )
	if nGroups ne 0 then begin
		isOk = widget_info( group, /VALID_ID )
		if isOk ne 1 then begin
			print, 'Error: the group identifier is not valid'
			print, 'Returning to the main application'
			return
		endif
		groupBase = group
	endif else groupBase = 0L

	; Create the widgets starting with the top level base
    if n_elements( group ) eq 0 then begin
        wTopBase = widget_base( TITLE='ALARA-CAD Shielding Design Tool', $
            MAP=0, $
            /TLB_KILL_REQUEST_EVENTS, $
            MBAR=barBase, TLB_FRAME_ATTR=0, /COLUMN )
    endif else begin
        wTopBase = widget_base( TITLE='ALARA-CAD Shielding Design Tool', $
            GROUP_LEADER=group, $
            MAP=0, $
            /TLB_KILL_REQUEST_EVENTS, $
            MBAR=barBase, TLB_FRAME_ATTR=0, /COLUMN )
    endelse

	menuItems = [ '1File', $
					  '1Open', $
					  		'0Floorplan (.bmp)', $
					  		'0Replacement floorplan (.bmp)', $
					  		'1ROIs (.sav)', $
					  			'0Sources (P_*)', $
					  			'0Shields (S_*)', $
					  			'0Horizontal shields (H_*)', $
					  			'0Regions (R_*)', $
					  			'2Queries (Q_*)', $
					  		'0Dosemap (.img)', $
					  		'2Session (.sav)', $
					  '1Add', $
					  		'1ROIs (.sav)', $
					  			'0Sources (P_*)', $
					  			'0Shields (S_*)', $
					  			'0Horizontal shields (H_*)', $
					  			'0Regions (R_*)', $
					  			'2Queries (Q_*)', $
					  		'0Protocols (.txt)', $
					  		'2Dosemap (.img)', $
					  '1Save', $
					  		'0Source table (.txt)', $
					  		'0Source-region table (.txt)', $
					  		'0Dose table (.txt)', $
					  		'0Source-query table (.txt)', $
					  		'0Query dose table (.txt)', $
					  		'0Shield table (.txt)', $
					  		'0Horizontal shield table (.txt)', $
					  		'0All tables (.txt)', $
					  		'1ROIs (.sav)', $
					  			'0Sources (P_*)', $
					  			'0Shields (S_*)', $
					  			'0Horizontal shields (H_*)', $
					  			'0Regions (R_*)', $
					  			'2Queries (Q_*)', $
					  		'0Dosemap (.img)', $
					  		'2Session (.sav)', $
					  '2Quit', $
				  '1Edit', $
				  	  '3Replace', $
				  	  		'0Sources (P_*)', $
				  	  		'0Shields (S_*)', $
				  	  		'0Horizontal shields (H_*)', $
				  	  		'2Regions (R_*)', $
				  '1Format', $
				      '2ROIs', $
				  '1View', $
				  	  '0Shift TLHC', $
				  	  '0Shift colorbar', $
				  	  '0Adjust compass', $
				  	  '1Dose map', $
				  	  		'0Set threshold', $
				  	  		'0Grayscale', $
				  	  		'0Grayscale > thresh', $
				  	  		'0Grayscale > thresh + occ', $
				  	  		'0Colour', $
				  	  		'0Colour > thresh', $
				  	  		'0Colour > thresh + occ', $
				  	  		'0Floor rois', $
				  	  		'2None', $
				  	  '3Horizontal rois', $
				  	  		'0Fill', $
				  	  		'2No fill' ]

	; Create the pull-down menu bar and all its buttons
	shielding_guiMenuCreate, menuItems, menuButtons, barBase

	; Create a three row sub base (buttons, draw windows, info)
	wSubBase = widget_base( wTopBase, ROW=3 )

		; Create the button toolbar
		wButtonBase = widget_base( wSubBase, /ROW, /ALIGN_LEFT )

		; Zoom in/out buttons
		wZoomBase = widget_base( wButtonBase, /ROW, $
				SPACE=0, /TOOLBAR )

			wBase = widget_base( wZoomBase, $
					SPACE=0, XPAD=0, YPAD=0 )
			wZoomInButton = widget_button( wBase, $
					VALUE='bitmaps\zoom_in.bmp', /BITMAP, /NO_RELEASE, $
					TOOLTIP='zoom in' )

			wBase = widget_base( wZoomBase, $
					SPACE=0, XPAD=0, YPAD=0 )
			wZoomOutButton = widget_button( wBase, $
					VALUE='bitmaps\zoom_out.bmp', /BITMAP, /NO_RELEASE, $
					TOOLTIP='zoom out' )

			wBase = widget_base( wZoomBase, /EXCLUSIVE, $
					SPACE=0, XPAD=0, YPAD=0 )
			wPanButton = widget_button( wBase, $
					VALUE='bitmaps\pan.bmp', /BITMAP, /NO_RELEASE, $
					TOOLTIP='pan image' )

			wBase = widget_base( wZoomBase, $
					SPACE=0, XPAD=0, YPAD=0 )
			wRecentreButton = widget_button( wBase, $
					VALUE='bitmaps\recentre.bmp', /BITMAP, /NO_RELEASE, $
					TOOLTIP='recentre image' )

		; Add/remove crosshairs buttons
		wCrosshairsBase = widget_base( wButtonBase, /ROW, $
				SPACE=0, /TOOLBAR )

			wBase = widget_base( wCrosshairsBase, /NONEXCLUSIVE, $
					SPACE=0, XPAD=0, YPAD=0 )
			wCrosshairsButton = widget_button( wBase, $
					VALUE='bitmaps\crosshairs_off.bmp', /BITMAP, $
					TOOLTIP='show/hide crosshairs' )

		; Draw ROIs buttons
		wROIDrawBase = widget_base( wButtonBase, /ROW, $
				SPACE=0, /TOOLBAR )

			wBase = widget_base( wROIDrawBase, /EXCLUSIVE, $
					SPACE=0, XPAD=0, YPAD=0 )
			wSourceROIButton = widget_button( wBase, $
					VALUE='bitmaps\source.bmp', /BITMAP, /NO_RELEASE, $
					TOOLTIP='source ROI' )

			wBase = widget_base( wROIDrawBase, /EXCLUSIVE, $
					SPACE=0, XPAD=0, YPAD=0 )
			wLineROIButton = widget_button( wBase, $
					VALUE='bitmaps\line.bmp', /BITMAP, /NO_RELEASE, $
					TOOLTIP='line ROI' )

			wBase = widget_base( wROIDrawBase, /EXCLUSIVE, $
					SPACE=0, XPAD=0, YPAD=0 )
			wRightROIButton = widget_button( wBase, $
					VALUE='bitmaps\right.bmp', /BITMAP, /NO_RELEASE, $
					TOOLTIP='right ROI' )

			wBase = widget_base( wROIDrawBase, /EXCLUSIVE, $
					SPACE=0, XPAD=0, YPAD=0 )
			wHROIButton = widget_button( wBase, $
					VALUE='bitmaps\hshield.bmp', /BITMAP, /NO_RELEASE, $
					TOOLTIP='horizontal shield' )

			wBase = widget_base( wROIDrawBase, /EXCLUSIVE, $
					SPACE=0, XPAD=0, YPAD=0 )
			wRectROIButton = widget_button( wBase, $
					VALUE='bitmaps\rectangle.bmp', /BITMAP, /NO_RELEASE, $
					TOOLTIP='rectangle ROI' )

			wBase = widget_base( wROIDrawBase, /EXCLUSIVE, $
					SPACE=0, XPAD=0, YPAD=0 )
			wQueryROIButton = widget_button( wBase, $
					VALUE='bitmaps\query.bmp', /BITMAP, /NO_RELEASE, $
					TOOLTIP='query point' )

		wROISnapBase = widget_base( wButtonBase, /ROW, $
				SPACE=0, /TOOLBAR )
			wBase = widget_base( wROISnapBase, /NONEXCLUSIVE, $
					SPACE=0, XPAD=0, YPAD=0 )
			wSnapROIButton = widget_button( wBase, $
					VALUE='bitmaps\snap.bmp', /BITMAP, $
					TOOLTIP='snap to nearest' )

		wROIEditBase = widget_base( wButtonBase, /ROW, $
				SPACE=0, /TOOLBAR )

			wBase = widget_base( wROIEditBase, /EXCLUSIVE, $
					SPACE=0, XPAD=0, YPAD=0 )
			wExtendROIButton = widget_button( wBase, $
					VALUE='bitmaps\extend.bmp', /BITMAP, /NO_RELEASE, $
					TOOLTIP='extend line ROI' )

			wBase = widget_base( wROIEditBase, /EXCLUSIVE, $
					SPACE=0, XPAD=0, YPAD=0 )
			wTrimROIButton = widget_button( wBase, $
					VALUE='bitmaps\trim.bmp', /BITMAP, /NO_RELEASE, $
					TOOLTIP='trim line ROI' )

			wBase = widget_base( wROIEditBase, /EXCLUSIVE, $
					SPACE=0, XPAD=0, YPAD=0 )
			wMoveROIVertexButton = widget_button( wBase, $
					VALUE='bitmaps\move_vertex.bmp', /BITMAP, /NO_RELEASE, $
					TOOLTIP='move ROI vertex' )

			wBase = widget_base( wROIEditBase, /EXCLUSIVE, $
					SPACE=0, XPAD=0, YPAD=0 )
			wMoveROIButton = widget_button( wBase, $
					VALUE='bitmaps\move_all.bmp', /BITMAP, /NO_RELEASE, $
					TOOLTIP='move entire ROI' )

			wBase = widget_base( wROIEditBase, /EXCLUSIVE, $
					SPACE=0, XPAD=0, YPAD=0 )
			wDeleteROIButton = widget_button( wBase, $
					VALUE='bitmaps\delete.bmp', /BITMAP, /NO_RELEASE, $
					TOOLTIP='delete ROI' )

		wROIOtherBase = widget_base( wButtonBase, /ROW, $
				SPACE=0, /TOOLBAR, SENSITIVE=0 )

			wBase = widget_base( wROIOtherBase, $
					SPACE=0, XPAD=0, YPAD=0 )
			wUndoROIButton = widget_button( wBase, $
					VALUE='bitmaps\undo.bmp', /BITMAP, /NO_RELEASE, $
					TOOLTIP='undo last vertex' )

			wBase = widget_base( wROIOtherBase, $
					SPACE=0, XPAD=0, YPAD=0 )
			wRedoROIButton = widget_button( wBase, $
					VALUE='bitmaps\redo.bmp', /BITMAP, /NO_RELEASE, $
					TOOLTIP='redo last vertex' )

			wBase = widget_base( wROIOtherBase, /EXCLUSIVE, $
					SPACE=0, XPAD=0, YPAD=0 )
			wCopyROIButton = widget_button( wBase, $
					VALUE='bitmaps\copy.bmp', /BITMAP, /NO_RELEASE, $
					TOOLTIP='copy ROI' )

			wBase = widget_base( wROIOtherBase, $
					SPACE=0, XPAD=0, YPAD=0 )
			wPasteROIButton = widget_button( wBase, $
					VALUE='bitmaps\paste.bmp', /BITMAP, /NO_RELEASE, $
					TOOLTIP='paste ROI', SENSITIVE=0 )

		wCalcBase = widget_base( wButtonBase, /ROW, SPACE=0 )

			wBase = widget_base( wCalcBase, $
					SPACE=0, XPAD=0, YPAD=0 )
			wCalcThicknessButton = widget_button( wBase, $
					VALUE='bitmaps\calculator.bmp', /BITMAP, /NO_RELEASE, $
					TOOLTIP='shield thickness calculator' )

			if pref_modality ne 'PET' then $
				widget_control, wCalcThicknessButton, SENSITIVE=0

		wProtocolBase = widget_base( wButtonBase, /ROW, SPACE=0 )

			wBase = widget_base( wProtocolBase, SPACE=0, XPAD=0, YPAD=0 )
			wProtocolButton = widget_button( wBase, $
					VALUE='New Protocol', /NO_RELEASE, $
					TOOLTIP='Add a new protocol' )

		wMeasBase = widget_base( wButtonBase, /ROW )

			wLabel = widget_label( wMeasBase, VALUE='Measuring tape origin' )
			wBase = widget_base( wMeasBase, /ROW, $
					SPACE=0, XPAD=0, YPAD=0 )
			wLabel = widget_label( wBase, VALUE='x(m):' )
			wMeasureXValText = widget_text( wBase, VALUE='0.0', XSIZE=6 )
			wLabel = widget_label( wBase, VALUE='y(m):' )
			wMeasureYValText = widget_text( wBase, VALUE='0.0', XSIZE=6 )
			wBase = widget_base( wMeasBase, /EXCLUSIVE, $
					SPACE=0, XPAD=0, YPAD=0 )
			wMeasurePickButton = widget_button( wBase, $
					VALUE='bitmaps\arrow.bmp', /BITMAP, /NO_RELEASE, $
					TOOLTIP='Pick meas tool origin' )

		; Create a two column (user settings and main) sub base
		wWinBase = widget_base( wSubBase, /ROW )

		; Create a user settings base
		wLeftBase = widget_base( wWinBase, /COLUMN, /FRAME )

			; Scale input
			wScaleBase = widget_base( wLeftBase, /COLUMN, /FRAME, /ALIGN_CENTER )
			wScaleLabel = widget_label( wScaleBase, VALUE='SCALE (m/pixel)' )
			wBase = widget_base( wScaleBase, /ROW )
			wLabel = widget_label( wBase, VALUE='Floorplan:' )
			wFloorplanScaleText = widget_text( wBase, VALUE='1.0', /EDITABLE, XSIZE=10 )
			wLabel = widget_label( wBase, VALUE='Dose map:' )
			wDosemapScaleText = widget_text( wBase, VALUE='0.5', XSIZE=10  )

			; Tabbed widget for tables
			wTab = widget_tab( wLeftBase )

			; Source location input
			wSourceBase = widget_base( wTab, /COLUMN, /FRAME, /ALIGN_CENTER, TITLE='Sources' )
			wSourceLabel = widget_label( wSourceBase, VALUE='SOURCE SPECIFICATIONS' )
			wDummyBase = widget_base( wSourceBase, /ROW )
			wDeleteSourceButton = widget_button( wDummyBase, VALUE='Delete', $
					/NO_RELEASE, TOOLTIP='delete row from source table' )
			wHideSourcesButton = widget_button( wDummyBase, VALUE='Hide', $
					/NO_RELEASE, TOOLTIP='hide all source ROIs' )
			colLabels = ['Name','x(m)','y(m)','Tracer', $
						 'A0(GBq)','T1(min)','T2(min)','NA(pat/yr)', $
						 'PV(%)','SS(%)','Description']
			colWidths = make_array( n_elements(colLabels), /INT, VALUE=50 )
			colWidths[n_elements(colLabels)-1] = 150 ; make the description column wider
			wSourceTable = widget_table( wSourceBase, $
					COLUMN_WIDTHS=colWidths, $
					COLUMN_LABELS=colLabels, $
					XSIZE=n_elements(colLabels), X_SCROLL_SIZE=4, $
					YSIZE=1, Y_SCROLL_SIZE=20, $
					UVALUE=0, EDITABLE=b_tables_editable, /ALL_EVENTS )

			; Structure input
			wShieldBase = widget_base( wTab, /COLUMN, /FRAME, /ALIGN_CENTER, TITLE='Shields' )
			wShieldLabel = widget_label( wShieldBase, VALUE='VERTICAL SHIELDING SPECIFICATIONS' )
			wDummyBase = widget_base( wShieldBase, /ROW )
;			wInsertShieldButton = widget_button( wDummyBase, VALUE='Insert', $
;					/NO_RELEASE, TOOLTIP='add shield material' )
			wDeleteShieldButton = widget_button( wDummyBase, VALUE='Delete', $
					/NO_RELEASE, TOOLTIP='delete row from shield table' )
			wHideShieldsButton = widget_button( wDummyBase, VALUE='Hide', $
					/NO_RELEASE, TOOLTIP='hide all shield ROIs' )
			colLabels = ['Name', 'x1(m)', 'y1(m)', 'x2(m)', 'y2(m)', $
						 'h1(m)', 'h2(m)', $
						 'Material', 'Thick.(cm)', 'Description']
			colWidths = make_array( n_elements(colLabels), /INT, VALUE=50 )
			colWidths[n_elements(colLabels)-1] = 150 ; make the description column wider
			wShieldTable = widget_table( wShieldBase, $
					COLUMN_WIDTHS=colWidths, $
					COLUMN_LABELS=colLabels, $
					XSIZE=n_elements(colLabels), X_SCROLL_SIZE=4, $
					YSIZE=1, Y_SCROLL_SIZE=15, $
					UVALUE=0, EDITABLE=b_tables_editable, /ALL_EVENTS )

			wHShieldLabel = widget_label( wShieldBase, VALUE='HORIZONTAL SHIELDING SPECIFICATIONS' )
			wDummyBase = widget_base( wShieldBase, /ROW )
;			wInsertHShieldButton = widget_button( wDummyBase, VALUE='Insert', $
;					/NO_RELEASE, TOOLTIP='add shield material' )
			wDeleteHShieldButton = widget_button( wDummyBase, VALUE='Delete', $
					/NO_RELEASE, TOOLTIP='delete row from shield table' )
			wHideHShieldsButton = widget_button( wDummyBase, VALUE='Hide', $
					/NO_RELEASE, TOOLTIP='hide all horizontal shield ROIs' )
			colLabels = ['Name', 'x1(m)', 'y1(m)', 'x2(m)', 'y2(m)', $
						 'x3(m)', 'y3(m)', 'x4(m)', 'y4(m)', $
						 'h(m)', 'Material', 'Thick.(cm)', 'Description']
			colWidths = make_array( n_elements(colLabels), /INT, VALUE=50 )
			colWidths[n_elements(colLabels)-1] = 150 ; make the description column wider
			wHShieldTable = widget_table( wShieldBase, $
					COLUMN_WIDTHS=colWidths, $
					COLUMN_LABELS=colLabels, $
					XSIZE=n_elements(colLabels), X_SCROLL_SIZE=4, $
					YSIZE=1, Y_SCROLL_SIZE=2, $
					UVALUE=0, EDITABLE=b_tables_editable, /ALL_EVENTS )

			; Region input
			wRegionBase = widget_base( wTab, /COLUMN, /FRAME, /ALIGN_CENTER, TITLE='Regions' )
			wRegionLabel = widget_label( wRegionBase, VALUE='REGION SPECIFICATIONS' )
			wDummyBase = widget_base( wRegionBase, /ROW )
			wDeleteRegionButton = widget_button( wDummyBase, VALUE='Delete', $
					/NO_RELEASE, TOOLTIP='delete row from region table' )
			wHideRegionsButton = widget_button( wDummyBase, VALUE='Hide', $
					/NO_RELEASE, TOOLTIP='hide all region ROIs' )
			colLabels = ['Name', 'x1(m)', 'y1(m)', 'x2(m)', 'y2(m)', $
						 'x3(m)', 'y3(m)', 'x4(m)', 'y4(m)', $
						 'xMax(m)', 'yMax(m)', 'Max(uSv)', $
						 'OF', 'EffMax(uSv)', 'Description']
			colWidths = make_array( n_elements(colLabels), /INT, VALUE=50 )
			colWidths[n_elements(colLabels)-1] = 150 ; make the description column wider
			wRegionTable = widget_table( wRegionBase, $
					COLUMN_WIDTHS=colWidths, $
					COLUMN_LABELS=colLabels, $
					XSIZE=n_elements(colLabels), X_SCROLL_SIZE=4, $
					YSIZE=1, Y_SCROLL_SIZE=20, $
					UVALUE=0, EDITABLE=b_tables_editable, /ALL_EVENTS )
			wCalcRegionsButton = widget_button( wRegionBase, VALUE='Calculate hot regions', $
					/NO_RELEASE, TOOLTIP='calculate dose to hot regions' )


			; Query point UI
			geom = widget_info( wShieldTable, /GEOMETRY )
			wQueryBase = widget_base( wTab, /COLUMN, /FRAME, /ALIGN_CENTER, TITLE='Query' )
			wLabel = widget_label( wQueryBase, VALUE='QUERY POINTS' )
			wQueryButtonBase = widget_base( wQueryBase, /ROW, SPACE=0, /TOOLBAR, $
					/ALIGN_CENTER )
			wHideQueryButton = widget_button( wQueryButtonBase, VALUE='Hide', $
					/NO_RELEASE, TOOLTIP='hide query points' )
			wClearQueryButton = widget_button( wQueryButtonBase, VALUE='Clear Selected Text', $
					/NO_RELEASE, TOOLTIP='delete highlighted text in query window' )
			wClearAllQueryButton = widget_button( wQueryButtonBase, VALUE='Clear All Text', $
					/NO_RELEASE, TOOLTIP='delete all text in query window' )
			wQueryText = widget_text( wQueryBase, VALUE='', /SCROLL, $
					SCR_XSIZE=geom.scr_xsize, YSIZE=30 )


			; Calculate button
			wCalculateBase = widget_base( wTab, /COLUMN, /FRAME, /ALIGN_CENTER, TITLE='Calculate' )
			wLabel = widget_label( wCalculateBase, VALUE='CALCULATION PARAMETERS' )
			wBase = widget_base( wCalculateBase, /ROW )
			wLevelLabel = widget_label( wBase, VALUE='Level to calculate dose to: ' )
			wLevelList = widget_droplist( wBase, $
					VALUE=['current', 'above', 'below'] )
			wBase = widget_base( wCalculateBase, /ROW )
			wResolutionLabel = widget_label( wBase, VALUE='Dose map resolution (m/pixel): ' )
			wResolutionText = widget_text( wBase, VALUE='0.5', /EDIT ) ; Should be same as wDosemapScaleText to start
			wBase = widget_base( wCalculateBase, /ROW )
			wShieldHeightLabel = widget_label( wBase, VALUE='Default shielding height (m): ' )
			wShieldHeightText = widget_text( wBase, VALUE='3', /EDIT )
			wBase = widget_base( wCalculateBase, /ROW )
			wSourceHeightLabel = widget_label( wBase, VALUE='Source height above ground (m): ' )
			wSourceHeightText = widget_text( wBase, VALUE='1.0', /EDIT )
			wBase = widget_base( wCalculateBase, /ROW )
			wAboveDistLabel = widget_label( wBase, VALUE='Distance to floor above (m): ' )
			wAboveDistText = widget_text( wBase, VALUE='3', /EDIT )
			wBase = widget_base( wCalculateBase, /ROW )
			wAboveThickLabel = widget_label( wBase, VALUE='Above slab thickness (cm): ')
			wAboveThickText = widget_text( wBase, VALUE='13.97', /EDIT )
			wBase = widget_base( wCalculateBase, /ROW )
			wAboveTargetHeightLabel = widget_label( wBase, VALUE='Above target height (m): ' )
			wAboveTargetHeightText = widget_text( wBase, VALUE='0.5', /EDIT )
			wBase = widget_base( wCalculateBase, /ROW )
			wBelowDistLabel = widget_label( wBase, VALUE='Distance to floor below (m): ' )
			wBelowDistText = widget_text( wBase, VALUE='3', /EDIT )
			wBase = widget_base( wCalculateBase, /ROW )
			wBelowThickLabel = widget_label( wBase, VALUE='Below slab thickness (cm): ')
			wBelowThickText = widget_text( wBase, VALUE='13.97', /EDIT )
			wBase = widget_base( wCalculateBase, /ROW )
			wBelowTargetHeightLabel = widget_label( wBase, VALUE='Below target height (m); ' )
			wBelowTargetHeightText = widget_text( wBase, VALUE='1.7', /EDIT )
			wBase = widget_base( wCalculateBase, /ROW )
			wBoxPointLabel = widget_label( wBase, VALUE='Contained source point: ')
			wBoxPointText = widget_text( wBase, VALUE='', /EDIT )
			wBase = widget_base( wCalculateBase, /ROW )
			wBoxThickLabel = widget_label( wBase, VALUE='Container thickness (cm Pb): ' )
			wBoxThickText = widget_text( wBase, VALUE='', /EDIT )

			; Make the widget pretty
			g0 = widget_info( wShieldHeightLabel, /GEOM )
			g1 = widget_info( wAboveDistLabel, /GEOM )
			g2 = widget_info( wAboveThickLabel, /GEOM )
			g3 = widget_info( wBoxPointLabel, /GEOM )
			g4 = widget_info( wBoxThickLabel, /GEOM )
			g5 = widget_info( wBelowDistLabel, /GEOM )
			g6 = widget_info( wBelowThickLabel, /GEOM )
			g7 = widget_info( wLevelLabel, /GEOM )
			g8 = widget_info( wResolutionLabel, /GEOM )
			g9 = widget_info( wSourceHeightLabel, /GEOM )
			g10 = widget_info( wAboveTargetHeightLabel, /GEOM )
			g11 = widget_info( wBelowTargetHeightLabel, /GEOM )
			xMax = max( [g0.scr_xsize, g1.scr_xsize, g2.scr_xsize, $
						 g3.scr_xsize, g4.scr_xsize, g5.scr_xsize, $
						 g6.scr_xsize, g7.scr_xsize, g8.scr_xsize, $
						 g9.scr_xsize, g10.scr_xsize, g11.scr_xsize] )
			widget_control, wLevelLabel, SCR_XSIZE=xMax
			widget_control, wResolutionLabel, SCR_XSIZE=xMax
			widget_control, wShieldHeightLabel, SCR_XSIZE=xMax
			widget_control, wAboveDistLabel, SCR_XSIZE=xMax
			widget_control, wAboveThickLabel, SCR_XSIZE=xMax
			widget_control, wBoxPointLabel, SCR_XSIZE=xMax
			widget_control, wBoxThickLabel, SCR_XSIZE=xMax
			widget_control, wBelowDistLabel, SCR_XSIZE=xMax
			widget_control, wBelowThickLabel, SCR_XSIZE=xMax
			widget_control, wSourceHeightLabel, SCR_XSIZE=xMax
			widget_control, wAboveTargetHeightLabel, SCR_XSIZE=xMax
			widget_control, wBelowTargetHeightLabel, SCR_XSIZE=xMax

			wCalculateButton = widget_button( wCalculateBase, VALUE='Calculate', $
					/NO_RELEASE, TOOLTIP='calculate dose map' )
;			wCalcDoseRateButton = widget_button( wCalculateBase, VALUE='Calculate dose rate', $
;					/NO_RELEASE, TOOLTIP='calculate dose rate map' )


			; Make the left portion pretty
			g1 = widget_info( wScaleBase, /GEOM )
			g2 = widget_info( wShieldBase, /GEOM )
			g3 = widget_info( wSourceBase, /GEOM )
			g4 = widget_info( wCalculateBase, /GEOM )
			g5 = widget_info( wQueryBase, /GEOM )
			g6 = widget_info( wRegionBase, /GEOM )
			xMax = max( [g1.scr_xsize, g2.scr_xsize, g3.scr_xsize, $
						 g4.scr_xsize, g5.scr_xsize, g6.scr_xsize] )
			widget_control, wScaleBase, SCR_XSIZE=xMax
			widget_control, wShieldBase, SCR_XSIZE=xMax
			widget_control, wSourceBase, SCR_XSIZE=xMax
			widget_control, wCalculateBase, SCR_XSIZE=xMax
			widget_control, wQueryBase, SCR_XSIZE=xMax
			widget_control, wRegionBase, SCR_XSIZE=xMax

		; Divide the RH portion of the screen into a viewing area and lower
		; tool area
		wRightBase = widget_base( wWinBase, /COLUMN, YPAD=0 )

		; Create a 3 column main view base (CT, scrollbar and PET)
		wMainBase = widget_base( wRightBase, /ROW, /FRAME )

			; Add labels, windows and info text widgets to the
			; CT and PET bases
			leftGeom = widget_info( wLeftBase, /GEOMETRY )
			device, GET_SCREEN=scrnSize
;			scrnSize[0] = 640
;			scrnSize[1] = 480
			vpSize = intarr(2)
			vpSize[0] = fix( scrnSize[0] - leftGeom.scr_xsize - 46 )
			vpSize[1] = fix( scrnSize[1] - 230 )

			wVPBase = widget_base( wMainBase, /COLUMN )
			fileName = ''
			wLabel = widget_label( wVPBase, $
					/ALIGN_LEFT, XSIZE=vpSize[0], $
					VALUE=string( fileName, FORMAT='(a34)') )

			wDraw = widget_draw( wVPBase, $
					/BUTTON, /MOTION, KEYBOARD=2, $ ; events to watch for
					RETAIN=2, GRAPHICS_LEVEL=2, $
					XSIZE=vpSize[0], YSIZE=vpSize[1] )

			wPixelInfoText = widget_text( wVPBase, VALUE='' )

			widget_control, wLabel, SET_VALUE=fileName

		; Status text at the bottom of the program window
		geom = widget_info( wSubBase, /GEOMETRY )
		value = 'Current mode: ' + strtrim( pref_modality, 2 )
		wInfoBase = widget_base( wSubBase, /ROW )
		wInfoText = widget_text( wInfoBase, VALUE=value, $
				SCR_XSIZE=geom.scr_xSize-2*geom.xPad-4*geom.space )

	; Create a context menu
	wShieldContextMenu = widget_base( wTopBase, /CONTEXT_MENU )
;	wCopyMenuButton = widget_button( wShieldContextMenu, VALUE='Copy', $
;			UVALUE='Copy ROI' )
	wButton = widget_button( wShieldContextMenu, VALUE='Delete', $
			UVALUE='Delete ROI' )
	wButton = widget_button( wShieldContextMenu, VALUE='Set scale', $
			UVALUE='Set scale', /SEPARATOR )
	wButton = widget_button( wShieldContextMenu, VALUE='Print length', $
			UVALUE='Print length' )

	wSourceContextMenu = widget_base( wTopBase, /CONTEXT_MENU )
;	wCopyMenuButton = widget_button( wSourceContextMenu, VALUE='Copy', $
;			UVALUE='Copy ROI' )
	wButton = widget_button( wSourceContextMenu, VALUE='Delete', $
			UVALUE='Delete ROI' )
	wButton = widget_button( wSourceContextMenu, VALUE='Change description', $
			UVALUE='Change description' )
	wButton = widget_button( wSourceContextMenu, VALUE='Add specs', $
			UVALUE='Add specs' )

	wQueryContextMenu = widget_base( wTopBase, /CONTEXT_MENU )
;	wCopyMenuButton = widget_button( wQueryContextMenu, VALUE='Copy', $
;			UVALUE='Copy ROI' )
	wButton = widget_button( wQueryContextMenu, VALUE='Delete', $
			UVALUE='Delete ROI' )
	wButton = widget_button( wQueryContextMenu, VALUE='Recalculate', $
			UVALUE='Recalculate' )

	wRegionContextMenu = widget_base( wTopBase, /CONTEXT_MENU )
	wButton = widget_button( wRegionContextMenu, VALUE='Rename', $
			UVALUE='Rename ROI' )
	wButton = widget_button( wRegionContextMenu, VALUE='Delete', $
			UVALUE='Delete ROI' )
	wButton = widget_button( wRegionContextMenu, VALUE='Find max pixel', $
			UVALUE='Find max pixel' )

	wROIPasteContextMenu = widget_base( wTopBase, /CONTEXT_MENU )
	wPasteMenuButton = widget_button( wROIPasteContextMenu, VALUE='Paste', $
			UVALUE='Paste ROI' )

	; Realize the widget hierarchy.
	widget_control, wTopBase, /REALIZE
	widget_control, wButtonBase, SENSITIVE=0
	widget_control, wDraw, SENSITIVE=0

	; Return the top level base to the APPTLB keyword
    appTLB = wTopBase

	; Create main display object hierarchies
	widget_control, wDraw, GET_VALUE=oWindow
	oFloorplan		= obj_new( 'IDLgrImage', HIDE=0 )
	oDosemap		= obj_new( 'IDLgrImage', HIDE=1 )
	oModel			= obj_new( 'IDLgrModel' )
	oView			= obj_new( 'IDLgrView' )

	oXAxis			= obj_new( 'IDLgrAxis', DIRECTION=0, $
							   COLOR=[0,255,255], MAJOR=0, HIDE=1 )
	oYAxis			= obj_new( 'IDLgrAxis', DIRECTION=1, $
							   COLOR=[0,255,255], MAJOR=0, HIDE=1 )
	oDispROIGroup	= obj_new( 'IDLgrModel' )
	oDispCopyROI	= obj_new( 'IDLgrROI', COLOR=[0,0,255], LINESTYLE=2, HIDE=1 )

	oVertexModel	= obj_new( 'IDLgrModel', HIDE=1 )
	oVertices		= obj_new( 'IDLgrPolyline', [[-4,-4],[-4,4],[4,4],[4,-4]], $
							   POLYLINES=[5,0,1,2,3,0], COLOR=[0,255,0] )
	oFill 			= obj_new( 'IDLgrPattern', STYLE=1, $
							   ORIENTATION=45, SPACING=10 ) ; Line fill
	oHPolyModel		= obj_new( 'IDLgrModel' )

	oViewGroup		= obj_new( 'IDLgrViewGroup' )

	oModel->add, oFloorplan
	oModel->add, oDosemap
	oView->add, oModel
	oModel->add, oXAxis
	oModel->add, oYAxis
	oModel->add, oDispROIGroup
	oModel->add, oDispCopyROI
	oVertexModel->add, oVertices
	oModel->add, oVertexModel
	oModel->add, oHPolyModel
	oViewGroup->add, oView

	; Save the current colour table
    tvlct, savedR, savedG, savedB, /GET
    colourTable = [[savedR], [savedG], [savedB]]

	; Load the grey scale colour table
	topClr = !D.TABLE_SIZE-1
	loadct, 0, /SILENT, NCOLORS=topClr+1

	; Set the background object palette (reverse grayscale)
	tvlct, r, g, b, /GET
	oPalette = obj_new( 'IDLgrPalette', reverse(r), reverse(g), reverse(b) )
	oFloorplan->setProperty, PALETTE=oPalette

	; Create a colour bar
	oCBView	= obj_new( 'IDLgrView', /TRANSPARENT )
	oViewGroup->add, oCBView
	oCBar	= obj_new('HColorBar', HIDE=1, POSITION=[-0.975, -0.9, -0.75, -0.86], $
			FONTSIZE=11 )
	oCBView->add, oCBar
	oTransPalette = obj_new( 'IDLgrPalette' )

	; Create a ruler bar
	oRulerView	= obj_new( 'IDLgrView', /TRANSPARENT )
	oViewGroup->add, oRulerView
	oRuler	= obj_new( 'HRuler', HIDE=1, POSITION=[-0.975, -0.9, -0.75, -0.9], $;[0.5, -0.9, 0.95, -0.9], $
			TEXTPOS=1, TICKPOS=0, TITLE='meters', MAJOR=3, MINOR=0, $
			FONTSIZE=11, TICKLEN=0.05 )
	oRulerView->add, oRuler

	; Create a compass
	oCompassView = obj_new( 'IDLgrView', /TRANSPARENT )
	oViewGroup->add, oCompassView
	oCompass = obj_new( 'MKCompass', HIDE=1, POSITION=[0.5+(0.95-0.5)/2.0,-0.65], $
			NORTH=2, FONTSIZE=11, COLOR=[0,0,0], VPSIZE=vpSize )
	oCompassView->add, oCompass

	; Map the top level base.
	widget_control, wTopBase, MAP=1

	; Define table enums
	eR = { name:		0, $
		   x1:			1, $
		   y1:			2, $
		   x2:			3, $
		   y2:			4, $
		   x3:			5, $
		   y3:			6, $
		   x4:			7, $
		   y4:			8, $
		   xMax:		9, $
		   yMax: 		10, $
		   maxDose:		11, $
		   occ:			12, $
		   effMaxDose:	13, $
		   desc:		14 }

	eP = { name:		0, $
		   x:			1, $
		   y:			2, $
		   tracer:		3, $
		   A0:			4, $
		   TU:			5, $
		   TI:			6, $
		   NA:			7, $
		   PV:			8, $
		   SS:			9, $
		   desc:		10 }

	eS = { name:		0, $
		   x1:			1, $
		   y1:			2, $
		   x2:			3, $
		   y2:			4, $
		   h1:			5, $
		   h2:			6, $
		   material:	7, $
		   thickness:	8, $
		   desc:		9 }

    eH = { name:		0, $
		   x1:			1, $
		   y1:			2, $
		   x2:			3, $
		   y2:			4, $
		   x3:			5, $
		   y3:			6, $
		   x4:			7, $
		   y4:			8, $
		   h:			9, $
		   material:	10, $
		   thickness:	11, $
		   desc:		12 }

	; Create the info structure
    info = { groupBase:				groupBase, $
    		 colourTable:			colourTable, $
			 topClr:				topClr, $
			 vpSize:				vpSize, $
			 fileName:				fileName, $
			 zoomFactor:			1.0, $
			 max0:					1000, $
			 min0:					0, $
			 max1:					100, $
			 min1:					0, $
			 menuItems:				menuItems, $
			 menuButtons:			menuButtons, $
			 barBase:				barBase, $
			 wTopBase:				wTopBase, $
			 wDraw:					wDraw, $
			 wLabel:				wLabel, $
			 wPixelInfoText:		wPixelInfoText, $
			 wSubBase:				wSubBase, $
			 ; Toolbar ==============================================
			 wButtonBase:			wButtonBase, $
			 wZoomInButton:			wZoomInButton, $
			 wZoomOutButton:		wZoomOutButton, $
			 wPanButton:			wPanButton, $
			 wRecentreButton:		wRecentreButton, $
			 wCrosshairsButton:		wCrosshairsButton, $
			 wSourceROIButton:		wSourceROIButton, $
			 wLineROIButton:		wLineROIButton, $
			 wRightROIButton:		wRightROIButton, $
			 wHROIButton:			wHROIButton, $
			 wRectROIButton:		wRectROIButton, $
			 wQueryROIButton:		wQueryROIButton, $
			 wSnapROIButton:		wSnapROIButton, $
			 wUndoROIButton:		wUndoROIButton, $
			 wRedoROIButton:		wRedoROIButton, $
			 wMoveROIVertexButton:	wMoveROIVertexButton, $
			 wMoveROIButton:		wMoveROIButton, $
			 wExtendROIButton:		wExtendROIButton, $
			 wTrimROIButton:		wTrimROIButton, $
			 wDeleteROIButton:		wDeleteROIButton, $
			 wCopyROIButton:		wCopyROIButton, $
			 wPasteROIButton:		wPasteROIButton, $
			 wCalcThicknessButton:	wCalcThicknessButton, $
			 wProtocolButton:		wProtocolButton, $
			 wMeasurePickButton:	wMeasurePickButton, $
			 wMeasureXValText:		wMeasureXValText, $
			 wMeasureYValText:		wMeasureYValText, $
			 wInfoText:				wInfoText, $
			 wShieldContextMenu:	wShieldContextMenu, $
			 wSourceContextMenu:	wSourceContextMenu, $
			 wQueryContextMenu:		wQueryContextMenu, $
			 wRegionContextMenu:	wRegionContextMenu, $
			 wROIPasteContextMenu:	wROIPasteContextMenu, $
			 ; User inputs ==========================================
			 wFloorplanScaleText:	wFloorplanScaleText, $
			 wDosemapScaleText:		wDosemapScaleText, $
			 wDeleteSourceButton:	wDeleteSourceButton, $
			 wHideSourcesButton:	wHideSourcesButton, $
			 wSourceTable:			wSourceTable, $
			 wShieldTable:			wShieldTable, $
;			 wInsertShieldButton:	wInsertShieldButton, $
			 wDeleteShieldButton:	wDeleteShieldButton, $
			 wHideShieldsButton:	wHideShieldsButton, $
			 wHShieldTable:			wHShieldTable, $
;			 wInsertHShieldButton:	wInsertHShieldButton, $
			 wDeleteHShieldButton:	wDeleteHShieldButton, $
			 wHideHShieldsButton:	wHideHShieldsButton, $
			 wRegionBase:			wRegionBase, $
			 wRegionTable:			wRegionTable, $
			 wCalcRegionsButton:	wCalcRegionsButton, $
			 wDeleteRegionButton:	wDeleteRegionButton, $
			 wHideRegionsButton:	wHideRegionsButton, $
			 curCell:				[-1,-1], $
			 curCellData:			'', $
			 wLevelList:			wLevelList, $
			 wResolutionText:		wResolutionText, $
			 wShieldHeightText:		wShieldHeightText, $
			 wSourceHeightText:		wSourceHeightText, $
			 wAboveDistText:		wAboveDistText, $
			 wAboveThickText:		wAboveThickText, $
			 wAboveTargetHeightText:wAboveTargetHeightText, $
			 wBoxPointText:			wBoxPointText, $
			 wBoxThickText:			wBoxThickText, $
			 wBelowDistText:		wBelowDistText, $
			 wBelowThickText:		wBelowThickText, $
			 wBelowTargetHeightText:wBelowTargetHeightText, $
			 wCalculateButton:		wCalculateButton, $
;			 wCalcDoseRateButton:	wCalcDoseRateButton, $
			 wHideQueryButton:		wHideQueryButton, $
			 wClearQueryButton:		wClearQueryButton, $
			 wClearAllQueryButton:	wClearAllQueryButton, $
			 wQueryText:			wQueryText, $
			 ; Viewports ============================================
			 vp2imgScale:			[1.0,1.0], $
			 vp2dmScale:			[1.0,1.0], $
			 dmThresh:				50.0, $
			 oWindow:				oWindow, $
			 oViewGroup:			oViewGroup, $
			 oView:					oView, $
			 oModel:				oModel, $
			 oFloorplan:			oFloorplan, $
			 oDosemap:				oDosemap, $
			 oPalette:				oPalette, $
			 oTransPalette:			oTransPalette, $
			 oCBar:					oCBar, $
			 oCBView:				oCBView, $
			 oRuler:				oRuler, $
			 oRulerView:			oRulerView, $
			 oCompass:				oCompass, $
			 oCompassView:			oCompassView, $
			 oXAxis:				oXAxis, $
			 oYAxis:				oYAxis, $
			 oDispROIGroup:			oDispROIGroup, $
			 oDispCurROI:			obj_new(), $
			 oVertexModel:			oVertexModel, $
			 oROIGroup:				obj_new( 'IDLgrModel' ), $
			 oFill:					oFill, $
			 oHPolyModel:			oHPolyModel, $
			 roiThick:				3.0, $
			 textSize:				18.0, $
			 oCurROI:				obj_new(), $
			 oCopyROI:				obj_new( 'MKgrROI' ), $
			 oDispCopyROI:			oDispCopyROI, $
			 curVertIndex:			-1L, $
			 oUndoContainer:		obj_new( 'IDL_Container' ), $
			 oRedoContainer:		obj_new( 'IDL_Container' ), $
			 curScrnCoords:			[0.0,0.0], $
			 mode:					'none', $
			 pSeries0:				ptr_new(/ALLOCATE_HEAP), $
			 pSeries1:				ptr_new(/ALLOCATE_HEAP), $
			 displayMode:			'gray-all', $
			 nPx:					1000, $
			 nPy:					800, $
			 cPoint:				[0,0], $
			 bButtonDown:			0b, $
			 workingDir:			pref_data_dir, $
			 tmpDir:				temp_write_dir, $
			 modality:				pref_modality, $
			 eR:					eR, $
			 eP:					eP, $
			 eS:					eS, $
			 eH:					eH }

	pInfo = ptr_new( info, /NO_COPY )

	; Assign the info structure into the user value of the top level base
    widget_control, wTopBase, SET_UVALUE=pInfo, /NO_COPY
	widget_control, wTopBase, /HOURGLASS

	XMANAGER, 'shielding_gui', wTopBase, CLEANUP='shielding_guiCleanup',  $
		Event_Handler='shielding_guiEvent', /NO_BLOCK
end



