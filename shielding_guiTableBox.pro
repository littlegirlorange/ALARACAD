;+
; NAME:
;  shielding_guiTableBox
;
; PURPOSE:
;
;  This function allows the user to type some text in a
;  pop-up dialog widget and have it returned to the program.
;  This is an example of a Pop-Up Dialog Widget.
;
; AUTHOR:
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
;  thetext = shielding_guiTableBox()
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
;       theText = shielding_guiTableBox(Title='Provide Phone Number...', Label='Number:', Cancel=cancelled)
;       IF cancelled THEN Return
;
;  GROUP_LEADER: The widget ID of the group leader of this pop-up
;       dialog. This should be provided if you are calling
;       the program from within a widget program:
;
;          thetext = shielding_guiTableBox(Group_Leader=event.top)
;
;       If a group leader is not provided, an unmapped top-level base widget
;       will be created as a group leader.
;
;  LABEL: A string the appears to the left of the text box.
;
;  TITLE:  The title of the top-level base. If not specified, the
;       string 'Provide Input:' is used by default.
;
;  VALUE: A string variable that is the intial value of the shielding_guiTableBox. By default, a null string.
;
;  XSIZE: The size of the text widget in pixel units. By default, 200.
;
; OUTPUTS:
;
;  theText: The string of characters the user typed in the
;       text widget. No error checking is done.
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
;  Written by: David W. Fanning, December 20, 2001.
;  Added VALUE keyword to set the initial value of the text box. 4 Nov 2002. DWF.
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


PRO shielding_guiTableBox_CenterTLB, tlb

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



PRO shielding_guiTableBox_Event, event

   ; This event handler responds to all events. Widget
   ; is always destoyed. The text is recorded if ACCEPT
   ; button is selected or user hits CR in text widget.

	Widget_Control, event.top, Get_UValue=info
	if info.bEditable then begin
		CASE event.ID OF
			info.wCancelButton: widget_control, event.top, /DESTROY
			info.wAcceptButton: begin
				widget_control, info.wTable, GET_VALUE=value
				(*info.ptr).data = value
				(*info.ptr).cancel = 0
				widget_control, event.top, /DESTROY
			end
			else:
		ENDCASE
	endif else begin
		widget_control, event.top, /DESTROY
	endelse

END ;-----------------------------------------------------



FUNCTION shielding_guiTableBox, Title=title, $
				  ROW_LABLES=rowLabels, $
				  COLUMN_LABELS=colLabels, $
				  DATA=dataIn, $
				  ALIGNMENT=alignment, $
				  EDITABLE=bEditable, $
   				  GROUP_LEADER=groupleader, $
   				  XSIZE=xSize, $
   				  CANCEL=cancel			; out

   ; Return to caller if there is an error. Set the cancel
   ; flag and destroy the group leader if it was created.

Catch, theError
IF theError NE 0 THEN BEGIN
   Catch, /Cancel
   ok = Dialog_Message(!Error_State.Msg)
   cancel = 1
   RETURN, 0
ENDIF

   ; Check parameters and keywords.

if n_elements(title) eq 0 then title = 'Table Data'
if n_elements(rowLabels) eq 0 then begin
	rowLabels = ''
endif else begin
	rowLabels = strtrim( rowLabels, 2 )
endelse
if n_elements(colLabels) eq 0 then begin
	colLabels = ''
endif else begin
	colLabels = strtrim( colLabels, 2 )
endelse
if n_elements(dataIn) eq 0 then begin
	return, -1L
endif else begin
	dataIn = strtrim( dataIn, 2 )
endelse
if n_elements(alignment) eq 0 then begin
	alignment = 0
endif
if n_elements(bEditable) eq 0 then begin
	bEditable = 0b
endif else begin
	bEditable = 1b
endelse
if n_elements(xSize) eq 0 then xSize = 200

   ; Provide a group leader if not supplied with one. This
   ; is required for modal operation of widgets. Set a flag
   ; for destroying the group leader widget before returning.

if n_elements(groupLeader) eq 0 then begin
	groupLeader = widget_base( MAP=0 )
	widget_control, groupLeader, /REALIZE
	destroy_groupleader = 1
endif else destroy_groupleader = 0

   ; Create modal base widget.

tlb = widget_base( TITLE=title, COLUMN=1, /MODAL, $
   /BASE_ALIGN_CENTER, GROUP_LEADER=groupLeader )

   ; Create the rest of the widgets.

wTableBase = widget_base( tlb, /ROW )
labelWidths = strlen( colLabels )
dataWidths = max( strlen( dataIn ), DIMENSION=2 )
colWidths = max( [[labelWidths],[dataWidths]], DIMENSION=2 ) * 12
wTable =widget_table( wTableBase, VALUE=dataIn, $
		COLUMN_LABELS=colLabels, ROW_LABELS=rowLabels, $
		COLUMN_WIDTHS=colWidths, ALIGNMENT=alignment, $
		EDITABLE=bEditable )

buttonBase = Widget_Base(tlb, Row=1)
if bEditable then begin
	wCancelButton = widget_button(buttonBase, Value='Cancel')
	wAcceptButton = widget_button(buttonBase, Value='Accept')
	widget_control, wAcceptButton, /INPUT_FOCUS
endif else begin
	wCloseButton = widget_button( buttonBase, VALUE='Close Window' )
	widget_control, wCloseButton, /INPUT_FOCUS
endelse

shielding_guiTableBox_CenterTLB, tlb
widget_control, tlb, /REALIZE

   ; Create a pointer for the text the user will type into the program.
   ; The cancel field is set to 1 to indicate that the user canceled
   ; the operation. Only if a successful conclusion is reached (i.e.,
   ; a Carriage Return or Accept button selection) is the cancel field
   ; set to 0.

ptr = Ptr_New({	data:			dataIn, $
				cancel:			1})

   ; Store the program information:

if bEditable then begin
	info = { ptr:				ptr, $
			 bEditable:			bEditable, $
			 wTable:			wDropList, $
			 wCancelButton:		wCancelButton, $
			 wAcceptButton:		wAcceptButton }
endif else begin
	info = { ptr:				ptr, $
			 bEditable:			bEditable, $
			 wCloseButton:		wCloseButton }
endelse

widget_control, tlb, SET_UVALUE=info, /NO_COPY

   ; Blocking or modal widget, depending upon group leader.

xmanager, 'shielding_guiTableBox', tlb

   ; Return from block. Return the text to the caller of the program,
   ; taking care to clean up pointer and group leader, if needed.
   ; Set the cancel keyword.

dataOut	= (*ptr).data
cancel	= (*ptr).cancel
Ptr_Free, ptr
IF destroy_groupleader THEN Widget_Control, groupleader, /Destroy

RETURN, 1
END ;-----------------------------------------------------


