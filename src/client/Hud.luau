--!strict
-- Bottom-left HP, posture and stamina bars, read from the Humanoid and the
-- attributes CombatService publishes on the character.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local BAR_WIDTH = 260
local BAR_HEIGHT = 14
local BAR_GAP = 6

local Hud = {}

local function makeBar(parent: Instance, order: number, label: string, color: Color3): Frame
	local back = Instance.new("Frame")
	back.Name = label
	back.Size = UDim2.fromOffset(BAR_WIDTH, BAR_HEIGHT)
	back.Position = UDim2.fromOffset(0, (order - 1) * (BAR_HEIGHT + BAR_GAP))
	back.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
	back.BackgroundTransparency = 0.2
	back.BorderSizePixel = 0
	back.Parent = parent

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Parent = back

	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = label
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0.5
	text.Font = Enum.Font.GothamBold
	text.TextSize = 11
	text.Parent = back

	return fill
end

local function ratio(value: unknown, max: unknown): number
	if typeof(value) ~= "number" or typeof(max) ~= "number" or max <= 0 then
		return 1
	end
	return math.clamp(value / max, 0, 1)
end

function Hud.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "CombatHud"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0, 1)
	holder.Position = UDim2.new(0, 16, 1, -16)
	holder.Size = UDim2.fromOffset(BAR_WIDTH, 3 * BAR_HEIGHT + 2 * BAR_GAP)
	holder.Parent = gui

	local health = makeBar(holder, 1, "HP", Color3.fromRGB(200, 40, 50))
	local posture = makeBar(holder, 2, "POSTURE", Color3.fromRGB(230, 190, 60))
	local stamina = makeBar(holder, 3, "STAMINA", Color3.fromRGB(70, 160, 230))

	RunService.RenderStepped:Connect(function()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		gui.Enabled = humanoid ~= nil
		if not character or not humanoid then
			return
		end
		health.Size = UDim2.fromScale(ratio(humanoid.Health, humanoid.MaxHealth), 1)
		posture.Size = UDim2.fromScale(ratio(character:GetAttribute("Posture"), character:GetAttribute("MaxPosture")), 1)
		stamina.Size = UDim2.fromScale(ratio(character:GetAttribute("Stamina"), character:GetAttribute("MaxStamina")), 1)
	end)
end

return Hud
