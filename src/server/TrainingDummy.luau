--!strict
-- Spawns a standing R15 dummy for testing hits. It respawns after dying.

local Players = game:GetService("Players")

local TrainingDummy = {}

local RESPAWN_DELAY = 3

function TrainingDummy.spawn(position: Vector3)
	local dummy = Players:CreateHumanoidModelFromDescription(
		Instance.new("HumanoidDescription"),
		Enum.HumanoidRigType.R15
	)
	dummy.Name = "TrainingDummy"
	dummy:PivotTo(CFrame.new(position))

	local humanoid = dummy:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayName = "Training Dummy"
	-- Anchored so knockback later doesn't send it flying off the baseplate.
	local root = dummy:FindFirstChild("HumanoidRootPart") :: BasePart
	root.Anchored = true
	humanoid.Died:Connect(function()
		task.delay(RESPAWN_DELAY, function()
			dummy:Destroy()
			TrainingDummy.spawn(position)
		end)
	end)

	dummy.Parent = workspace
end

return TrainingDummy
