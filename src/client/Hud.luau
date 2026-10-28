--!strict
-- Pixel-style combat HUD: name plate, HP and stamina (bottom left), posture
-- and state text (bottom center, shown only when relevant), and dash/dodge
-- cooldown slots. Reads the Humanoid and the attributes CombatService
-- publishes on the character. Everything is drawn from plain Frames on a
-- 2px grid with notched corners, so no image uploads are needed.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local CombatConfig = require(game:GetService("ReplicatedStorage").Shared.CombatConfig)

local player = Players.LocalPlayer

local P = 2 -- size of one "pixel" in screen pixels
local FONT = Enum.Font.Arcade
local TRAIL_DELAY = 0.4 -- seconds before the damage trail starts catching up
local TRAIL_SPEED = 0.8 -- fraction of the bar per second

-- Ink, paper and blood: black panels, off-white trim, crimson accents.
local Palette = {
	Outline = Color3.fromRGB(8, 8, 10),
	Trim = Color3.fromRGB(214, 206, 190),
	Inner = Color3.fromRGB(26, 22, 24),
	Trail = Color3.fromRGB(240, 232, 214),
	Accent = Color3.fromRGB(196, 24, 42),
	Text = Color3.fromRGB(236, 230, 218),
	Shadow = Color3.fromRGB(0, 0, 0),
}

type BarColors = { fill: Color3, light: Color3, dark: Color3 }

local HealthColors: BarColors = {
	fill = Color3.fromRGB(176, 22, 38),
	light = Color3.fromRGB(226, 62, 74),
	dark = Color3.fromRGB(110, 12, 24),
}
local StaminaColors: BarColors = {
	fill = Color3.fromRGB(196, 190, 176),
	light = Color3.fromRGB(240, 236, 226),
	dark = Color3.fromRGB(132, 126, 114),
}
local PostureColors: BarColors = {
	fill = Color3.fromRGB(214, 160, 44),
	light = Color3.fromRGB(246, 204, 96),
	dark = Color3.fromRGB(150, 104, 20),
}

type Bar = {
	frame: Frame,
	set: (self: Bar, ratio: number, dt: number) -> (),
}

local Hud = {}

local function rect(parent: Instance, x: number, y: number, w: number, h: number, color: Color3, z: number?): Frame
	local frame = Instance.new("Frame")
	frame.Position = UDim2.fromOffset(x, y)
	frame.Size = UDim2.fromOffset(math.max(w, 0), math.max(h, 0))
	frame.BackgroundColor3 = color
	frame.BorderSizePixel = 0
	frame.ZIndex = z or 1
	frame.Parent = parent
	return frame
end

local function text(parent: Instance, value: string, size: number, color: Color3, alignment: Enum.TextXAlignment?): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = FONT
	label.TextSize = size
	label.TextColor3 = color
	label.TextStrokeColor3 = Palette.Shadow
	label.TextStrokeTransparency = 0
	label.TextXAlignment = alignment or Enum.TextXAlignment.Center
	label.Text = value
	label.ZIndex = 10
	label.Parent = parent
	return label
end

-- A panel with a 1-pixel outline, 1-pixel trim and notched corners. Returns
-- the outer frame and the inner content frame (clipped).
local function panel(parent: Instance, name: string, width: number, height: number): (Frame, Frame)
	local outer = Instance.new("Frame")
	outer.Name = name
	outer.BackgroundTransparency = 1
	outer.Size = UDim2.fromOffset(width, height)
	outer.Parent = parent

	-- Two overlapping rectangles per layer leave the corners cut out.
	rect(outer, P, 0, width - 2 * P, height, Palette.Outline)
	rect(outer, 0, P, width, height - 2 * P, Palette.Outline)
	rect(outer, 2 * P, P, width - 4 * P, height - 2 * P, Palette.Trim, 2)
	rect(outer, P, 2 * P, width - 2 * P, height - 4 * P, Palette.Trim, 2)

	local inner = rect(outer, 2 * P, 2 * P, width - 4 * P, height - 4 * P, Palette.Inner, 3)
	inner.Name = "Inner"
	inner.ClipsDescendants = true
	return outer, inner
end

local function snap(value: number): number
	return math.floor(value / P) * P
end

local function bar(parent: Instance, name: string, width: number, height: number, colors: BarColors, segments: number): Bar
	local outer, inner = panel(parent, name, width, height)
	local innerWidth = width - 4 * P
	local innerHeight = height - 4 * P

	local trail = rect(inner, 0, 0, innerWidth, innerHeight, Palette.Trail, 4)
	local fill = rect(inner, 0, 0, innerWidth, innerHeight, colors.fill, 5)
	fill.ClipsDescendants = true
	rect(fill, 0, 0, innerWidth, P, colors.light, 6)
	rect(fill, 0, innerHeight - P, innerWidth, P, colors.dark, 6)

	for i = 1, segments - 1 do
		local tick = rect(inner, snap(innerWidth * i / segments), 0, P, innerHeight, Palette.Outline, 7)
		tick.BackgroundTransparency = 0.45
	end

	local shown = 1
	local trailRatio = 1
	local trailHoldUntil = 0

	local self = { frame = outer } :: Bar
	function self.set(_: Bar, ratio: number, dt: number)
		local t = os.clock()
		if ratio < shown then
			trailHoldUntil = t + TRAIL_DELAY
		end
		shown = ratio
		if ratio >= trailRatio then
			trailRatio = ratio
		elseif t >= trailHoldUntil then
			trailRatio = math.max(ratio, trailRatio - TRAIL_SPEED * dt)
		end
		fill.Size = UDim2.fromOffset(snap(innerWidth * ratio), innerHeight)
		trail.Size = UDim2.fromOffset(snap(innerWidth * trailRatio), innerHeight)
	end
	return self
end

type Slot = { frame: Frame, set: (self: Slot, remaining: number, total: number) -> () }

local function slot(parent: Instance, name: string, key: string, size: number): Slot
	local outer, inner = panel(parent, name, size, size)
	local innerSize = size - 4 * P

	local title = text(inner, string.upper(name), 10, Palette.Text)
	title.Size = UDim2.new(1, 0, 0, 12)
	title.Position = UDim2.fromOffset(0, P)

	local keyLabel = text(inner, key, 16, Palette.Accent)
	keyLabel.Size = UDim2.new(1, 0, 1, -12)
	keyLabel.Position = UDim2.fromOffset(0, 12)

	local shade = rect(inner, 0, 0, innerSize, innerSize, Palette.Outline, 8)
	shade.BackgroundTransparency = 0.35
	local timer = text(shade, "", 14, Palette.Text)
	timer.ZIndex = 11

	local self = { frame = outer } :: Slot
	function self.set(_: Slot, remaining: number, total: number)
		if remaining <= 0 then
			shade.Visible = false
			return
		end
		shade.Visible = true
		local height = snap(innerSize * math.clamp(remaining / total, 0, 1))
		shade.Position = UDim2.fromOffset(0, innerSize - height)
		shade.Size = UDim2.fromOffset(innerSize, height)
		timer.Text = string.format("%.1f", remaining)
	end
	return self
end

local function ratio(value: unknown, max: unknown): number
	if typeof(value) ~= "number" or typeof(max) ~= "number" or max <= 0 then
		return 1
	end
	return math.clamp(value / max, 0, 1)
end

function Hud.start(getCooldowns: () -> (number, number))
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	end)

	local gui = Instance.new("ScreenGui")
	gui.Name = "CombatHud"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Bottom left: name plate, HP, stamina.
	local vitals = Instance.new("Frame")
	vitals.Name = "Vitals"
	vitals.BackgroundTransparency = 1
	vitals.AnchorPoint = Vector2.new(0, 1)
	vitals.Position = UDim2.new(0, 24, 1, -24)
	vitals.Size = UDim2.fromOffset(328, 76)
	vitals.Parent = gui

	local plate, plateInner = panel(vitals, "NamePlate", 200, 22)
	plate.Position = UDim2.fromOffset(0, 0)
	local nameLabel = text(plateInner, string.upper(player.DisplayName), 14, Palette.Text, Enum.TextXAlignment.Left)
	nameLabel.Position = UDim2.fromOffset(2 * P, 0)
	nameLabel.Size = UDim2.new(1, -4 * P, 1, 0)
	local raceLabel = text(plateInner, "HUMAN", 14, Palette.Accent, Enum.TextXAlignment.Right)
	raceLabel.Position = UDim2.fromOffset(-2 * P, 0)

	local health = bar(vitals, "Health", 328, 28, HealthColors, 10)
	health.frame.Position = UDim2.fromOffset(0, 26)
	local healthText = text(health.frame, "", 14, Palette.Text, Enum.TextXAlignment.Right)
	healthText.Position = UDim2.fromOffset(-4 * P, 0)

	local stamina = bar(vitals, "Stamina", 248, 16, StaminaColors, 0)
	stamina.frame.Position = UDim2.fromOffset(0, 58)

	-- Bottom center: state text, posture, cooldown slots.
	local center = Instance.new("Frame")
	center.Name = "Center"
	center.BackgroundTransparency = 1
	center.AnchorPoint = Vector2.new(0.5, 1)
	center.Position = UDim2.new(0.5, 0, 1, -24)
	center.Size = UDim2.fromOffset(240, 104)
	center.Parent = gui

	local stateText = text(center, "", 16, Palette.Accent)
	stateText.Size = UDim2.new(1, 0, 0, 16)
	stateText.Position = UDim2.fromOffset(0, 0)

	local posture = bar(center, "Posture", 240, 16, PostureColors, 4)
	posture.frame.Position = UDim2.fromOffset(0, 22)

	local slots = Instance.new("Frame")
	slots.BackgroundTransparency = 1
	slots.Size = UDim2.fromOffset(104, 48)
	slots.Position = UDim2.fromOffset(68, 56)
	slots.Parent = center
	local dashSlot = slot(slots, "Dash", "Q", 48)
	local dodgeSlot = slot(slots, "Dodge", "Q", 48)
	dodgeSlot.frame.Position = UDim2.fromOffset(56, 0)

	RunService.RenderStepped:Connect(function(dt)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		gui.Enabled = humanoid ~= nil
		if not character or not humanoid then
			return
		end
		local t = workspace:GetServerTimeNow()

		health:set(ratio(humanoid.Health, humanoid.MaxHealth), dt)
		healthText.Text = string.format("%d/%d", math.ceil(humanoid.Health), humanoid.MaxHealth)
		stamina:set(ratio(character:GetAttribute("Stamina"), character:GetAttribute("MaxStamina")), dt)

		local race = character:GetAttribute("Race")
		raceLabel.Text = if typeof(race) == "string" then string.upper(race) else "HUMAN"

		local postureRatio = ratio(character:GetAttribute("Posture"), character:GetAttribute("MaxPosture"))
		local blocking = character:GetAttribute("Blocking") == true
		posture.frame.Visible = blocking or postureRatio < 1
		posture:set(postureRatio, dt)

		local stunnedUntil = character:GetAttribute("StunnedUntil")
		local stunned = typeof(stunnedUntil) == "number" and t < stunnedUntil
		stateText.Text = if stunned then "STUNNED" elseif blocking then "GUARD" else ""
		stateText.TextColor3 = if stunned then Palette.Accent else Palette.Text

		local dashReadyAt, dodgeReadyAt = getCooldowns()
		dashSlot:set(dashReadyAt - t, CombatConfig.Dash.Cooldown)
		dodgeSlot:set(dodgeReadyAt - t, CombatConfig.Dodge.Cooldown)
	end)
end

return Hud
