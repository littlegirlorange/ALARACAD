;+
; NAME:
;
;		TRIM_FLOAT
;
; PURPOSE:
;
;		Eliminates trailing zeros from string float values
;
; AUTHOR:
;
;		Maggie Kusano, February 15, 2009
;
; CALLING SEQUENCE:
;
;		retString = trim_float( floatString )
;
; ARGUMENTS:
;
;		floatString:	The string to be formatted.
;
; KEYWORDS:
;
;
; RETURN VALUE:
;
;		retString:		The trimmed float string.
;
; EXAMPLES:
;
;		IDL> print, trim_float( '0.037000' )
;				0.037
;		IDL> print, trim_float( 500.00 )
;				500
;
; MODIFICATION HISTORY:
;
;-


function trim_float, aString

	; Split the number into a whole part and a fractional part.
	parts = strsplit( aString, '.', /EXTRACT )
	if n_elements( parts ) eq 0 then return, strtrim( parts[0], 2 )

	wholePart = strtrim( parts[0], 2 )
	fracPart = strtrim( parts[1], 2 )
	if fix( fracPart ) eq 0 then return, wholePart
	lastchar = strmid( fracPart, 0, 1, /REVERSE )
	while lastchar eq '0' do begin
		len = strlen( fracPart )
		fracPart = strmid( fracPart, 0, len-1 )
		lastChar = strmid( fracPart, 0, 1, /REVERSE )
	endwhile
	retVal = wholePart + '.' + fracPart
	return, retVal

end