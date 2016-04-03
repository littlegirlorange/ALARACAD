pro save_tracer_specs

@shielding_gui_SPECT_tracer_specs
@shielding_gui_tissue_specs

file = "C:\Users\maggie\Documents\nmtracerspecs.txt"
openw, 1, file
leadThicknesses = [0.16,0.32,0.64]
concThicknesses = [21.0, 23.0]
headings = 'tracer; half-life; energy; fraction; uEn; DER; ' $
		 + strjoin( format_float( leadThicknesses ), ' cm Pb; ' ) + ' cm Pb; ' $
		 + strjoin( format_float( concThicknesses ), ' cm Concrete; ' ) + ' cm Concrete'
printf, 1, headings

nTracers = n_elements( tracers.name )
for iT=0, nTracers-1 do begin
    leadNums = dblarr(n_elements(leadThicknesses))
    concNums = dblarr(n_elements(concThicknesses))
    DERTotal = 0
	energies = *(tracers[iT].energies)
	fractions = *(tracers[iT].fractions)
	nEs = n_elements( energies )
	for iE=0, nEs-1 do begin
		if iE eq 0 then begin
			name = tracers[iT].name
			hl = string( tracers[iT].hl )
		endif else begin
			name = ' '
			hl = ' '
		endelse
		energy = energies[iE]
		fraction = fractions[iE]
		index = (where( mu_en_tissue[0,*] gt energy ))[0]
		muEn = interpol( mu_en_tissue[1,index-1:index], $
				mu_en_tissue[0,index-1:index], energy )
		DER = 4.58939 * energy * fraction * muEn
		DERTotal += DER
		line = strjoin( strtrim([name,hl,string([energy,fraction,muEn,DER])],2),';' ) + ';'
		for i=0, n_elements( leadThicknesses )-1 do begin
			TF = shielding_guiCalculateTF( "SPECT", "Lead", leadThicknesses[i], energy )
			line = line + strtrim( TF, 2 ) + ';'
			leadNums[i] += energy * fraction * muEn * TF
		endfor
		for i=0, n_elements( concThicknesses )-1 do begin
			TF = shielding_guiCalculateTF( "SPECT", "Concrete", concThicknesses[i], energy )
			line = line + strtrim( TF, 2 ) + ';'
			concNums[i] += energy * fraction * muEn * TF
		endfor
		printf, 1, line
	endfor ; Energies
	leadTFs = leadNums * 4.58939 / DERTotal
	concTFs = concNums * 4.58939 / DERTotal
	printf, 1, ";;;;;" + strtrim(DERTotal,2) + ";" + strjoin( strtrim( leadTFs, 2 ), ";" ) + ";" + strjoin( strtrim( concTFs, 2 ), ";")
endfor

heap_free, tracers

close, 1

end