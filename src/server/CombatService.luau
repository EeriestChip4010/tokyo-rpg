--!strict
-- Server-authoritative combat. Clients only send intents; this module owns
-- every timer, resource and hit. Attacks run windup -> hit -> recovery:
-- getting hit during a windup interrupts it, an M1 windup can be feinted,
-- and hitboxes are resolved from server positions when the windup ends.
--
-- The server never plays animations or effects. It broadcasts outcomes on
-- Remotes.CombatFx (see Shared.CombatFx) and publishes state as character
-- attributes, and each client renders them locally.
--
-- Timestamps use workspace:GetServerTimeNow() so clients can compare the
-- published values (StunnedUntil, DeployEndsAt) with their own clock.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local CombatActions = require(ReplicatedStorage.Shared.CombatActions)
local CombatConfig = require(ReplicatedStorage.Shared.CombatConfig)
local CombatFx = require(ReplicatedStorage.Shared.CombatFx)
local Movesets = require(ReplicatedStorage.Shared.Movesets)
local Loadout = require(script.Parent.Loadout)

type Attack = Movesets.Attack
type Moveset = Movesets.Moveset
type WeaponState = "Sheathed" | "Deploying" | "Drawn"

local remotes = ReplicatedStorage.Remotes
local combatAction = remotes.CombatAction :: RemoteEvent
local combatFx = remotes.CombatFx :: RemoteEvent

type Fighter = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	player: Player?,

	-- Every new action bumps the token; pending hits check it before landing,
	-- so a stun or feint cancels them.
	actionToken: number,
	pending: ("M1" | "Skill" | "Deploy")?,
	windupEndsAt: number,
	busyUntil: number,

	lastSwing: number,
	chainIndex: number,
	feintReadyAt: number,
	skillReadyAt: { [string]: number },

	blocking: boolean,
	blockStartedAt: number,
	lastBlockAt: number,
	posture: number,

	stamina: number,
	lastStaminaUse: number,

	stunnedUntil: number,
	iFramesUntil: number,
	dashReadyAt: number,
	dodgeReadyAt: number,

	weaponState: WeaponState,
	rc: number,
	charge: number,
}

type RateLimit = {
	windowStart: number,
	count: number,
}

local fighters: { [Model]: Fighter } = {}
local rateLimits: { [Player]: RateLimit } = {}

local CombatService = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function loadoutOf(fighter: Fighter): Loadout.Loadout
	if fighter.player then
		return Loadout.forPlayer(fighter.player)
	end
	return { kind = "Civilian", weaponMoveset = nil, oneEyed = false }
end

local function currentMoveset(fighter: Fighter): Moveset
	if fighter.weaponState == "Drawn" then
		local id = loadoutOf(fighter).weaponMoveset
		local moveset = id and Movesets.byId[id]
		if moveset then
			return moveset
		end
	end
	return Movesets.byId.Fists
end

local function publishWeapon(fighter: Fighter, deployEndsAt: number?)
	local model = fighter.model
	local loadout = loadoutOf(fighter)
	model:SetAttribute("Loadout", loadout.kind)
	model:SetAttribute("WeaponId", loadout.weaponMoveset)
	model:SetAttribute("OneEyed", loadout.oneEyed)
	model:SetAttribute("WeaponState", fighter.weaponState)
	if deployEndsAt then
		model:SetAttribute("DeployEndsAt", deployEndsAt)
	end
end

local function getFighter(model: Model?): Fighter?
	if not model then
		return nil
	end
	local existing = fighters[model]
	if existing then
		return existing
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		return nil
	end

	local fighter: Fighter = {
		model = model,
		humanoid = humanoid,
		root = root,
		player = Players:GetPlayerFromCharacter(model),
		actionToken = 0,
		pending = nil,
		windupEndsAt = 0,
		busyUntil = 0,
		lastSwing = 0,
		chainIndex = 0,
		feintReadyAt = 0,
		skillReadyAt = {},
		blocking = false,
		blockStartedAt = 0,
		lastBlockAt = 0,
		posture = CombatConfig.Posture.Max,
		stamina = CombatConfig.Stamina.Max,
		lastStaminaUse = 0,
		stunnedUntil = 0,
		iFramesUntil = 0,
		dashReadyAt = 0,
		dodgeReadyAt = 0,
		weaponState = "Sheathed",
		rc = CombatConfig.RC.Max,
		charge = CombatConfig.QuinqueCharge.Start,
	}
	fighters[model] = fighter

	model:SetAttribute("MaxPosture", CombatConfig.Posture.Max)
	model:SetAttribute("MaxStamina", CombatConfig.Stamina.Max)
	publishWeapon(fighter)
	model.Destroying:Connect(function()
		fighters[model] = nil
	end)
	return fighter
end

local function isAlive(fighter: Fighter): boolean
	return fighter.humanoid.Health > 0 and fighter.model.Parent ~= nil
end

local function isStunned(fighter: Fighter, t: number): boolean
	return t < fighter.stunnedUntil
end

local function isBusy(fighter: Fighter, t: number): boolean
	return t < fighter.busyUntil or fighter.pending ~= nil
end

-- Cancels whatever the fighter was doing: pending hits, a deploy, the chain.
local function interrupt(fighter: Fighter)
	fighter.actionToken += 1
	fighter.pending = nil
	fighter.chainIndex = 0
	if fighter.weaponState == "Deploying" then
		fighter.weaponState = "Sheathed"
		publishWeapon(fighter)
	end
end

local function stun(fighter: Fighter, t: number, duration: number)
	fighter.stunnedUntil = math.max(fighter.stunnedUntil, t + duration)
	fighter.blocking = false
	interrupt(fighter)
end

local function fxResult(target: Fighter, result: string)
	combatFx:FireAllClients(CombatFx.Result, target.model, result, target.root.Position)
end

local function applyVelocity(root: BasePart, velocity: Vector3, duration: number)
	local attachment = Instance.new("Attachment")
	attachment.Parent = root

	local mover = Instance.new("LinearVelocity")
	mover.Attachment0 = attachment
	mover.RelativeTo = Enum.ActuatorRelativeTo.World
	mover.MaxForce = math.huge
	mover.VectorVelocity = velocity
	mover.Parent = root

	Debris:AddItem(mover, duration)
	Debris:AddItem(attachment, duration)
end

local function knockback(target: Fighter, from: BasePart, kb: Movesets.Knockback)
	local away = target.root.Position - from.Position
	away = Vector3.new(away.X, 0, away.Z)
	local direction = if away.Magnitude > 0.01 then away.Unit else from.CFrame.LookVector
	applyVelocity(target.root, direction * kb.speed + Vector3.new(0, kb.upward, 0), kb.duration)
end

-- True when `attacker` is in front of `defender`, so the block covers the hit.
local function isFacing(defender: BasePart, attacker: BasePart): boolean
	local toAttacker = attacker.Position - defender.Position
	toAttacker = Vector3.new(toAttacker.X, 0, toAttacker.Z)
	if toAttacker.Magnitude < 0.01 then
		return true
	end
	return defender.CFrame.LookVector:Dot(toAttacker.Unit) > CombatConfig.Block.FrontAngleDot
end

-- Marks both fighters as in combat. A PvP tag isn't downgraded to PvE
-- while it's still active.
local function tagCombat(attacker: Fighter, target: Fighter, t: number)
	local kind = if attacker.player and target.player then "PvP" else "PvE"
	local untilTime = t + CombatConfig.CombatTagDuration
	for _, fighter in { attacker, target } do
		local model = fighter.model
		local current = model:GetAttribute("CombatTagUntil")
		local stillPvP = model:GetAttribute("CombatTag") == "PvP" and typeof(current) == "number" and t < current
		model:SetAttribute("CombatTag", if stillPvP then "PvP" else kind)
		model:SetAttribute("CombatTagUntil", untilTime)
	end
end

local function matchupMultiplier(attackerType: string?, defenderType: string?): number
	if not attackerType or not defenderType then
		return 1
	end
	if Movesets.Beats[attackerType] == defenderType then
		return CombatConfig.MatchupBonus
	elseif Movesets.Beats[defenderType] == attackerType then
		return 1 / CombatConfig.MatchupBonus
	end
	return 1
end

local function resolveHit(attacker: Fighter, target: Fighter, moveset: Moveset, attack: Attack, t: number)
	local block = CombatConfig.Block

	if t < target.iFramesUntil then
		fxResult(target, CombatFx.Results.Dodged)
		return
	end
	tagCombat(attacker, target, t)

	if not attack.unblockable and target.blocking and isFacing(target.root, attacker.root) then
		if t - target.blockStartedAt <= block.ParryWindow then
			stun(attacker, t, block.ParryStun)
			target.posture = math.min(CombatConfig.Posture.Max, target.posture + block.ParryPostureRefund)
			fxResult(target, CombatFx.Results.Parried)
			return
		end

		target.posture -= attack.postureDamage
		target.lastBlockAt = t
		if target.posture <= 0 then
			target.posture = CombatConfig.Posture.Max
			stun(target, t, block.GuardBreakStun)
			fxResult(target, CombatFx.Results.GuardBreak)
		else
			fxResult(target, CombatFx.Results.Blocked)
		end
		return
	end

	local damage = attack.damage * matchupMultiplier(moveset.kaguneType, currentMoveset(target).kaguneType)
	if attacker.player then
		target.humanoid:SetAttribute("LastDamagedBy", attacker.player.UserId)
	end
	target.humanoid:TakeDamage(damage)

	if attack.heal then
		local humanoid = attacker.humanoid
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + damage * attack.heal)
	end
	if moveset.resource == "Charge" then
		attacker.charge =
			math.min(CombatConfig.QuinqueCharge.Max, attacker.charge + CombatConfig.QuinqueCharge.GainOnHit)
	end

	stun(target, t, attack.hitStun)
	if attack.knockback then
		knockback(target, attacker.root, attack.knockback)
	end
	fxResult(target, CombatFx.Results.Hit)
end

local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Exclude

local function findTargets(attacker: Fighter, attack: Attack): { Fighter }
	local hitboxCFrame = attacker.root.CFrame * CFrame.new(attack.offset)
	overlapParams.FilterDescendantsInstances = { attacker.model }

	local targets: { Fighter } = {}
	local seen: { [Model]: boolean } = {}
	for _, part in workspace:GetPartBoundsInBox(hitboxCFrame, attack.hitbox, overlapParams) do
		local model = part:FindFirstAncestorOfClass("Model")
		-- Weapon models are parented under characters; walk up to the character.
		while model and not model:FindFirstChildOfClass("Humanoid") do
			model = model:FindFirstAncestorOfClass("Model")
		end
		if model and not seen[model] then
			seen[model] = true
			local target = getFighter(model)
			if target and isAlive(target) then
				table.insert(targets, target)
			end
		end
	end
	return targets
end

local function hasResource(fighter: Fighter, moveset: Moveset, cost: number): boolean
	if moveset.resource == "RC" then
		return fighter.rc >= cost
	elseif moveset.resource == "Charge" then
		return fighter.charge >= cost
	end
	return true
end

local function spendResource(fighter: Fighter, moveset: Moveset, cost: number)
	if moveset.resource == "RC" then
		fighter.rc -= cost
	elseif moveset.resource == "Charge" then
		fighter.charge -= cost
	end
end

-- Starts an attack's windup, then lands its hits unless interrupted.
-- Returns once the windup is scheduled; `onDone` gets whether anything was hit.
local function performAttack(
	fighter: Fighter,
	moveset: Moveset,
	attack: Attack,
	kind: "M1" | "Skill",
	t: number,
	onDone: ((landed: boolean) -> ())?
)
	local hits = attack.hits or 1
	local interval = attack.hitInterval or 0

	fighter.actionToken += 1
	local token = fighter.actionToken
	fighter.pending = kind
	fighter.windupEndsAt = t + attack.windup
	fighter.busyUntil = t + attack.windup + (hits - 1) * interval + attack.recovery

	if attack.lunge then
		applyVelocity(fighter.root, fighter.root.CFrame.LookVector * attack.lunge, attack.windup)
	end

	task.delay(attack.windup, function()
		local landed = false
		for i = 1, hits do
			if fighter.actionToken ~= token or not isAlive(fighter) then
				return
			end
			local hitTime = now()
			for _, target in findTargets(fighter, attack) do
				landed = true
				resolveHit(fighter, target, moveset, attack, hitTime)
			end
			if i < hits then
				task.wait(interval)
			end
		end
		if fighter.actionToken == token then
			fighter.pending = nil
			if onDone then
				onDone(landed)
			end
		end
	end)
end

local function handleM1(fighter: Fighter, t: number)
	if fighter.blocking or isStunned(fighter, t) or isBusy(fighter, t) or fighter.weaponState == "Deploying" then
		return
	end

	local moveset = currentMoveset(fighter)
	if t - fighter.lastSwing > moveset.chainResetTime or fighter.chainIndex >= #moveset.m1 then
		fighter.chainIndex = 0
	end
	local attack = moveset.m1[fighter.chainIndex + 1]
	local cost = attack.cost or 0
	if not hasResource(fighter, moveset, cost) then
		return
	end
	spendResource(fighter, moveset, cost)

	fighter.chainIndex += 1
	fighter.lastSwing = t
	combatFx:FireAllClients(CombatFx.Swing, fighter.model, moveset.id, fighter.chainIndex, t + attack.windup)
	performAttack(fighter, moveset, attack, "M1", t, function(landed)
		-- Whiffing resets the chain (vault/02-Design/Combat System.md).
		if not landed then
			fighter.chainIndex = 0
		end
	end)
end

local function handleFeint(fighter: Fighter, t: number)
	if fighter.pending ~= "M1" or t >= fighter.windupEndsAt or t < fighter.feintReadyAt then
		return
	end
	local feint = CombatConfig.Feint
	fighter.actionToken += 1
	fighter.pending = nil
	fighter.chainIndex = math.max(fighter.chainIndex - 1, 0)
	fighter.busyUntil = t + feint.Recovery
	fighter.feintReadyAt = t + feint.Cooldown
	combatFx:FireAllClients(CombatFx.Feint, fighter.model)
end

local function handleSkill(skillKey: string): (Fighter, number) -> ()
	return function(fighter: Fighter, t: number)
		if fighter.blocking or isStunned(fighter, t) or isBusy(fighter, t) or fighter.weaponState ~= "Drawn" then
			return
		end
		local moveset = currentMoveset(fighter)
		local attack = moveset.skills[skillKey]
		if not attack then
			return
		end
		local cooldownKey = moveset.id .. skillKey
		if t < (fighter.skillReadyAt[cooldownKey] or 0) then
			return
		end
		local cost = attack.cost or 0
		if not hasResource(fighter, moveset, cost) then
			return
		end
		spendResource(fighter, moveset, cost)
		fighter.skillReadyAt[cooldownKey] = t + (attack.cooldown or 0)
		fighter.chainIndex = 0

		combatFx:FireAllClients(CombatFx.Skill, fighter.model, moveset.id, skillKey, t + attack.windup)
		performAttack(fighter, moveset, attack, "Skill", t)
	end
end

local function handleBlockStart(fighter: Fighter, t: number)
	if fighter.blocking or isStunned(fighter, t) or isBusy(fighter, t) then
		return
	end
	fighter.blocking = true
	fighter.blockStartedAt = t
	fighter.lastBlockAt = t
end

local function handleBlockEnd(fighter: Fighter, t: number)
	if fighter.blocking then
		fighter.blocking = false
		fighter.lastBlockAt = t
	end
end

local function trySpendStamina(fighter: Fighter, cost: number, t: number): boolean
	if fighter.stamina < cost then
		return false
	end
	fighter.stamina -= cost
	fighter.lastStaminaUse = t
	return true
end

local function handleDash(fighter: Fighter, t: number)
	local dash = CombatConfig.Dash
	if isStunned(fighter, t) or t < fighter.dashReadyAt then
		return
	end
	if not trySpendStamina(fighter, dash.StaminaCost, t) then
		return
	end
	fighter.dashReadyAt = t + dash.Cooldown
	fighter.blocking = false
end

local function handleDodge(fighter: Fighter, t: number)
	local dodge = CombatConfig.Dodge
	if isStunned(fighter, t) or t < fighter.dodgeReadyAt then
		return
	end
	if not trySpendStamina(fighter, dodge.StaminaCost, t) then
		return
	end
	-- Dodging cancels a windup: it's the panic button.
	if fighter.pending == "M1" or fighter.pending == "Skill" then
		interrupt(fighter)
	end
	fighter.dodgeReadyAt = t + dodge.Cooldown
	fighter.iFramesUntil = t + dodge.IFrames
	fighter.blocking = false
end

local function sheathe(fighter: Fighter, t: number)
	fighter.weaponState = "Sheathed"
	fighter.chainIndex = 0
	fighter.busyUntil = math.max(fighter.busyUntil, t + CombatConfig.Deploy.SheatheTime)
	publishWeapon(fighter)
end

local function handleToggleWeapon(fighter: Fighter, t: number)
	if fighter.blocking or isStunned(fighter, t) or isBusy(fighter, t) then
		return
	end

	if fighter.weaponState == "Drawn" then
		sheathe(fighter, t)
		return
	elseif fighter.weaponState ~= "Sheathed" then
		return
	end

	local loadout = loadoutOf(fighter)
	if not loadout.weaponMoveset then
		return
	end
	local deploy = CombatConfig.Deploy
	local duration = if loadout.kind == "Ghoul" then deploy.KaguneTime else deploy.QuinqueTime
	if loadout.kind == "Ghoul" and fighter.rc < CombatConfig.RC.RetractBelow * 10 then
		return
	end

	fighter.actionToken += 1
	local token = fighter.actionToken
	fighter.pending = "Deploy"
	fighter.weaponState = "Deploying"
	fighter.busyUntil = t + duration
	publishWeapon(fighter, t + duration)

	task.delay(duration, function()
		if fighter.actionToken ~= token or not isAlive(fighter) then
			return
		end
		fighter.pending = nil
		fighter.weaponState = "Drawn"
		publishWeapon(fighter)
	end)
end

local function handleDevSwapOrigin(fighter: Fighter, t: number)
	local player = fighter.player
	if not player or not RunService:IsStudio() then
		return
	end
	interrupt(fighter)
	Loadout.devSwap(player)
	sheathe(fighter, t)
end

local handlers: { [string]: (Fighter, number) -> () } = {
	[CombatActions.M1] = handleM1,
	[CombatActions.Feint] = handleFeint,
	[CombatActions.BlockStart] = handleBlockStart,
	[CombatActions.BlockEnd] = handleBlockEnd,
	[CombatActions.Dash] = handleDash,
	[CombatActions.Dodge] = handleDodge,
	[CombatActions.Skill1] = handleSkill(CombatActions.Skill1),
	[CombatActions.Skill2] = handleSkill(CombatActions.Skill2),
	[CombatActions.ToggleWeapon] = handleToggleWeapon,
	[CombatActions.DevSwapOrigin] = handleDevSwapOrigin,
}

local function isRateLimited(player: Player, t: number): boolean
	local limit = rateLimits[player]
	if not limit or t - limit.windowStart >= 1 then
		limit = { windowStart = t, count = 0 }
		rateLimits[player] = limit
	end
	limit.count += 1
	return limit.count > CombatConfig.MaxActionsPerSecond
end

-- Regenerates resources, sets walk speed, and publishes state as attributes
-- on the character. RC and quinque charge stay server-only (hidden values).
local function tick(dt: number)
	local t = now()
	local posture = CombatConfig.Posture
	local stamina = CombatConfig.Stamina
	local walkSpeed = CombatConfig.WalkSpeed

	for model, fighter in fighters do
		-- Respawned characters may be removed without being destroyed.
		if model.Parent == nil then
			fighters[model] = nil
			continue
		end

		-- Test dummies flagged AlwaysBlock re-raise their guard once a stun ends.
		if not fighter.blocking and not isStunned(fighter, t) and model:GetAttribute("AlwaysBlock") == true then
			fighter.blocking = true
			fighter.blockStartedAt = t - CombatConfig.Block.ParryWindow - 1
		end

		if not fighter.blocking and t - fighter.lastBlockAt > posture.RegenDelay then
			fighter.posture = math.min(posture.Max, fighter.posture + posture.RegenPerSecond * dt)
		end
		if t - fighter.lastStaminaUse > stamina.RegenDelay then
			fighter.stamina = math.min(stamina.Max, fighter.stamina + stamina.RegenPerSecond * dt)
		end

		local moveset = currentMoveset(fighter)
		if fighter.weaponState ~= "Drawn" or moveset.resource ~= "RC" then
			fighter.rc = math.min(CombatConfig.RC.Max, fighter.rc + CombatConfig.RC.RegenPerSecond * dt)
		elseif fighter.rc < CombatConfig.RC.RetractBelow and not fighter.pending then
			sheathe(fighter, t)
		end
		local charge = CombatConfig.QuinqueCharge
		fighter.charge = math.min(charge.Max, fighter.charge + charge.RegenPerSecond * dt)

		if fighter.player then
			local speed = if isStunned(fighter, t)
				then walkSpeed.Stunned
				elseif fighter.weaponState == "Deploying" then walkSpeed.Deploying
				elseif fighter.blocking then walkSpeed.Blocking
				elseif fighter.pending == "M1" or fighter.pending == "Skill" then walkSpeed.Attacking
				else walkSpeed.Normal
			if fighter.humanoid.WalkSpeed ~= speed then
				fighter.humanoid.WalkSpeed = speed
			end
		end

		model:SetAttribute("Posture", math.floor(fighter.posture))
		model:SetAttribute("Stamina", math.floor(fighter.stamina))
		model:SetAttribute("Blocking", fighter.blocking)
		model:SetAttribute("StunnedUntil", fighter.stunnedUntil)
	end
end

function CombatService.start()
	combatAction.OnServerEvent:Connect(function(player: Player, action: unknown)
		if typeof(action) ~= "string" then
			return
		end
		local handler = handlers[action]
		if not handler then
			return
		end

		local t = now()
		if isRateLimited(player, t) then
			return
		end

		local fighter = getFighter(player.Character)
		if not fighter or not isAlive(fighter) then
			return
		end
		handler(fighter, t)
	end)

	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			character:WaitForChild("HumanoidRootPart")
			getFighter(character)
		end)
		if player.Character then
			getFighter(player.Character)
		end
		-- The origin is rolled after join; refresh the character's loadout.
		player:GetAttributeChangedSignal("Origin"):Connect(function()
			local fighter = player.Character and fighters[player.Character]
			if fighter then
				publishWeapon(fighter)
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end

	-- Register NPCs (such as training dummies) as they appear, so state like
	-- AlwaysBlock applies before their first hit.
	local function onWorkspaceChild(child: Instance)
		if child:IsA("Model") and child:FindFirstChildOfClass("Humanoid") then
			getFighter(child)
		end
	end
	workspace.ChildAdded:Connect(onWorkspaceChild)
	for _, child in workspace:GetChildren() do
		onWorkspaceChild(child)
	end

	Players.PlayerRemoving:Connect(function(player)
		rateLimits[player] = nil
	end)

	RunService.Heartbeat:Connect(tick)
end

return CombatService
