
;==============================================================================
;
;	Description:
;				Physical properties of SPECT tracers.
;
;	Version:
;				080814
;				Many previous version, just no header info.

;	Written by:
;				Maggie Kusano, August 14, 2008
;
;==============================================================================

;==============================================================================
;
;	DERs in m^2.uSv/GBq.h from Wasserman and Groenewald, Eur J Nucl Med 1988
;	Energies in keV from Saunders and Phelps, Physics in Nuclear Medicine 1987
;	Ir-192 energies and fractions from http://ie.lbl.gov/toi/nuclide.asp?iZA=770192

	tracers = [ {tracer, $
				NAME		: 'Tc-99m', $
				DER			: 15.6, $
				N_ENERGIES	: 1, $
				ENERGIES	: ptr_new([140.5]), $
				FRACTIONS	: ptr_new([1.0]), $
				HL			: 6.03}, $ ; h
				{tracer, $
				NAME		: 'Ga-67', $
				DER			: 20.8, $
				N_ENERGIES	: 3, $
				ENERGIES	: ptr_new([93.3, 184.6, 300.2]), $
				FRACTIONS	: ptr_new([0.3739, 0.2388, 0.1613]), $
				HL			: 78.1}, $
				{tracer, $
				NAME		: 'In-111', $
				DER			: 84.15, $
				N_ENERGIES	: 2, $
				ENERGIES	: ptr_new([172.0, 247.0]), $
				FRACTIONS	: ptr_new([0.8959, 0.9395]), $
				HL			: 67.44}, $
				{tracer, $
				NAME		: 'I-123', $
				DER			: 39.7, $
				N_ENERGIES	: 1, $
				ENERGIES	: ptr_new([159.1]), $
				FRACTIONS	: ptr_new([1.0]), $
				HL			: 13.0}, $
				{tracer, $
				NAME		: 'I-131', $
				DER			: 56.1, $
				N_ENERGIES	: 4, $
				ENERGIES	: ptr_new([284.3,364.4,637.0,722.9]), $
				FRACTIONS	: ptr_new([0.0615,0.8170,0.0717,0.0177]), $
				HL			: 193.44}, $
				{tracer, $
				NAME		: 'I-131 - thyroidal', $
				DER			: 56.1, $
				N_ENERGIES	: 4, $
				ENERGIES	: ptr_new([284.3,364.4,637.0,722.9]), $
				FRACTIONS	: ptr_new([0.0615,0.8170,0.0717,0.0177]), $
				HL			: 0.32*24}, $
				{tracer, $
				NAME		: 'I-131 - extra-thyroidal', $
				DER			: 56.1, $
				N_ENERGIES	: 4, $
				ENERGIES	: ptr_new([284.3,364.4,637.0,722.9]), $
				FRACTIONS	: ptr_new([0.0615,0.8170,0.0717,0.0177]), $
				HL			: 7.3*24}, $
				{tracer, $
				NAME		: 'Tl-201', $
				DER			: 11.7, $
				N_ENERGIES	: 2, $
				ENERGIES	: ptr_new([135.34,167.43]), $
				FRACTIONS	: ptr_new([0.2565,1.0]), $
				HL			: 72.912}, $
				{tracer, $
				NAME		: 'Ir-192', $
				DER			: 121.0, $
				N_ENERGIES	: 9, $
				ENERGIES	: ptr_new([205.0,295.96,308.46,316.51,468.07,484.6,588.6,604.4,612.5]), $ ; from
				FRACTIONS	: ptr_new([0.0330,0.2867,0.3000,0.8281,0.4783,0.0318,0.0452,0.0823,0.0531]), $
				HL			: 73.831*24} $
			]
