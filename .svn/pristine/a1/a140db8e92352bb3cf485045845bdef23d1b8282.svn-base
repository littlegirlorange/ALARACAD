function undoInfo::init, ACTION=action, OROI=oROI, TABLE_DATA=tableData

	self.action = action
	self.oROI = oROI
	self.pTableData = ptr_new( tableData )
	if obj_valid(oROI) then begin
		oROI->getProperty, NAME=name
		self.roiName = name
	endif
	return, 1

end ; of undoInfo::init


pro undoInfo::cleanup

	ptr_free, self.pTableData

end ; of undoInfo::cleanup


pro undoInfo::getProperty, ACTION=action, TABLE_DATA=tableData, NAME=name, PREFIX=prefix, OROI=oROI

	if arg_present( action ) then $
		action = self.action
	if arg_present( name ) then $
		name = self.roiName
	if arg_present( prefix ) then $
		prefix = (strsplit( self.roiName, '_', /EXTRACT ))[0]
	if arg_present( tableData ) then $
		tableData = *(self.pTableData)
	if arg_present( oROI ) then $
		oROI = self.oROI

end ; of undoInfo::getProperty

pro undoInfo::setProperty, ACTION=action, TABLE_DATA=tableData, OROI=oROI

	if n_elements( action ) ne 0 then $
		self.action = self.action
	if n_elements( tableData ) ne 0 then begin
		ptr_free, self.pTableData
		self.pTableData = ptr_new( tableData )
	end
	if n_elements( oROI ) then $
		 self.oROI = oROI

end ; of undoInfo::setProperty

pro undoInfo__define

	struct = {	undoInfo, $
				action:		'', $
				pTableData:	ptr_new(/ALLOCATE_HEAP), $
				oROI:		obj_new(), $
				roiName:	'' }

end ; of undoInfo__define
