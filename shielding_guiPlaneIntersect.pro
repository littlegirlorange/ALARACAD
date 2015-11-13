;==============================================================================
;
;	Method:		shielding_guiPlaneIntersect
;
;	Description:
;				Calculates the intersection of a line and a plane given
;				two points on the line and three points on the plane.
;				Based on the equations given by Paul Bourke
;				http://local.wasp.uwa.edu.au/~pbourke/geometry/planeline/
;				Note: the plane must be horizontal (i.e. v1[2]=v2[2]=v3[2])
;
;	Version:
;				080405
;				First version.
;
;				080912
;				Fixed incorrect true return value when both line points
;				are on the same side of the plane.
;;
;	Inputs:
;				p1, p2 - points on the line (3-element arrays)
;				v1, v2, v3 - points on the plane (3-element arrays)
;
;	Outputs:
;				Returns 1b if the line and plane intersect, 0b if not.
;
;	Required Modules:
;				None.
;
;	Written by:
;				Maggie Kusano, May 4, 2008
;
;==============================================================================

function shielding_guiPlaneIntersect, p1, p2, v1, v2, v3

	if n_params() ne 5 then return, 0

	if ((p1[2] lt v1[2]) and (p2[2] lt v1[2])) or $
	   ((p1[2] gt v1[2]) and (p2[2] gt v1[2])) then return, 0

	; v1=[x1,y1,z1], v2=[x2,y2,z2], v3=[x3,y3,z3]
	; A = y1 (z2 - z3) + y2 (z3 - z1) + y3 (z1 - z2)
	; B = z1 (x2 - x3) + z2 (x3 - x1) + z3 (x1 - x2)
	; C = x1 (y2 - y3) + x2 (y3 - y1) + x3 (y1 - y2)
	; - D = x1 (y2 z3 - y3 z2) + x2 (y3 z1 - y1 z3) + x3 (y1 z2 - y2 z1)
	A = v1[1]*(v2[2]-v3[2]) + v2[1]*(v3[2]-v1[2]) + v3[1]*(v1[2]-v2[2])
	B = v1[2]*(v2[0]-v3[0]) + v2[2]*(v3[0]-v1[0]) + v3[2]*(v1[0]-v2[0])
	C = v1[0]*(v2[1]-v3[1]) + v2[0]*(v3[1]-v1[1]) + v3[0]*(v1[1]-v2[1])
	D = -( v1[0]*(v2[1]*v3[2]-v3[1]*v2[2]) $
		 + v2[0]*(v3[1]*v1[2]-v1[1]*v3[2]) $
		 + v3[0]*(v1[1]*v2[2]-v2[1]*v1[2]) )

	num = A*p1[0] + B*p1[1] + C*p1[2] + D
	den = A*(p1[0]-p2[0]) + B*(p1[1]-p2[1]) + C*(p1[2]-p2[2])

	if den eq 0 then begin
		; Normal to plane is perpendicular to line, therefore the line is
		; either parallel to the plane (no solutions) or on the plane (infinite
		; solutions)
		return, 0
	endif else begin
		sign1 = num
		sign2 = A*p2[0] + B*p2[1] + C*p2[2] + D
		; Check to see if both points are on the same side of the
		if sign1 eq sign2 then return, 0

		u = num/den
		p = p1 + u*(p2-p1)

;		if (u ge 0) and (u le 1) then begin
		if (p[0] ge min([v1[0],v2[0],v3[0]])) and $
			(p[0] le max([v1[0],v2[0],v3[0]])) and $
			(p[1] ge min([v1[1],v2[1],v3[1]])) and $
			(p[1] le max([v1[1],v2[1],v3[1]])) then begin
			return, 1
		endif else begin
			return, 0
		endelse
	endelse

end ; of shielding_guiPlaneIntersect