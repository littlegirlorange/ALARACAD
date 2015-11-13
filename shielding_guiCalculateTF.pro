;==============================================================================
;
;	Method:		shielding_guiCalculateTF
;
;	Description:
;				Calculates the transmission factor of a material of thickness
;				d for a particular radionuclide.
;
;	Version:
;				080504
;				First version.
;
;				080814
;				Modified for change to dose equivalent rate constant calc
;				method.
;
;	Usage:
;				retVal = shielding_guiCalculateTF( modality, material, d, energy[, MUM=mum, AF=af, BF=bf] )
;
;	Parameters:
;				modality	- (in) 'PET' or 'SPECT'
;				material	- (in) 'Lead', 'Concrete', or 'Iron'
;				d			- (in) material thickness in cm
;				energy		- (in) nuclide energy in keV
;				MUM			- (out, opt) mass attenuation coefficient for
;							material at energy (SPECT only)
;				AF			- (out, opt) attenuation factor for material
;							at energy (SPECT only)
;				BF			- (out, opt) buildup factor for material
;							at energy (SPECT only)
;
;	Outputs:
;				Returns the transmission factor (value between 0 and 1).
;
;	Required Modules:
;				shielding_gui_shield_specs
;				shielding_gui_PET_tracer_specs
;				shielding_gui_SPECT_tracer_specs
;
;	Written by:
;				Maggie Kusano, May 4, 2008
;
;==============================================================================

function shielding_guiCalculateTF, $
	modality, $
	material, $
	d, $
	energy, $
	MUM=mum, $
	AF=t, $
	BF=b

	if n_params() ne 4 then return, 1.0

	@'shielding_gui_shield_specs'

	if modality eq 'PET' then begin

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
				if index ne 0 then begin ; E > 20 keV
					mum = interpol( mu_m_lead[1,index-1:index], $
							mu_m_lead[0,index-1:index], energy )
				endif else begin ; E < 20 keV
					mum = mu_m_lead[1,0]
				endelse
				index = (where( gp_cfs_lead[0,*] gt energy ))[0]
				if index ne 0 then begin
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
				endif else begin
					gp_b = gp_cfs_lead[1,0]
					gp_c = gp_cfs_lead[2,0]
					gp_a = gp_cfs_lead[3,0]
					gp_e = gp_cfs_lead[4,0]
					gp_d = gp_cfs_lead[5,0]
				endelse
			end
			'Concrete': begin
				rho = rho_concrete
				index = (where( mu_m_concrete[0,*] gt energy ))[0]
				if index ne 0 then begin ; E > 20 keV
					mum = interpol( mu_m_concrete[1,index-1:index], $
							mu_m_concrete[0,index-1:index], energy )
				endif else begin ; E < 20 keV
					mum = mu_m_concrete[1,0]
				endelse
				index = (where( gp_cfs_concrete[0,*] gt energy ))[0]
				if index ne 0 then begin ; E > 20 keV
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
				endif else begin
					gp_b = gp_cfs_concrete[1,0]
					gp_c = gp_cfs_concrete[2,0]
					gp_a = gp_cfs_concrete[3,0]
					gp_e = gp_cfs_concrete[4,0]
					gp_d = gp_cfs_concrete[5,0]
				endelse
			end
			else:
		endcase

		muX = mum * rho * d
		t = exp( -muX )
		if t eq 0 then begin
			b = 1
		endif else begin
			k = gp_c*muX^gp_a + gp_d*(tanh(muX/gp_e-2)-tanh(-2))/(1-tanh(-2))
			if k ne 1 then begin
				b = 1 + (gp_b-1)*(k^muX-1)/(k-1)
			endif else begin
				b = 1 + (gp_b-1)*muX
			endelse
		endelse
		TF = t*b

	endelse ; SPECT

	return, TF

end ; of shielding_guiCalculateTF