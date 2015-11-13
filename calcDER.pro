;==============================================================================
;
;	Method:		calcDER
;
;	Description:
;				Calculates the dose equivalent rate constant for a particular
;				gamma ray energy.
;
;	Version:
;				080818
;				First version.
;
;	Usage:
;				retVal = calcDER( energy )
;
;	Parameters:
;				energy		- (in) gamma ray energy in keV
;
;	Outputs:
;				Returns the dose equivalent rate constant for the specified
;				energy.
;
;	Required Modules:
;
;	Written by:
;				Maggie Kusano, August 18, 2008
;
;==============================================================================

function calcDER, energy

	if n_params() ne 1 then return

	@'shielding_gui_tissue_specs'
	@'shielding_gui_SPECT_tracer_specs'

		i = (where( materials eq material ))[0]
		if i eq -1L then return, 1.0

		; Calculate the broad beam transmission factor using the Archer equation
		; and coefficients given by the AAPM Task Group 108 (Madsen et al, 2006)
		TF = ((1+(beta[i]/alpha[i]))*exp(alpha[i]*gamma[i]*d)- $
			  (beta[i]/alpha[i]))^(-1/gamma[i])

	endif else begin ; SPECT

		; Calculate the broad beam transmission factor from the attenuation
		; and geometric progression buildup factors
		case material of
			'Lead': begin
				rho = rho_lead
				index = (where( mu_m_lead[0,*] gt energy ))[0]
				mum = interpol( mu_m_lead[1,index-1:index], $
						mu_m_lead[0,index-1:index], energy )
				index = (where( gp_cfs_lead[0,*] gt energy ))[0]
				gp_b = interpol( gp_cfs_lead[1,index-1:index], $
						gp_cfs_lead[0,index-1:index], energy )
				gp_c = interpol( gp_cfs_lead[2,index-1:index], $
						gp_cfs_lead[0,index-1:index], energy )
				gp_a = interpol( gp_cfs_lead[3,index-1:index], $
						gp_cfs_lead[0,index-1:index], energy )
				gp_e = interpol( gp_cfs_lead[4,index-1:index], $
						gp_cfs_lead[0,index-1:index], energy )
				gp_d = interpol( gp_cfs_lead[5,index-1:index], $
						gp_cfs_lead[0,index-1:index], energy )
			end
			'Concrete': begin
				rho = rho_concrete
				index = (where( mu_m_concrete[0,*] gt energy ))[0]
				mum = interpol( mu_m_concrete[1,index-1:index], $
						mu_m_concrete[0,index-1:index], energy )
				index = (where( gp_cfs_concrete[0,*] gt energy ))[0]
				gp_b = interpol( gp_cfs_concrete[1,index-1:index], $
						gp_cfs_concrete[0,index-1:index], energy )
				gp_c = interpol( gp_cfs_concrete[2,index-1:index], $
						gp_cfs_concrete[0,index-1:index], energy )
				gp_a = interpol( gp_cfs_concrete[3,index-1:index], $
						gp_cfs_concrete[0,index-1:index], energy )
				gp_e = interpol( gp_cfs_concrete[4,index-1:index], $
						gp_cfs_concrete[0,index-1:index], energy )
				gp_d = interpol( gp_cfs_concrete[5,index-1:index], $
						gp_cfs_concrete[0,index-1:index], energy )
			end
			else:
		endcase

		muX = mum * rho * d
		t = exp( -muX )
		k = gp_c*muX^gp_a + gp_d*(tanh(muX/gp_e-2)-tanh(-2))/(1-tanh(-2))
		if k ne 1 then begin
			b = 1 + (gp_b-1)*(k^muX-1)/(k-1)
		endif else begin
			b = 1 + (gp_b-1)*muX
		endelse
		b = 1
		TF = t*b

	endelse ; SPECT

	heap_free, tracers

	return, TF

end ; of shielding_guiCalculateTF