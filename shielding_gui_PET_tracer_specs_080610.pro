;==================================================================================================
;
;	DERs in m^2.uSv/GBq.h from Wasserman and Groenewald, Eur J Nucl Med 1988
;	Energies in keV from Saunders and Phelps, Physics in Nuclear Medicine 1987
;
	tracers = [ {tracer, $
				NAME		: 'F-18', $
				DER			: (0.143*0.64*1000), $
				N_ENERGIES	: 1, $
				ENERGIES	: ptr_new([511]), $
				FRACTIONS	: ptr_new([1]), $
				HL			: 1.83}, $ ; h
				{tracer, $
				NAME		: 'C-11', $
				DER			: (0.148*0.64*1000), $
				N_ENERGIES	: 1, $
				ENERGIES	: ptr_new([511]), $
				FRACTIONS	: ptr_new([1]), $
				HL			: (20.4/60.0)}, $
				{tracer, $
				NAME		: 'N-13', $
				DER			: (0.148*0.64*1000), $
				N_ENERGIES	: 1, $
				ENERGIES	: ptr_new([511]), $
				FRACTIONS	: ptr_new([1]), $
				HL			: (10.0/60.0)}, $
				{tracer, $
				NAME		: 'O-15', $
				DER			: (0.148*0.64*1000), $
				N_ENERGIES	: 1, $
				ENERGIES	: ptr_new([511]), $
				FRACTIONS	: ptr_new([1]), $
				HL			: (2.0/60.0)}, $
				{tracer, $
				NAME		: 'Ga-68', $
				DER			: (0.134*0.64*1000), $
				N_ENERGIES	: 1, $
				ENERGIES	: ptr_new([511]), $
				FRACTIONS	: ptr_new([1]), $
				HL			: (68.3/60.0)} $
			  ]
