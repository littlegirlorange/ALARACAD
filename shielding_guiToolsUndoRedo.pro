;--------------------------------------------------------------------
;
;    PURPOSE  Save a ROI action for undo
;
pro shielding_guiSaveUndoROI, pInfo, ACTION=action, OROI=oROI, OUNDO=oUndo

	forward_function shielding_guiGenerateUndoRedoROI

	oUndo = shielding_guiGenerateUndoRedoROI( $
			pInfo, ACTION=action, oROI=oROI )
	if obj_valid( oUndo ) then begin
		(*pInfo).oUndoContainer->add, oUndo
		widget_control, (*pInfo).wUndoROIButton, SENSITIVE=1

		; For debugging
		oUndo->getProperty, TABLE_DATA=data
		print, 'save undo ', action, data, oROI
	endif

end ; of shielding_guiSaveUndoROI


;--------------------------------------------------------------------
;
;    PURPOSE  Save a ROI action for redo
;
pro shielding_guiSaveRedoROI, pInfo, ACTION=action, OROI=oROI, OREDO=oRedo

	forward_function shielding_guiGenerateUndoRedoROI

	oRedo = shielding_guiGenerateUndoRedoROI( $
			pInfo, ACTION=action, oROI=oROI )
	if obj_valid( oUndoRedo ) then begin
		(*pInfo).oRedoContainer->add, oRedo
		widget_control, (*pInfo).wRedoROIButton, SENSITIVE=1

		; For debugging
		oRedo->getProperty, TABLE_DATA=data
		print, 'save redo ', action, data, oROI
	endif

end ; of shielding_guiSaveRedoROI


;--------------------------------------------------------------------
;
;    PURPOSE  Save a ROI action for undo/redo
;
function shielding_guiGenerateUndoRedoROI, pInfo, ACTION=action, OROI=oROI

	catch, err
	if err ne 0 then return, 0L

	if obj_valid( oROI ) then begin
		oROI->getProperty, NAME=name
		prefix = (strsplit( name, '_', /EXTRACT ))[0]
		case prefix of
		'P': table = (*pInfo).wSourceTable
		'S': table = (*pInfo).wShieldTable
		'H': table = (*pInfo).wHShieldTable
		'R': table = (*pInfo).wRegionTable
		else: return, 0L
		endcase

		widget_control, table, GET_VALUE=value
		rows = where( value[0,*] eq name, nRows )
		if nRows eq 0 then begin
			tableData = 0L
		endif else begin
			tableData = value[*,rows]
		endelse
	endif else begin
		tableData = 0L
	endelse

	oUndoRedo = obj_new( 'undoInfo', ACTION=action, OROI=oROI, TABLE_DATA=tableData )
	return, oUndoRedo

end ; of shielding_guiSaveUndoROI


;--------------------------------------------------------------------
;
;    PURPOSE  Clear undo/redo container
;
pro shielding_guiClearUndoRedoROI, pInfo

	obj_destroy, (*pInfo).oUndoContainer
	(*pInfo).oUndoContainer = obj_new( 'IDL_container' )
	obj_destroy, (*pInfo).oRedoContainer
	(*pInfo).oRedoContainer = obj_new( 'IDL_container' )

	; Disable undo/redo
	widget_control, (*pInfo).wUndoROIButton, SENSITIVE=0
	widget_control, (*pInfo).wRedoROIButton, SENSITIVE=0

end ; of shielding_guiClearUndoRedoROI


;--------------------------------------------------------------------
;
;    PURPOSE  Undo ROI action
;
pro shielding_guiUndoROI, pInfo

	forward_function shielding_guiSetCurrentROI

	; Get last action
	index = (*pInfo).oUndoContainer->count()-1
	oUndo = (*pInfo).oUndoContainer->get( POSITION=index )
	(*pInfo).oUndoContainer->remove, oUndo
	if not obj_valid( oUndo ) then return

	oUndo->getProperty, ACTION=action, TABLE_DATA=tableData, oROI=oROI
	print, 'undo container size: ', index+1
	print, 'undo ', action, tableData, oROI

	; Disable undo if the container is empty
	if index eq 0 then $
		widget_control, (*pInfo).wUndoROIButton, SENSITIVE=0

	; Save current state for redo
	shielding_guiSaveRedoROI, pInfo, ACTION=action, oROI=oROI, oREDO=oRedo

	; Undo
	bOk = shielding_guiUndoRedoROI( pInfo, oUndo )

	; Record reference to new ROI if action was 'delete_roi'
	if action eq 'delete_roi' then begin
		oRedo->setProperty, OROI=(*pInfo).oCurROI
	endif

	bOk = shielding_guiSetCurrentROI( pInfo, /NONE )
	obj_destroy, oUndo

end ; of shielding_guiUndoROI


;--------------------------------------------------------------------
;
;    PURPOSE  Redo ROI action
;
pro shielding_guiRedoROI, pInfo

	forward_function shielding_guiSetCurrentROI

	; Get last action
	index = (*pInfo).oRedoContainer->count()-1
	oRedo = (*pInfo).oRedoContainer->get( POSITION=index )
	(*pInfo).oRedoContainer->remove, POSITION=index
	if not obj_valid( oRedo ) then return

	oRedo->getProperty, ACTION=action, TABLE_DATA=tableData, oROI=oROI
	print, 'redo container size: ', index+1
	print, 'redo ', action, tableData, oROI

	; Disable redo if the container is empty
	if index eq 0 then $
		widget_control, (*pInfo).wRedoROIButton, SENSITIVE=0

	; Save current state for undo if necessary
	shielding_guiSaveUndoROI, pInfo, ACTION=action, oROI=oROI

	; Redo
	bOk = shielding_guiUndoRedoROI( pInfo, oRedo )

	bOk = shielding_guiSetCurrentROI( pInfo, /NONE )
	obj_destroy, oRedo

end ; of shielding_guiRedoROI


;--------------------------------------------------------------------
;
;    PURPOSE  Do ROI action
;
function shielding_guiUndoRedoROI, pInfo, oUndoRedo

	catch, err
	if err ne 0 then begin
		obj_destroy, oUndoRedo
		return, 0b
	endif

	oUndoRedo->getProperty, ACTION=action, TABLE_DATA=tableData, $
			OROI=oROI, NAME=name

	if n_elements(tableData) gt 1 then begin
		widget_control, (*pInfo).wFloorplanScaleText, GET_VALUE=value
		scale = float(value[0])

		prefix = (strsplit( name, '_', /EXTRACT ))[0]
		case prefix of
		'P': begin
			table = (*pInfo).wSourceTable
			s = (*pInfo).eP
			data = [tableData[s.x],tableData[s.y]]/scale
		end
		'S': begin
			table = (*pInfo).wShieldTable
			s = (*pInfo).eS
			data = [[tableData[s.x1],tableData[s.y1]], $
					[tableData[s.x2],tableData[s.y2]]]/scale
		end
		'H': begin
			table = (*pInfo).wHShieldTable
			s = (*pInfo).eH
			data = [[tableData[s.x1],tableData[s.y1]], $
					[tableData[s.x2],tableData[s.y2]], $
					[tableData[s.x3],tableData[s.y3]], $
					[tableData[s.x4],tableData[s.y4]]]/scale
		end
		'R': begin
			table = (*pInfo).wRegionTable
			s = (*pInfo).eR
			data = [[tableData[s.x1],tableData[s.y1]], $
					[tableData[s.x2],tableData[s.y2]], $
					[tableData[s.x3],tableData[s.y3]], $
					[tableData[s.x4],tableData[s.y4]]]/scale
		end
		else: begin
			obj_destroy, oUndoRedo
			return, 0b
		end
		endcase

	endif

	if action eq 'delete_roi' then begin

		if obj_valid( oROI ) then begin

			bOK = shielding_guiSetCurrentROI( pInfo, oROI )
			shielding_guiDeleteROI, pInfo, oROI

		endif else begin

		; Need to recreate the ROI object and table entry
		case prefix of
		'P': begin
			style = 0				; point
			color = [255,100,0]		; orange
			oSymbol = obj_new( 'IDLgrSymbol', 5, SIZE=5 )
			oROI = obj_new( 'IDLgrROI', NAME=name, DATA=data, $
					STYLE=style, COLOR=color, SYMBOL=oSymbol )
			oDispROI = obj_new( 'MKgrROI', NAME=name, DATA=data, $
					STYLE=style, COLOR=color, SYMBOL=oSYMBOL, $
					THICK=(*pInfo).roiThick, TEXT_SIZE=(*pInfo).textSize )
			(*pInfo).oROIGroup->add, oROI
			(*pInfo).oDispROIGroup->add, oDispROI
			bOk = shielding_guiSetCurrentROI( pInfo, oDispROI )
			if size( tableData, /N_DIM ) gt 1 then begin
				nRows = (size( tableData, /DIM ))[1]
			endif else begin
				nRows = 1
			endelse
			for i=0, nRows-1 do begin
				shielding_guiAddSourceSpecs, pInfo, oROI, $
						TRACER=tableData[s.tracer,i], $
						A0=tableData[s.a0,i], $
						TU=tableData[s.TU,i], $ 			; uptake time (h)
						TI=tableData[s.TI,i], $ 			; imaging time (h)
						NA=tableData[s.NA,i], $			; no. patients/year
						PV=tableData[s.PV,i], $ 			; patient voiding (%)
						SS=tableData[s.SS,i], $ 			; scanner shielding (%)
						DESCRIPTION=tableData[s.desc,i]
			endfor
		end
		'S': begin
			style = 1				; open ROI
			case tableData[s.material] of
			'Lead': 	color = [255,0,0] 		; red
			'Concrete':	color = [160,32,240]	; purple
			'Iron':		color = [255,192,203]	; pink
			else:		color = [255,0,0]		; red by default
			endcase ; material
			oROI = obj_new( 'IDLgrROI', NAME=name, DATA=data, $
					STYLE=style, COLOR=color )
			oDispROI = obj_new( 'MKgrROI', NAME=name, DATA=data, $
					STYLE=style, COLOR=color, $
					THICK=(*pInfo).roiThick, TEXT_SIZE=(*pInfo).textSize )
			(*pInfo).oROIGroup->add, oROI
			(*pInfo).oDispROIGroup->add, oDispROI
			bOk = shielding_guiSetCurrentROI( pInfo, oDispROI )
			shielding_guiSetShieldSpecs, pInfo, oROI, $
					MATERIAL=tableData[s.material], $
					THICKNESS=tableData[s.thickness], $
					HEIGHT1=tableData[s.h1], $
					HEIGHT2=tableData[s.h2], $
					DESCRIPTION=tableData[s.desc]
		end
		'H': begin
			style = 2				; closed ROI
			case tableData[s.material] of
			'Lead': 	color = [255,0,0] 		; red
			'Concrete':	color = [160,32,240]	; purple
			'Iron':		color = [255,192,203]	; pink
			else:		color = [255,0,0]		; red by default
			endcase ; material
			oROI = obj_new( 'IDLgrROI', NAME=name, DATA=data, $
					STYLE=style, COLOR=color )
			oDispROI = obj_new( 'MKgrROI', NAME=name, DATA=data, $
					STYLE=style, COLOR=color, $
					THICK=(*pInfo).roiThick, TEXT_SIZE=(*pInfo).textSize )
			(*pInfo).oROIGroup->add, oROI
			(*pInfo).oDispROIGroup->add, oDispROI
			bOk = shielding_guiSetCurrentROI( pInfo, oDispROI )
			shielding_guiSetHShieldSpecs, pInfo, oROI, $
					MATERIAL=tableData[s.material], $
					THICKNESS=tableData[s.thickness], $
					HEIGHT=tableData[s.h], $
					DESCRIPTION=tableData[s.desc]
			end
		'R': begin
			style = 2				; closed
			color = [0,0,255]		; blue
			oROI = obj_new( 'IDLgrROI', NAME=name, DATA=data, $
					STYLE=style, COLOR=color )
			oDispROI = obj_new( 'MKgrROI', NAME=name, DATA=data, $
					STYLE=style, COLOR=color, $
					THICK=(*pInfo).roiThick, TEXT_SIZE=(*pInfo).textSize )
			(*pInfo).oROIGroup->add, oROI
			(*pInfo).oDispROIGroup->add, oDispROI
			bOk = shielding_guiSetCurrentROI( pInfo, oDispROI )
			shielding_guiSetRegionSpecs, pInfo, oROI, $
					OCCUPANCY=tableData[s.occ], $
					DESCRIPTION=tableData[s.desc]
			shielding_guiFindMax, pInfo, oROI
		end
		endcase ; prefix

		(*pInfo).oWindow->draw, (*pInfo).oViewGroup

		endelse

	endif else begin

		; Need to update the ROI object and table entry
		bContained = (*pInfo).oROIGroup->isContained( oROI, POSITION=pos )
		if not bContained then begin
			obj_destroy, oUndoRedo
			return, 0b
		endif
		oDispROI = (*pInfo).oDispROIGroup->get( POSITION=pos )

		; Reset the data and redisplay
		oROI->setProperty, NAME=name, DATA=data
		oDispROI->setProperty, NAME=name, DATA=data
		(*pInfo).oVertexModel->setProperty, HIDE=1
		(*pInfo).oWindow->draw, (*pInfo).oViewGroup

		if (*pInfo).oCurROI ne oROI then $
			bOk = shielding_guiSetCurrentROI( pInfo, /NONE )

		; Update the ROI's table entry
		widget_control, table, GET_VALUE=value
		rows = where( value[0,*] eq name, nRows )
		for i=0, nRows-1 do begin
			value[*,rows[0]+i] = tableData[*,i]
		endfor
		widget_control, table, SET_VALUE=value

	endelse


	return, 1b

end ; of shielding_guiUndoRedoROI


