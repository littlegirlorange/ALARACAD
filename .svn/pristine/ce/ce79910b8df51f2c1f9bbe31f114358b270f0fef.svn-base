pro convert_thickness, d, material1, material2

@shielding_gui_shield_specs

materials = ['lead', 'concrete']

if keyword_set( d ) eq 0b then $
	read, 'd (cm) = ', d
if keyword_set( material1 ) eq 0b then begin
	read, 'Convert from (0-lead, 1-concrete): ', i
endif else if total( strcmp( materials, material1, /FOLD ) ) eq 0b then begin
	read, 'Convert from (0-lead, 1-concrete): ', i
endif else begin
	i = where( strcmp(materials, material1, /FOLD) eq 1 )
endelse
if keyword_set( material2 ) eq 0b then begin
	read, 'Convert to (0-lead, 1-concrete): ', j
endif else if total( strcmp( materials, material2, /FOLD ) ) eq 0b then begin
	read, 'Convert to (0-lead, 1-concrete): ', j
endif else begin
	j = where( strcmp(materials, material2, /FOLD) eq 1 )
endelse

line = 'Converting ' + strtrim(d,2) + ' cm ' + materials[i] + ' to X cm ' + materials[j]
print, line

b = ((1+(beta[i]/alpha[i]))*exp(alpha[i]*gamma[i]*d)-(beta[i]/alpha[i]))^(-1/gamma[i])
print, 'B = ', strtrim(b,2)

x = (1/(alpha[j]*gamma[j]))*alog((b^(-gamma[j])+(beta[j]/alpha[j]))/(1+(beta[j]/alpha[j])))
print, 'X = ', strtrim(x,2)

end



