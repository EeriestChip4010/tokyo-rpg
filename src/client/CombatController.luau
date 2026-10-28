--!strict
-- Reads combat input and asks the server to act. Never applies damage itself.
--
-- Prediction for feel: M1 swings and dash/dodge movement play locally right
-- away, mirroring the server's checks (stun, swing timing, chain, cooldowns,
-- stamina) so a rejected action rarely shows. The server still decides
-- everything; its echo of a predicted swing is skipped by CharacterAnimator,
-- and its chain index re-syncs ours.
--
-- Controls: LMB M1, RMB feint, F block/parry, Q dash (moving) or dodge
-- (still), E/R weapon skills, G draw/sheathe. In Studio, P swaps between
-- the ghoul and investigator test loadouts.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local CombatActions = require(ReplicatedStorage.Shared.CombatActions)
local CombatConfig = require(ReplicatedStorage.Shared.CombatConfig)
local CombatFx = require(ReplicatedStorage.Shared.CombatFx)
local Movesets = require(ReplicatedStorage.Shared.Movesets)
local CharacterAnimator = require(script.Parent.CharacterAnimator)

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local combatAction = remotes:WaitForChild("CombatAction") :: RemoteEvent
local combatFx = remotes:WaitForChild("CombatFx") :: RemoteEvent
local player = Players.LocalPlayer

local Keys = {
	Block = Enum.KeyCode.F,
	Move = Enum.KeyCode.Q,
	Skill1 = Enum.KeyCode.E,
	Skill2 = Enum.KeyCode.R,
	ToggleWeapon = Enum.KeyCode.G,
	DevSwap = Enum.KeyCode.P,
}
local MOVING_THRESHOLD = 0.1

local dashReadyAt = 0
local dodgeReadyAt = 0
local nextSwingAt = 0
local lastSwing = 0
local chainIndex = 0

local CombatController = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function getCharacterParts(): (Model?, Humanoid?, BasePart?)
	local character = player.Character
	if not character then
		return nil, nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil, nil, nil
	end
	return character, humanoid, root
end

local function canAct(character: Model): boolean
	local stunnedUntil = character:GetAttribute("StunnedUntil")
	return not (typeof(stunnedUntil) == "number" and now() < stunnedUntil)
end

local function hasStamina(character: Model, cost: number): boolean
	local stamina = character:GetAttribute("Stamina")
	return typeof(stamina) ~= "number" or stamina >= cost
end

local function currentMoveset(character: Model): Movesets.Moveset
	if character:GetAttribute("WeaponState") == "Drawn" then
		local id = character:GetAttribute("WeaponId")
		local moveset = typeof(id) == "string" and Movesets.byId[id]
		if moveset then
			return moveset
		end
	end
	return Movesets.byId.Fists
end

local function push(root: BasePart, velocity: Vector3, duration: number)
	local attachment = Instance.new("Attachment")
	attachment.Parent = root

	local mover = Instance.new("LinearVelocity")
	mover.Attachment0 = attachment
	mover.RelativeTo = Enum.ActuatorRelativeTo.World
	mover.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	mover.PrimaryTangentAxis = Vector3.xAxis
	mover.SecondaryTangentAxis = Vector3.zAxis
	mover.MaxForce = math.huge
	mover.PlaneVelocity = Vector2.new(velocity.X, velocity.Z)
	mover.Parent = root

	Debris:AddItem(mover, duration)
	Debris:AddItem(attachment, duration)
end

local function onM1()
	combatAction:FireServer(CombatActions.M1)

	local character = getCharacterParts()
	local t = now()
	if
		not character
		or not canAct(character)
		or t < nextSwingAt
		or character:GetAttribute("Blocking") == true
		or character:GetAttribute("WeaponState") == "Deploying"
	then
		return
	end
	local moveset = currentMoveset(character)
	if t - lastSwing > moveset.chainResetTime or chainIndex >= #moveset.m1 then
		chainIndex = 0
	end
	chainIndex += 1
	lastSwing = t
	local attack = moveset.m1[chainIndex]
	nextSwingAt = t + attack.windup + attack.recovery
	CharacterAnimator.playAttack(character, attack.pose, t + attack.windup, attack.recovery, true)
end

-- Q while moving dashes in the move direction; Q while standing still dodges
-- backward with i-frames.
local function onMoveKey()
	local character, humanoid, root = getCharacterParts()
	if not character or not humanoid or not root or not canAct(character) then
		return
	end

	local t = now()
	local moveDirection = humanoid.MoveDirection
	if moveDirection.Magnitude > MOVING_THRESHOLD then
		local dash = CombatConfig.Dash
		if t < dashReadyAt or not hasStamina(character, dash.StaminaCost) then
			return
		end
		dashReadyAt = t + dash.Cooldown
		combatAction:FireServer(CombatActions.Dash)
		push(root, moveDirection.Unit * dash.Speed, dash.Duration)
	else
		local dodge = CombatConfig.Dodge
		if t < dodgeReadyAt or not hasStamina(character, dodge.StaminaCost) then
			return
		end
		dodgeReadyAt = t + dodge.Cooldown
		combatAction:FireServer(CombatActions.Dodge)
		CharacterAnimator.cancel(character)
		push(root, -root.CFrame.LookVector * dodge.Speed, dodge.Duration)
	end
end

local keyActions: { [Enum.KeyCode]: string } = {
	[Keys.Skill1] = CombatActions.Skill1,
	[Keys.Skill2] = CombatActions.Skill2,
	[Keys.ToggleWeapon] = CombatActions.ToggleWeapon,
}

function CombatController.start()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			onM1()
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			combatAction:FireServer(CombatActions.Feint)
		elseif input.KeyCode == Keys.Block then
			combatAction:FireServer(CombatActions.BlockStart)
		elseif input.KeyCode == Keys.Move then
			onMoveKey()
		elseif input.KeyCode == Keys.DevSwap and RunService:IsStudio() then
			combatAction:FireServer(CombatActions.DevSwapOrigin)
		elseif keyActions[input.KeyCode] then
			combatAction:FireServer(keyActions[input.KeyCode])
		end
	end)

	-- Always send BlockEnd, even if the release was over a UI element.
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Keys.Block then
			combatAction:FireServer(CombatActions.BlockEnd)
		end
	end)

	-- The server is the source of truth for the chain (a whiff resets it).
	combatFx.OnClientEvent:Connect(function(kind: string, model: Model, _movesetId: any, index: any)
		if model ~= player.Character then
			return
		end
		if kind == CombatFx.Swing and typeof(index) == "number" then
			chainIndex = index
		elseif kind == CombatFx.Skill or kind == CombatFx.Feint then
			chainIndex = 0
		end
	end)
end

return CombatController
