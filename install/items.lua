	['evidence_bag'] = {
		label = 'Evidence Bag',
		weight = 100,
		close = true,
		stack = true,
		description = 'For collecting evidence'
	},
	
	['casing'] = {
		label = 'Bullet Casing',
		weight = 50,
		stack = false,
		close = false,
		description = 'A spent bullet casing',
		metadata = {
			serial = nil, -- Will be populated when collected
			weapon = nil, -- Weapon hash
			collectedAt = nil, -- Collection timestamp
			collectedBy = nil, -- Officer who collected it
		},
	},

	['blood_sample'] = {
		name = 'blood_sample',
		label = 'Blood Sample',
		weight = 0.15,
		stack = false,
		close = true,
		description = 'A collected blood sample for forensic analysis',
	},

	['bloodkit'] = {
		label = 'Blood Collection Kit',
		weight = 500,
		stack = true,
		close = true,
		description = 'A sterile kit for collecting blood samples',
		client = {
			status = { thirst = 2000 }, -- Optional: using it reduces thirst
			anim = { dict = 'anim@amb@business@weed@weed_inspecting_lo_med_hi@', 
					clip = 'weed_spraybottle_crouch_base_inspector' },
			prop = { model = `v_ret_ta_firstaid`, -- Model for when held
					pos = vec3(0.05, 0.0, 0.0),
					rot = vec3(0.0, 0.0, 0.0) },
			usetime = 50000
		}
	},
