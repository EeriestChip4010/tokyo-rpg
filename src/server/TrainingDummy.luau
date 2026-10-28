--!strict
-- Spawns a standing R6 dummy for testing hits. It respawns after dying.
-- A dummy spawned with alwaysBlock = true holds block, for testing posture
-- and guard breaks (CombatService reads the AlwaysBlock attribute).

local Players = game:GetService("Players")

local TrainingDummy = {}

local RESPAWN_DELAY = 3

function TrainingDummy.spawn(position: Vector3, alwaysBlock: boolean?)
	local dummy = Players:CreateHumanoidModelFromDescription(
		Instance.new("HumanoidDescription"),
		Enum.HumanoidRigType.R6
	)
	dummy.Name = if alwaysBlock then "BlockingDummy" else "TrainingDummy"
	dummy:SetAttribute("AlwaysBlock", alwaysBlock == true)
	-- Face +Z, toward the default spawn, so blocks cover hits from players there.
	dummy:PivotTo(CFrame.new(position) * CFrame.Angles(0, math.pi, 0))

	local humanoid = dummy:FindFirstChildOfClass("Humanoid") :: Humanoid
	humanoid.DisplayName = if alwaysBlock then "Blocking Dummy" else "Training Dummy"
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.Died:Connect(function()
		task.delay(RESPAWN_DELAY, function()
			dummy:Destroy()
			TrainingDummy.spawn(position, alwaysBlock)
		end)
	end)

	dummy.Parent = workspace
	local root = dummy:FindFirstChild("HumanoidRootPart") :: BasePart
	root:SetNetworkOwner(nil) -- server simulates it, so knockback applies reliably
end

return TrainingDummy
