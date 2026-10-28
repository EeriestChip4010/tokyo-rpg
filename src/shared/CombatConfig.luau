--!strict
-- Combat tuning shared by server and client that isn't tied to one weapon.
-- Per-weapon attacks and skills live in Movesets. All values are
-- placeholders until playtested; see vault/02-Design/Combat System.md.

local CombatConfig = {
	Block = {
		ParryWindow = 0.2, -- seconds after pressing block that count as a parry
		ParryStun = 1.0, -- stun applied to the attacker on a parry
		ParryPostureRefund = 15, -- posture the defender gets back on a parry
		GuardBreakStun = 1.5,
		FrontAngleDot = 0, -- attacks from behind (dot below this) ignore the block
	},

	Feint = {
		Cooldown = 1.5, -- M2 during an M1 windup cancels it
		Recovery = 0.1,
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

	-- Releasing a kagune or opening the quinque case. Getting hit while
	-- deploying interrupts it (vault/02-Design/Quinque Design.md).
	Deploy = {
		KaguneTime = 0.6,
		QuinqueTime = 0.7,
		SheatheTime = 0.3,
	},

	-- RC is hidden from the HUD on purpose; it only gates kagune use.
	RC = {
		Max = 100,
		RegenPerSecond = 2,
		RetractBelow = 1, -- the kagune is forced back in when RC runs out
	},

	QuinqueCharge = {
		Max = 100,
		Start = 50,
		RegenPerSecond = 3,
		GainOnHit = 5,
	},

	-- Damage multiplier when the attacker's type beats the defender's, and
	-- its inverse when it loses (vault/02-Design/Kagune Design.md#Matchups).
	MatchupBonus = 1.12,

	WalkSpeed = {
		Normal = 16,
		Blocking = 8,
		Attacking = 10,
		Deploying = 8,
		Stunned = 4,
	},

	-- Seconds a fighter stays combat-tagged after hitting or being hit.
	CombatTagDuration = 20,

	-- Max remote calls a player may send per second before being ignored.
	MaxActionsPerSecond = 20,
}

return CombatConfig
