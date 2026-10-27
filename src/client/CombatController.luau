--!strict
-- Reads combat input and asks the server to act. Never applies damage itself.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local CombatActions = require(ReplicatedStorage.Shared.CombatActions)

local combatAction = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CombatAction") :: RemoteEvent

local CombatController = {}

function CombatController.start()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			combatAction:FireServer(CombatActions.M1)
		end
	end)
end

return CombatController
