;+
; NAME:
;  shielding_guiNewProtocol
;
; PURPOSE:
;
;  This function allows the user to type some text in a
;  pop-up dialog widget and have it returned to the program.
;  This is an example of a Pop-Up Dialog Widget.
;
; AUTHOR:
;  Maggie Kusano, February 11, 2009
;
;  Based on textbox.pro by:
;
;       FANNING SOFTWARE CONSULTING
;       David Fanning, Ph.D.
;       1645 Sheely Drive
;       Fort Collins, CO 80526 USA
;       Phone: 970-221-0438
;       E-mail: davidf@dfanning.com
;       Coyote's Guide to IDL Programming: http://www.dfanning.com
;
; CATEGORY:
;
;  Utility, Widgets
;
; CALLING SEQUENCE:
;
;  thetext = shielding_guiNewProtocol()
;
; INPUTS:
;
;  None.
;
; KEYWORD PARAMETERS:
;
;  CANCEL: An output parameter. If the user kills the widget or clicks the Cancel
;       button this keyword is set to 1. It is set to 0 otherwise. It
;       allows you to determine if the user canceled the dialog without
;       having to check the validity of the answer.
;
;       theText = shielding_guiNewProtocol(Title='Provide Phone Number...', Label='Number:', Cancel=cancelled)
;       IF cancelled THEN Return
;
;  GROUP_LEADER: The widget ID of the group leader of this pop-up
;       dialog. This should be provided if you are calling
;       the program from within a widget program:
;
;          thetext = shielding_guiNewProtocol(Group_Leader=event.top)
;
;       If a group leader is not provided, an unmapped top-level base widget
;       will be created as a group leader.
;
;  XSIZE: The size of the text widget in pixel units. By default, 200.
;
; OUTPUTS:
;
; RESTRICTIONS:
;
;  The widget is destroyed if the user clicks on either button or
;  if they hit a carriage return (CR) in the text widget. The
;  text is recorded if the user hits the ACCEPT button or hits
;  a CR in the text widget.
;
; MODIFICATION HISTORY:
;
;-
;
;###########################################################################
;
; LICENSE
;
; This software is OSI Certified Open Source Software.
; OSI Certified is a certification mark of the Open Source Initiative.
;
; Copyright © 2000-2002 Fanning Software Consulting.
;
; This software is provided "as-is", without any express or
; implied warranty. In no event will the authors be held liable
; for any damages arising from the use of this software.
;
; Permission is granted to anyone to use this software for any
; purpose, including commercial applications, and to alter it and
; redistribute it freely, subject to the following restrictions:
;
; 1. The origin of this software must not be misrepresented; you must
;    not claim you wrote the original software. If you use this software
;    in a product, an acknowledgment in the product documentation
;    would be appreciated, but is not required.
;
; 2. Altered source versions must be plainly marked as such, and must
;    not be misrepresented as being the original software.
;
; 3. This notice may not be removed or altered from any source distribution.
;
; For more information on Open Source Software, visit the Open Source
; web site: http://www.opensource.org.
;
;###########################################################################


PRO shielding_guiNewProtocol_CenterTLB, tlb

   ; This utility routine centers the TLB.

Device, Get_Screen_Size=screenSize
IF screenSize[0] GT 2000 THEN screenSize[0] = screenSize[0]/2 ; Dual monitors.
xCenter = screenSize(0) / 2
yCenter = screenSize(1) / 2

geom = Widget_Info(tlb, /Geometry)
xHalfSize = geom.Scr_XSize / 2
yHalfSize = geom.Scr_YSize / 2

Widget_Control, tlb, XOffset = xCenter-xHalfSize, $
   YOffset = yCenter-yHalfSize

END ;-----------------------------------------------------



PRO shielding_guiNewProtocol_Event, event

   ; This event handler responds to all events. Widget
   ; is always destoyed. The text is recorded if ACCEPT
   ; button is selected or user hits CR in text widget.

	Widget_Control, event.top, Get_UValue=info

	CASE event.ID OF

		info.wCancelButton: widget_control, event.top, /DESTROY

		info.wAcceptButton: begin
			; Get name
			widget_control, info.wNameText, GET_VALUE=name
			(*info.ptr).protocol = name
			; Get tracer index
			index = widget_info( info.wTracerList, /DROPLIST_SELECT )
			(*info.ptr).iTracer = index
			; Get activity
			widget_control, info.wActivityText, GET_VALUE=activity
			(*info.ptr).a0 = activity
			; Get no. patients
			widget_control, info.wNPatientsText, GET_VALUE=nPats
			(*info.ptr).na = nPats
			; Get table
			widget_control, info.wTable, GET_VALUE=table
			(*info.ptr).table = table
			(*info.ptr).cancel = 0
			widget_control, event.top, /DESTROY
		end

		else:

	ENDCASE

END ;-----------------------------------------------------



FUNCTION shielding_guiNewProtocol, $
	PARENT		= parent, $
	MODALITY	= modality, $
	SOURCES		= sources, $		; out
	CANCEL		= cancel			; out

   ; Return to caller if there is an error. Set the cancel
   ; flag and destroy the group leader if it was created.

Catch, theError
IF theError NE 0 THEN BEGIN
   Catch, /Cancel
   ok = Dialog_Message(!Error_State.Msg)
   IF destroy_groupleader THEN Widget_Control, groupleader, /Destroy
   cancel = 1
   heap_free, tracers
   RETURN, 0
ENDIF

if n_elements( modality ) eq 0 then modality = 'PET'
if modality eq 'PET' then begin
	@'shielding_gui_PET_tracer_specs'
endif else begin
	@'shielding_gui_SPECT_tracer_specs'
endelse


   ; Check parameters and keywords.
title = 'New protocol'
xsize = 200

   ; Provide a group leader if not supplied with one. This
   ; is required for modal operation of widgets. Set a flag
   ; for destroying the group leader widget before returning.

destroy_groupleader = 0

   ; Create modal base widget.

tlb = widget_base( TITLE='New protocol', COLUMN=1, /MODAL, $
   /Base_Align_Center, Group_Leader=parent )

   ; Create the rest of the widgets.

wBase = widget_base( tlb, /ROW )
wNameLabel = widget_label( wBase, VALUE='Protocol name:' )
wNameText = widget_text( wBase, /EDITABLE, XSIZE=xSize )
wBase = widget_base( tlb, /ROW )
wTracerLabel = widget_label( wBase, VALUE='Tracer:' )
wTracerList = widget_droplist( wBase, VALUE=tracers.name )
wBase = widget_base( tlb, /ROW )
wActivityLabel = widget_label( wBase, VALUE='Admin activity (GBq)' )
wActivityText = widget_text( wBase, /EDITABLE, XSIZE=xSize )
wBase = widget_base( tlb, /ROW )
wNPatientsLabel = widget_label( wBase, VALUE='No patients/yr' )
wNPatientsText = widget_text( wBase, /EDITABLE, XSIZE=xSize )
wTableBase = widget_base( tlb, /ROW )
colLabels = ['Point', 'Desc', 't1 (min)', 't2 (min)', 'PV', 'SS', 'Frac']
nCols = n_elements( colLabels )
nRows = 10
labelWidths = strlen( colLabels )
colWidths = make_array( n_elements(colLabels), /INT, VALUE=50 )
colWidths[1] = 200 ; make the description column wider
wTable =widget_table( wTableBase, YSIZE=10, $
		COLUMN_LABELS=colLabels, $
		COLUMN_WIDTHS=colWidths, /EDITABLE )

buttonBase = Widget_Base(tlb, Row=1)
wCancelButton = Widget_Button(buttonBase, Value='Cancel')
wAcceptButton = Widget_Button(buttonBase, Value='Accept')

   ; Center the widgets on display.

shielding_guiNewProtocol_CenterTLB, tlb
Widget_Control, tlb, /Realize
widget_control, wAcceptButton, /INPUT_FOCUS

   ; Create a pointer for the text the user will type into the program.
   ; The cancel field is set to 1 to indicate that the user canceled
   ; the operation. Only if a successful conclusion is reached (i.e.,
   ; a Carriage Return or Accept button selection) is the cancel field
   ; set to 0.

ptr = Ptr_New({$
		tracers:	tracers.name, $
		protocol:	'', $
		iTracer:	0, $
		a0:			0.0, $
		na:			0, $
		table:		strarr(nCols,nRows), $
		cancel:		0})

   ; Store the program information:

info = { ptr:				ptr, $
		 wNameText:			wNameText, $
		 wTracerList:		wTracerList, $
		 wActivityText:		wActivityText, $
		 wNPatientsText:	wNPatientsText, $
		 wTable:			wTable, $
		 wCancelButton:		wCancelButton, $
		 wAcceptButton:		wAcceptButton }

Widget_Control, tlb, Set_UValue=info, /No_Copy

heap_free, tracers

   ; Blocking or modal widget, depending upon group leader.

XManager, 'shielding_guiNewProtocol', tlb

   ; Return from block. Return the text to the caller of the program,
   ; taking care to clean up pointer and group leader, if needed.
   ; Set the cancel keyword.

table = (*ptr).table
indices = where( table[0,*] ne '', count )
sources = replicate( {source, $
	point:		'', $
	protocol:	'', $
	tracer:		'', $
	a0:			0.0, $
	na:			0, $
	t1:			0.0, $
	t2:			0.0, $
	pv:			0.0, $
	ss:			0.0, $
	desc:		''}, count )

for i=0, count-1 do begin
	s = sources[i]
	s.point = table[0,indices[i]]
	s.protocol = (*ptr).protocol
	s.tracer = ((*ptr).tracers)[(*ptr).iTracer]
	s.a0 = (*ptr).a0
	s.na = strtrim(float((*ptr).na)/float(table[6,indices[i]]),2)
	s.t1 = table[2,indices[i]]
	s.t2 = table[3,indices[i]]
	s.pv = table[4,indices[i]]
	s.ss = table[5,indices[i]]
	s.desc = table[1,indices[i]]
	sources[i] = s
endfor
cancel = (*ptr).cancel

ptr_free, ptr

return, 1

END ;-----------------------------------------------------


