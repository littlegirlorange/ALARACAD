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
;	Parameters:
;				modality	- (in) 'PET' or 'SPECT'
;				tracer		- (in) if 'PET see shielding_gui_PET_tracer_specs
;							for options
;							if 'SPECT' see shielding_gui_SPECT_tracer_specs
;				material	- (in) 'Lead', 'Concrete' or 'Iron'
;				d			- (in) material thickness in cm
;				ES			- (out, opt) tracer energies (SPECT only)
;				MUMS		- (out, opt) mass attenuation coefficients of
;							material at energies ES (SPECT only)
;				AFS			- (out, opt) attenuation factors of material
;							at energies ES (SPECT only)
;				BFS			- (out, opt) buildup factors of material
;							at energies ES (SPECT only)
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
	tracer, $
	material, $
	d, $
	ES=es, $
	FRACTIONS=fracs, $
	MUMS=mu_ms, $
	AFS=afs, $
	BFS=bfs

	if n_params() ne 4 then return, 1.0

	@'shielding_gui_shield_specs'
	if modality eq 'PET' then begin
		@'shielding_gui_PET_tracer_specs'
	endif else begin
		@'shielding_gui_SPECT_tracer_specs'
	endelse

	i = (where( materials eq material ))[0]
	if i eq -1L then return, 1.0
	if not keyword_set( d ) then return, 1.0

	nEs		= tracer.n_energies
	es		= fltarr( nEs )
	fracs	= fltarr( nEs )
	mu_ms	= fltarr( nEs )
	afs		= fltarr( nEs )
	bfs		= fltarr( nEs )

	if modality eq 'PET' then begin

		; Calculate the broad beam attenuation factor using the Archer equation
		; and coefficients given by the AAPM Task Group 108 (Madsen et al, 2006)
		TF = ((1+(beta[i]/alpha[i]))*exp(alpha[i]*gamma[i]*d)- $
			  (beta[i]/alpha[i]))^(-1/gamma[i])

	endif else begin ; SPECT

;		if tracer.name eq 'Ir-192' then begin
;
;			; Lymperopoulou thickness is in mm for Lead, cm for Concrete
;			if material eq 'Lead' then begin
;				x = d*10.0
;			endif else begin
;				x = d
;			endelse
;
;			TF = ((1+(beta_ir[i]/alpha_ir[i]))*exp(alpha_ir[i]*gamma_ir[i]*x)- $
;				  (beta_ir[i]/alpha_ir[i]))^(-1/gamma_ir[i])
;
;		endif else begin

			TF = 0.0
			totalFracs = total( *tracer.fractions )
			for iE=0, n_elements(*tracer.energies)-1 do begin
				energy = (*tracer.energies)[iE]

				case material of
				'Lead': begin
					rho = rho_lead
					index = (where( mu_m_lead[0,*] gt energy ))[0]
					mu_m = interpol( mu_m_lead[1,index-1:index], $
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
					mu_m = interpol( mu_m_concrete[1,index-1:index], $
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

				muX = mu_m * rho * d
				t = exp( -muX )
				k = gp_c*muX^gp_a + gp_d*(tanh(muX/gp_e-2)-tanh(-2))/(1-tanh(-2))
				if k ne 1 then begin
					b = 1 + (gp_b-1)*(k^muX-1)/(k-1)
				endif else begin
					b = 1 + (gp_b-1)*muX
				endelse
				b = 1
				TF 	+= ( t * b * (*tracer.fractions)[iE] / totalFracs )

;				case material of
;				'Lead': begin
;					; Calculate the attenuation factor (t) from the
;					; mass attenuation coefficient (mu_m), density
;					; (rho_lead)
;					mu_m = interpol( mu_m_lead[1,*], mu_m_lead[0,*], (*tracer.energies)[iE] ) ; cm^2/g
;					mu_l = mu_m * rho_lead ; 1/cm
;					muX	= mu_m * rho_lead * d
;					t = exp( -muX )
;
;					; Calculate the buildup factor (b) using a
;					; Taylor approximation with the coefficients given
;					; by Shultis and Faw
;					index = (where( b_cfs_lead[0,*] gt (*tracer.energies)[iE], count ))[0]
;					b1	= b_cfs_lead[1,index-1] * exp( -b_cfs_lead[2,index-1]*muX ) $
;						+ b_cfs_lead[3,index-1] * exp( -b_cfs_lead[4,index-1]*muX )
;					b2	= b_cfs_lead[1,index] * exp( -b_cfs_lead[2,index]*muX ) $
;						+ b_cfs_lead[3,index] * exp( -b_cfs_lead[4,index]*muX )
;					e1	= b_cfs_lead[0,index-1]
;					e2	= b_cfs_lead[0,index]
;					b	= b1 + (b2-b1) * ((*tracer.energies)[iE]-e1)/(e2-e1)
;;					b = 1
;					TF  += ( t * b * (*tracer.fractions)[iE] / totalFracs )
;				end
;				'Concrete': begin
;					; Calculate the attenuation factor (t) from the
;					; mass attenuation coefficient (mu_m), density
;					; (rho_concrete)
;					mu_m = interpol( mu_m_concrete[1,*], $ ; (cm^2/g)
;									 mu_m_concrete[0,*], $
;									 (*tracer.energies)[iE] )
;					mu_l = mu_m * rho_concrete ; (1/cm)
;								muX	= mu_m * rho_concrete * d
;					t = exp( -muX )
;
;					; Calculate the buildup factor (b) using a
;					; Taylor approximation with the coefficients given
;					; by Shultis and Faw
;					index = (where( b_cfs_concrete[0,*] gt (*tracer.energies)[iE], count ))[0]
;					b1	= b_cfs_concrete[1,index-1] * exp( -b_cfs_concrete[2,index-1]*muX ) $
;						+ b_cfs_concrete[3,index-1] * exp( -b_cfs_concrete[4,index-1]*muX )
;					b2	= b_cfs_concrete[1,index] * exp( -b_cfs_concrete[2,index]*muX ) $
;						+ b_cfs_concrete[3,index] * exp( -b_cfs_concrete[4,index]*muX )
;					e1	= b_cfs_concrete[0,index-1]
;					e2	= b_cfs_concrete[0,index]
;					b	= b1 + (b2-b1) * ((*tracer.energies)[iE]-e1)/(e2-e1)
;;					b = 1
;					TF 	+= ( t * b * (*tracer.fractions)[iE] / totalFracs )
;				end
;				else: begin
;					TF = 1.0
;					break
;				end
;				endcase

			es[iE] = (*tracer.energies)[iE]
			fracs[iE] = (*tracer.fractions)[iE]
			mu_ms[iE] = mu_m
			afs[iE] = t
			bfs[iE] = b

		endfor

;		endelse

	endelse ; SPECT

	heap_free, tracers

	return, TF

end ; of shielding_guiCalculateTF