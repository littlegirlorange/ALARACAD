pro testdoses

thicknesses = [0, 1, 2, 3, 4, 5, 6]*10

for i=0, n_elements(thicknesses)-1 do begin
	shieldedDose = calcShieldedDose( 'SPECT', 'Ir-192', 1, 1000, 1, 'Concrete', thicknesses[i], DOSE=dose, DER=der )
	print, shieldedDose
endfor

end