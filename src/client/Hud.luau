--!strict
-- Pixel-style combat HUD, laid out after the references in
-- vault/04-References: thin bars, mostly world on screen, and status shown by
-- how a bar looks rather than by text.
--
--   Bottom center: state text, posture (only while it builds), health,
--                  stamina, and RC (ghouls) or quinque charge (CCG) if present.
--   Right of that: dash and dodge cooldown icons that grey out while cooling.
--   Bottom left:   name plate with race tag, and hunger for ghouls.
--   Top center:    combat tag skull (blue PvE, red PvP) while tagged.
--
-- Health bar skins: the trim turns crimson on the last life ("stained"), and
-- the fill turns ashen while starving. Everything is drawn from plain Frames
-- on a 2px grid with notched corners, so no image uploads are needed. Values
-- come from the Humanoid and attributes on the character; anything a system
-- doesn't publish yet (Lives, Hunger, RC, QuinqueCharge) simply stays hidden.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local CombatConfig = require(ReplicatedStorage.Shared.CombatConfig)

local player = Players.LocalPlayer

local P = 2 -- size of one "pixel" in screen pixels
local FONT = Enum.Font.Arcade
local TRAIL_DELAY = 0.4 -- seconds before the damage trail starts catching up
local TRAIL_SPEED = 0.8 -- fraction of the bar per second
local POSTURE_DANGER = 0.75 -- posture fill at which the bar starts flashing
local STARVING_BELOW = 0.2 -- hunger ratio that switches on the starving skin

local CENTER_WIDTH = 360

-- Ink, paper and blood: black panels, off-white trim, crimson accents.
local Palette = {
	Outline = Color3.fromRGB(8, 8, 10),
	Trim = Color3.fromRGB(214, 206, 190),
	Inner = Color3.fromRGB(26, 22, 24),
	Trail = Color3.fromRGB(240, 232, 214),
	Accent = Color3.fromRGB(196, 24, 42),
	Text = Color3.fromRGB(236, 230, 218),
	Muted = Color3.fromRGB(92, 88, 84),
	Shadow = Color3.fromRGB(0, 0, 0),
	Steel = Color3.fromRGB(110, 150, 186),
	PvE = Color3.fromRGB(86, 140, 236),
}

type BarColors = { fill: Color3, light: Color3, dark: Color3 }

local Skins: { [string]: BarColors } = {
	Health = {
		fill = Color3.fromRGB(176, 22, 38),
		light = Color3.fromRGB(226, 62, 74),
		dark = Color3.fromRGB(110, 12, 24),
	},
	Starving = {
		fill = Color3.fromRGB(110, 92, 104),
		light = Color3.fromRGB(150, 130, 142),
		dark = Color3.fromRGB(64, 52, 60),
	},
	Stamina = {
		fill = Color3.fromRGB(196, 190, 176),
		light = Color3.fromRGB(240, 236, 226),
		dark = Color3.fromRGB(132, 126, 114),
	},
	Posture = {
		fill = Color3.fromRGB(214, 160, 44),
		light = Color3.fromRGB(246, 204, 96),
		dark = Color3.fromRGB(150, 104, 20),
	},
	PostureDanger = {
		fill = Color3.fromRGB(196, 24, 42),
		light = Color3.fromRGB(240, 80, 90),
		dark = Color3.fromRGB(120, 10, 22),
	},
	RC = {
		fill = Color3.fromRGB(150, 28, 92),
		light = Color3.fromRGB(204, 70, 146),
		dark = Color3.fromRGB(90, 14, 56),
	},
	Charge = {
		fill = Color3.fromRGB(96, 136, 170),
		light = Color3.fromRGB(150, 188, 216),
		dark = Color3.fromRGB(56, 84, 110),
	},
	Hunger = {
		fill = Color3.fromRGB(150, 110, 70),
		light = Color3.fromRGB(196, 156, 108),
		dark = Color3.fromRGB(96, 66, 38),
	},
}

local RaceColors: { [string]: Color3 } = {
	HUMAN = Palette.Text,
	GHOUL = Palette.Accent,
	["ONE-EYED"] = Palette.Accent,
	CCG = Palette.Steel,
}

-- 7-wide pixel glyphs; "#" is a filled pixel.
local Glyphs = {
	Dash = {
		"#..#...",
		".#..#..",
		"..#..#.",
		"...#..#",
		"..#..#.",
		".#..#..",
		"#..#...",
	},
	Dodge = {
		"...#...",
		"..##...",
		".######",
		"#######",
		".######",
		"..##...",
		"...#...",
	},
	Skull = {
		".#####.",
		"#######",
		"#..#..#",
		"#######",
		".##.##.",
		".#.#.#.",
	},
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

local function glyph(parent: Instance, rows: { string }, scale: number, color: Color3, x: number, y: number): { Frame }
	local pixels = {}
	for row, line in rows do
		for col = 1, #line do
			if string.sub(line, col, col) == "#" then
				table.insert(pixels, rect(parent, x + (col - 1) * scale, y + (row - 1) * scale, scale, scale, color, 9))
			end
		end
	end
	return pixels
end

local function recolor(frames: { Frame }, color: Color3)
	for _, frame in frames do
		frame.BackgroundColor3 = color
	end
end

-- A panel with a 1-pixel outline, 1-pixel trim and notched corners. Returns
-- the outer frame, the clipped inner frame, and the trim frames (to recolor).
local function panel(parent: Instance, name: string, width: number, height: number): (Frame, Frame, { Frame })
	local outer = Instance.new("Frame")
	outer.Name = name
	outer.BackgroundTransparency = 1
	outer.Size = UDim2.fromOffset(width, height)
	outer.Parent = parent

	-- Two overlapping rectangles per layer leave the corners cut out.
	rect(outer, P, 0, width - 2 * P, height, Palette.Outline)
	rect(outer, 0, P, width, height - 2 * P, Palette.Outline)
	local trim = {
		rect(outer, 2 * P, P, width - 4 * P, height - 2 * P, Palette.Trim, 2),
		rect(outer, P, 2 * P, width - 2 * P, height - 4 * P, Palette.Trim, 2),
	}

	local inner = rect(outer, 2 * P, 2 * P, width - 4 * P, height - 4 * P, Palette.Inner, 3)
	inner.Name = "Inner"
	inner.ClipsDescendants = true
	return outer, inner, trim
end

local function snap(value: number): number
	return math.floor(value / P) * P
end

type Bar = {
	frame: Frame,
	set: (self: Bar, ratio: number, dt: number) -> (),
	setSkin: (self: Bar, colors: BarColors) -> (),
	setTrim: (self: Bar, color: Color3) -> (),
	setStained: (self: Bar, stained: boolean) -> (),
}

local function bar(parent: Instance, name: string, width: number, height: number, colors: BarColors, segments: number): Bar
	local outer, inner, trim = panel(parent, name, width, height)
	local innerWidth = width - 4 * P
	local innerHeight = height - 4 * P

	local trail = rect(inner, 0, 0, innerWidth, innerHeight, Palette.Trail, 4)
	local fill = rect(inner, 0, 0, innerWidth, innerHeight, colors.fill, 5)
	fill.ClipsDescendants = true
	local light = rect(fill, 0, 0, innerWidth, P, colors.light, 6)
	local dark = rect(fill, 0, innerHeight - P, innerWidth, P, colors.dark, 6)

	-- Fixed dark specks over the fill for the "stained" (last life) look.
	local stains = {}
	for i = 1, math.floor(innerWidth / 24) do
		local speck = rect(fill, snap((i * 37) % innerWidth), snap((i * 13) % math.max(innerHeight - P, P)), P * 2, P, Palette.Outline, 7)
		speck.BackgroundTransparency = 0.35
		speck.Visible = false
		table.insert(stains, speck)
	end

	for i = 1, segments - 1 do
		local tick = rect(inner, snap(innerWidth * i / segments), 0, P, innerHeight, Palette.Outline, 8)
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
	function self.setSkin(_: Bar, skin: BarColors)
		fill.BackgroundColor3 = skin.fill
		light.BackgroundColor3 = skin.light
		dark.BackgroundColor3 = skin.dark
	end
	function self.setTrim(_: Bar, color: Color3)
		recolor(trim, color)
	end
	function self.setStained(_: Bar, stained: boolean)
		for _, speck in stains do
			speck.Visible = stained
		end
	end
	return self
end

type Icon = { frame: Frame, set: (self: Icon, remaining: number, total: number) -> () }

local function cooldownIcon(parent: Instance, name: string, rows: { string }): Icon
	local size = 28
	local outer, inner = panel(parent, name, size, size)
	local innerSize = size - 4 * P
	local scale = P
	local offset = snap((innerSize - #rows[1] * scale) / 2)
	local pixels = glyph(inner, rows, scale, Palette.Text, offset, offset)

	local shade = rect(inner, 0, 0, innerSize, 0, Palette.Outline, 10)
	shade.BackgroundTransparency = 0.5

	local self = { frame = outer } :: Icon
	function self.set(_: Icon, remaining: number, total: number)
		local cooling = remaining > 0
		recolor(pixels, if cooling then Palette.Muted else Palette.Text)
		local height = if cooling then snap(innerSize * math.clamp(remaining / total, 0, 1)) else 0
		shade.Size = UDim2.fromOffset(innerSize, height)
	end
	return self
end

local function ratio(value: unknown, max: unknown): number?
	if typeof(value) ~= "number" or typeof(max) ~= "number" or max <= 0 then
		return nil
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

	-- Bottom center stack. UIListLayout skips hidden rows, so optional bars
	-- (posture, resource) don't leave gaps.
	local center = Instance.new("Frame")
	center.Name = "Center"
	center.BackgroundTransparency = 1
	center.AnchorPoint = Vector2.new(0.5, 1)
	center.Position = UDim2.new(0.5, 0, 1, -20)
	center.Size = UDim2.fromOffset(CENTER_WIDTH, 112)
	center.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = center

	local stateHolder = Instance.new("Frame")
	stateHolder.BackgroundTransparency = 1
	stateHolder.Size = UDim2.fromOffset(CENTER_WIDTH, 16)
	stateHolder.LayoutOrder = 1
	stateHolder.Parent = center
	local stateText = text(stateHolder, "", 16, Palette.Accent)

	local posture = bar(center, "Posture", 200, 14, Skins.Posture, 4)
	posture.frame.LayoutOrder = 2

	local health = bar(center, "Health", CENTER_WIDTH, 22, Skins.Health, 10)
	health.frame.LayoutOrder = 3

	local stamina = bar(center, "Stamina", CENTER_WIDTH, 14, Skins.Stamina, 0)
	stamina.frame.LayoutOrder = 4

	local resource = bar(center, "Resource", CENTER_WIDTH, 14, Skins.RC, 8)
	resource.frame.LayoutOrder = 5

	-- Cooldown icons, to the right of the health/stamina rows.
	local icons = Instance.new("Frame")
	icons.Name = "Cooldowns"
	icons.BackgroundTransparency = 1
	icons.AnchorPoint = Vector2.new(0, 1)
	icons.Position = UDim2.new(0.5, CENTER_WIDTH / 2 + 8, 1, -20)
	icons.Size = UDim2.fromOffset(60, 28)
	icons.Parent = gui
	local dashIcon = cooldownIcon(icons, "Dash", Glyphs.Dash)
	local dodgeIcon = cooldownIcon(icons, "Dodge", Glyphs.Dodge)
	dodgeIcon.frame.Position = UDim2.fromOffset(32, 0)

	-- Bottom left: name plate and survival bars.
	local vitals = Instance.new("Frame")
	vitals.Name = "Vitals"
	vitals.BackgroundTransparency = 1
	vitals.AnchorPoint = Vector2.new(0, 1)
	vitals.Position = UDim2.new(0, 16, 1, -20)
	vitals.Size = UDim2.fromOffset(212, 38)
	vitals.Parent = gui

	local _, plateInner = panel(vitals, "NamePlate", 200, 22)
	local nameLabel = text(plateInner, string.upper(player.DisplayName), 14, Palette.Text, Enum.TextXAlignment.Left)
	nameLabel.Position = UDim2.fromOffset(2 * P, 0)
	nameLabel.Size = UDim2.new(1, -4 * P, 1, 0)
	local raceLabel = text(plateInner, "HUMAN", 14, Palette.Text, Enum.TextXAlignment.Right)
	raceLabel.Position = UDim2.fromOffset(-2 * P, 0)

	local hunger = bar(vitals, "Hunger", 140, 12, Skins.Hunger, 4)
	hunger.frame.Position = UDim2.fromOffset(0, 26)
	local hungerLabel = text(hunger.frame, "HUNGER", 10, Palette.Text, Enum.TextXAlignment.Left)
	hungerLabel.Position = UDim2.fromOffset(148, 0)
	hungerLabel.Size = UDim2.fromOffset(60, 12)

	-- Top center: combat tag.
	local tag, tagInner = panel(gui, "CombatTag", 32, 28)
	tag.AnchorPoint = Vector2.new(0.5, 0)
	tag.Position = UDim2.new(0.5, 0, 0, 12)
	local skull = glyph(tagInner, Glyphs.Skull, P, Palette.PvE, snap((24 - 14) / 2), snap((20 - 12) / 2))

	RunService.RenderStepped:Connect(function(dt)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		gui.Enabled = humanoid ~= nil
		if not character or not humanoid then
			return
		end
		local t = workspace:GetServerTimeNow()
		local attr = function(name: string): any
			return character:GetAttribute(name)
		end

		-- Race tag.
		local race = attr("Race")
		local raceText = if typeof(race) == "string" then string.upper(race) else "HUMAN"
		raceLabel.Text = raceText
		raceLabel.TextColor3 = RaceColors[raceText] or Palette.Text

		-- Health, with skins for starving and last life.
		local hungerRatio = ratio(attr("Hunger"), attr("MaxHunger"))
		local starving = hungerRatio ~= nil and hungerRatio < STARVING_BELOW
		local lastLife = attr("Lives") == 1
		health:set(ratio(humanoid.Health, humanoid.MaxHealth) or 1, dt)
		health:setSkin(if starving then Skins.Starving else Skins.Health)
		health:setTrim(if lastLife then Palette.Accent else Palette.Trim)
		health:setStained(lastLife)

		stamina:set(ratio(attr("Stamina"), attr("MaxStamina")) or 1, dt)

		-- RC for ghouls, quinque charge for CCG; hidden for plain humans.
		local rcRatio = ratio(attr("RC"), attr("MaxRC"))
		local chargeRatio = ratio(attr("QuinqueCharge"), attr("MaxQuinqueCharge"))
		resource.frame.Visible = rcRatio ~= nil or chargeRatio ~= nil
		if rcRatio then
			resource:setSkin(Skins.RC)
			resource:set(rcRatio, dt)
		elseif chargeRatio then
			resource:setSkin(Skins.Charge)
			resource:set(chargeRatio, dt)
		end

		hunger.frame.Visible = hungerRatio ~= nil
		if hungerRatio then
			hunger:set(hungerRatio, dt)
			hunger:setTrim(if starving then Palette.Accent else Palette.Trim)
		end

		-- Posture fills up as damage builds and flashes near a guard break.
		local blocking = attr("Blocking") == true
		local postureLeft = ratio(attr("Posture"), attr("MaxPosture")) or 1
		local postureBuilt = 1 - postureLeft
		posture.frame.Visible = blocking or postureBuilt > 0
		posture:set(postureBuilt, dt)
		local flashing = postureBuilt >= POSTURE_DANGER and math.floor(os.clock() * 8) % 2 == 0
		posture:setSkin(if postureBuilt >= POSTURE_DANGER then Skins.PostureDanger else Skins.Posture)
		posture:setTrim(if flashing then Palette.Accent else Palette.Trim)

		local stunnedUntil = attr("StunnedUntil")
		local stunned = typeof(stunnedUntil) == "number" and t < stunnedUntil
		stateText.Text = if stunned then "STUNNED" else ""

		local dashReadyAt, dodgeReadyAt = getCooldowns()
		dashIcon:set(dashReadyAt - t, CombatConfig.Dash.Cooldown)
		dodgeIcon:set(dodgeReadyAt - t, CombatConfig.Dodge.Cooldown)

		local tagUntil = attr("CombatTagUntil")
		tag.Visible = typeof(tagUntil) == "number" and t < tagUntil
		recolor(skull, if attr("CombatTag") == "PvP" then Palette.Accent else Palette.PvE)
	end)
end

return Hud
