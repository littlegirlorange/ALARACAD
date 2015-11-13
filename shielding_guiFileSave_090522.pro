;--------------------------------------------------------------------
;
;    PURPOSE  Save a table of the source parameters
;
pro shielding_guiSaveSourceTable, $
	pInfo, $
	FILENAME=filename

	; Return if we don't have any data to save
	widget_control, (*pInfo).wSourceTable, GET_VALUE=pData, GET_UVALUE=nPs
	if nPs eq 0 then begin
		; Bark at the user if s/he prompted this save. Otherwise just
		; exit quietly.
		if n_elements( filename ) eq 0 then begin
			void = dialog_message( 'No sources. Table not saved.' )
		endif
		return
	endif

	if n_elements( filename ) eq 0 then begin
		; Prompt for file to save to.
		defBase = file_basename( (*pInfo).filename, '.txt' )
		defPath = file_dirname( (*pInfo).filename, /MARK_DIRECTORY )
		file = dialog_pickfile( /WRITE, DIALOG_PARENT=(*pInfo).wTopBase, $
				PATH=defPath, FILE=defPath+defBase+'_sourceTable.txt', $
				GET_PATH=path, /OVERWRITE_PROMPT )
	endif else begin
		file = (file_search( filename ))[0]
		if file ne '' then begin
			; File already exists. Prompt for new file name.
			title = strtrim( file_basename( filename ), 2 ) $
					+ ' exists. Save as...'
			file = dialog_pickfile( DIALOG_PARENT=(*pInfo).wTopBase, $
					TITLE=title, FILE=filename, /OVERWRITE_PROMPT )
		endif else begin
			file = filename
		endelse
	endelse

	if file eq '' then return

	openw, lun, /GET_LUN, file
	printf, lun, 'Point;' + 'Description;' + 'Isotope;' + 'A0 (GBq);' + $
				 'T1 (min);' + 'T2 (min);' + 'NA (pat/yr);' + 'PV (%);' + 'SS (%);'

	eP = (*pInfo).eP

	for iP=0, nPs-1 do begin

		line = pData[eP.name,iP] + ';' $
			 + pData[eP.desc,iP] + ';' $
			 + pData[eP.tracer,iP] + ';' $
			 + pData[eP.A0,iP] + ';' $
			 + pData[eP.TU,iP] + ';' $
			 + pData[eP.TI,iP] + ';' $
			 + pData[eP.NA,iP] + ';' $
			 + pData[eP.PV,iP] + ';' $
			 + pData[eP.SS,iP] + ';'

		printf, lun, line

	endfor

	close, lun

end ; of shielding_guiSaveSourceTable


;--------------------------------------------------------------------
;
;    PURPOSE  Save a table of the source-regional max dose distances
;
pro shielding_guiSaveSourceRegionTable, $
	pInfo, $
	FILENAME=filename

	forward_function shielding_guiGetROIs

	; Return if we don't have any data to save
	widget_control, (*pInfo).wSourceTable, GET_VALUE=pData, GET_UVALUE=nPs
	widget_control, (*pInfo).wRegionTable, GET_VALUE=rData, GET_UVALUE=nRs
	if (nPs eq 0) or (nRs eq 0) then begin
		; Bark at the user if s/he prompted this save. Otherwise just
		; exit quietly.
		if n_elements( filename ) eq 0 then begin
			void = dialog_message( 'No sources and/or regions. Table not saved.' )
		endif
		return
	endif

	if n_elements( filename ) eq 0 then begin
		; Prompt for file to save to.
		defBase = file_basename( (*pInfo).filename, '.txt' )
		defPath = file_dirname( (*pInfo).filename, /MARK_DIRECTORY )
		file = dialog_pickfile( /WRITE, DIALOG_PARENT=(*pInfo).wTopBase, $
				PATH=defPath, FILE=defPath+defBase+'_sourceRegionTable.txt', $
				GET_PATH=path, /OVERWRITE_PROMPT )
	endif else begin
		file = (file_search( filename ))[0]
		if file ne '' then begin
			; File already exists. Prompt for new file name.
			title = strtrim( file_basename( filename ), 2 ) $
					+ ' exists. Save as...'
			file = dialog_pickfile( DIALOG_PARENT=(*pInfo).wTopBase, $
					TITLE=title, FILE=filename, /OVERWRITE_PROMPT )
		endif else begin
			file = filename
		endelse
	endelse

	if file eq '' then return
	defBase = file_basename( (*pInfo).filename, '.txt' )
	defPath = file_dirname( (*pInfo).filename, /MARK_DIRECTORY )

	eR = (*pInfo).eR
	eP = (*pInfo).eP

	levelIndex = widget_info( (*pInfo).wLevelList, /DROPLIST_SELECT )
	case levelIndex of
		1: begin ; above
			widget_control, (*pInfo).wAboveDistText, GET_VALUE=aboveDist
			widget_control, (*pInfo).wSourceHeightText, GET_VALUE=sourceHeight
			widget_control, (*pInfo).wAboveTargetHeightText, GET_VALUE=targetHeight
			aboveDist = float(aboveDist[0])
			sourceHeight = float(sourceHeight[0])
			targetHeight = float(targetHeight[0])
			height = aboveDist - sourceHeight + targetHeight
		end
		2: begin ; below
			widget_control, (*pInfo).wBelowDistText, GET_VALUE=belowDist
			widget_control, (*pInfo).wSourceHeightText, GET_VALUE=sourceHeight
			widget_control, (*pInfo).wBelowTargetHeightText, GET_VALUE=targetHeight
			belowDist = float(belowDist[0])
			sourceHeight = float(sourceHeight[0])
			targetHeight = float(targetHeight[0])
			height = belowDist + sourceHeight - targetHeight
		end
		else: begin
			height = 0
		end
	endcase

	; Get point descriptions, if they exist
	oPRois = shielding_guiGetROIs( pInfo, /SOURCE, COUNT=nPRois, NAMES=pNames, DESC=pDescs )
	openw, lun, /GET_LUN, file
	printf, lun, ' ;' + ' ;' + strjoin( pNames, ';', /SINGLE )
	printf, lun, 'Region;' + 'Description;' + strjoin( pDescs, ';', /SINGLE )

	for iR=0, nRs-1 do begin

		line = rData[eR.name,iR] + ';' + rData[eR.desc,iR] + ';'

		xR = float( rData[eR.xMax,iR] )
		yR = float( rData[eR.yMax,iR] )

		for iP=0, nPRois-1 do begin

			rows = where( pData[eP.name,*] eq pNames[iP] )
			xP = float( pData[eP.x,rows[0]] )
			yP = float( pData[eP.y,rows[0]] )

			d = sqrt( (xR-xP)^2 + (yR-yP)^2 + height^2 )
			line = line + format_float( d ) + ';'

		endfor

		printf, lun, line

	endfor

;	printf, lun, ' ;' + ' ;' + strjoin( rData[eR.name,*], ';', /SINGLE )
;	printf, lun, 'Source;' + 'Description;' + strjoin( rData[eR.desc,*], ';', /SINGLE )

;	for iP=0, nPs-1 do begin
;
;			line = pData[eP.name,iP] + ';' + pData[eP.desc,iP] + ';'
;			xP = float(pData[eP.x,iP])
;			yP = float(pData[eP.y,iP])
;
;			for iR=0, nRs-1 do begin
;
;				xR = float(rData[eR.xMax,iR])
;				yR = float(rData[eR.yMax,iR])
;
;				d = sqrt( (xR-xP)^2 + (yR-yP)^2 + height^2 )
;
;				line = line + strtrim(d,2) + ';'
;
;			endfor
;
;		printf, lun, line
;
;	endfor

	close, lun

end ; of shielding_guiSaveSourceRegionTable


;--------------------------------------------------------------------
;
;    PURPOSE  Save a table of the source-regional max dose values
;
pro shielding_guiSaveDoseTable, $
	pInfo, $
	FILENAME=filename

	; Return if we don't have any data to save
	widget_control, (*pInfo).wRegionTable, GET_VALUE=rData, GET_UVALUE=nRs
	if nRs eq 0 then begin
		; Bark at the user if s/he prompted this save. Otherwise just
		; exit quietly.
		if n_elements( filename ) eq 0 then begin
			void = dialog_message( 'No regions. Table not saved.' )
		endif
		return
	endif

	if n_elements( filename ) eq 0 then begin
		; Prompt for file to save to.
		defBase = file_basename( (*pInfo).filename, '.txt' )
		defPath = file_dirname( (*pInfo).filename, /MARK_DIRECTORY )
		file = dialog_pickfile( /WRITE, DIALOG_PARENT=(*pInfo).wTopBase, $
				PATH=defPath, FILE=defPath+defBase+'_doseTable.txt', $
				GET_PATH=path, /OVERWRITE_PROMPT )
	endif else begin
		file = (file_search( filename ))[0]
		if file ne '' then begin
			; File already exists. Prompt for new file name.
			title = strtrim( file_basename( filename ), 2 ) $
					+ ' exists. Save as...'
			file = dialog_pickfile( DIALOG_PARENT=(*pInfo).wTopBase, $
					TITLE=title, FILE=filename, /OVERWRITE_PROMPT )
		endif else begin
			file = filename
		endelse
	endelse

	if file eq '' then return

	openw, lun, /GET_LUN, file
	printf, lun, 'Region;' + 'Description;' + 'Max annual dose (uSv);' + $
				 'Occupancy factor;' + 'Effective max annual dose (uSv);'

	eR = (*pInfo).eR

	for iR=0, nRs-1 do begin

		line = rData[eR.name,iR] + ';' $
			 + rData[eR.desc,iR] + ';' $
			 + rData[eR.maxDose,iR] + ';' $
			 + rData[eR.occ,iR] + ';' $
			 + rData[eR.effMaxDose,iR] + ';'

		printf, lun, line

	endfor

	close, lun

end ; of shielding_guiSaveDoseTable


;--------------------------------------------------------------------
;
;    PURPOSE  Save a table of the source-query point distances
;
pro shielding_guiSaveSourceQueryTable, $
	pInfo, $
	FILENAME=filename

	forward_function shielding_guiGetROIs

	; Return if we don't have any data to save
	oPRois = shielding_guiGetROIs( pInfo, /SOURCE, COUNT=nPRois, NAMES=pNames, DESC=pDescs )
	oQRois = shielding_guiGetROIs( pInfo, /QUERY, COUNT=nQRois, NAMES=qNames, DESC=qDescs )

	if (nPRois eq 0) or (nQRois eq 0) then begin
		; Bark at the user if s/he prompted this save. Otherwise just
		; exit quietly.
		if n_elements( filename ) eq 0 then begin
			void = dialog_message( 'No sources and/or query points. Table not saved.' )
		endif
		return
	endif

	if n_elements( filename ) eq 0 then begin
		; Prompt for file to save to.
		defBase = file_basename( (*pInfo).filename, '.txt' )
		defPath = file_dirname( (*pInfo).filename, /MARK_DIRECTORY )
		file = dialog_pickfile( /WRITE, DIALOG_PARENT=(*pInfo).wTopBase, $
				PATH=defPath, FILE=defPath+defBase+'_sourceQueryTable.txt', $
				GET_PATH=path, /OVERWRITE_PROMPT )
	endif else begin
		file = (file_search( filename ))[0]
		if file ne '' then begin
			; File already exists. Prompt for new file name.
			title = strtrim( file_basename( filename ), 2 ) $
					+ ' exists. Save as...'
			file = dialog_pickfile( DIALOG_PARENT=(*pInfo).wTopBase, $
					TITLE=title, FILE=filename, /OVERWRITE_PROMPT )
		endif else begin
			file = filename
		endelse
	endelse

	if file eq '' then return
	defBase = file_basename( (*pInfo).filename, '.txt' )
	defPath = file_dirname( (*pInfo).filename, /MARK_DIRECTORY )

	eP = (*pInfo).eP

	levelIndex = widget_info( (*pInfo).wLevelList, /DROPLIST_SELECT )
	case levelIndex of
		1: begin ; above
			widget_control, (*pInfo).wAboveDistText, GET_VALUE=aboveDist
			widget_control, (*pInfo).wSourceHeightText, GET_VALUE=sourceHeight
			widget_control, (*pInfo).wAboveTargetHeightText, GET_VALUE=targetHeight
			aboveDist = float(aboveDist[0])
			sourceHeight = float(sourceHeight[0])
			targetHeight = float(targetHeight[0])
			height = aboveDist - sourceHeight + targetHeight
		end
		2: begin ; below
			widget_control, (*pInfo).wBelowDistText, GET_VALUE=belowDist
			widget_control, (*pInfo).wSourceHeightText, GET_VALUE=sourceHeight
			widget_control, (*pInfo).wBelowTargetHeightText, GET_VALUE=targetHeight
			belowDist = float(belowDist[0])
			sourceHeight = float(sourceHeight[0])
			targetHeight = float(targetHeight[0])
			height = belowDist + sourceHeight - targetHeight
		end
		else: begin
			height = 0
		end
	endcase

	; Get image scale
	widget_control, (*pInfo).wFloorplanScaleText, GET_VALUE=value
	fpScale = float(value[0])

	; Get point descriptions, if they exist
	openw, lun, /GET_LUN, file
	printf, lun, ' ;' + ' ;' + strjoin( pNames, ';', /SINGLE )
	printf, lun, 'Point;' + 'Description;' + strjoin( pDescs, ';', /SINGLE )

	for iQ=0, nQRois-1 do begin

		line = qNames[iQ] + ';' + qDescs[iQ] + ';'
		oQRoi = (*pInfo).oROIGroup->getByName( qNames[iQ] )
		if not obj_valid( oQRoi ) then continue
		oQRoi->getProperty, DATA=qData
		qData *= fpScale

		for iP=0, nPRois-1 do begin

			oPRoi = (*pInfo).oROIGroup->getByName( pNames[iP] )
			if not obj_valid( oPRoi ) then continue
			oPRoi->getProperty, DATA=pData
			pData *= fpScale

			d = sqrt( (qData[0]-pData[0])^2 + (qData[1]-pData[1])^2 + height^2 )
			line = line + format_float( d ) + ';'

		endfor

		printf, lun, line

	endfor

	close, lun

end ; of shielding_guiSaveSourceQueryTable


;--------------------------------------------------------------------
;
;    PURPOSE  Save a table of the query point dose values
;
pro shielding_guiSaveQueryDoseTable, $
	pInfo, $
	FILENAME=filename

	; Return if we don't have any data to save
	oPRois = shielding_guiGetRois( pInfo, /SOURCE, COUNT=nPRois, NAMES=pNames, DESC=pDescs )
	oQRois = shielding_guiGetRois( pInfo, /QUERY, COUNT=nQRois, NAMES=qNames, DESC=qDescs )
	oRRois = shielding_guiGetRois( pInfo, /REGION, COUNT=nRRois, NAMES=rNames, DESC=rDescs )
	widget_control, (*pInfo).wRegionTable, GET_VALUE=rTable, GET_UVALUE=nRs
	eR = (*pInfo).eR

	if (nPRois eq 0) or (nQRois eq 0) then begin
		; Bark at the user if s/he prompted this save. Otherwise just
		; exit quietly.
		if n_elements( filename ) eq 0 then begin
			void = dialog_message( 'No sources and/or query points. Table not saved.' )
		endif
		return
	endif

	if n_elements( filename ) eq 0 then begin
		; Prompt for file to save to.
		defBase = file_basename( (*pInfo).filename, '.txt' )
		defPath = file_dirname( (*pInfo).filename, /MARK_DIRECTORY )
		file = dialog_pickfile( /WRITE, DIALOG_PARENT=(*pInfo).wTopBase, $
				PATH=defPath, FILE=defPath+defBase+'_queryDoseTable.txt', $
				GET_PATH=path, /OVERWRITE_PROMPT )
	endif else begin
		file = (file_search( filename ))[0]
		if file ne '' then begin
			; File already exists. Prompt for new file name.
			title = strtrim( file_basename( filename ), 2 ) $
					+ ' exists. Save as...'
			file = dialog_pickfile( DIALOG_PARENT=(*pInfo).wTopBase, $
					TITLE=title, FILE=filename, /OVERWRITE_PROMPT )
		endif else begin
			file = filename
		endelse
	endelse

	if file eq '' then return

	openw, lun, /GET_LUN, file
	printf, lun, 'Point;' + 'Description;' + 'Max annual dose (uSv);' + $
				 'Occupancy factor;' + 'Effective max annual dose (uSv);'

	for iQ=0, nQRois-1 do begin

		; Get dose at query point from dose map
		oQRoi = (*pInfo).oROIGroup->getByName( qNames[iQ] )
		if not obj_valid( oQRoi ) then continue
		oQRoi->getProperty, DATA=qData
		dose = (*(*pInfo).pSeries1)[qData[0],qData[1]]

		; Get occupancy factor at query point from region table
		occ = 1.0
		for iR=0, nRRois-1 do begin
			oRRoi = (*pInfo).oROIGroup->getByName( rNames[iR] )
			if not obj_valid( oRRoi ) then continue
			bContained = oRRoi->containsPoints( qData[0], qData[1] )
			if bContained then begin
				rIndex = where( rTable[eR.name,*] eq rNames[iR], count )
				if count eq 0 then continue
				occ = float(rTable[eR.occ,rIndex])
				break
			endif
		endfor

		; Calc max effective dose
		effDose = dose * occ

		line = qNames[iQ] + ';' $
			 + qDescs[iQ] + ';' $
			 + strtrim( dose, 2 ) + ';' $
			 + strtrim( occ, 2 ) + ';' $
			 + strtrim( effDose, 2 ) + ';'

		printf, lun, line

	endfor

	close, lun

end ; of shielding_guiSaveQueryDoseTable


;--------------------------------------------------------------------
;
;    PURPOSE  Save the shield table
;
pro shielding_guiSaveShieldTable, pInfo

	; Return if we don't have any data to save
	widget_control, (*pInfo).wShieldTable, GET_VALUE=sData, GET_UVALUE=nSs
	if nSs eq 0 then begin
		; Bark at the user if s/he prompted this save. Otherwise just
		; exit quietly.
		if n_elements( filename ) eq 0 then begin
			void = dialog_message( 'No shields. Table not saved.' )
		endif
		return
	endif

	if n_elements( filename ) eq 0 then begin
		; Prompt for file to save to.
		defBase = file_basename( (*pInfo).filename, '.txt' )
		defPath = file_dirname( (*pInfo).filename, /MARK_DIRECTORY )
		file = dialog_pickfile( /WRITE, DIALOG_PARENT=(*pInfo).wTopBase, $
				PATH=defPath, FILE=defPath+defBase+'_shieldTable.txt', $
				GET_PATH=path, /OVERWRITE_PROMPT )
	endif else begin
		file = (file_search( filename ))[0]
		if file ne '' then begin
			; File already exists. Prompt for new file name.
			title = strtrim( file_basename( filename ), 2 ) $
					+ ' exists. Save as...'
			file = dialog_pickfile( DIALOG_PARENT=(*pInfo).wTopBase, $
					TITLE=title, FILE=filename, /OVERWRITE_PROMPT )
		endif else begin
			file = filename
		endelse
	endelse

;	if file eq '' then return
;
;	openw, lun, /GET_LUN, file
;	printf, lun, 'Structure;' + 'Description;' + 'Material;' + 'Thickness;'
;
;	eS = (*pInfo).eS
;
;	for iS=0, nSs-1 do begin
;
;		line = sData[eS.name,iS] + ';' $
;			 + sData[eS.desc,iS] + ';' $
;			 + sData[eS.material,iS] + ';' $
;			 + sData[eS.thickness,iS] + ';'
;
;		printf, lun, line
;
;	endfor

	if file eq '' then return

	openw, lun, /GET_LUN, file

	if (*pInfo).modality eq 'PET' then begin
		headings = 'Structure;' + 'Description;' + 'Material;' + 'Thickness;' $
				 + 'Transmission factor;' $
				 + 'x1;' + 'y1;' + 'x2;' + 'y2;' + 'h1;' + 'h2;'
	endif else begin
		headings = 'Structure;' + 'Description;' + 'Material;' + 'Thickness;' $
				 + 'x1;' + 'y1;' + 'x2;' + 'y2;' + 'h1;' + 'h2;'
	endelse

	printf, lun, headings

	eS = (*pInfo).eS

	for iS=0, nSs-1 do begin

		if (*pInfo).modality eq 'PET' then begin
			TF = shielding_guiCalculateTF( (*pInfo).modality, $
					sData[eS.material,iS], sData[eS.thickness,iS], 511 )
			line = sData[eS.name,iS] + ';' $
				 + sData[eS.desc,iS] + ';' $
				 + sData[eS.material,iS] + ';' $
				 + sData[eS.thickness,iS] + ';' $
				 + strtrim(TF,2) + ';' $
				 + sData[eS.x1,iS] + ';' $
				 + sData[eS.y1,iS] + ';' $
				 + sData[eS.x2,iS] + ';' $
				 + sData[eS.y2,iS] + ';' $
				 + sData[eS.h1,iS] + ';' $
				 + sData[es.h2,iS] + ';'
		endif else begin
			line = sData[eS.name,iS] + ';' $
				 + sData[eS.desc,iS] + ';' $
				 + sData[eS.material,iS] + ';' $
				 + sData[eS.thickness,iS] + ';' $
				 + sData[eS.x1,iS] + ';' $
				 + sData[eS.y1,iS] + ';' $
				 + sData[eS.x2,iS] + ';' $
				 + sData[eS.y2,iS] + ';' $
				 + sData[eS.h1,iS] + ';' $
				 + sData[es.h2,iS] + ';'
		endelse

		printf, lun, line

	endfor

	close, lun

end ; of shielding_guiSaveShieldTable


;--------------------------------------------------------------------
;
;    PURPOSE  Save the horizontal shield table
;
pro shielding_guiSaveHShieldTable, $
	pInfo, $
	FILENAME=filename

	; Return if we don't have any data to save
	widget_control, (*pInfo).wHShieldTable, GET_VALUE=hData, GET_UVALUE=nHs
	if nHs eq 0 then begin
		; Bark at the user if s/he prompted this save. Otherwise just
		; exit quietly.
		if n_elements( filename ) eq 0 then begin
			void = dialog_message( 'No horizontal shields. Table not saved.' )
		endif
		return
	endif

	if n_elements( filename ) eq 0 then begin
		; Prompt for file to save to.
		defBase = file_basename( (*pInfo).filename, '.txt' )
		defPath = file_dirname( (*pInfo).filename, /MARK_DIRECTORY )
		file = dialog_pickfile( /WRITE, DIALOG_PARENT=(*pInfo).wTopBase, $
				PATH=defPath, FILE=defPath+defBase+'_hShieldTable.txt', $
				GET_PATH=path, /OVERWRITE_PROMPT )
	endif else begin
		file = (file_search( filename ))[0]
		if file ne '' then begin
			; File already exists. Prompt for new file name.
			title = strtrim( file_basename( filename ), 2 ) $
					+ ' exists. Save as...'
			file = dialog_pickfile( DIALOG_PARENT=(*pInfo).wTopBase, $
					TITLE=title, FILE=filename, /OVERWRITE_PROMPT )
		endif else begin
			file = filename
		endelse
	endelse

	if file eq '' then return

	openw, lun, /GET_LUN, file

	if (*pInfo).modality eq 'PET' then begin
		headings = 'Structure;' + 'Description;' + 'Material;' + 'Thickness;' $
			+ 'Transmission factor;' $
			+ 'x1;' + 'y1;' + 'x2;' + 'y2;' + 'x3;' + 'y3;' + 'x4;' + 'y4;' + 'Height;'
	endif else begin
		headings = 'Structure;' + 'Description;' + 'Material;' + 'Thickness;' $
			+ 'x1;' + 'y1;' + 'x2;' + 'y2;' + 'x3;' + 'y3;' + 'x4;' + 'y4;' + 'Height;'
	endelse

	printf, lun, headings

	eH = (*pInfo).eH

	for iH=0, nHs-1 do begin

		if (*pInfo).modality eq 'PET' then begin
			TF = shielding_guiCalculateTF( (*pInfo).modality, $
					hData[eH.material,iH], hData[eH.thickness,iH], 511 )
			line = hData[eH.name,iH] + ';' $
				 + hData[eH.desc,iH] + ';' $
				 + hData[eH.material,iH] + ';' $
				 + hData[eH.thickness,iH] + ';' $
				 + strtrim(TF,2) + ';' $
				 + hData[eH.x1,iH] + ';' $
				 + hData[eH.y1,iH] + ';' $
				 + hData[eH.x2,iH] + ';' $
				 + hData[eH.y2,iH] + ';' $
				 + hData[eH.x3,iH] + ';' $
				 + hData[eH.y3,iH] + ';' $
				 + hData[eH.x4,iH] + ';' $
				 + hData[eH.y4,iH] + ';' $
				 + hData[eH.h,iH] + ';'
		endif else begin
			line = hData[eH.name,iH] + ';' $
				 + hData[eH.desc,iH] + ';' $
				 + hData[eH.material,iH] + ';' $
				 + hData[eH.thickness,iH] + ';' $
				 + hData[eH.x1,iH] + ';' $
				 + hData[eH.y1,iH] + ';' $
				 + hData[eH.x2,iH] + ';' $
				 + hData[eH.y2,iH] + ';' $
				 + hData[eH.x3,iH] + ';' $
				 + hData[eH.y3,iH] + ';' $
				 + hData[eH.x4,iH] + ';' $
				 + hData[eH.y4,iH] + ';' $
				 + hData[eH.h,iH] + ';'
		endelse

		printf, lun, line

	endfor

	close, lun

end ; of shielding_guiSaveHShieldTable


;--------------------------------------------------------------------
;
;    PURPOSE  Save the ROI data
;
pro shielding_guiSaveROIs, $
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
		oROIs = shielding_guiGetROIs( pInfo, /SOURCE, COUNT=nROIs )
	endif else if keyword_set( shield ) then begin
		type = 'shield'
		prefix = 'S'
		widget = (*pInfo).wShieldTable
		oROIs = shielding_guiGetROIs( pInfo, /SHIELD, COUNT=nROIs )
	endif else if keyword_set( hShield ) then begin
		type = 'hshield'
		prefix = 'H'
		widget = (*pInfo).wHShieldTable
		oROIs = shielding_guiGetROIs( pInfo, /HSHIELD, COUNT=nROIs )
	endif else if keyword_set( region ) then begin
		type = 'region'
		prefix = 'R'
		widget = (*pInfo).wRegionTable
		oROIs = shielding_guiGetROIs( pInfo, /REGION, COUNT=nROIs )
	endif else if keyword_set( query ) then begin
		type = 'query'
		prefix = 'Q'
		oROIs = shielding_guiGetROIs( pInfo, /QUERY, COUNT=nROIs )
	endif else begin
		return
	endelse

	; Make sure we have ROIs of this type to save
	if nROIs eq 0 then begin
		void = dialog_message( 'No ' +type+ ' ROIs to save. Returning.', /ERROR )
	endif

	; Prompt user for file to save to
	defBase = file_basename( (*pInfo).filename )
	defBase = (strsplit( defBase, '.', /EXTRACT ))[0]
	defPath = file_dirname( (*pInfo).filename, /MARK_DIRECTORY )

	file = dialog_pickfile( /WRITE, DIALOG_PARENT=(*pInfo).wTopBase, $
			PATH=defPath , FILE=defPath+defBase+type+'_rois.sav', $
			/OVERWRITE_PROMPT )
	if file eq '' then return

	; Create a temporary ROI group and an array of symbol objects
	oROIGroup = obj_new( 'IDLgrModel' )
;	allNames = data[0,0:uVal-1]
;	names = allNames[uniq( allNames, sort(allNames))]
;	void = where( names ne '', nROIs )
	oSymArray = objarr( nROIs )

	for iROI=0, nROIs-1 do begin
		oROIs[iROI]->getProperty, NAME=name, DATA=coords, DESC=desc, COLOR=color, SYMBOL=oSym
		oCopyROI = obj_new( 'IDLgrROI', NAME=name, DATA=coords, DESC=desc, COLOR=color )
		oROIGroup->add, oCopyROI
		if obj_valid( oSym ) then oSymArray[iROI] = oSym
	endfor

	; Get current image info
	widget_control, (*pInfo).wFloorplanScaleText, GET_VALUE=value
	fpScale = float(value[0])
	nPx = (*pInfo).nPx
	nPy = (*pInfo).nPy

	; Save ROI objects, symbol array, table data (if non-Q) and image info
	if prefix ne 'Q' then begin
		widget_control, widget, GET_VALUE=data, GET_UVALUE=uVal
		save, oROIGroup, oSymArray, data, uVal, $
				nPx, nPy, fpScale, FILENAME=file
	endif else begin
		save, oROIGroup, oSymArray, $
				nPx, nPy, fpScale, FILENAME=file
	endelse

	; Destroy temporary ROI group
	obj_destroy, oROIGroup

end ; of shielding_guiSaveROIs


;--------------------------------------------------------------------
;
;    PURPOSE  Save the final dose image
;
pro shielding_guiSaveDoseImage, pInfo

	defBase = file_basename( (*pInfo).filename, '.img' )
	defPath = file_dirname( (*pInfo).filename, /MARK_DIRECTORY )

	file = dialog_pickfile( /WRITE, DIALOG_PARENT=(*pInfo).wTopBase, $
			PATH=defPath, FILE=defPath+defBase+'.img', $
			GET_PATH=path, /OVERWRITE_PROMPT )

	if file ne '' then begin

		; Write image
		openw, lun, /GET_LUN, file
		writeu, lun, (*pInfo).pSeries1
		close, lun

		; Write header
		textFile = path+defBase+'_info.txt'

		openw, lun, /GET_LUN, textFile
		printf, lun, "Image Info"
		printf, lun, "=========="
		printf, lun, "nPx = ", strtrim( (*pInfo).nPx, 2 )
		printf, lun, "nPy = ", strtrim( (*pInfo).nPy, 2 )
		printf, lun, "pixSizeX (mm) = ", strtrim( (*pInfo).pixSizeX, 2 )
		printf, lun, "pixSizeY (mm) = ", strtrim( (*pInfo).pixSizeY, 2 )
		close, lun

	endif else begin

			blah = dialog_message( 'Dose image not saved' )

	endelse

end ; of shielding_guiSaveDoseImage


;--------------------------------------------------------------------
;
;    PURPOSE  Save the entire session
;
pro shielding_guiSaveSession, pInfo, FILENAME=file

	if n_elements(file) eq 0 then begin

		; Save everything
		defBase = file_basename( (*pInfo).filename )
		defBase = (strsplit( defBase, '.', /EXTRACT ))[0]
		defPath = file_dirname( (*pInfo).filename, /MARK_DIRECTORY )

		file = dialog_pickfile( /WRITE, DIALOG_PARENT=(*pInfo).wTopBase, $
				PATH=defPath , FILE=defPath+defBase+'_session.sav', $
				/OVERWRITE_PROMPT )

	endif

	if file ne '' then begin

		; Get ROIs and their symbol objects
		oROIGroup = (*pInfo).oROIGroup
		if obj_valid( oROIGroup ) then begin
			oROIs = oROIGroup->get( /ALL, COUNT=nROIs )
			if nROIs gt 0 then begin
				oSymArray = objarr( nROIs )
				for iROI=0, nROIs-1 do begin
					oROIs[iROI]->getProperty, SYMBOL=oSym
					if obj_valid( oSym ) then oSymArray[iROI] = oSym
				endfor
			endif
		endif

		; Get ROI table data
		widget_control, (*pInfo).wShieldTable, GET_VALUE=sData, GET_UVALUE=sUVal
		widget_control, (*pInfo).wHShieldTable, GET_VALUE=hData, GET_UVALUE=hUVal
		widget_control, (*pInfo).wSourceTable, GET_VALUE=pData, GET_UVALUE=pUVal
		widget_control, (*pInfo).wRegionTable, GET_VALUE=rData, GET_UVALUE=rUVal

		; Get current scales
		widget_control, (*pInfo).wFloorplanScaleText, GET_VALUE=fpScaleText
		widget_control, (*pInfo).wDosemapScaleText, GET_VALUE=dmScaleText

		; Get images
		series0 = *(*pInfo).pSeries0
		series1 = *(*pInfo).pSeries1

		; Get floor above/below GUI info
		levelIndex = widget_info( (*pInfo).wLevelList, /DROPLIST_SELECT )
		widget_control, (*pInfo).wShieldHeightText, GET_VALUE=shieldHeight
		widget_control, (*pInfo).wAboveDistText, GET_VALUE=aboveDist
		widget_control, (*pInfo).wAboveThickText, GET_VALUE=aboveThick
		widget_control, (*pInfo).wBoxPointText, GET_VALUE=boxPoint
		widget_control, (*pInfo).wBoxThickText, GET_VALUE=boxThick
		widget_control, (*pInfo).wBelowDistText, GET_VALUE=belowDist
		widget_control, (*pInfo).wBelowThickText, GET_VALUE=belowThick
		widget_control, (*pInfo).wSourceHeightText, GET_VALUE=sourceHeight
		widget_control, (*pInfo).wAboveTargetHeightText, GET_VALUE=aboveTargetHeight
		widget_control, (*pInfo).wBelowTargetHeightText, GET_VALUE=belowTargetHeight

		save, FILENAME=file, $
				oROIGroup, oSymArray, $
				sData, sUVal, hData, hUVal, pData, pUVal, rData, rUVal, $
				series0, series1, fpScaleText, dmScaleText, $
				levelIndex, shieldHeight, aboveDist, aboveThick, $
				boxPoint, boxThick, belowDist, belowThick, $
				sourceHeight, aboveTargetHeight, belowTargetHeight

	endif else begin

		blah = dialog_message( 'Session not saved' )

	endelse

end ; of shielding_guiSaveSession

