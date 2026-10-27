--!strict
-- Server-authoritative combat. Clients only ask to act; this module checks
-- cooldowns and rate limits, finds hits, and applies damage.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatConfig = require(ReplicatedStorage.Shared.CombatConfig)
local CombatActions = require(ReplicatedStorage.Shared.CombatActions)

local combatAction = ReplicatedStorage.Remotes.CombatAction :: RemoteEvent

type PlayerState = {
	lastSwing: number,
	chainIndex: number,
	windowStart: number,
	actionsInWindow: number,
}

local states: { [Player]: PlayerState } = {}

local CombatService = {}

local function getState(player: Player): PlayerState
	local state = states[player]
	if not state then
		state = { lastSwing = 0, chainIndex = 0, windowStart = 0, actionsInWindow = 0 }
		states[player] = state
	end
	return state
end

local function isRateLimited(state: PlayerState, now: number): boolean
	if now - state.windowStart >= 1 then
		state.windowStart = now
		state.actionsInWindow = 0
	end
	state.actionsInWindow += 1
	return state.actionsInWindow > CombatConfig.MaxActionsPerSecond
end

local function getLivingRoot(character: Model?): (BasePart?, Humanoid?)
	if not character then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil, nil
	end
	return root, humanoid
end

local function findTargets(attacker: Model, root: BasePart): { Humanoid }
	local m1 = CombatConfig.M1
	local hitboxCFrame = root.CFrame * CFrame.new(0, 0, -m1.HitboxOffset)

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { attacker }

	local targets: { Humanoid } = {}
	local seen: { [Model]: boolean } = {}
	for _, part in workspace:GetPartBoundsInBox(hitboxCFrame, m1.HitboxSize, params) do
		local model = part:FindFirstAncestorOfClass("Model")
		if model and not seen[model] then
			seen[model] = true
			local _, humanoid = getLivingRoot(model)
			if humanoid then
				table.insert(targets, humanoid)
			end
		end
	end
	return targets
end

local function handleM1(player: Player, state: PlayerState, now: number)
	local m1 = CombatConfig.M1
	if now - state.lastSwing < m1.SwingInterval then
		return
	end

	local character = player.Character
	local root = getLivingRoot(character)
	if not character or not root then
		return
	end

	if now - state.lastSwing > m1.ChainResetTime or state.chainIndex >= m1.ChainLength then
		state.chainIndex = 0
	end
	state.chainIndex += 1
	state.lastSwing = now

	for _, humanoid in findTargets(character, root) do
		humanoid:TakeDamage(m1.Damage)
	end
end

local handlers: { [string]: (Player, PlayerState, number) -> () } = {
	[CombatActions.M1] = handleM1,
}

function CombatService.start()
	combatAction.OnServerEvent:Connect(function(player: Player, action: unknown)
		if typeof(action) ~= "string" then
			return
		end
		local handler = handlers[action]
		if not handler then
			return
		end

		local now = os.clock()
		local state = getState(player)
		if isRateLimited(state, now) then
			return
		end
		handler(player, state, now)
	end)

	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
end

return CombatService
