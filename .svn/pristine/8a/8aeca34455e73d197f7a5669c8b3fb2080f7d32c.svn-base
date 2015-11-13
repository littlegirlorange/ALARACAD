function MKgrROI::init, _EXTRA=_extra, TEXT_HIDE=bHideText, TEXT_ANCHOR=anchor, TEXT_SIZE=textSize

	; Initialize the model parent
	if  self->IDLgrModel::init( /SELECT_TARGET ) eq 0 then $
		return, 0

	; Create the ROI object
	self._oROI = obj_new( 'IDLgrROI', _EXTRA=_extra )

	; Create an IDLgrText with similar properties to ROI and show if requested
	self._oROI->getProperty, DATA=data, COLOR=color, NAME=name

	; Hide/show the Text, as specified by the user:
	;	if bHide=1 & bHideText=1 then bHideText=1
	;	if bHide=1 & bHideText=0 then bHideText=1
	;	if bHide=0 & bHideText=1 then bHideText=1
	;	if bHide=0 & bHideText=0 then bHideText=0
	if n_elements( bHide ) eq 0 then bHide = 0
	if n_elements( bHideText ) eq 0 then bHideText = 0
	if n_elements( data ) ne 0 then anchor = data[*,0]
	self->IDLgrModel::setProperty, HIDE=bHide
	self._oText = obj_new( 'IDLgrText', COLOR=color, LOCATION=anchor, $
			ALIGNMENT=1.0, RECOMPUTE_DIMENSIONS=2, $
			STRING=name, HIDE=(bHide or bHideText) )
	self.bHideText = bHideText
	if n_elements( textSize ) ne 0 then begin
		self._oText->getProperty, FONT=oFont
		if obj_valid( oFont ) then begin
			oFont->setProperty, SIZE=textSize
		endif else begin
			oFont = obj_new( 'IDLgrFont', SIZE=textSize )
			self._oText->setProperty, FONT=oFont
		endelse
	endif

	; Add the ROI and Text to the model parent
	self->IDLgrModel::add, self._oROI
	self->IDLgrModel::add, self._oText

	return, 1

end ; of MKgrROI::init


pro MKgrROI::cleanup

	; Destroy objects
	if obj_valid( self._oROI ) then begin
		self._oROI->getProperty, SYMBOL=oSymbol
		if obj_valid( oSymbol ) then obj_destroy, oSymbol
		obj_destroy, self._oROI
	endif
	if obj_valid( self._oText ) then begin
		self._oText->getProperty, FONT=oFont
		if obj_valid( oFont ) then obj_destroy, oFont
		obj_destroy, self._oText
	endif
	self->IDLgrModel::cleanup

end ; of MKgrROI::cleanup


pro MKgrROI::getProperty, _REF_EXTRA=_extra, TEXT_HIDE=bHideText, TEXT_ANCHOR=anchor, TEXT_SIZE=textSize, PARENT=parent

	if n_elements( _extra ) ne 0 then $
		self._oROI->getProperty, _EXTRA=_extra

	if n_elements( bHide ) ne 0 then $
		self->IDLgrModel::getProperty, HIDE=bHide

	if n_elements( bHideText ) ne 0 then $
		bHideText = self.bHideText

	if arg_present( anchor ) then $
		anchor = self.textAnchor

	if arg_present( textSize ) then begin
		self._oText->getProperty, FONT=oFont
		if obj_valid( oFont ) then begin
			oFont->getProperty, SIZE=size
			textSize = size
		endif else begin
			textSize = 12.0
		endelse
	endif

	if arg_present( parent ) then $
		self->IDLgrModel::getProperty, PARENT=parent

end ; of MKgrROI::getProperty


pro MKgrROI::setProperty, _EXTRA=_extra, TEXT_HIDE=bHideText, TEXT_ANCHOR=anchor, TEXT_SIZE=textSize, PARENT=parent

	if n_elements( _extra ) gt 0 then begin
		self._oROI->setProperty, _EXTRA=_extra

		; Check to see if the name was set
		index = where( tag_names(_extra) eq 'NAME', bSet )
		if bSet then $
			self._oText->setProperty, STRINGS=_extra.(index)

		; Check to see if the ROI was moved
		index = where( tag_names(_extra) eq 'DATA', bSet )
		if bSet then $
			self._oText->setProperty, LOCATION=(_extra.(index))[*,0]

		; Check to see if the color was changed
		index = where( tag_names(_extra) eq 'COLOR', bSet )
		if bSet then $
			self._oText->setProperty, COLOR=_extra.(index)

	endif

	if n_elements( bHide ) ne 0 then $
		self->IDLgrModel::setProperty, HIDE=bHide

	if n_elements( bHideText ) ne 0 then begin
		self.bHideText = bHideText
		self._oText->setProperty, HIDE=bHideText
	endif

	if keyword_set( anchor ) then begin
		self.textAnchor = anchor
		self._oText->setProperty, LOCATION=anchor
	endif

	if arg_present( textSize ) then begin
		self._oText->getProperty, FONT=oFont
		if obj_valid( oFont ) then begin
			oFont->setProperty, SIZE=textSize
		endif else begin
			oFont = obj_new( 'IDLgrFont', SIZE=textSize )
			self._oText->setProperty, FONT=oFont
		endelse
	endif

	if arg_present( parent ) then $
		self->IDLgrModel::setProperty, PARENT=parent

end ; of MKgrROI::getProperty


pro MKgrROI::appendData, x, y, z, _EXTRA=_extra

	nParams = n_params()

	case nParams of
		1: self._oROI->appendData, x, _EXTRA=_extra
		2: self._oROI->appendData, x, y, _EXTRA=_extra
		3: self._oROI->appendData, x, y, z, EXTRA=_extra
		else: return
	endcase

	; Update location of text if this is the first vertex in the ROI
	self._oROI->getProperty, DATA=verts, N_VERTS=nVerts
	if nVerts eq 1 then begin
		self._oText->setProperty, LOCATION=(verts[*,0])
	endif

end ; of MKgrROI::appendData


pro MKgrROI::replaceData, x, y, z, _EXTRA=_extra

	nParams = n_params()

	case nParams of
		1: self._oROI->replaceData, x, _EXTRA=_extra
		2: self._oROI->replaceData, x, y, _EXTRA=_extra
		3: self._oROI->replaceData, x, y, z, EXTRA=_extra
		else: return
	endcase

	; Update location of text
	self._oROI->getProperty, DATA=verts
	self._oText->setProperty, LOCATION=(verts[*,0])

end ; of MKgrROI::replaceData


function MKgrROI::pickVertex, dest, view, point, _STRICT_EXTRA=_extra

	if n_elements( _extra ) gt 0 then begin
		return, self._oROI->pickVertex( dest, view, point, _extra )
	endif else begin
		return, self._oROI->pickVertex( dest, view, point )
	endelse

end ; of MKgrROI::pickVertex


pro MKgrROI::translate, x, y, z

	nParams = n_params()

	case nParams of
		1: self._oROI->translate, x
		2: self._oROI->translate, x, y
		3: self._oROI->translate, x, y, z
		else: return
	endcase

	; Update location of text
	self._oROI->getProperty, DATA=verts
	self._oText->setProperty, LOCATION=(verts[*,0])

end ; of MKgrROI::translate


function MKgrROI::computeMask, _STRICT_EXTRA=_extra

	return, self._oROI->computeMask( _extra )

end ; of MKgrROI::computeMask


pro MKgrROI__define

	struct = {	MKgrROI, inherits IDLgrModel, $
				_oROI:		obj_new(), $
				_oText:		obj_new(), $
				bHideText:	0b, $
				textAnchor:	[0,0] }

end ; of MKgrROI__define
