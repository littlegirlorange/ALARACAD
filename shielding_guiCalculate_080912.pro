;==============================================================================
;
;	Method:		shielding_guiCalculate
;
;	Description:
;				Calculates the dose image.
;
;	Version:
;				080814
;				Lots of previous versions, just no info because I was lazy
;				and didn't create a header for this function until today.
;
;				080814
;				Changed calculation of dose equivalent rate constant for
;				soft tissue (used to use values from Wasserman &
;				Groenewald, but now calculate manually).
;
;	Parameters:
;				pInfo - pointer to main program info structure.
;
;	Outputs:
;				Dose image saved to info structure (*pInfo.pSeries1)
;
;	Required Modules:
;				shielding_guiLinesIntersect
;				shielding_guiGetIntersect
;				shielding_guiCalculateTF
;				shielding_guiPlaneIntersect
;				shielding_gui_shield_specs
;				shielding_gui_PET_tracer_specs
;				shielding_gui_SPECT_tracer_specs
;				shielding_gui_tissue_specs
;
;	Written by:
;				Maggie Kusano, August 14, 2008
;
;==============================================================================

pro shielding_guiCalculate, $
	pInfo, $
	QPOINT=qPoint, $
	QNAME=qName

	forward_function shielding_guiLinesIntersect
	forward_function shielding_guiGetIntersect
	forward_function shielding_guiCalculateTF
	forward_function shielding_guiPlaneIntersect

	modality = (*pInfo).modality
	if modality eq 'PET' then begin
		@'shielding_gui_PET_tracer_specs'
	endif else begin
		@'shielding_gui_SPECT_tracer_specs'
	endelse

	; Determine the number of sources and shields we're working with
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
	if (count ne 0) and (row ge 0) then begin
		nPoints	= row+1
	endif

	if nPoints eq 0 then begin

		; Return a zero dosemap if we don't have any sources
		heap_free, tracers
		if bQuery eq 0b then begin
			(*pInfo).pSeries1 = fltarr( (*pInfo).nPx, (*pInfo).nPy )
		endif
		return

	endif else begin

		pTable = pTable[*,0:row]

		@'shielding_gui_tissue_specs'

		; Create a list of all applicable energies and tissue mass energy absorption constants
			tracerList = pTable[eP.tracer,*]
			tracerList = tracerList[uniq(tracerList, sort(tracerList))]
			nTracers = n_elements( tracerList )
			for iTracer=0, nTracers-1 do begin
				tracer = tracers[where(tracers.name eq tracerList[iTracer])]
				if n_elements(energyList) eq 0 then begin
					energyList = *tracer.energies
					for iEnergy=0, n_elements(*tracer.energies)-1 do begin
						energy = (*tracer.energies)[iEnergy]
						index = (where( mu_en_tissue[0,*] gt energy ))[0]
						if n_elements(muEns) eq 0 then begin
							muEns = interpol( mu_en_tissue[1,index-1:index], $
									mu_en_tissue[0,index-1:index], energy )
						endif else begin
							muEn = interpol( mu_en_tissue[1,index-1:index], $
									mu_en_tissue[0,index-1:index], energy )
							muEns = [muEns, muEn]
						endelse
					endfor
				endif else begin
					energyList = [energyList, *tracer.energies]
					for iEnergy=0, n_elements(*tracer.energies)-1 do begin
						energy = (*tracer.energies)[iEnergy]
						index = (where( mu_en_tissue[0,*] gt energy ))[0]
						muEn = interpol( mu_en_tissue[1,index-1:index], $
								mu_en_tissue[0,index-1:index], energy )
						muEns = [muEns, muEn]
					endfor
				endelse
			endfor

			indices = uniq(energylist, sort(energyList))
			energyList = energyList[indices]
			muEns = muEns[indices]
			nEnergies = n_elements( energyList )

	endelse

	eS = (*pInfo).eS
	widget_control, (*pInfo).wShieldTable, GET_VALUE=sTable
	row = (where( sTable[0,*] eq '', count ))[0]-1
	if (count ne 0) and (row ge 0 ) then begin
		shieldNames	= sTable[eS.name,0:row]
		shieldMaterials	= sTable[eS.material,0:row]
		shieldThicknesses = float(sTable[eS.thickness,0:row])
		nShields = row+1
	endif

	eH = (*pInfo).eH
	widget_control, (*pInfo).wHShieldTable, GET_VALUE=hTable
	row = (where( hTable[0,*] eq '', count ))[0]-1
	if (count ne 0) and (row ge 0) then begin
		hShieldNames = hTable[eH.name,0:row]
		hShieldMaterials = hTable[eH.material,0:row]
		hShieldThicknesses = float(hTable[eH.thickness,0:row])
		nHShields = row+1
	endif

	; Calculate transmission factor for each shield/energy pair
	if nShields gt 0 then begin
		TFTable = fltarr( nEnergies, nShields )
		AFTable = fltarr( nEnergies, nShields )
		BFTable = fltarr( nEnergies, nShields )
		for iEnergy=0, nEnergies-1 do begin
			for iShield=0, nShields-1 do begin
				material = shieldMaterials[iShield]
				d = shieldThicknesses[iShield]
				TFTable[iEnergy,iShield] = $
						shielding_guiCalculateTF( modality, material, $
						d, energyList[iEnergy], AF=af, BF=bf )
				if modality eq 'SPECT' then begin
					AFTable[iEnergy,iShield] = af
					BFTable[iEnergy,iShield] = bf
				endif
			endfor
		endfor
	endif

	if nHShields gt 0 then begin
		HTFTable = fltarr( nEnergies, nHShields )
		HAFTable = fltarr( nEnergies, nHShields )
		HBFTable = fltarr( nEnergies, nHShields )
		for iEnergy=0, nEnergies-1 do begin
			for iShield=0, nHShields-1 do begin
				material = hShieldMaterials[iShield]
				d = hShieldThicknesses[iShield]
				HTFTable[iEnergy,iShield] = $
						shielding_guiCalculateTF( modality, material, $
						d, energyList[iEnergy], AF=af, BF=bf )
				if modality eq 'SPECT' then begin
					HAFTable[iEnergy,iShield] = af
					HBFTable[iEnergy,iShield] = bf
				endif
			endfor
		endfor
	endif

	; Calculate the floor/ceiling concrete slab transmission factor for each energy
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
	TFFloor = make_array( nEnergies, /FLOAT, VALUE=1.0  )
	AFFloor = make_array( nEnergies, /FLOAT, VALUE=1.0 )
	BFFloor = make_array( nEnergies, /FLOAT, VALUE=1.0 )
	TFBox = make_array( nEnergies, /FLOAT, VALUE=1.0 )
	AFBox = make_array( nEnergies, /FLOAT, VALUE=1.0 )
	BFBox = make_array( nEnergies, /FLOAT, VALUE=1.0 )

	if ((levelIndex gt 0) and (dFloor ne 0)) or (dBox ne 0) then begin ; above or below

		for iEnergy=0, nEnergies-1 do begin

			if (levelIndex gt 0) and (dFloor ne 0) then begin
				TFFloor[iEnergy] = shielding_guiCalculateTF( modality, 'Concrete', $
						dFloor, energyList[iEnergy], AF=af, BF=bf )
				if modality eq 'SPECT' then begin
					AFFloor[iEnergy] = af
					BFFloor[iEnergy] = bf
				endif
			endif

			if dBox ne 0 then begin
				TFBox[iEnergy] = shielding_guiCalculateTF( modality, 'Lead', $
						dBox, energyList[iEnergy], AF=af, BF=bf )
				if modality eq 'SPECT' then begin
					AFBox[iEnergy] = af
					BFBox[iEnergy] = bf
				endif
			endif

		endfor ; all energies

	endif

	widget_control, (*pInfo).wFloorplanScaleText, GET_VALUE=value
	fpScale = float(value[0])
	widget_control, (*pInfo).wResolutionText, GET_VALUE=value
	dmScale = float(value[0])

	if n_elements( qPoint ) eq 0 then begin
		bQuery = 0b
		nPx = (*pInfo).nPx*fpScale/dmScale
		nPy = (*pInfo).nPy*fpScale/dmScale
	endif else begin
		bQuery = 1b
		nPx = 1
		nPy = 1
	endelse

	nPixels = strtrim( long(nPx) * long(nPy), 2 )
	curPixel = 1L

	bHaveStructs = 0b
	oROIGroup = (*pInfo).oROIGroup
	nROIs = 0
	if obj_valid( oROIGroup ) then begin
		oROIs = oROIGroup->get( /ALL, COUNT=nROIs )
	endif

	typeArray = strarr( nROIs )
	nameArray = strarr( nROIs )
	dataArray = fltarr( 8, nROIs )

	for iROI=0, nROIs-1 do begin
		oROIs[iROI]->getProperty, NAME=name, DATA=data
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

	unshieldedArray = fltarr( nPx, nPy )
	shieldedArray	= fltarr( nPx, nPy )

	for y=0, nPy-1 do begin
		for x=0, nPx-1 do begin

			; Tell the user what we're doing
			if bQuery eq 0b then begin
				if curPixel mod 1000 eq 0 then begin
					status = 'Please wait. Calculating transmission factor for ' $
							+ strtrim( curPixel, 2 ) + ' of ' $
			 				+ strtrim( nPixels, 2 ) + ' image pixels'
					widget_control, (*pInfo).wInfoText, SET_VALUE=status
				endif
				curPixel++
				qData = ([x,y]+0.5)*dmScale
			endif else begin
				qData = qPoint*fpScale
			endelse

			for iP=0, nPs-1 do begin

				pName = nameArray[pIndices[iP]]
				pData = dataArray[*,pIndices[iP]]
				pData *= fpScale

				pRows = where( pTable[0,*] eq pName, nPRows )

				if nPRows gt 0 then begin

					pqFloorDist = sqrt( ( qData[0] - pData[0] )^2 + $
										( qData[1] - pData[1] )^2 )
					pqDist = sqrt( ( qData[0] - pData[0] )^2 + $
								   ( qData[1] - pData[1] )^2 + dist^2 )

					; See if the line intersects any vertical shields
					if nShields gt 0 then begin

						bIntersects = bytarr( nShields )

						for iS=0, nSs-1 do begin

							sName = nameArray[sIndices[iS]]
							sData = dataArray[*,sIndices[iS]]
							sData *= fpScale

							retVal = shielding_guiLinesIntersect( $
									[[qData[0],qData[1]],[pData[0],pData[1]]], $
									[[sData[0],sData[1]],[sData[2],sData[3]]] )

							if retVal ne 0 then begin ; Lines intersect

								case levelIndex of

								0: begin	; current level
									; Remember this structure
									bIntersects[where( shieldNames eq sName, count )] = 1b
								end
								1: begin	; floor above
									coords = shielding_guiGetIntersect( $
											[[pData[0],pData[1]],[qData[0],qData[1]]], $
											[[sData[0],sData[1]],[sData[2],sData[3]]] )
									psFloorDist = sqrt( (coords[0]-pData[0])^2 + $
											(coords[1]-pData[1])^2 )
									h = psFloorDist * dist / pqFloorDist

									; Assume the source is 1 m above the ground
									row = (where( shieldNames eq sName, count ))[0]
									if h lt (float(sTable[eS.h2,row])-sourceHeight) then begin ; Lines intersect
										; Remember this structure
										bIntersects[row] = 1b
									endif
								end
								2: begin	; floor below
									coords = shielding_guiGetIntersect( $
											[[pData[0],pData[1]],[qData[0],qData[1]]], $
											[[sData[0],sData[1]],[sData[2],sData[3]]] )

									psFloorDist = sqrt( (coords[0]-pData[0])^2 + $
											(coords[1]-pData[1])^2 )

									h = psFloorDist * dist / pqFloorDist

									; Assume the source is 1 m above the ground
									row = (where( shieldNames eq sName, count ))[0]
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

					if (nHShields gt 0) and (levelIndex gt 0) then begin

						bIntersects = bytarr( nHShields )

						for iH=0, nHShields-1 do begin

							hData = dataArray[*,hIndices[iH]] * fpScale
							p1 = [pData[0], pData[1], sourceDist]
							p2 = [qData[0], qData[1], targetDist]
							v1 = [hData[0], hData[1], hTable[eH.h, iH]]
							v2 = [hData[2], hData[3], hTable[eH.h, iH]]
							v3 = [hData[4], hData[5], hTable[eH.h, iH]]
							bIntersects[iH] = shielding_guiPlaneIntersect( p1, p2, v1, v2, v3 )

						endfor

						hRows = where( bIntersects eq 1b, nHRows )

					endif else begin

						nHRows = 0

					endelse

					for iPRow=0, nPRows-1 do begin

						; Get values from imaging table
						tracerName 	= pTable[eP.tracer,pRows[iPRow]]
						tIndex = (where( tracers.name eq tracerName, count ))[0]
						if count eq 0 then continue

						tracer = (tracers[tIndex])[0]

						A0	= float( pTable[eP.A0,pRows[iPRow]] )		; admin. activity (GBq)
						TU	= float( pTable[eP.TU,pRows[iPRow]] )/60.0	; uptake time (h)
						TI	= float( pTable[eP.TI,pRows[iPRow]] )/60.0	; imaging time (h)
						NA	= float( pTable[eP.NA,pRows[iPRow]] )		; no. patients/year
						PV	= float( pTable[eP.PV,pRows[iPRow]] )		; patient voiding (%)
						SS	= float( pTable[eP.SS,pRows[iPRow]] )		; scanner shielding (%)

						; Half-life (h)
						HL = tracer.hl
						; Dose reduction factor over imaging time
						RI = 1.443 * (HL/TI) * (1-exp(-0.693*TI/HL))
						; Uptake time decay factor
						FU = exp(-0.693*TU/HL)

						; Add to text widget
						if bQuery then begin
						text = '  ' + pTable[eP.name,pRows[iPRow]] $
							 + ' (' + pTable[eP.x,pRows[iPRow]] + 'm, ' + pTable[eP.y,pRows[iPRow]] + 'm), ' $
							 + pTable[eP.tracer,pRows[iPRow]] + ', ' $
							 + 'A0 = ' + pTable[eP.A0,pRows[iPRow]] + ' GBq, ' $
							 + 'T1 = ' + pTable[eP.TU,pRows[iPRow]] + ' min, ' $
							 + 'T2 = ' + pTable[eP.TI,pRows[iPRow]] + ' min, ' $
							 + 'NA = ' + pTable[eP.NA,pRows[iPRow]] + ' pat/yr'
						widget_control, (*pInfo).wQueryText, SET_VALUE=text, /APPEND
						text = '    Description: ' + pTable[eP.desc,pRows[iPRow]]
						widget_control, (*pInfo).wQueryText, SET_VALUE=text, /APPEND
						text = '    Distance from ' + qName + ' = ' + strtrim(pqDist,2) + ' m'
						widget_control, (*pInfo).wQueryText, SET_VALUE=text, /APPEND
						endif ; bQuery

						nEnergies = n_elements( *tracer.energies )
						doses = fltarr( nEnergies )
						shieldedDoses = fltarr( nEnergies )
						ders = fltarr( nEnergies )

						for iEnergy=0, nEnergies-1 do begin

							energy = (*tracer.energies)[iEnergy]
							frac = (*tracer.fractions)[iEnergy]
							eIndex = (where(energyList eq energy))[0]

							if modality eq 'PET' then begin
								ders[iEnergy] = tracer.der
								doses[iEnergy] = tracer.der * NA * A0 * (1.0-PV/100.0) $
									 	* (1.0-SS/100.0) * FU * TI * RI / (pqDist^2)
							endif else begin ; modality eq 'SPECT'
								muEn = muEns[eIndex]
								; 4.58939 = unit conversion factor
								;		  = 3600 s/h * 1000 g/kg * 1.602e-13 J/MeV $
								;		  * 1 MeV/1000 keV
								;		  * 1e9 Bq/GBq * 1e6 uSv/Gy * 1e-4 m^2/cm^2
								ders[iEnergy] = 4.58939 * energy * frac * muEn
								doses[iEnergy] = 4.58939 * energy * frac * muEn $
										* NA * A0 * (1.0-PV/100.0) $
									 	* (1.0-SS/100.0) * FU * TI * RI / (pqDist^2)
							endelse

							; Add to text widget
							if bQuery then begin
							text = '    ' + strtrim(energy,2) + ' keV gammas, ' + strtrim(frac*100.0,2) + '%'
							widget_control, (*pInfo).wQueryText, SET_VALUE=text, /APPEND
							text = '      DER const = ' + strtrim(ders[iEnergy],2) + ' m^2uSv/GBqh'
							widget_control, (*pInfo).wQueryText, SET_VALUE=text, /APPEND
							text = '      Unshielded dose = ' + strtrim(doses[iEnergy],2) + ' uSv'
							widget_control, (*pInfo).wQueryText, SET_VALUE=text, /APPEND
							endif ; bQuery

							TF = 1.0

							for iSRow=0, nSRows-1 do begin
								sIndex = sRows[iSRow]
								TF *= TFTable[eIndex,sIndex]
								if bQuery then begin
									eS = (*pInfo).eS
									text = '      ' + sTable[eS.name,sIndex] $
						 				 + ' ([' + strtrim(sData[0],2) + ' m, ' + strtrim(sData[1],2) + ' m], [' $
						 				 + strtrim(sData[2],2) + ' m, ' + strtrim(sData[3],2) + ' m]), ' $
						 				 + sTable[eS.thickness,sIndex] + ' cm ' $
						 				 + sTable[eS.material,sIndex]
						 			if levelIndex gt 0 then $
						 				 text = text + ' from ' $
						 				 			 + sTable[eS.h1,sRows[iSRow]] + ' m above ground to , ' $
						 				 			 + sTable[eS.h2,sRows[iSRow]] + ' m above ground.'
						 			widget_control, (*pInfo).wQueryText, SET_VALUE=text, /APPEND
						 			text = '        Description: ' + sTable[eS.desc,sIndex]
									widget_control, (*pInfo).wQueryText, SET_VALUE=text, /APPEND
									if modality eq 'SPECT' then begin
										text = '        AF = ' + strtrim(AFTable[eIndex,sIndex],2) $
											 + ', BF = ' + strtrim(BFTable[eIndex,sIndex],2)
						 				widget_control, (*pInfo).wQueryText, SET_VALUE=text, /APPEND
						 			endif
						 			text = '        TF = ' + strtrim(TFTable[eIndex,sIndex],2)
						 			widget_control, (*pInfo).wQueryText, SET_VALUE=text, /APPEND
						 		endif
							endfor
							if levelIndex gt 0 then begin
								for iHRow=0, nHRows-1 do begin
									hIndex = hRows[iHRow]
									TF *= HTFTable[eIndex,hIndex]
									if bQuery then begin
										eH = (*pInfo).eH
										text = '      ' + hTable[eH.name,hIndex] $
							 				 + ' ([' + strtrim(hData[0],2) + ' m, ' + strtrim(hData[1],2) + ' m], [' $
							 				 + strtrim(hData[4],2) + ' m, ' + strtrim(hData[5],2) + ' m]), ' $
							 				 + strtrim(hTable[eH.h,hIndex],2) + ' m above ground, ' $
							 				 + strtrim(hTable[eH.thickness,hIndex],2) + ' cm ' $
							 				 + strtrim(hTable[eH.material,hIndex],2)
							 			widget_control, (*pInfo).wQueryText, SET_VALUE=text, /APPEND
							 			text = '        Description: ' + hTable[eH.desc,hIndex]
							 			widget_control, (*pInfo).wQueryText, SET_VALUE=text, /APPEND
							 			if modality eq 'SPECT' then begin
											text = '        AF = ' + strtrim(HAFTable[eIndex,hIndex],2) $
												 + ', BF = ' + strtrim(HBFTable[eIndex,hIndex],2)
											widget_control, (*pInfo).wQueryText, SET_VALUE=text, /APPEND
										endif
							 			text = '        TF=' + strtrim(HTFTable[eIndex,hIndex],2)
							 			widget_control, (*pInfo).wQueryText, SET_VALUE=text, /APPEND
							 		endif
								endfor
							endif
							if (boxPoint eq pName) and (dBox gt 0) then begin
								TF *= TFBox[eIndex]
								if bQuery then begin
									text = '      Lead container (' $
										 + strtrim(dBox,2) + ' cm thick)'
									widget_control, (*pInfo).wQueryText, SET_VALUE=text, /APPEND
									text = '        AF = ' + strtrim(AFBox[eIndex],2) $
										 + ', BF = ' + strtrim(BFBox[eIndex],2)
									widget_control, (*pInfo).wQueryText, SET_VALUE=text, /APPEND
									text = '        TF = ' + strtrim(TFBox[eIndex],2)
									widget_control, (*pInfo).wQueryText, SET_VALUE=text, /APPEND
								endif
							endif
							if (dFloor gt 0) and (levelIndex gt 0) then begin
								TF *= TFFloor[eIndex]
								if bQuery then begin
									text = '      Floor/ceiling (' $
										 + strtrim(dFloor,2) + 'cm thick, ' $
										 + strtrim(dist,2) + ' m below/above source)'
									widget_control, (*pInfo).wQueryText, SET_VALUE=text, /APPEND
									text = '        AF = ' + strtrim(AFFloor[eIndex],2) $
										 + ', BF = ' + strtrim(BFFloor[eIndex],2)
									widget_control, (*pInfo).wQueryText, SET_VALUE=text, /APPEND
									text = '        TF = ' + strtrim(TFFloor[eIndex],2)
									widget_control, (*pInfo).wQueryText, SET_VALUE=text, /APPEND
								endif
							endif

							shieldedDoses[iEnergy] = doses[iEnergy] * TF

							if bQuery then begin
							text = '      Shielded dose = ' + strtrim(shieldedDoses[iEnergy],2) + ' uSv'
							widget_control, (*pInfo).wQueryText, SET_VALUE=text, /APPEND
							endif

						endfor

						if bQuery then begin
						text = '    Total DER const = ' + strtrim(total(ders),2) + ' m^2uSv/GBqh'
						widget_control, (*pInfo).wQueryText, SET_VALUE=text, /APPEND
						text = '    Total unshielded dose = ' + strtrim(total(doses),2) + ' uSv'
						widget_control, (*pInfo).wQueryText, SET_VALUE=text, /APPEND
						text = '    Total shielded dose = ' + strtrim(total(shieldedDoses),2) + ' uSv'
						widget_control, (*pInfo).wQueryText, SET_VALUE=text, /APPEND
						endif

						unshieldedArray[x,y] += total( doses )
						shieldedArray[x,y] += total( shieldedDoses )

					endfor ; each tracer

				endif ; there are point sources specified

			endfor ; each imaging ROI

		endfor ; y
	endfor ; x

	for i=0, n_elements(tracerObjs)-1 do begin
		obj_destroy, tracerObjs[i]
	endfor

	heap_free, tracers

	if bQuery then begin

		text = '  Total dose = ' + strtrim(total(unshieldedArray),2) + ' uSv'
		widget_control, (*pInfo).wQueryText, SET_VALUE=text, /APPEND
		text = '  Total shielded dose = ' + strtrim(total(shieldedArray),2) + ' uSv'
		widget_control, (*pInfo).wQueryText, SET_VALUE=text, /APPEND

	endif else begin

		; Scale the dose image to the floorplan image
		; Use NN interpolation if the dose map pixels are larger than the floorplan pixels
		; Use bilinear interpolation if the dose map pixels are smaller.
		xOffset = (dmScale-fpScale)/2.0/fpScale
		xVals = findgen( (*pInfo).nPx ) * fpScale / dmScale
		yVals = findgen( (*pInfo).nPy ) * fpScale / dmScale
	;	if dmScale > fpScale then begin
	;;		xOffset = -xOffset
	;		xVals = round( xVals )
	;		yVals = round( yVals )
	;	endif
		yOffset = xOffset
	 	*(*pInfo).pSeries1 = shift( interpolate( shieldedArray, xVals, yVals, /GRID ), xOffset, yOffset )

	endelse ; bQuery

	; Update status
	widget_control, (*pInfo).wInfoText, SET_VALUE='Ready'

end ; of shielding_guiCalculate