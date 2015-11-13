pro gammaSelfAtten

nMax = 1000000L		; number of particles
r = 10*0.157		; number of mean free paths

seed = randomu( 28 )
nr = 0L
rsq = r*r

for i=0L, nMax-1 do begin

	z = r*randomu(seed)^0.3333333333	; pick uniformly from sphere
	costh = 2.0*randomu(seed)-1.0		; component in z-dir
	sinth = sqrt( 1.0-costh*costh )		; perpendicular component
	d = -alog(randomu(seed))			; flight path distance
	zc = z + d*costh					; distance to collision along z
	xc = d*sinth						; distance to collision along x
	rcsq = xc*xc+zc*zc					; square of radius to collision point
	if rcsq gt rsq then nr++			; did the particle escape the sphere?

endfor

prob = float(nr)/float(nMax)
stdev = sqrt(prob-prob^2)/sqrt(float(nMax))
print, "For mfp = " + strtrim(r,2) $
		+ ", the probability of escape is " + strtrim(prob,2) + " +/- " + strtrim(stdev,2)

end