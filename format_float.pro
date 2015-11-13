;+
; NAME:
;
;		FORMAT_FLOAT
;
; PURPOSE:
;
;		Formats floating point numbers to the specified number of
;		decimal places and returns the result as a string or
;		rounded float.  Wraps David Fanning's number_formatter which only
;		allows scalar inputs and only outputs string values.
;
; AUTHOR:
;
;		Maggie Kusano, January 28, 2009
;
; CALLING SEQUENCE:
;
;		retVal = format_float( number $
;							[, DECIMALS=decimals]$
;							[, STRING=bString] $
;							[, FLOAT=bFloat] )
;
; ARGUMENTS:
;
;		number:		The number or array of numbers to be formatted. May be any
;					type except complex, double complex, pointer or object.
;
; KEYWORDS:
;
;		DECIMALS:	The number of decimal places to be included to the right
;					of the decimal point. Set to 2 by default.
;
;		STRING:		Set this keyword to return the formatted float as a string.
;					(default).
;
;		FLOAT:		Set this keyword to return the formatted float as a float
;
; RETURN VALUE:
;
;		retVal:		The formatted string or float.
;
; EXAMPLES:
;
;		IDL> print, format_float( [3.5234, 1.9324723e-16] )
;				3.52000 1.93000e-016
;		IDL> print, format_float( 16.837574837e-14, DECIMALS=3, /STRING )
;				1.684e-13
;
; MODIFICATION HISTORY:
;
;-

function format_float, $
	number, $
	DECIMALS=dec, $
	STRING=bString, $
	FLOAT=bFloat

	; Set number of decimal places to 2 by default
	if n_elements( dec ) eq 0 then dec = 2

	info = size( number, /STRUCT )

	if info.n_elements eq 1 then begin
		str = number_formatter( number, DECIMAL=dec )
	endif else begin
		str = strarr( info.dimensions[0:info.n_dimensions-1] )
		for i=0, info.n_Elements-1 do begin
			str[i] = number_formatter( number[i], DECIMAL=dec )
		endfor
	endelse

	if keyword_set( bFloat ) then begin
		; Return the formatted float(s) or double(s)
		return, fix( str, TYPE=info.type )
	endif else begin
		; Return the formatted string(s)
		return, str
	endelse

end ; of format_float

