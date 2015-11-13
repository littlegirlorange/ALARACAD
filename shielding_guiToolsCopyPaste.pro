;--------------------------------------------------------------------
;
;    PURPOSE  Copy a ROI
;
pro shielding_guiCopyROI, pInfo, oDispROI

	; Get the database ROI
	oDispROIGroup = (*pInfo).oDispROIGroup
	bContained = oDispROIGroup->isContained( oDispROI, POSITION=pos )
	oROIGroup = (*pInfo).oROIGroup
	oROI = oROIGroup->get( POSITION=pos )

	; Copy the ROI
	oROI->getProperty, DATA=data, NAME=name
	(*pInfo).oCopyROI->setProperty, DATA=data, NAME=name
	(*pInfo).oDispCopyROI->setProperty, DATA=data, NAME=name, HIDE=0
	(*pInfo).oWindow->draw, (*pInfo).oView

end ; of shielding_guiCopyROI


;--------------------------------------------------------------------
;
;    PURPOSE  Paste a ROI
;
pro shielding_guiPasteROI, pInfo

	forward_function shielding_guiGenerateROIName

	; Get the copied ROI from the state
	oCopyROI = (*pInfo).oCopyROI
	if not obj_valid( oCopyROI ) then return
	oDispCopyROI = (*pInfo).oDispCopyROI
	oCopyROI->getProperty, DATA=data, NAME=name

	; Create a new database ROI
	oROI = obj_new( 'IDLgrROI', DATA=data, COLOR=[255,0,0] )

	; Create new display ROI
	oDispROI = obj_new( 'MKgrROI', DATA=data, COLOR=[255,0,0] )

	oROIGroup = (*pInfo).oROIGroup
	oROIGroup->add, oROI
	name = shielding_guiGenerateROIName( oROIGroup, PREFIX=name )
	oROI->setProperty, NAME=name
	oDispROI->setProperty, NAME=name

	; Add to the display ROI groups for this slice and redisplay
	(*pInfo).oDispROIGroup->add, oDispROI
	(*pInfo).oWindow->draw, (*pInfo).oView

end ; of shielding_guiPasteROI


;--------------------------------------------------------------------
;
;    PURPOSE  Stop ROI copy/paste
;
pro shielding_guiCopyROIStop, pInfo

	; Hide the copy the ROIs
	(*pInfo).oDispCopyROI->setProperty, HIDE=1
	(*pInfo).oWindow->draw, (*pInfo).oView

end ; of shielding_guiCopyROIStop

