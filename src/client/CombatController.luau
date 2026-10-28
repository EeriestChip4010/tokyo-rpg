--!strict
-- Reads combat input and asks the server to act. Never applies damage itself.
-- Dash and dodge movement is played locally right away for responsiveness
-- (the character is client-simulated); the server still decides cooldowns,
-- stamina and dodge i-frames, and this mirrors those checks so a rejected
-- action doesn't move the player.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

local CombatActions = require(ReplicatedStorage.Shared.CombatActions)
local CombatConfig = require(ReplicatedStorage.Shared.CombatConfig)

local combatAction = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CombatAction") :: RemoteEvent
local player = Players.LocalPlayer

local BLOCK_KEY = Enum.KeyCode.F
local MOVE_KEY = Enum.KeyCode.Q
local MOVING_THRESHOLD = 0.1

local dashReadyAt = 0
local dodgeReadyAt = 0

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
		push(root, -root.CFrame.LookVector * dodge.Speed, dodge.Duration)
	end
end

function CombatController.start()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			combatAction:FireServer(CombatActions.M1)
		elseif input.KeyCode == BLOCK_KEY then
			combatAction:FireServer(CombatActions.BlockStart)
		elseif input.KeyCode == MOVE_KEY then
			onMoveKey()
		end
	end)

	-- Always send BlockEnd, even if the release was over a UI element.
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == BLOCK_KEY then
			combatAction:FireServer(CombatActions.BlockEnd)
		end
	end)
end

return CombatController
