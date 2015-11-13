pro create_spectra

@shielding_gui_SPECT_tracer_specs

minE = 20
maxE = 1000
binSize = 20
nBins = (maxE-minE)/binSize

openw, 1, 'C:\Users\makusan\Documents\Research\MC\Background\spectra.txt\
printf, 1, 'isotope' + string(9b) + strjoin( strtrim( minE+(indgen(nBins)+1)*binSize, 2 ), string(9b) )
for iTracer=0, n_elements( tracers )-1 do begin
	print, tracers.name
	counts = fltarr(nBins)
	tracer = tracers[iTracer]
	for iE = 0, n_elements( *tracer.energies )-1 do begin
		energy = (*tracer.energies)[iE]
		fraction = (*tracer.fractions)[iE]
		for iBin=0, nBins-1 do begin
			if (minE+iBin*binSize le energy) and (energy lt minE+(iBin+1)*binSize) then begin
				counts[iBin] += fraction
				print, energy, fraction, iBin
				break
			endif
		endfor
	endfor
	window, 1
	plot, counts
	print, (tracers.name)[iTracer], counts
	printf, 1, (tracers.name)[iTracer] + string(9b) + strjoin( strtrim( counts, 2 ), string(9b) )
endfor

close, 1

end