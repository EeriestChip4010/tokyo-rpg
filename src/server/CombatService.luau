--!strict
-- Server-authoritative combat. Clients only ask to act; this module checks
-- cooldowns, stun, stamina and rate limits, resolves hits against blocks,
-- parries and dodges, and applies damage.
--
-- Timestamps use workspace:GetServerTimeNow() so clients can compare the
-- values published as attributes (for example StunnedUntil) with their own clock.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CombatConfig = require(ReplicatedStorage.Shared.CombatConfig)
local CombatActions = require(ReplicatedStorage.Shared.CombatActions)

local combatAction = ReplicatedStorage.Remotes.CombatAction :: RemoteEvent

type Fighter = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	isPlayer: boolean,

	lastSwing: number,
	chainIndex: number,

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
}

type RateLimit = {
	windowStart: number,
	count: number,
}

local fighters: { [Model]: Fighter } = {}
local rateLimits: { [Player]: RateLimit } = {}

local HIT_COLOR = Color3.new(1, 1, 1)
local BLOCK_COLOR = Color3.fromRGB(80, 140, 255)
local PARRY_COLOR = Color3.fromRGB(255, 220, 60)
local GUARD_BREAK_COLOR = Color3.fromRGB(255, 50, 50)

local CombatService = {}

local function now(): number
	return workspace:GetServerTimeNow()
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
		isPlayer = Players:GetPlayerFromCharacter(model) ~= nil,
		lastSwing = 0,
		chainIndex = 0,
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
	}
	fighters[model] = fighter

	model:SetAttribute("MaxPosture", CombatConfig.Posture.Max)
	model:SetAttribute("MaxStamina", CombatConfig.Stamina.Max)
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

local function stun(fighter: Fighter, t: number, duration: number)
	fighter.stunnedUntil = math.max(fighter.stunnedUntil, t + duration)
	fighter.blocking = false
	fighter.chainIndex = 0
end

local function flash(model: Model, color: Color3)
	local highlight = Instance.new("Highlight")
	highlight.FillColor = color
	highlight.FillTransparency = 0.4
	highlight.OutlineTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model
	Debris:AddItem(highlight, 0.15)
end

local function knockback(target: Fighter, from: BasePart)
	local finisher = CombatConfig.Finisher
	local away = target.root.Position - from.Position
	away = Vector3.new(away.X, 0, away.Z)
	local direction = if away.Magnitude > 0.01 then away.Unit else from.CFrame.LookVector

	local attachment = Instance.new("Attachment")
	attachment.Parent = target.root

	local velocity = Instance.new("LinearVelocity")
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.MaxForce = math.huge
	velocity.VectorVelocity = direction * finisher.KnockbackSpeed + Vector3.new(0, finisher.KnockbackUpward, 0)
	velocity.Parent = target.root

	Debris:AddItem(velocity, finisher.KnockbackDuration)
	Debris:AddItem(attachment, finisher.KnockbackDuration)
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

local function resolveHit(attacker: Fighter, target: Fighter, isFinisher: boolean, t: number)
	local m1 = CombatConfig.M1
	local block = CombatConfig.Block

	if t < target.iFramesUntil then
		return
	end

	if target.blocking and isFacing(target.root, attacker.root) then
		if t - target.blockStartedAt <= block.ParryWindow then
			stun(attacker, t, block.ParryStun)
			flash(target.model, PARRY_COLOR)
			return
		end

		target.posture -= m1.PostureDamage
		target.lastBlockAt = t
		if target.posture <= 0 then
			target.posture = CombatConfig.Posture.Max
			stun(target, t, block.GuardBreakStun)
			flash(target.model, GUARD_BREAK_COLOR)
		else
			flash(target.model, BLOCK_COLOR)
		end
		return
	end

	target.humanoid:TakeDamage(m1.Damage)
	flash(target.model, HIT_COLOR)
	if isFinisher then
		stun(target, t, CombatConfig.Finisher.Stun)
		knockback(target, attacker.root)
	else
		stun(target, t, m1.HitStun)
	end
end

local function findTargets(attacker: Fighter): { Fighter }
	local m1 = CombatConfig.M1
	local hitboxCFrame = attacker.root.CFrame * CFrame.new(0, 0, -m1.HitboxOffset)

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { attacker.model }

	local targets: { Fighter } = {}
	local seen: { [Model]: boolean } = {}
	for _, part in workspace:GetPartBoundsInBox(hitboxCFrame, m1.HitboxSize, params) do
		local model = part:FindFirstAncestorOfClass("Model")
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

local function handleM1(fighter: Fighter, t: number)
	local m1 = CombatConfig.M1
	if fighter.blocking or isStunned(fighter, t) or t - fighter.lastSwing < m1.SwingInterval then
		return
	end

	if t - fighter.lastSwing > m1.ChainResetTime or fighter.chainIndex >= m1.ChainLength then
		fighter.chainIndex = 0
	end
	fighter.chainIndex += 1
	fighter.lastSwing = t

	local isFinisher = fighter.chainIndex == m1.ChainLength
	for _, target in findTargets(fighter) do
		resolveHit(fighter, target, isFinisher, t)
	end
end

local function handleBlockStart(fighter: Fighter, t: number)
	if fighter.blocking or isStunned(fighter, t) then
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
	fighter.dodgeReadyAt = t + dodge.Cooldown
	fighter.iFramesUntil = t + dodge.IFrames
	fighter.blocking = false
end

local handlers: { [string]: (Fighter, number) -> () } = {
	[CombatActions.M1] = handleM1,
	[CombatActions.BlockStart] = handleBlockStart,
	[CombatActions.BlockEnd] = handleBlockEnd,
	[CombatActions.Dash] = handleDash,
	[CombatActions.Dodge] = handleDodge,
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

-- Regenerates posture and stamina, sets walk speed, and publishes state as
-- attributes on the character for the HUD.
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

		if fighter.isPlayer then
			local speed = if isStunned(fighter, t)
				then walkSpeed.Stunned
				elseif fighter.blocking then walkSpeed.Blocking
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
