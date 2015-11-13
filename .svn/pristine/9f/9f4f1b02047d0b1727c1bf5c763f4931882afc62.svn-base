;--------------------------------------------------------------------
;
;    PURPOSE  Get/set query point data
;
pro shielding_guiSetQueryData, $
	pInfo, $
	oROI, $
	PROMPT=prompt, $
	DESCRIPTION=desc

	if not obj_valid( oROI ) then return
	oROI->getProperty, NAME=qName, DATA=qData, DESC=desc
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
				  strtrim( desc, 2 )]

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
			oROI->setProperty, DATA=qData, DESC=desc
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

	shielding_guiCalculate, pInfo, QPOINT=qData, QNAME=qName

end ; of shielding_guiSetQueryData