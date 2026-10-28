--!strict
-- Tracks every R6 fighter model in the workspace (players and NPCs) so the
-- animation and weapon visuals can run for all of them on this client.

local Players = game:GetService("Players")

type Observer = (character: Model) -> (() -> ())?

local Characters = {}

local tracked: { [Model]: { () -> () } } = {}
local observers: { Observer } = {}

local function isFighter(model: Instance): boolean
	return model:IsA("Model")
		and model:FindFirstChildOfClass("Humanoid") ~= nil
		and model:FindFirstChild("Torso") ~= nil
		and model:FindFirstChild("HumanoidRootPart") ~= nil
end

local function untrack(model: Model)
	local cleanups = tracked[model]
	if not cleanups then
		return
	end
	tracked[model] = nil
	for _, cleanup in cleanups do
		task.spawn(cleanup)
	end
end

local function track(model: Model)
	if tracked[model] or not isFighter(model) then
		return
	end
	local cleanups: { () -> () } = {}
	tracked[model] = cleanups
	for _, observer in observers do
		local cleanup = observer(model)
		if cleanup then
			table.insert(cleanups, cleanup)
		end
	end
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) then
			untrack(model)
		end
	end)
end

-- Calls `observer` for every tracked character, now and in the future. The
-- function it returns (if any) runs when that character goes away.
function Characters.observe(observer: Observer)
	table.insert(observers, observer)
	for model, cleanups in tracked do
		local cleanup = observer(model)
		if cleanup then
			table.insert(cleanups, cleanup)
		end
	end
end

function Characters.all(): { [Model]: any }
	return tracked
end

function Characters.start()
	local function consider(instance: Instance)
		if instance:IsA("Model") then
			-- Characters stream in part by part; wait briefly for the rig.
			task.delay(0.1, function()
				if instance:IsDescendantOf(workspace) then
					track(instance)
				end
			end)
		end
	end
	workspace.ChildAdded:Connect(consider)
	for _, child in workspace:GetChildren() do
		consider(child)
	end
	for _, player in Players:GetPlayers() do
		if player.Character then
			consider(player.Character)
		end
	end
end

return Characters
