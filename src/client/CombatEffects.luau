--!strict
-- Client-side hit effects. The server reports each outcome on CombatFx and
-- every client renders it locally (roblox-vfx: one-shot bursts belong on the
-- client). Blood is kept minimal on purpose: a few small dark-red flecks.
--
-- Hit flashes: white = hit, blue = blocked, yellow = parried,
-- red = guard break, grey = dodged or feinted.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatFx = require(ReplicatedStorage.Shared.CombatFx)
local Movesets = require(ReplicatedStorage.Shared.Movesets)

local combatFx = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CombatFx") :: RemoteEvent

local Results = CombatFx.Results

local FLASH_COLORS: { [string]: Color3 } = {
	[Results.Hit] = Color3.new(1, 1, 1),
	[Results.Blocked] = Color3.fromRGB(80, 140, 255),
	[Results.Parried] = Color3.fromRGB(255, 220, 60),
	[Results.GuardBreak] = Color3.fromRGB(255, 50, 50),
	[Results.Dodged] = Color3.fromRGB(150, 150, 150),
}

local BLOOD_COLOR = Color3.fromRGB(110, 8, 16)
local SPARK_COLOR = Color3.fromRGB(255, 230, 150)

-- Stock sounds that ship with every Roblox client.
local Sounds = {
	Swing = "rbxasset://sounds/swordslash.wav",
	Heavy = "rbxasset://sounds/swordlunge.wav",
	Draw = "rbxasset://sounds/unsheath.wav",
}

local CombatEffects = {}

function CombatEffects.flash(model: Model, color: Color3, duration: number?)
	local highlight = Instance.new("Highlight")
	highlight.FillColor = color
	highlight.FillTransparency = 0.4
	highlight.OutlineTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model
	Debris:AddItem(highlight, duration or 0.15)
end

-- One-shot particle burst at a world position.
function CombatEffects.burst(position: Vector3, color: Color3, count: number, speed: number?, size: number?)
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.one * 0.2
	holder.CFrame = CFrame.new(position)

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 0.2
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size or 0.25),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new(0.1, 1)
	emitter.Lifetime = NumberRange.new(0.25, 0.45)
	emitter.Speed = NumberRange.new((speed or 12) * 0.5, speed or 12)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, -30, 0)
	emitter.Drag = 4
	emitter.Rate = 0
	emitter.Parent = holder

	holder.Parent = workspace
	emitter:Emit(count)
	Debris:AddItem(holder, 0.6)
end

-- Brief coloured light, for kagune releases and quinque deploys.
function CombatEffects.pulse(parent: BasePart, color: Color3, duration: number)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 3
	light.Range = 10
	light.Parent = parent
	Debris:AddItem(light, duration)
end

function CombatEffects.sound(parent: Instance, id: string, volume: number?, pitch: number?)
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume or 0.5
	sound.PlaybackSpeed = pitch or 1
	sound.RollOffMaxDistance = 80
	sound.Parent = parent
	sound:Play()
	Debris:AddItem(sound, 2)
end

CombatEffects.Sounds = Sounds

local function rootOf(model: Model): BasePart?
	local root = model:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function onFx(kind: string, model: Model, ...: any)
	if typeof(model) ~= "Instance" or not model:IsA("Model") then
		return
	end
	local root = rootOf(model)
	if kind == CombatFx.Result then
		local result, position = ...
		local color = FLASH_COLORS[result]
		if color then
			CombatEffects.flash(model, color)
		end
		if typeof(position) ~= "Vector3" then
			return
		end
		if result == Results.Hit then
			CombatEffects.burst(position, BLOOD_COLOR, 5, 10, 0.18)
		elseif result == Results.Parried or result == Results.Blocked then
			CombatEffects.burst(
				position + Vector3.new(0, 0.5, 0),
				SPARK_COLOR,
				if result == Results.Parried then 14 else 6
			)
		elseif result == Results.GuardBreak then
			CombatEffects.burst(position, FLASH_COLORS[Results.GuardBreak], 18, 16)
		end
		if root and result ~= Results.Dodged then
			CombatEffects.sound(root, Sounds.Heavy, 0.35, if result == Results.Hit then 1.2 else 1.6)
		end
	elseif kind == CombatFx.Swing or kind == CombatFx.Skill then
		local movesetId = ...
		local moveset = Movesets.byId[movesetId]
		if root and moveset then
			local pitch = if moveset.weapon == "Quinque" then 1 elseif moveset.weapon == "Kagune" then 0.7 else 1.4
			CombatEffects.sound(root, Sounds.Swing, if kind == CombatFx.Skill then 0.6 else 0.35, pitch)
		end
	elseif kind == CombatFx.Feint then
		CombatEffects.flash(model, FLASH_COLORS[Results.Dodged], 0.1)
	end
end

function CombatEffects.start()
	combatFx.OnClientEvent:Connect(onFx)
end

return CombatEffects
