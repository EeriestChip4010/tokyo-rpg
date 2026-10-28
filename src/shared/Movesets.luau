--!strict
-- Per-weapon attacks. The server reads these for timing, hitboxes and damage;
-- clients read them for animation timing and to mirror cooldowns. Values are
-- placeholders until playtested (vault/02-Design/Combat System.md).
--
-- Timing of one attack: `windup` (telegraph, interrupted by getting hit,
-- feintable for M1s) -> hit -> `recovery` (no new action yet). Hitboxes are
-- boxes of `hitbox` size centred at `offset` in the attacker's root space.

export type Knockback = {
	speed: number, -- studs per second, away from the attacker
	upward: number,
	duration: number,
}

export type Attack = {
	pose: string, -- client animation id (see client/Poses)
	damage: number,
	postureDamage: number, -- posture lost when this is blocked
	windup: number,
	recovery: number,
	hitStun: number,
	hitbox: Vector3,
	offset: Vector3,
	hits: number?, -- multi-hit attacks
	hitInterval: number?,
	unblockable: boolean?, -- grabs: only a dodge avoids them
	knockback: Knockback?,
	lunge: number?, -- forward speed during the windup, studs per second
	heal: number?, -- fraction of damage dealt returned to the attacker
	cost: number?, -- RC or quinque charge
	cooldown: number?,
}

export type Moveset = {
	id: string,
	displayName: string,
	weapon: "Fists" | "Kagune" | "Quinque",
	kaguneType: string?, -- quinques inherit the type of their source kagune
	resource: ("RC" | "Charge")?,
	chainResetTime: number, -- idle time that resets the M1 chain
	m1: { Attack }, -- the last entry is the finisher
	skills: { [string]: Attack }, -- keyed by CombatActions.Skill1 / Skill2
}

local FINISHER_KNOCKBACK: Knockback = { speed = 45, upward = 15, duration = 0.2 }

local function m1(pose: string, overrides: { [string]: any }?): Attack
	local attack: { [string]: any } = {
		pose = pose,
		damage = 4,
		postureDamage = 12,
		windup = 0.12,
		recovery = 0.23,
		hitStun = 0.4,
		hitbox = Vector3.new(5, 5, 5),
		offset = Vector3.new(0, 0, -3.5),
	}
	for key, value in overrides or {} do
		attack[key] = value
	end
	return (attack :: any) :: Attack
end

local byId: { [string]: Moveset } = {}

-- Everyone's bare-handed fallback, and humans' only option.
byId.Fists = {
	id = "Fists",
	displayName = "Fists",
	weapon = "Fists",
	chainResetTime = 1.2,
	m1 = {
		m1("FistJabR"),
		m1("FistJabL"),
		m1("FistHook"),
		m1("FistFinisher", { windup = 0.18, hitStun = 0.9, knockback = FINISHER_KNOCKBACK }),
	},
	skills = {},
}

-- Rinkaku: aggressive brawler. Long reach, heals on the grab, burns RC.
local RINKAKU_M1 = {
	damage = 6,
	postureDamage = 14,
	windup = 0.18,
	recovery = 0.27,
	hitbox = Vector3.new(6, 6, 11),
	offset = Vector3.new(0, 0, -6.5),
	cost = 2,
}
byId.Rinkaku = {
	id = "Rinkaku",
	displayName = "Rinkaku",
	weapon = "Kagune",
	kaguneType = "Rinkaku",
	resource = "RC",
	chainResetTime = 1.3,
	m1 = {
		m1("KaguneStrikeR", RINKAKU_M1),
		m1("KaguneStrikeL", RINKAKU_M1),
		m1("KaguneSweep", RINKAKU_M1),
		m1("KaguneSlam", {
			damage = 8,
			postureDamage = 20,
			windup = 0.26,
			recovery = 0.35,
			hitStun = 1.0,
			hitbox = Vector3.new(8, 6, 12),
			offset = Vector3.new(0, 0, -7),
			cost = 3,
			knockback = { speed = 55, upward = 20, duration = 0.22 },
		}),
	},
	skills = {
		-- E: four quick tentacle stabs.
		Skill1 = {
			pose = "KaguneBarrage",
			damage = 3,
			postureDamage = 10,
			windup = 0.3,
			recovery = 0.4,
			hitStun = 0.35,
			hitbox = Vector3.new(8, 6, 12),
			offset = Vector3.new(0, 0, -7),
			hits = 4,
			hitInterval = 0.12,
			cost = 15,
			cooldown = 8,
		},
		-- R: grab and slam. Can't be blocked or parried, heals on hit.
		Skill2 = {
			pose = "KaguneGrab",
			damage = 14,
			postureDamage = 0,
			windup = 0.45,
			recovery = 0.5,
			hitStun = 1.2,
			hitbox = Vector3.new(6, 6, 11),
			offset = Vector3.new(0, 0, -6.5),
			unblockable = true,
			heal = 0.5,
			knockback = { speed = 10, upward = 35, duration = 0.18 },
			cost = 25,
			cooldown = 14,
		},
	},
}

-- C-rate issue quinque, after the mass-produced Bikaku Tsunagi: a guardless
-- long blade. Balanced and technical,
-- recharges from hits instead of feeding.
local BLADE_M1 = {
	damage = 5,
	postureDamage = 16,
	windup = 0.16,
	recovery = 0.26,
	hitbox = Vector3.new(6, 5, 7),
	offset = Vector3.new(0, 0, -4.5),
}
byId.BikakuBlade = {
	id = "BikakuBlade",
	displayName = "CCG Issue Blade (Tsunagi pattern)",
	weapon = "Quinque",
	kaguneType = "Bikaku",
	resource = "Charge",
	chainResetTime = 1.3,
	m1 = {
		m1("BladeSlash1", BLADE_M1),
		m1("BladeSlash2", BLADE_M1),
		m1("BladeSlash3", BLADE_M1),
		m1("BladeThrust", {
			damage = 7,
			postureDamage = 22,
			windup = 0.22,
			recovery = 0.32,
			hitStun = 0.9,
			hitbox = Vector3.new(5, 5, 9),
			offset = Vector3.new(0, 0, -5.5),
			lunge = 25,
			knockback = FINISHER_KNOCKBACK,
		}),
	},
	skills = {
		-- E: rising slash that launches and chews through posture.
		Skill1 = {
			pose = "BladeRising",
			damage = 10,
			postureDamage = 40,
			windup = 0.32,
			recovery = 0.45,
			hitStun = 1.0,
			hitbox = Vector3.new(6, 7, 7),
			offset = Vector3.new(0, 0, -4.5),
			knockback = { speed = 8, upward = 40, duration = 0.2 },
			cost = 30,
			cooldown = 8,
		},
		-- R: Bikaku tail-style spin around the user. Built to guard break.
		Skill2 = {
			pose = "BladeSpin",
			damage = 9,
			postureDamage = 60,
			windup = 0.4,
			recovery = 0.5,
			hitStun = 0.8,
			hitbox = Vector3.new(14, 5, 14),
			offset = Vector3.new(0, 0, 0),
			knockback = { speed = 40, upward = 10, duration = 0.2 },
			cost = 40,
			cooldown = 12,
		},
	},
}

return {
	byId = byId,

	-- Who beats whom (vault/01-Lore/Kagune Types.md#Matchups).
	Beats = {
		Ukaku = "Rinkaku",
		Rinkaku = "Bikaku",
		Bikaku = "Koukaku",
		Koukaku = "Ukaku",
	} :: { [string]: string },
}
