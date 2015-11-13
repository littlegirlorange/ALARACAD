;+
; NAME:
;  shielding_gui_prompt_box
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
;  thetext = shielding_gui_prompt_box()
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
;       theText = shielding_gui_prompt_box(Title='Provide Phone Number...', Label='Number:', Cancel=cancelled)
;       IF cancelled THEN Return
;
;  GROUP_LEADER: The widget ID of the group leader of this pop-up
;       dialog. This should be provided if you are calling
;       the program from within a widget program:
;
;          thetext = shielding_gui_prompt_box(Group_Leader=event.top)
;
;       If a group leader is not provided, an unmapped top-level base widget
;       will be created as a group leader.
;
;  LABEL: A string the appears to the left of the text box.
;
;  TITLE:  The title of the top-level base. If not specified, the
;       string 'Provide Input:' is used by default.
;
;  VALUE: A string variable that is the intial value of the shielding_gui_prompt_box. By default, a null string.
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


PRO shielding_gui_prompt_box_CenterTLB, tlb

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



PRO shielding_gui_prompt_box_Event, event

   ; This event handler responds to all events. Widget
   ; is always destoyed. The text is recorded if ACCEPT
   ; button is selected or user hits CR in text widget.

	Widget_Control, event.top, Get_UValue=info

	if tag_names( event, /STRUCT ) eq 'WIDGET_TEXT_CH' then begin
		if event.ch eq 9b then begin
			index = where( info.wTextValueArray eq event.id, count )
			if count eq 0 then return
			nIndices = n_elements( info.wTextValueArray )
			if (index+1) lt (nIndices-1) then begin
				widget_control, info.wTextValueArray[index+1], /INPUT_FOCUS
			endif else begin
				widget_control, info.wAcceptButton, /INPUT_FOCUS
			endelse
		endif
	endif

	CASE event.ID OF

		info.wCancelButton: widget_control, event.top, /DESTROY

		info.wAcceptButton: begin

			index = widget_info( info.wDropList, /DROPLIST_SELECT )
			(*info.ptr).dropIndex = index
			; Get the text and store it in the pointer location.
			for i=0, n_elements( info.wTextValueArray )-1 do begin
				widget_control, info.wTextValueArray[i], GET_VALUE=theText
				(*info.ptr).textValues[i] = theText[0]
			endfor
			(*info.ptr).cancel = 0
			widget_control, event.top, /DESTROY
		end

		else:

	ENDCASE

END ;-----------------------------------------------------



FUNCTION shielding_gui_prompt_box, Title=title, $
				  Drop_Label=dropLabel, $
				  Drop_Values=dropValues, $
				  Drop_Index=dropIndex, $
				  Text_Labels=textLabels, $
				  Text_Values=textValues, $
   				  Group_Leader=groupleader, $
   				  XSize=xsize, $
   				  THE_INDEX=theIndex, $	; out
   				  THE_TEXT=theText, $	; out
   				  CANCEL=cancel			; out

   ; Return to caller if there is an error. Set the cancel
   ; flag and destroy the group leader if it was created.

Catch, theError
IF theError NE 0 THEN BEGIN
   Catch, /Cancel
   ok = Dialog_Message(!Error_State.Msg)
   cancel = 1
   RETURN, ""
ENDIF

   ; Check parameters and keywords.

IF N_Elements(title) EQ 0 THEN title = 'Provide Input:'
if n_elements(dropLabel) eq 0 then dropLabel=''
if n_elements(dropValues) eq 0 then dropValues = ['']
if n_elements(dropIndex) eq 0 then dropIndex = 0
IF N_Elements(textLabels) EQ 0 THEN textLabels = [""]
IF N_Elements(textValues) EQ 0 THEN textValues = [""]
IF N_Elements(xsize) EQ 0 THEN xsize = 200

   ; Provide a group leader if not supplied with one. This
   ; is required for modal operation of widgets. Set a flag
   ; for destroying the group leader widget before returning.

IF N_Elements(groupleader) EQ 0 THEN BEGIN
   groupleader = Widget_Base(Map=0)
   Widget_Control, groupleader, /Realize
   destroy_groupleader = 1
ENDIF ELSE destroy_groupleader = 0

   ; Create modal base widget.

tlb = Widget_Base(Title=title, Column=1, /Modal, $
   /Base_Align_Center, Group_Leader=groupleader )

   ; Create the rest of the widgets.

wDropBase = widget_base( tlb, /ROW )
wDropLabel = widget_label( wDropBase, VALUE=dropLabel )
wDropList = widget_droplist( wDropBase, VALUE=dropValues )
widget_control, wDropList, SET_DROPLIST_SELECT=dropIndex

if textLabels[0] eq '' then begin
	wTextBase = widget_base()
endif else begin
	wTextBase = widget_base( tlb, /COLUMN )
endelse
wTextBaseArray = lonarr( n_elements( textLabels ) )
wTextLabelArray = wTextBaseArray
wTextValueArray = wTextBaseArray

maxWidth = 0

for i=0, n_elements( textLabels )-1 do begin
		wTextBaseArray[i]	= Widget_Base(wtextBase, Row=1)
		wTextLabelArray[i]	= Widget_Label(wTextBaseArray[i], Value=textLabels[i])
		wTextValueArray[i]	= Widget_Text(wTextBaseArray[i], /Editable, $
							  XSize=xsize, Value=textValues[i], /ALL_EVENTS )
		geom = widget_info( wTextLabelArray[i], /GEOMETRY )
		if geom.xsize gt maxWidth then maxWidth = geom.xsize
endfor
for i=0, n_elements( textLabels )-1 do begin
		widget_control, wTextLabelArray[i], XSIZE=maxWidth
endfor

buttonBase = Widget_Base(tlb, Row=1)
wCancelButton = Widget_Button(buttonBase, Value='Cancel')
wAcceptButton = Widget_Button(buttonBase, Value='Accept')

   ; Center the widgets on display.

shielding_gui_prompt_box_CenterTLB, tlb
Widget_Control, tlb, /Realize
widget_control, wAcceptButton, /INPUT_FOCUS

   ; Create a pointer for the text the user will type into the program.
   ; The cancel field is set to 1 to indicate that the user canceled
   ; the operation. Only if a successful conclusion is reached (i.e.,
   ; a Carriage Return or Accept button selection) is the cancel field
   ; set to 0.

ptr = Ptr_New({dropIndex:0, textValues:strarr( n_elements( textLabels ) ), cancel:1})

   ; Store the program information:

info = { ptr:				ptr, $
		 wDropList:			wDropList, $
		 wTextValueArray:	wTextValueArray, $
		 wCancelButton:		wCancelButton, $
		 wAcceptButton:		wAcceptButton }

Widget_Control, tlb, Set_UValue=info, /No_Copy

   ; Blocking or modal widget, depending upon group leader.

XManager, 'shielding_gui_prompt_box', tlb

   ; Return from block. Return the text to the caller of the program,
   ; taking care to clean up pointer and group leader, if needed.
   ; Set the cancel keyword.

theIndex	= (*ptr).dropIndex
theText		= (*ptr).textValues
cancel		= (*ptr).cancel
Ptr_Free, ptr
IF destroy_groupleader THEN Widget_Control, groupleader, /Destroy

RETURN, 1
END ;-----------------------------------------------------


