--!strict
-- Simple HUD: a health bar and a hunger bar, bottom center. Everything else
-- (RC, posture, stamina) stays hidden on purpose. Bars are drawn from plain
-- Frames with notched pixel corners, so no image uploads are needed.
--
-- Hunger reads the Hunger/MaxHunger attributes on the character and shows
-- full until a hunger system publishes them.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer

local P = 2 -- size of one "pixel" in screen pixels
local BAR_WIDTH = 300
local TRAIL_DELAY = 0.4 -- seconds before the damage trail starts catching up
local TRAIL_SPEED = 0.8 -- fraction of the bar per second
local LOW_HUNGER = 0.2 -- below this the hunger bar's trim turns red

local Palette = {
	Outline = Color3.fromRGB(8, 8, 10),
	Trim = Color3.fromRGB(214, 206, 190),
	Inner = Color3.fromRGB(26, 22, 24),
	Trail = Color3.fromRGB(240, 232, 214),
	Warning = Color3.fromRGB(196, 24, 42),
}

type BarColors = { fill: Color3, light: Color3, dark: Color3 }

local HealthColors: BarColors = {
	fill = Color3.fromRGB(176, 22, 38),
	light = Color3.fromRGB(226, 62, 74),
	dark = Color3.fromRGB(110, 12, 24),
}
local HungerColors: BarColors = {
	fill = Color3.fromRGB(150, 110, 70),
	light = Color3.fromRGB(196, 156, 108),
	dark = Color3.fromRGB(96, 66, 38),
}

type Bar = {
	frame: Frame,
	set: (self: Bar, ratio: number, dt: number) -> (),
	setTrim: (self: Bar, color: Color3) -> (),
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

local function snap(value: number): number
	return math.floor(value / P) * P
end

local function bar(parent: Instance, name: string, height: number, colors: BarColors): Bar
	local outer = Instance.new("Frame")
	outer.Name = name
	outer.BackgroundTransparency = 1
	outer.Size = UDim2.fromOffset(BAR_WIDTH, height)
	outer.Parent = parent

	-- Two overlapping rectangles per layer leave the corners cut out.
	rect(outer, P, 0, BAR_WIDTH - 2 * P, height, Palette.Outline)
	rect(outer, 0, P, BAR_WIDTH, height - 2 * P, Palette.Outline)
	local trim = {
		rect(outer, 2 * P, P, BAR_WIDTH - 4 * P, height - 2 * P, Palette.Trim, 2),
		rect(outer, P, 2 * P, BAR_WIDTH - 2 * P, height - 4 * P, Palette.Trim, 2),
	}

	local innerWidth = BAR_WIDTH - 4 * P
	local innerHeight = height - 4 * P
	local inner = rect(outer, 2 * P, 2 * P, innerWidth, innerHeight, Palette.Inner, 3)
	inner.ClipsDescendants = true

	local trail = rect(inner, 0, 0, innerWidth, innerHeight, Palette.Trail, 4)
	local fill = rect(inner, 0, 0, innerWidth, innerHeight, colors.fill, 5)
	fill.ClipsDescendants = true
	rect(fill, 0, 0, innerWidth, P, colors.light, 6)
	rect(fill, 0, innerHeight - P, innerWidth, P, colors.dark, 6)

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
	function self.setTrim(_: Bar, color: Color3)
		for _, frame in trim do
			frame.BackgroundColor3 = color
		end
	end
	return self
end

local function ratio(value: unknown, max: unknown): number
	if typeof(value) ~= "number" or typeof(max) ~= "number" or max <= 0 then
		return 1
	end
	return math.clamp(value / max, 0, 1)
end

function Hud.start()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	end)

	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local holder = Instance.new("Frame")
	holder.Name = "Bars"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Position = UDim2.new(0.5, 0, 1, -20)
	holder.Size = UDim2.fromOffset(BAR_WIDTH, 22 + 4 + 14)
	holder.Parent = gui

	local health = bar(holder, "Health", 22, HealthColors)
	local hunger = bar(holder, "Hunger", 14, HungerColors)
	hunger.frame.Position = UDim2.fromOffset(0, 26)

	RunService.RenderStepped:Connect(function(dt)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		gui.Enabled = humanoid ~= nil
		if not character or not humanoid then
			return
		end

		health:set(ratio(humanoid.Health, humanoid.MaxHealth), dt)

		local hungerRatio = ratio(character:GetAttribute("Hunger"), character:GetAttribute("MaxHunger"))
		hunger:set(hungerRatio, dt)
		hunger:setTrim(if hungerRatio < LOW_HUNGER then Palette.Warning else Palette.Trim)
	end)
end

return Hud
