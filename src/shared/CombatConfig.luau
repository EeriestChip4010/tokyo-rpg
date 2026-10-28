--!strict
-- Combat tuning shared by server and client. All values are placeholders
-- until playtested; see vault/02-Design/Combat System.md.

local CombatConfig = {
	M1 = {
		Damage = 4,
		SwingInterval = 0.35, -- seconds between swings
		ChainLength = 4, -- the last hit is the finisher
		ChainResetTime = 1.2, -- idle time that resets the chain
		HitboxSize = Vector3.new(5, 5, 5),
		HitboxOffset = 3.5, -- studs in front of the attacker
		HitStun = 0.4,
		PostureDamage = 12, -- posture lost when this hit is blocked
	},

	Finisher = {
		KnockbackSpeed = 45, -- studs per second
		KnockbackUpward = 15,
		KnockbackDuration = 0.2,
		Stun = 0.9,
	},

	Block = {
		ParryWindow = 0.2, -- seconds after pressing block that count as a parry
		ParryStun = 1.0, -- stun applied to the attacker on a parry
		GuardBreakStun = 1.5,
		FrontAngleDot = 0, -- attacks from behind (dot below this) ignore the block
	},

	Posture = {
		Max = 100,
		RegenPerSecond = 15,
		RegenDelay = 1.0, -- seconds after the last block before regen starts
	},

	Stamina = {
		Max = 100,
		RegenPerSecond = 20,
		RegenDelay = 1.0,
	},

	Dash = {
		StaminaCost = 20,
		Cooldown = 2.0,
		Speed = 70,
		Duration = 0.18,
	},

	Dodge = {
		StaminaCost = 25,
		Cooldown = 6.0,
		Speed = 45,
		Duration = 0.25,
		IFrames = 0.3,
	},

	WalkSpeed = {
		Normal = 16,
		Blocking = 8,
		Stunned = 4,
	},

	-- Seconds a fighter stays combat-tagged after hitting or being hit.
	CombatTagDuration = 20,

	-- Max remote calls a player may send per second before being ignored.
	MaxActionsPerSecond = 20,
}

return CombatConfig
