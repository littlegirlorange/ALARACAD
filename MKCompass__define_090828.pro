;+
; NAME:
;       MKCompass
;
; FILENAME:
;
;       MKCompass__define.pro
;;
; PURPOSE:
;
;       The purpose of this program is to create a horizontal
;       colorbar object to be used in conjunction with other
;       IDL 5 graphics objects.
;
; AUTHOR:
;
;       FANNING SOFTWARE CONSULTING
;       David Fanning, Ph.D.
;       1645 Sheely Drive
;       Fort Collins, CO 80526 USA
;       Phone: 970-221-0438
;       E-mail: davidf@dfanning.com
;       Coyote's Guide to IDL Programming: http://www.dfanning.com/
;
; CATEGORY:
;
;       Object Graphics.
;
; CALLING SEQUENCE:
;
;       oCompass = Obj_New('MKCompass')
;
; REQUIRED INPUTS:
;
;       None.
;
; INIT METHOD KEYWORD PARAMETERS:
;
;       COLOR: A three-element array representing the RGB values of a color
;          for the colorbar axes and annotation. The default value is
;          white: [255,255,255].
;
;       FONTSIZE: A floating value that is the point size of the font
;           used for the axis and title annotations. Set to 8 point by default.
;
;       NAME: The name associated with this object.
;
;       POSITION: A four-element array specifying the position of the
;           colorbar in normalized coordinate space. The default position
;           is [0.10, 0.90, 0.90, 0.95].
;
; OTHER METHODS:
;
;       GetProperty (Procedure): Returns colorbar properties in keyword
;          parameters as defined for the INIT method. Keywords allowed are:
;
;               COLOR
;               NAME
;               POSITION
;               TRANSFORM
;
;       SetProperty (Procedure): Sets colorbar properties in keyword
;          parameters as defined for the INIT method. Keywords allowed are:
;
;               COLOR
;               NAME
;               POSITION
;               TRANSFORM
;
; SIDE EFFECTS:
;
;       A MKCompass structure is created. The colorbar INHERITS IDLgrMODEL.
;       Thus, all IDLgrMODEL methods and keywords can also be used. It is
;       the model that is selected in a selection event, since the SELECT_TARGET
;       keyword is set for the model.
;
; RESTRICTIONS:
;
;       Requires NORMALIZE from Coyote Library:
;
;         http://www.dfanning.com/programs/normalize.pro
;
; EXAMPLE:
;
;       To create a compass object and add it to a plot view object, type:
;
;       oCompass = Obj_New('MKCompass')
;       plotView->Add, oCompass
;       plotWindow->Draw, plotView
;
; MODIFICATION HISTORY:
;
;       Written by David Fanning, from VColorBar code, 20 Sept 98. DWF.
;       Changed a reference to _Ref_Extra to _Extra. 27 Sept 98. DWF.
;       Fixed bug when adding a text object via the TEXT keyword. 9 May 99. DWF.
;       Fixed the same bug when getting the text using the TEXT keyword. :-( 16 Aug 2000. DWF.
;       Fixed a bug with getting the text object via the TEXT keyword. 16 Aug 2000. DWF.
;       Added the TRANSFORM keyword to GetProperty and SetProperty methods. 16 Aug 2000. DWF.
;       Added RECOMPUTE_DIMENSIONS=2 to text objects. 16 Aug 2000. DWF.
;       Added a polygon object around the image object. This allows rotation in 3D space. 16 Aug 2000. DWF.
;       Removed TEXT keyword (which was never used) and improved documentation. 15 AUG 2001. DWF.
;       Added ENABLE_FORMATTING keyword to title objects. 22 October 2001. DWF.
;       Added a CLAMP method. 18 November 2001. DWF.
;       Forgot to pass extra keywords along to the text widget. As a result, you couldn't
;          format tick labels, etc. Fixed this. Any keywords appropriate for IDLgrTick objects
;          are now available. 26 June 2002. DWF.
;       Fixed a problem with POSITION keyword in SetProperty method. 23 May 2003. DWF.
;       Fixed a problem with setting RANGE keyword in SetProperty method. 6 Sept 2003. DWF.
;       Removed NORMALIZE from source code. 19 November 2005. DWF.
;		080405 - MK - Fixed POSITION keyword in SetProperty. Axes were begin left behind
;			and texts were reset to default values.  Weird quirk with IDLgrAxis.
;-
;
;###########################################################################
;
; LICENSE
;
; This software is OSI Certified Open Source Software.
; OSI Certified is a certification mark of the Open Source Initiative.
;
; Copyright © 2000-2005 Fanning Software Consulting.
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


FUNCTION MKCompass::INIT, Position=position, $
	NORTH=north, $
	VPSIZE=vpSize, $
	Color=color, $
    Name=name, $
    FontSize=fontsize, $
    _Extra=extra

   ; Catch possible errors.

Catch, error
IF error NE 0 THEN BEGIN
   Catch, /Cancel
   ok = Dialog_Message(!Error_State.Msg)
   Message, !Error_State.Msg, /Informational
   RETURN, 0
ENDIF

   ; Initialize superclass.

IF (self->IDLgrModel::Init(_EXTRA=extra) NE 1) THEN RETURN, 0

    ; Define default values for keywords, if necessary.

IF N_Elements(name) EQ 0 THEN name=''
IF N_Elements(color) EQ 0 THEN self.color = [255,255,255] $
   ELSE self.color = color
IF N_Elements(fontsize) EQ 0 THEN fontsize = 8.0
thisFont = Obj_New('IDLgrFont', 'Helvetica', Size=fontsize)
thisTitle = Obj_New('IDLgrText', 'N', Color=self.color, $
    Font=thisFont, Recompute_Dimensions=2, /Enable_Formatting, $
    ALIGNMENT=0.5, VERTICAL_ALIGNMENT=0.5 )
IF N_Elements(position) EQ 0 THEN self.position = [0.8,0.8] $
   ELSE self.position = position
whRatio = float(vpSize[0])/vpSize[1]

    ; Create scale factors to position the axes.

longXConv = [0,1]
longYConv = Normalize([0,1], $
		Position=[self.position[1]-0.08,self.position[1]+0.08])
shortXConv = Normalize([0,1], $
		Position=[self.position[0]-0.04/whRatio,self.position[0]+0.04/whRatio])
shortYConv = [0,1]

    ; Create the compass axes.

shortAxis = Obj_New("IDLgrAxis", 0, Color=self.color, RANGE=[0,1], $
    Major=0, Minor=0, /NOTEXT, $
    XCoord_Conv=shortXConv, YCOORD_CONV=shortYConv, /EXACT, $
    Location=self.position, _Extra=extra )
longAxis = obj_new( 'IDLgrAxis', 1, COLOR=self.color, RANGE=[0,1], $
	MAJOR=0, MINOR=0, /NOTEXT, $
	XCOORD_CONV=longXConv, YCoord_Conv=longYConv, /EXACT, $
	LOCATION=self.position, _EXTRA=extra )
thisTitle->setProperty, LOCATION=[self.position[0],self.position[1]+0.09]

    ; Add the parts to the model.

self->Add, shortAxis
self->add, longAxis
self->add, thisTitle
if north ne 0 then begin
	self->translate, -self.position[0], -self.position[1], 0
	self->rotate, [0,0,1], -90*north
	if north eq 1 or north eq 3 then begin
		if whRatio gt 1 then begin
			self->scale, 1.0/whRatio, 1.0*whRatio, 1.0
		endif else if whRatio lt 1 then begin
			self->scale, 1.0*whRatio, 1.0/whRatio, 1.0
		endif
	endif
	self->translate, self.position[0], self.position[1], 0
endif

   ; Assign the name.

self->IDLgrModel::SetProperty, Name=name, Select_Target=1

    ; Create a container object and put the model into it.

thisContainer = Obj_New('IDL_Container')
thisContainer->Add, thisFont
thisContainer->Add, thisTitle
thisContainer->Add, shortAxis
thisContainer->add, longAxis

    ; Update the SELF structure.

self.thisFont = thisFont
self.shortAxis = shortAxis
self.longAxis = longAxis
self.thisContainer = thisContainer
self.thisTitle = thisTitle
self.fontsize = fontsize
self.north = north
self.whRatio = whRatio

RETURN, 1
END
;-------------------------------------------------------------------------



PRO MKCompass::Cleanup

    ; Lifecycle method to clean itself up.

Obj_Destroy, self.thisContainer
self->IDLgrMODEL::Cleanup
END
;-------------------------------------------------------------------------



PRO MKCompass::GetProperty, Position=position, $
    Color=color, Transform=transform, Name=name, _Ref_Extra=extra

    ; Get the properties of the colorbar.

IF Arg_Present(position) THEN position = self.position
IF Arg_Present(color) THEN color = self.color
IF Arg_Present(name) THEN self->IDLgrMODEL::GetProperty, Name=name
IF Arg_Present(transform) THEN self->IDLgrMODEL::GetProperty, Transform=transform
IF Arg_Present(extra) THEN self->IDLgrMODEL::GetProperty, _Ref_Extra=extra

END
;-------------------------------------------------------------------------



PRO MKCompass::SetProperty, Position=position, NORTH=north, $
    Color=color, Transform=transform, Name=name, _Extra=extra

    ; Set properties of the colorbar.

IF N_Elements(position) NE 0 THEN BEGIN
    self.position = position
    whRatio = self.whRatio

	longXConv = [0,1]
	longYConv = Normalize([0,1], $
			Position=[self.position[1]-0.08,self.position[1]+0.08])
	shortXConv = Normalize([0,1], $
			Position=[self.position[0]-0.04/whRatio,self.position[0]+0.04/whRatio])
	shortYConv = [0,1]

	    ; Create the compass axes.

	self.shortAxis->setProperty, $
	    XCoord_Conv=shortXConv, YCOORD_CONV=shortYConv, LOCATION=self.position
	self.longAxis->setProperty, $
		XCOORD_CONV=longXConv, YCoord_Conv=longYConv, LOCATION=self.position
	self.thisTitle->setProperty, LOCATION=[self.position[0],self.position[1]+0.09]
ENDIF
if n_elements(north) ne 0 then begin
	self.north = north
	whRatio = self.whRatio
	self->reset
	if north ne 0 then begin
		self->translate, -self.position[0], -self.position[1], 0
		self->rotate, [0,0,1], -90*north
		if north eq 1 or north eq 3 then begin
			if whRatio gt 1 then begin
				self->scale, 1.0/whRatio, 1.0*whRatio, 1.0
			endif else if whRatio lt 1 then begin
				self->scale, 1.0*whRatio, 1.0/whRatio, 1.0
			endif
		endif
		self->translate, self.position[0], self.position[1], 0
	endif
endif
IF N_Elements(transform) NE 0 THEN self->IDLgrMODEL::SetProperty, Transform=transform
IF N_Elements(color) NE 0 THEN BEGIN
    self.color = color
    self.shortAxis->SetProperty, Color=color
ENDIF
IF N_Elements(name) NE 0 THEN self->IDLgrMODEL::SetProperty, Name=name
IF N_Elements(extra) NE 0 THEN BEGIN
   self->IDLgrMODEL::SetProperty, _Extra=extra
   self.shortAxis->SetProperty, _Extra=extra
   self.longAixs->setProperty, _EXTRA=extra
   self.thisTitle->SetProperty, _Extra=extra
ENDIF
END
;-------------------------------------------------------------------------



PRO MKCompass__Define

ruler = { MKCompass, $
             INHERITS IDLgrMODEL, $      ; Inherits the Model Object.
             Position:FltArr(2), $       ; The position of the ruler.
             thisContainer:Obj_New(), $  ; Container for cleaning up.
             thisFont:Obj_New(), $       ; The annotation font object.
             thisTitle:Obj_New(), $		 ; The annotation text object.
             shortAxis:Obj_New(), $       ; The axis containing annotation.
             longAxis:obj_new(), $
             fontsize:0.0, $             ; The font size of the axis labels. 8 pt by default.
             north:0, $					 ; The direction of north (0=t,1=r,2=b,3=l)
             whRatio:1.0, $				 ; The width:height ratio of the viewport
             Color:BytArr(3) }           ; The range of the colorbar axis.

END
;-------------------------------------------------------------------------