--!strict
-- Plays the procedural poses from Poses on every fighter this client can see.
-- Runs in PreSimulation, after the Animator has written this frame's
-- Motor6D.Transform values, and multiplies the pose on top so walking and
-- idling still show underneath. Transform isn't replicated, so every client
-- animates every character itself from the server's CombatFx events and the
-- character attributes (Blocking, StunnedUntil, WeaponState).
--
-- The local player's attacks are predicted: CombatController plays them on
-- input, and the server's echo for the same pose is then skipped.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CombatFx = require(ReplicatedStorage.Shared.CombatFx)
local Movesets = require(ReplicatedStorage.Shared.Movesets)
local Characters = require(script.Parent.Characters)
local Poses = require(script.Parent.Poses)

local combatFx = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CombatFx") :: RemoteEvent
local localPlayer = Players.LocalPlayer

local DEFAULT_STRIKE_TIME = 0.1
local HOLD_BLEND_SPEED = 12 -- weight per second
local PREDICTION_MATCH_WINDOW = 0.4

export type ActiveAttack = {
	name: string,
	pose: Poses.AttackPose,
	startedAt: number,
	windupEndsAt: number,
	strikeEndsAt: number,
	endsAt: number,
	predicted: boolean,
}

type State = {
	character: Model,
	joints: { [string]: Motor6D },
	attack: ActiveAttack?,
	holdWeights: { [string]: number },
	-- What we wrote to each joint last frame and the Transform underneath it,
	-- so joints no animation track touches don't accumulate our offsets.
	written: { [string]: CFrame },
	bases: { [string]: CFrame },
}

local states: { [Model]: State } = {}

local CharacterAnimator = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function easeOut(alpha: number): number
	return 1 - (1 - alpha) * (1 - alpha)
end

local function findJoints(character: Model): { [string]: Motor6D }
	local joints: { [string]: Motor6D } = {}
	local torso = character:FindFirstChild("Torso")
	local root = character:FindFirstChild("HumanoidRootPart")
	for key, name in Poses.JointNames do
		local parent = if key == "Root" then root else torso
		local joint = parent and parent:FindFirstChild(name)
		if joint and joint:IsA("Motor6D") then
			joints[key] = joint
		end
	end
	return joints
end

local function isStunned(character: Model, t: number): boolean
	local stunnedUntil = character:GetAttribute("StunnedUntil")
	return typeof(stunnedUntil) == "number" and t < stunnedUntil
end

-- The held pose this character's attributes call for, if any.
local function holdFor(character: Model, t: number): string?
	if isStunned(character, t) then
		return "Stunned"
	end
	local weaponState = character:GetAttribute("WeaponState")
	local loadout = character:GetAttribute("Loadout")
	local drawn = weaponState == "Drawn"
	if character:GetAttribute("Blocking") == true then
		if drawn and loadout == "Investigator" then
			return "BlockBlade"
		elseif drawn and loadout == "Ghoul" then
			return "BlockKagune"
		end
		return "BlockFists"
	end
	if weaponState == "Deploying" then
		return if loadout == "Ghoul" then "DeployKagune" else "DeployQuinque"
	end
	if drawn and loadout == "Investigator" then
		return "BladeReady"
	end
	return nil
end

local function blendSets(offsets: { [string]: CFrame }, set: Poses.JointSet, weight: number)
	for key, cframe in set do
		local current = offsets[key] or CFrame.identity
		offsets[key] = current * CFrame.identity:Lerp(cframe, weight)
	end
end

local function lerpSets(offsets: { [string]: CFrame }, from: Poses.JointSet, to: Poses.JointSet, alpha: number)
	local keys: { [string]: boolean } = {}
	for key in from do
		keys[key] = true
	end
	for key in to do
		keys[key] = true
	end
	for key in keys do
		local a = from[key] or CFrame.identity
		local b = to[key] or CFrame.identity
		local current = offsets[key] or CFrame.identity
		offsets[key] = current * a:Lerp(b, alpha)
	end
end

local REST: Poses.JointSet = {}

local function sampleAttack(offsets: { [string]: CFrame }, attack: ActiveAttack, t: number)
	local pose = attack.pose
	if t < attack.windupEndsAt then
		local span = math.max(attack.windupEndsAt - attack.startedAt, 1e-3)
		lerpSets(offsets, REST, pose.windup, easeOut(math.clamp((t - attack.startedAt) / span, 0, 1)))
	elseif t < attack.strikeEndsAt then
		local alpha = easeOut((t - attack.windupEndsAt) / (attack.strikeEndsAt - attack.windupEndsAt))
		lerpSets(offsets, pose.windup, pose.strike, alpha)
		if pose.spin then
			offsets.Root = (offsets.Root or CFrame.identity) * CFrame.Angles(0, 0, -2 * math.pi * alpha)
		end
	else
		local span = math.max(attack.endsAt - attack.strikeEndsAt, 1e-3)
		lerpSets(offsets, pose.strike, REST, easeOut(math.clamp((t - attack.strikeEndsAt) / span, 0, 1)))
	end
end

local function step(dt: number)
	local t = now()
	for character, state in states do
		local attack = state.attack
		if attack and (t >= attack.endsAt or (isStunned(character, t) and t < attack.strikeEndsAt)) then
			state.attack = nil
			attack = nil
		end

		local hold = if attack then nil else holdFor(character, t)
		if hold and state.holdWeights[hold] == nil then
			state.holdWeights[hold] = 0
		end

		local offsets: { [string]: CFrame } = {}
		for name, weight in state.holdWeights do
			local target = if name == hold then 1 else 0
			local delta = HOLD_BLEND_SPEED * dt
			weight = if target > weight then math.min(target, weight + delta) else math.max(target, weight - delta)
			if weight <= 0 then
				state.holdWeights[name] = nil
				continue
			end
			state.holdWeights[name] = weight
			blendSets(offsets, Poses.Holds[name], weight)
		end
		if attack then
			sampleAttack(offsets, attack, t)
		end

		for key, joint in state.joints do
			if not joint.Parent then
				continue
			end
			local current = joint.Transform
			local base = if state.written[key] == current then state.bases[key] else current
			local offset = offsets[key]
			if offset then
				local result = base * offset
				joint.Transform = result
				state.written[key] = result
				state.bases[key] = base
			elseif state.written[key] then
				joint.Transform = base
				state.written[key] = nil
				state.bases[key] = nil
			end
		end
	end
end

-- Starts an attack pose. `windupEndsAt` is in server time.
function CharacterAnimator.playAttack(
	character: Model,
	poseName: string,
	windupEndsAt: number,
	recovery: number,
	predicted: boolean?
)
	local state = states[character]
	local pose = Poses.Attacks[poseName]
	if not state or not pose then
		return
	end
	local t = now()
	if not predicted and character == localPlayer.Character then
		local current = state.attack
		if
			current
			and current.predicted
			and current.name == poseName
			and t - current.startedAt < PREDICTION_MATCH_WINDOW
		then
			return
		end
	end
	-- If the event arrived late, still show a short windup instead of skipping it.
	local windupEnd = math.max(windupEndsAt, t + 0.05)
	local strikeEnd = windupEnd + (pose.strikeTime or DEFAULT_STRIKE_TIME)
	state.attack = {
		name = poseName,
		pose = pose,
		startedAt = t,
		windupEndsAt = windupEnd,
		strikeEndsAt = strikeEnd,
		endsAt = strikeEnd + recovery,
		predicted = predicted == true,
	}
end

function CharacterAnimator.cancel(character: Model)
	local state = states[character]
	if state then
		state.attack = nil
	end
end

-- The attack this character is playing right now, for weapon rigs that
-- animate alongside the body (the kagune tentacles).
function CharacterAnimator.getAttack(character: Model): ActiveAttack?
	local state = states[character]
	return state and state.attack
end

local function onFx(kind: string, model: Model, ...: any)
	if typeof(model) ~= "Instance" or not states[model] then
		return
	end
	if kind == CombatFx.Swing then
		local movesetId, chainIndex, windupEndsAt = ...
		local moveset = Movesets.byId[movesetId]
		local attack = moveset and moveset.m1[chainIndex]
		if attack then
			CharacterAnimator.playAttack(model, attack.pose, windupEndsAt, attack.recovery)
		end
	elseif kind == CombatFx.Skill then
		local movesetId, skillKey, windupEndsAt = ...
		local moveset = Movesets.byId[movesetId]
		local attack = moveset and moveset.skills[skillKey]
		if attack then
			local hitsTime = ((attack.hits or 1) - 1) * (attack.hitInterval or 0)
			CharacterAnimator.playAttack(model, attack.pose, windupEndsAt, attack.recovery + hitsTime)
		end
	elseif kind == CombatFx.Feint then
		CharacterAnimator.cancel(model)
	end
end

function CharacterAnimator.start()
	Characters.observe(function(character)
		states[character] = {
			character = character,
			joints = findJoints(character),
			attack = nil,
			holdWeights = {},
			written = {},
			bases = {},
		}
		return function()
			states[character] = nil
		end
	end)
	combatFx.OnClientEvent:Connect(onFx)
	RunService.PreSimulation:Connect(step)
end

return CharacterAnimator
