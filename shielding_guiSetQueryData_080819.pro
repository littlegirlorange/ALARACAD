;--------------------------------------------------------------------
;
;    PURPOSE  Get/set query point data
;
pro shielding_guiSetQueryData, $
	pInfo, $
	oROI, $
	PROMPT=prompt, $
	DESCRIPTION=desc

	@'shielding_gui_shield_specs'
	modality = (*pInfo).modality
	if modality eq 'PET' then begin
		@'shielding_gui_PET_tracer_specs'
	endif else begin
		@'shielding_gui_SPECT_tracer_specs'
	endelse

	if not obj_valid( oROI ) then return
	oROI->getProperty, NAME=qName, DATA=qData
	if qName eq '' then return

	; Convert ROI coords from pixel values to m values
	widget_control, (*pInfo).wFloorplanScaleText, GET_VALUE=value
	fpScale = float(value[0])
	x = qData[0]*fpScale
	y = qData[1]*fpScale

	if n_elements( desc ) eq 0 then desc = ''

	if keyword_set( prompt ) then begin

		labels = ['x coord (m): ', $
				  'y coord (m): ', $
				  'Description: ']
		values = [strtrim( x, 2 ), $
				  strtrim( y, 2 ), $
				  '']

		text = textBox( $
			   GROUP_LEADER=(*pInfo).wTopBase, $
			   TITLE='Set query point specifications', $
			   LABEL=labels, $
			   VALUE=values, $
			   CANCEL=bCancel )

		if not bCancel then begin

			x = float(text[0])
			y = float(text[1])
			desc = text[2]

			; Update the displayed ROI
			qData[0] = x/fpScale
			qData[1] = y/fpScale

			oROIGroup = (*pInfo).oROIGroup
			bContained = oROIGroup->isContained( oROI, POSITION=pos )
			oDispROI = (*pInfo).oDispROIGroup->get( POSITION=pos )
			oROI->setProperty, DATA=qData
			oDispROI->setProperty, DATA=qData
			(*pInfo).oWindow->draw, (*pInfo).oViewGroup

		endif else begin
			desc = ''
		endelse

	endif

	; Add text to widget
	text = qName + ' (' + strtrim(x,2) + 'm, ' $
		 + strtrim(y,2) + 'm)'
	widget_control, (*pInfo).wQueryText, SET_VALUE=text, /APPEND
	text = '  Description: ' + desc
	widget_control, (*pInfo).wQueryText, SET_VALUE=text, /APPEND

	; Determine the number of sources and shields we're working with
	pPoints = 0
	shieldNames = 0
	shieldMaterials = 0
	shieldThicknesses = 0
	shieldPoints = 0
	nPoints = 0
	nShields = 0
	nHShields = 0

	eP = (*pInfo).eP
	widget_control, (*pInfo).wSourceTable, GET_VALUE=pTable
	row = (where( pTable[0,*] eq '', count ))[0]-1

	eS = (*pInfo).eS
	widget_control, (*pInfo).wShieldTable, GET_VALUE=sTable
	row = (where( sTable[0,*] eq '', count ))[0]-1
	if (count ne 0) and (row ge 0 ) then begin
		shieldNames	= sTable[eS.name,0:row]
		shieldMaterials	= sTable[eS.material,0:row]
		shieldThicknesses	= float(sTable[eS.thickness,0:row])
		nShields		= row+1
	endif

	eH = (*pInfo).eH
	widget_control, (*pInfo).wHShieldTable, GET_VALUE=hTable
	row = (where( hTable[0,*] eq '', count ))[0]-1
	if (count ne 0) and (row ge 0) then nHShields = row+1

	; Get transmission factor for concrete floor/ceiling
	levelIndex = widget_info( (*pInfo).wLevelList, /DROPLIST_SELECT )

	case levelIndex of

		1: begin ; above

			; Vertical distance from floor to top of wall shielding
			widget_control, (*pInfo).wShieldHeightText, GET_VALUE=value
			height = float(value[0])

			; Vertical distance from source to point above (assume source
			; is 1 m above floor and point above is 0.5 m above floor)
			widget_control, (*pInfo).wAboveDistText, GET_VALUE=aboveDist
			widget_control, (*pInfo).wSourceHeightText, GET_VALUE=sourceHeight
			widget_control, (*pInfo).wAboveTargetHeightText, GET_VALUE=targetHeight
			aboveDist = float(aboveDist[0])
			sourceHeight = float(sourceHeight[0])
			targetHeight = float(targetHeight[0])
			dist = aboveDist - sourceHeight + targetHeight
			sourceDist = sourceHeight
			targetDist = aboveDist + targetHeight

			; Floor/ceiling concrete slab thickness
			widget_control, (*pInfo).wAboveThickText, GET_VALUE=value
			dFloor = float(value[0])

			; Shielded container information
			widget_control, (*pInfo).wBoxPointText, GET_VALUE=value
			boxPoint = value[0]
			if boxPoint ne '' then begin
				index = where( pTable[0,*] eq boxPoint, count )
				if count eq 0 then begin
					void = dialog_message( /WARNING, 'Box point not found. Returning.' )
					return
				endif
				widget_control, (*pInfo).wBoxThickText, GET_VALUE=value
				dBox = float(value[0])
			endif else begin
				dBox = 0
			endelse

		end

		2: begin ; below

			; Vertical distance from source to point below (assume source
			; is 1 m above floor and point below is 1.7 m above floor)
			widget_control, (*pInfo).wBelowDistText, GET_VALUE=belowDist
			widget_control, (*pInfo).wSourceHeightText, GET_VALUE=sourceHeight
			widget_control, (*pInfo).wBelowTargetHeightText, GET_VALUE=targetHeight
			belowDist = float(belowDist[0])
			sourceHeight = float(sourceHeight[0])
			targetHeight = float(targetHeight[0])
			dist = belowDist + sourceHeight - targetHeight
			sourceDist = sourceHeight
			targetDist = -belowDist + targetHeight

			; Floor/ceiling concrete slab thickness
			widget_control, (*pInfo).wBelowThickText, GET_VALUE=value
			dFloor = float(value[0])

			; Shielded container information
			widget_control, (*pInfo).wBoxPointText, GET_VALUE=value
			boxPoint = value[0]
			if boxPoint ne '' then begin
				index = where( pTable[0,*] eq boxPoint, count )
				if count eq 0 then begin
					void = dialog_message( /WARNING, 'Box point not found. Returning.' )
					return
				endif
				widget_control, (*pInfo).wBoxThickText, GET_VALUE=value
				dBox = float(value[0])
			endif else begin
				dBox = 0
			endelse

		end

		else: begin

			dist = 0.0
			dFloor = 0.0

			; Shielded container information
			widget_control, (*pInfo).wBoxPointText, GET_VALUE=value
			boxPoint = value[0]
			if boxPoint ne '' then begin
				index = where( pTable[0,*] eq boxPoint, count )
				if count eq 0 then begin
					void = dialog_message( /WARNING, 'Box point not found. Returning.' )
					return
				endif
				widget_control, (*pInfo).wBoxThickText, GET_VALUE=value
				dBox = float(value[0])
			endif else begin
				dBox = 0
			endelse

		end
	endcase

	; Calculate floor/ceiling and box transmission factors
	TFFloorTable = make_array( n_elements(tracers), /FLOAT, VALUE=1.0  )
	TFBoxTable = make_array( n_elements(tracers), /FLOAT, VALUE=1.0 )

	if ((levelIndex gt 0) and (dFloor ne 0)) or (dBox ne 0) then begin ; above or below

		for iTracer=0, n_elements(tracers)-1 do begin

			tracer = tracers[iTracer]

			TFFloor = 1.0
			TFBox = 1.0

			if (levelIndex gt 0) and (dFloor ne 0) then begin
				; Calculate the attenuation factor using equation from
				; AAPM Task Group 108 (Madsen et al, 2006)
				TFFloor = shielding_guiCalculateTF( modality, tracer, 'Concrete', dFloor )
			endif

			if dBox ne 0 then begin
				TFBox = shielding_guiCalculateTF( modality, tracer, 'Lead', dBox )
			endif

			TFFloorTable[iTracer] = TFFloor
			TFBoxTable[iTracer] = TFBox

		endfor ; all tracers

	endif

	oROIGroup = (*pInfo).oROIGroup
	nROIs = 0
	if obj_valid( oROIGroup ) then begin
		oROIs = oROIGroup->get( /ALL, COUNT=nROIs )
	endif

	typeArray = strarr( nROIs )
	nameArray = strarr( nROIs )
	dataArray = fltarr( 8, nROIs )

	for iROI=0, nROIs-1 do begin
		oROIs[iROI]->getProperty, NAME=name, STYLE=style, DATA=data
		prefix = (strsplit( name, '_', /EXTRACT ))[0]
		typeArray[iROI] = prefix
		nameArray[iROI] = name
		if prefix eq 'P' then begin
			dataArray[0,iROI] = reform( data[[0,1]] )
		endif else if prefix eq 'S' then begin
			dataArray[0,iROI] = reform( data[[0,1,3,4]] )
		endif else if prefix eq 'H' then begin
			dataArray[0,iROI] = reform( data[[0,1,3,4,6,7]] )
		endif
	end

	pIndices = where( typeArray eq 'P', nPs )
	sIndices = where( typeArray eq 'S', nSs )
	hIndices = where( typeArray eq 'H', nHs )

	totShieldedDose = 0.0
	totUnshieldedDose = 0.0

	for iP=0, nPs-1 do begin

		pName = nameArray[pIndices[iP]]
		pData = dataArray[*,pIndices[iP]]
		pData *= fpScale

		pRows = where( pTable[0,*] eq pName, nPRows )

		if nPRows gt 0 then begin

			pqFloorDist = sqrt( ( x - pData[0] )^2 + $
								( y - pData[1] )^2 )
			pqDist = sqrt( ( x - pData[0] )^2 + $
						   ( y - pData[1] )^2 + dist^2 )

			; See if the line intersects any shields
			if nShields gt 0 then begin

				bIntersects = bytarr( nShields )

				for iS=0, nSs-1 do begin

					sName = nameArray[sIndices[iS]]
					sData = dataArray[*,sIndices[iS]]
					sData *= fpScale

					retVal = shielding_guiLinesIntersect( $
							[[x,y],[pData[0],pData[1]]], $
							[[sData[0],sData[1]],[sData[2],sData[3]]] )

					if retVal ne 0 then begin ; Lines intersect

						case levelIndex of

							0: begin	; current level
								; Remember this structure
								bIntersects[where( shieldNames eq sName, count )] = 1b
								end
							1: begin	; floor above
								coords = shielding_guiGetIntersect( $
										[[pData[0],pData[1]],[x,y]], $
										[[sData[0],sData[1]],[sData[2],sData[3]]] )

								psFloorDist = sqrt( (coords[0]-pData[0])^2 + $
												   (coords[1]-pData[1])^2 )

								h = psFloorDist * dist / pqFloorDist

								; Assume the source is 1 m above the ground
								row = where( shieldNames eq sName )
								if h lt (float(sTable[eS.h2,row])-sourceHeight) then begin ; Lines intersect
									; Remember this structure
									bIntersects[row] = 1b
								endif
								end
							2: begin	; floor below
								coords = shielding_guiGetIntersect( $
										[[pData[0],pData[1]],[x,y]], $
										[[sData[0],sData[1]],[sData[2],sData[3]]] )

								psFloorDist = sqrt( (coords[0]-pData[0])^2 + $
											   (coords[1]-pData[1])^2 )

								h = psFloorDist * dist / pqFloorDist

								; Assume the source is 1 m above the ground
								row = where( shieldNames eq sName )
								if h lt (sourceHeight-float(sTable[eS.h1,row])) then begin ; Lines intersect
									; Remember this structure
									bIntersects[row] = 1b
								endif
								end
							else:
						endcase

					endif

				endfor

				sRows = where( bIntersects eq 1b, nSRows )

			endif else begin

				nSRows = 0

			endelse

			for iPRow=0, nPRows-1 do begin

				; Get values from imaging table
				tracerName 	= pTable[eP.tracer,pRows[iPRow]]
				tIndex = (where( tracers.name eq tracerName, count ))[0]

				if count ne 0 then begin

					tracer = (tracers[tIndex])[0]

					A0		= float( pTable[eP.A0,pRows[iPRow]] )		; admin. activity (GBq)
					TU		= float( pTable[eP.TU,pRows[iPRow]] )/60.0	; uptake time (h)
					TI		= float( pTable[eP.TI,pRows[iPRow]] )/60.0	; imaging time (h)
					NA		= float( pTable[eP.NA,pRows[iPRow]] )		; no. patients/year
					PV		= float( pTable[eP.PV,pRows[iPRow]] )		; patient voiding (%)
					SS		= float( pTable[eP.SS,pRows[iPRow]] )		; scanner shielding (%)

					; Half-life (h)
					HL = tracer.hl
					; Dose reduction factor over imaging time
					RI = 1.443 * (HL/TI) * (1-exp(-0.693*TI/HL))
					; Uptake time decay factor
					FU = exp(-0.693*TU/HL)

					unshieldedDose = tracer.der * NA * A0 * (1.0-PV/100.0) * (1.0-SS/100.0) * FU * TI * RI / (pqDist^2)
					totUnshieldedDose += unshieldedDose

					; Add to text widget
					text = '  ' + pTable[eP.name,pRows[iPRow]] $
						 + ' (' + pTable[eP.x,pRows[iPRow]] + 'm, ' + pTable[eP.y,pRows[iPRow]] + 'm), ' $
						 + pTable[eP.tracer,pRows[iPRow]] + ', ' $
						 + 'A0 (GBq) = ' + pTable[eP.A0,pRows[iPRow]] + ', ' $
						 + 'T1 (min) = ' + pTable[eP.TU,pRows[iPRow]] + ', ' $
						 + 'T2 (min) = ' + pTable[eP.TI,pRows[iPRow]] + ', ' $
						 + 'NA (pat/a) = ' + pTable[eP.NA,pRows[iPRow]]
					widget_control, (*pInfo).wQueryText, SET_VALUE=text, /APPEND
					text = '    Description: ' + pTable[eP.desc,pRows[iPRow]]
					widget_control, (*pInfo).wQueryText, SET_VALUE=text, /APPEND
					text = '    Distance from ' + qName + ' (m) = ' + strtrim(pqDist,2)
					widget_control, (*pInfo).wQueryText, SET_VALUE=text, /APPEND
					text = '    Dose, unshielded (uSv/a) = ' + strtrim(unshieldedDose,2)
					widget_control, (*pInfo).wQueryText, SET_VALUE=text, /APPEND

					TFTotal = 1.0

					; Calculate attenuation due to floor/ceiling
					if levelIndex gt 0 then begin

						; Floor above/below
						if levelIndex eq 1 then begin
							floor='Ceiling concrete slab'
							adj='above'
						endif else if levelIndex eq 2 then begin
							floor='Floor concrete slab'
							adj = 'below'
						endif
						text = '    ' + floor $
			 				 + ' (' + strtrim(dist,2) + ' m ' + adj + ', ' $
			 				 + strtrim(dFloor,2) + ' cm thick)'
						widget_control, (*pInfo).wQueryText, SET_VALUE=text, /APPEND

						if modality eq 'PET' then begin
							TFFloor = shielding_guiCalculateTF( modality, tracer, 'Concrete', dFloor )
						endif else begin ; 'SPECT'
							TFFloor = shielding_guiCalculateTF( modality, tracer, 'Concrete', dFloor, $
									ES=es, FRACTIONS=fracs, MUMS=mums, AFS=afs, BFS=bfs )
							; Add to text widget
							for iE=0, n_elements(es)-1 do begin
								text = '      ' + strtrim(es[iE],2) + ' keV gammas (' $
									 + strtrim(fracs[iE]*100,2) + '%), ' $
									 + 'mu_m (cm^2/g) = ' + strtrim(mums[iE],2) $
									 + ', AF = ' + strtrim(afs[iE],2) + $
									   ', BF = ' + strtrim(bfs[iE],2)
								widget_control, (*pInfo).wQueryText, SET_VALUE=text, /APPEND
							endfor
						endelse ; modality

						; Add to text widget
						text = '      TF = ' + strtrim(TFFloor,2)
						widget_control, (*pInfo).wQueryText, SET_VALUE=text, /APPEND

						TFTotal *= TFFloor

						; Account for other horizontal (floor/ceiling) shielding
						for iH=0, nHShields-1 do begin

							hData = dataArray[*,hIndices[iH]] * fpScale
							p1 = [pData[0], pData[1], sourceDist]
							p2 = [x, y, targetDist]
							v1 = [hData[0], hData[1], hTable[eH.h, iH]]
							v2 = [hData[2], hData[3], hTable[eH.h, iH]]
							v3 = [hData[4], hData[5], hTable[eH.h, iH]]
							bIntersects = shielding_guiPlaneIntersect( p1, p2, v1, v2, v3 )

							if bIntersects then begin

								name = hTable[eH.name, iH]
								material = hTable[eH.material, iH]
								height = hTable[eH.h, iH]
								d = hTable[eH.thickness, iH]

								text = '    ' + name $
					 				 + ' (' + strtrim(height,2) + ' m above ground, ' $
					 				 + strtrim(d,2) + ' cm thick)'
								widget_control, (*pInfo).wQueryText, SET_VALUE=text, /APPEND

								if modality eq 'PET' then begin
									TF = shielding_guiCalculateTF( modality, tracer, material, d )
								endif else begin ; 'SPECT'
									TF = shielding_guiCalculateTF( modality, tracer, material, d, $
											ES=es, FRACTIONS=fracs, MUMS=mums, AFS=afs, BFS=bfs )
									for iE=0, n_elements(es)-1 do begin
										text = '      ' + strtrim(es[iE],2) + ' keV gammas (' $
											 + strtrim(fracs[iE]*100,2) + '%), ' $
											 + 'mu_m (cm^2/g) = ' + strtrim(mums[iE],2) $
											 + ', AF = ' + strtrim(afs[iE],2) + $
											   ', BF = ' + strtrim(bfs[iE],2)
										widget_control, (*pInfo).wQueryText, SET_VALUE=text, /APPEND
									endfor
								endelse

								text = '      TF = ' + strtrim(TF,2)
								widget_control, (*pInfo).wQueryText, SET_VALUE=text, /APPEND

								TFTotal *= TF

							endif ; bIntersects

						endfor ; nHShields-1

					endif ; floor above or floor below

					; Account for shielded box
					if (dBox ne 0) and (boxPoint eq pTable[eP.name,pRows[iPRow]]) then begin

						text = '    Lead container (' $
				 			 + strtrim(dBox,2) + ' cm thick)'
						widget_control, (*pInfo).wQueryText, SET_VALUE=text, /APPEND

						if modality eq 'PET' then begin
							TFBox = shielding_guiCalculateTF( modality, tracer, 'Lead', dBox )
						endif else begin ;SPECT
							TFBox = shielding_guiCalculateTF( modality, tracer, 'Lead', dBox, $
									ES=es, FRACTIONS=fracs, MUMS=mums, AFS=afs, BFS=bfs )
							for iE=0, n_elements(es)-1 do begin
								text = '      ' + strtrim(es[iE],2) + ' keV gammas (' $
									 + strtrim(fracs[iE]*100,2) + '%), ' $
									 + 'mu_m (cm^2/g) = ' + strtrim(mums[iE],2) $
									 + ', AF = ' + strtrim(afs[iE],2) + $
									   ', BF = ' + strtrim(bfs[iE],2)
								widget_control, (*pInfo).wQueryText, SET_VALUE=text, /APPEND
							endfor
						endelse

						; Add to text widget
						text = '      TF = ' + strtrim(TFBox,2)
						widget_control, (*pInfo).wQueryText, SET_VALUE=text, /APPEND

						TFTotal *= TFBox

					endif ; there's a box

					for iSRow=0, nSRows-1 do begin

						material = shieldMaterials[sRows[iSRow]]
						d = shieldThicknesses[sRows[iSRow]]
						i = where( materials eq material, count )

						; Add to text widget
						eS = (*pInfo).eS
						text = '    ' + sTable[eS.name,sRows[iSRow]] $
			 				 + ' ([' + strtrim(sData[0],2) + 'm, ' + strtrim(sData[1],2) + 'm], [' $
			 				 + strtrim(sData[2],2) + 'm, ' + strtrim(sData[3],2) + 'm]), ' $
			 				 + sTable[eS.thickness,sRows[iSRow]] + 'cm ' $
			 				 + sTable[eS.material,sRows[iSRow]]
			 			; Add wall height if we're looking at the floor above
			 			if levelIndex gt 0 then $
			 				 text = text + ' from ' $
			 				 			 + sTable[eS.h1,sRows[iSRow]] + 'm above ground to , ' $
			 				 			 + sTable[eS.h2,sRows[iSRow]] + 'm above ground.'
						widget_control, (*pInfo).wQueryText, SET_VALUE=text, /APPEND
						text = '      Description: ' + sTable[eS.desc,sRows[iSRow]]
						widget_control, (*pInfo).wQueryText, SET_VALUE=text, /APPEND

						if modality eq 'PET' then begin

							TF = shielding_guiCalculateTF( modality, tracer, material, d )

						endif else begin ; SPECT

							TF = shielding_guiCalculateTF( modality, tracer, material, d, $
									ES=energies, FRACTIONS=fracs, MUMS=mums, AFS=afs, BFS=bfs )
							for iE=0, n_elements(energies)-1 do begin
								text = '      ' + strtrim(energies[iE],2) + ' keV gammas (' $
									 + strtrim(fracs[iE]*100,2) + '%), ' $
									 + 'mu_m (cm^2/g) = ' + strtrim(mums[iE],2) $
									 + ', AF = ' + strtrim(afs[iE],2) + $
									   ', BF = ' + strtrim(bfs[iE],2)
								widget_control, (*pInfo).wQueryText, SET_VALUE=text, /APPEND
							endfor

						endelse

						; Add to text widget
						text = '      TF = ' + strtrim(TF,2)
						widget_control, (*pInfo).wQueryText, SET_VALUE=text, /APPEND

						TFTotal *= TF

					endfor ; each intersecting shield

					shieldedDose = unshieldedDose * TFTotal
					totShieldedDose += shieldedDose

					; Add to text widget
					text = '    Dose, shielded (uSv/a) = ' + strtrim(shieldedDose,2)
					widget_control, (*pInfo).wQueryText, SET_VALUE=text, /APPEND

				endif ; count

			endfor ; each imaging source

		endif ; there are imaging sources specified

	endfor ; each imaging ROI

	text = '  Total dose, unshielded (uSv/a) = ' + strtrim(totUnshieldedDose,2)
	widget_control, (*pInfo).wQueryText, SET_VALUE=text, /APPEND
	text = '  Total dose, shielded (uSv/a) = ' + strtrim(totShieldedDose,2)
	widget_control, (*pInfo).wQueryText, SET_VALUE=text, /APPEND
	widget_control, (*pInfo).wQueryText, SET_VALUE='====================', /APPEND
	widget_control, (*pInfo).wQueryText, SET_VALUE='', /APPEND
	geom = widget_info( (*pInfo).wQueryText, /GEOMETRY )
	topLine = geom.scr_xsize-geom.xsize
	widget_control, (*pInfo).wQueryText, SET_TEXT_TOP_LINE=topLine

	heap_free, tracers

end ; of shielding_guiSetQueryData