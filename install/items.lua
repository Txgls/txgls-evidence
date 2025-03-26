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
