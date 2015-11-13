pro calcThickness, d1, occ, d2, ENERGY=energy, TF=b, LEAD=lead, CONCRETE=concrete


if n_elements(energy) eq 0 then energy=511

@shielding_gui_shield_specs

if energy eq 511 then begin

	b = d2/(occ*d1)

	lead 		= (1/(alpha[0]*gamma[0]))*alog((b^(-gamma[0])+(beta[0]/alpha[0]))/(1+(beta[0]/alpha[0])))
	concrete	= (1/(alpha[1]*gamma[1]))*alog((b^(-gamma[1])+(beta[1]/alpha[1]))/(1+(beta[1]/alpha[1])))

endif else begin

endelse



end



