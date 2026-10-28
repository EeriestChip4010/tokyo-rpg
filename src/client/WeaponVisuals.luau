--!strict
-- Builds and animates each fighter's weapon on this client, from the
-- character attributes the server publishes (Loadout, WeaponState,
-- DeployEndsAt, OneEyed). Nothing here affects gameplay: hitboxes are the
-- server's boxes, so these parts are purely visual and client-local.
--
-- Ghouls: a Rinkaku kagune on the lower back. Four tentacles chained from
-- segment pieces with Motor6Ds, animated procedurally (idle sway, released
-- root-to-tip, stabs/sweeps/slams timed to CharacterAnimator's attack), and
-- the kakugan while the kagune is out.
--
-- Investigators: the CCG case in the right hand. On deploy the trigger
-- sparks, the shells hinge open and fold away, RC pours out along the blade
-- axis and hardens into the quinque; the handle stays in the hand as the
-- hilt (refs: /vault/02-Design/Quinque Design.md, assets/README.md).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CombatConfig = require(ReplicatedStorage.Shared.CombatConfig)
local CharacterAnimator = require(script.Parent.CharacterAnimator)
local Characters = require(script.Parent.Characters)
local CombatEffects = require(script.Parent.CombatEffects)
local WeaponModels = require(script.Parent.WeaponModels)

local Palette = WeaponModels.Palette
local rad = math.rad

-- Root angles plus one curl angle per joint, in degrees. Poses were tuned
-- by previewing this exact math in tools/blender/preview_kagune_pose.py.
type TentacleParams = { pitch: number, yaw: number, roll: number, curls: { number } }

type Tentacle = {
	side: number,
	upper: boolean,
	rest: TentacleParams,
	root: Motor6D,
	joints: { Motor6D },
	pieces: { BasePart },
	phase: number,
}

type KaguneRig = {
	kind: "Kagune",
	model: Model,
	kakuhou: BasePart,
	tentacles: { Tentacle },
	eyes: { BasePart },
}

type QuinqueRig = {
	kind: "Quinque",
	model: Model,
	grip: BasePart,
	welds: { [string]: Weld },
	parts: { [string]: BasePart },
	offsets: { [string]: CFrame },
	pour: BasePart,
}

type Rig = KaguneRig | QuinqueRig

type State = {
	character: Model,
	loadout: string?,
	rig: Rig?,
	progress: number, -- 0 = sheathed, 1 = fully drawn
	lastState: string?,
}

local states: { [Model]: State } = {}

-- Rest: the four tails fan up and back in a smooth S-curve, tips about
-- 1.8 studs above the head. Negative curl bends a joint forward.
local REST_CURL = { -6, 20, 13, -30, -30 }
local REST = {
	upper = { pitch = 55, roll = -20, curlScale = 1 },
	lower = { pitch = 55, roll = -30, curlScale = 0.75 },
}
-- Strike: all four tips converge about 7 studs ahead at chest height, the
-- upper pair past the shoulders and the lower pair round the flanks. Yaw and
-- roll are for the right side and mirrored for the left.
local STRIKE = {
	upper = { pitch = -49.7, yaw = 46.4, roll = -48.6, curls = { 5.4, -6.9, -39.3, -33.5, -1.0 } },
	lower = { pitch = 24.4, yaw = 53.3, roll = -101.4, curls = { -22.9, -6.9, -31.1, -25.9, 0.4 } },
}
local SWAY_DEGREES = 6
local SWAY_SPEED = 2.2

-- Case space -> blade space: the blade's +Y runs along the case handle bar
-- (case +X), so the grip doesn't turn in the hand during the transform.
local BLADE_TO_CASE = CFrame.fromMatrix(Vector3.zero, Vector3.zAxis, Vector3.xAxis, Vector3.yAxis)
-- Hand grip on the R6 right arm; the case hangs with its handle bar pointing forward.
local HAND_GRIP = CFrame.new(0, -1, 0) * CFrame.Angles(0, math.pi / 2, 0)

local WeaponVisuals = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function easeOut(alpha: number): number
	return 1 - (1 - alpha) * (1 - alpha)
end

-- Remaps `x` from [a, b] to [0, 1], clamped.
local function span(x: number, a: number, b: number): number
	return math.clamp((x - a) / (b - a), 0, 1)
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function lerpParams(a: TentacleParams, b: TentacleParams, t: number): TentacleParams
	local curls = table.create(#a.curls)
	for k, curl in a.curls do
		curls[k] = lerp(curl, b.curls[k], t)
	end
	return {
		pitch = lerp(a.pitch, b.pitch, t),
		yaw = lerp(a.yaw, b.yaw, t),
		roll = lerp(a.roll, b.roll, t),
		curls = curls,
	}
end

local function scaleCurls(curls: { number }, factor: number): { number }
	local scaled = table.create(#curls)
	for k, curl in curls do
		scaled[k] = curl * factor
	end
	return scaled
end

local function joint(part0: BasePart, part1: BasePart, c0: CFrame, c1: CFrame): Motor6D
	local motor = Instance.new("Motor6D")
	motor.Part0 = part0
	motor.Part1 = part1
	motor.C0 = c0
	motor.C1 = c1
	motor.Parent = part0
	return motor
end

local function weld(part0: BasePart, part1: BasePart, c0: CFrame, c1: CFrame?): Weld
	local w = Instance.new("Weld")
	w.Part0 = part0
	w.Part1 = part1
	w.C0 = c0
	w.C1 = c1 or CFrame.identity
	w.Parent = part1
	return w
end

local function buildEyes(character: Model, oneEyed: boolean, parent: Instance): { BasePart }
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return {}
	end
	local eyes = {}
	-- Kaneki's kakugan is his left eye; the character's left is -X.
	local sides = if oneEyed then { -1 } else { -1, 1 }
	for _, side in sides do
		for _, layer in
			{
				{ size = Vector3.new(0.2, 0.12, 0.02), color = Color3.new(0, 0, 0), z = -0.505 },
				{
					size = Vector3.new(0.08, 0.08, 0.02),
					color = Palette.RcGlow,
					z = -0.515,
				},
			}
		do
			local eye = Instance.new("Part")
			eye.Name = "Kakugan"
			eye.Size = layer.size
			eye.Color = layer.color
			eye.Material = if layer.color == Palette.RcGlow then Enum.Material.Neon else Enum.Material.SmoothPlastic
			eye.CanCollide = false
			eye.CanQuery = false
			eye.CanTouch = false
			eye.Massless = true
			eye.Transparency = 1
			eye.Parent = parent
			weld(head, eye, CFrame.new(0.2 * side, 0.12, layer.z))
			table.insert(eyes, eye)
		end
	end
	return eyes
end

local function buildKagune(character: Model): KaguneRig?
	local torso = character:FindFirstChild("Torso")
	if not torso or not torso:IsA("BasePart") then
		return nil
	end
	local spec = WeaponModels.Rinkaku
	local model = Instance.new("Model")
	model.Name = "KaguneRig"

	local kakuhou, kakuhouOffset = WeaponModels.build(spec.kakuhou)
	kakuhou.Parent = model
	weld(torso, kakuhou, spec.mount, kakuhouOffset:Inverse())

	local tentacles: { Tentacle } = {}
	for index, socket in spec.sockets do
		local pieces: { BasePart } = {}
		local offsets: { CFrame } = {}
		for _, pieceSpec in spec.segments do
			local part, offset = WeaponModels.build(pieceSpec)
			part.Parent = model
			table.insert(pieces, part)
			table.insert(offsets, offset)
		end

		local root =
			joint(kakuhou, pieces[1], kakuhouOffset:Inverse() * CFrame.new(socket.position), offsets[1]:Inverse())
		-- Piece k's top joint, in piece k's own space, is offset^-1 * (0, length, 0).
		local joints: { Motor6D } = {}
		for k = 1, #pieces - 1 do
			local length = spec.segments[k].length or 1
			local c0 = offsets[k]:Inverse() * CFrame.new(0, length, 0)
			table.insert(joints, joint(pieces[k], pieces[k + 1], c0, offsets[k + 1]:Inverse()))
		end

		local rest = if socket.upper then REST.upper else REST.lower
		table.insert(tentacles, {
			side = socket.side,
			upper = socket.upper,
			rest = {
				pitch = rest.pitch,
				yaw = 0,
				roll = socket.side * rest.roll,
				curls = scaleCurls(REST_CURL, rest.curlScale),
			},
			root = root,
			joints = joints,
			pieces = pieces,
			-- A quarter cycle apart, so the tails never sway in lockstep.
			phase = (index - 1) * 0.25 * 2 * math.pi,
		})
	end

	model.Parent = character
	return {
		kind = "Kagune",
		model = model,
		kakuhou = kakuhou,
		tentacles = tentacles,
		eyes = buildEyes(character, character:GetAttribute("OneEyed") == true, model),
	}
end

local function buildQuinque(character: Model): QuinqueRig?
	local arm = character:FindFirstChild("Right Arm")
	if not arm or not arm:IsA("BasePart") then
		return nil
	end
	local spec = WeaponModels.Quinque
	local model = Instance.new("Model")
	model.Name = "QuinqueRig"

	local grip = Instance.new("Part")
	grip.Name = "Grip"
	grip.Size = Vector3.one * 0.2
	grip.Transparency = 1
	grip.CanCollide = false
	grip.CanQuery = false
	grip.CanTouch = false
	grip.Massless = true
	grip.Parent = model
	weld(arm, grip, HAND_GRIP)

	local welds: { [string]: Weld } = {}
	local parts: { [string]: BasePart } = {}
	local offsets: { [string]: CFrame } = {}
	local function add(key: string, pieceSpec: WeaponModels.PieceSpec, space: CFrame)
		local part, offset = WeaponModels.build(pieceSpec)
		part.Parent = model
		parts[key] = part
		offsets[key] = space * offset
		welds[key] = weld(grip, part, offsets[key])
	end
	add("ShellFront", spec.caseShellFront, CFrame.identity)
	add("ShellBack", spec.caseShellBack, CFrame.identity)
	add("Handle", spec.caseHandle, CFrame.identity)
	add("Hilt", spec.hilt, BLADE_TO_CASE)
	add("Blade", spec.blade, BLADE_TO_CASE)

	local pour = Instance.new("Part")
	pour.Name = "RCPour"
	pour.Shape = Enum.PartType.Cylinder
	pour.Material = Enum.Material.Neon
	pour.Color = Palette.RcBright
	pour.CanCollide = false
	pour.CanQuery = false
	pour.CanTouch = false
	pour.Massless = true
	pour.Transparency = 1
	pour.Size = Vector3.new(0.1, 0.2, 0.2)
	pour.Parent = model
	parts.Pour = pour
	welds.Pour = weld(grip, pour, CFrame.identity)

	model.Parent = character
	return {
		kind = "Quinque",
		model = model,
		grip = grip,
		welds = welds,
		parts = parts,
		offsets = offsets,
		pour = pour,
	}
end

-- The converging strike for this tail, nudged by `yawOffset` (sweeps) and
-- `pitchOffset` (slams), with its curls scaled by `curlScale` (wraps).
local function strikeFor(
	tentacle: Tentacle,
	yawOffset: number?,
	pitchOffset: number?,
	curlScale: number?
): TentacleParams
	local strike = if tentacle.upper then STRIKE.upper else STRIKE.lower
	return {
		pitch = strike.pitch + (pitchOffset or 0),
		yaw = tentacle.side * strike.yaw + (yawOffset or 0),
		roll = tentacle.side * strike.roll,
		curls = scaleCurls(strike.curls, curlScale or 1),
	}
end

-- Pulled back and coiled, ready to lash out.
local function coiled(tentacle: Tentacle): TentacleParams
	local rest = tentacle.rest
	return { pitch = rest.pitch + 15, yaw = rest.yaw, roll = rest.roll, curls = scaleCurls(rest.curls, 1.5) }
end

-- Per-attack tentacle choreography: which tentacles move and how.
type Choreo = {
	tentacles: { number }?, -- nil = all; 1/3 are the right tails, 2/4 the left
	windup: (Tentacle) -> TentacleParams,
	strike: (Tentacle) -> TentacleParams,
	stagger: number?, -- seconds between tentacles (barrage)
}

local CHOREO: { [string]: Choreo } = {
	KaguneStrikeR = { tentacles = { 1, 3 }, windup = coiled, strike = strikeFor },
	KaguneStrikeL = { tentacles = { 2, 4 }, windup = coiled, strike = strikeFor },
	KaguneSweep = {
		windup = function(tentacle)
			return strikeFor(tentacle, 45)
		end,
		strike = function(tentacle)
			return strikeFor(tentacle, -45)
		end,
	},
	KaguneSlam = {
		windup = function(tentacle)
			local rest = tentacle.rest
			return { pitch = rest.pitch - 30, yaw = rest.yaw, roll = rest.roll, curls = scaleCurls(rest.curls, 0.4) }
		end,
		strike = function(tentacle)
			return strikeFor(tentacle, 0, -25)
		end,
	},
	KaguneBarrage = { windup = coiled, strike = strikeFor, stagger = 0.12 },
	KaguneGrab = {
		tentacles = { 1, 2 },
		windup = coiled,
		strike = function(tentacle)
			return strikeFor(tentacle, 0, 0, 1.3)
		end,
	},
}

local function tentacleTarget(character: Model, tentacle: Tentacle, index: number, t: number): TentacleParams
	local attack = CharacterAnimator.getAttack(character)
	local choreo = attack and CHOREO[attack.name]
	if attack and choreo and (not choreo.tentacles or table.find(choreo.tentacles, index)) then
		local delay = (choreo.stagger or 0) * (index - 1)
		local windupEnd = attack.windupEndsAt + delay
		local strikeEnd = attack.strikeEndsAt + delay
		if choreo.stagger then
			-- Barrage: each tentacle stabs once in turn during the strike window.
			strikeEnd = windupEnd + 0.1
		end
		local windup = choreo.windup(tentacle)
		local strike = choreo.strike(tentacle)
		if t < windupEnd then
			return lerpParams(tentacle.rest, windup, easeOut(span(t, attack.startedAt, windupEnd)))
		elseif t < strikeEnd then
			return lerpParams(windup, strike, easeOut(span(t, windupEnd, strikeEnd)))
		end
		return lerpParams(strike, tentacle.rest, easeOut(span(t, strikeEnd, attack.endsAt)))
	end
	if character:GetAttribute("Blocking") == true then
		-- A wall of tails curled in close in front of the body.
		return strikeFor(tentacle, 0, 10, 1.6)
	end
	return tentacle.rest
end

local function animateKagune(state: State, rig: KaguneRig, t: number, dt: number)
	local progress = state.progress
	local visibleSegments = progress * #WeaponModels.Rinkaku.segments
	rig.kakuhou.Transparency = if progress > 0 then 0 else 1
	for _, eye in rig.eyes do
		eye.Transparency = if progress > 0 then 0 else 1
	end

	for index, tentacle in rig.tentacles do
		for k, piece in tentacle.pieces do
			piece.Transparency = if k <= visibleSegments + 0.5 then 0 else 1
		end
		if progress <= 0 then
			continue
		end

		local params = tentacleTarget(state.character, tentacle, index, t)
		tentacle.root.Transform = CFrame.Angles(0, rad(params.yaw), 0)
			* CFrame.Angles(rad(params.pitch), 0, rad(params.roll))
		for k, motor in tentacle.joints do
			local sway = math.sin(t * SWAY_SPEED + tentacle.phase + k * 0.6) * SWAY_DEGREES
			local swaySide = math.cos(t * SWAY_SPEED * 0.7 + tentacle.phase + k) * SWAY_DEGREES * 0.6
			motor.Transform = CFrame.Angles(rad(params.curls[k] + sway), 0, rad(swaySide))
		end
	end
end

local function animateQuinque(rig: QuinqueRig, progress: number)
	local spec = WeaponModels.Quinque
	local parts, welds, offsets = rig.parts, rig.welds, rig.offsets

	-- Shells hinge open around the bottom edge, then fold away into the collar.
	local open = easeOut(span(progress, 0.15, 0.4))
	local fold = span(progress, 0.35, 0.55)
	local hinge = CFrame.new(spec.hinge)
	for key, direction in { ShellFront = -1, ShellBack = 1 } do
		local opened = hinge * CFrame.Angles(direction * rad(100) * open, 0, 0) * hinge:Inverse() * offsets[key]
		welds[key].C0 = opened:Lerp(CFrame.new(0, 0, 0), fold)
		parts[key].Transparency = if fold >= 1 then 1 else fold * 0.8
	end
	parts.Handle.Transparency = if progress < 0.45 then 0 else 1
	parts.Hilt.Transparency = if progress >= 0.45 then 0 else 1

	-- RC pours out along the blade axis, overshoots, then hardens into steel.
	local bladeSpec = spec.blade
	local bladeBase = bladeSpec.center.Y - bladeSpec.size.Y / 2
	local pourLength = bladeSpec.size.Y * 1.1 * easeOut(span(progress, 0.25, 0.55))
	local pourFade = span(progress, 0.55, 0.8)
	if pourLength > 0.05 and pourFade < 1 then
		rig.pour.Transparency = 0.15 + 0.85 * pourFade
		rig.pour.Size = Vector3.new(pourLength, 0.22, 0.22)
		-- Cylinders run along X; turn to run along blade +Y.
		welds.Pour.C0 = BLADE_TO_CASE * CFrame.new(0, bladeBase + pourLength / 2, 0) * CFrame.Angles(0, 0, math.pi / 2)
	else
		rig.pour.Transparency = 1
	end

	local grow = easeOut(span(progress, 0.45, 0.75))
	if grow > 0 then
		local length = math.max(bladeSpec.size.Y * grow, 0.05)
		parts.Blade.Size = Vector3.new(bladeSpec.size.X, length, bladeSpec.size.Z)
		welds.Blade.C0 = BLADE_TO_CASE * CFrame.new(0, bladeBase + length / 2, bladeSpec.center.Z)
		parts.Blade.Transparency = 0
	else
		parts.Blade.Transparency = 1
	end
end

local function destroyRig(state: State)
	if state.rig then
		state.rig.model:Destroy()
		state.rig = nil
	end
end

local function rebuild(state: State)
	destroyRig(state)
	local loadout = state.character:GetAttribute("Loadout")
	state.loadout = if typeof(loadout) == "string" then loadout else nil
	if state.loadout == "Ghoul" then
		state.rig = buildKagune(state.character)
	elseif state.loadout == "Investigator" then
		state.rig = buildQuinque(state.character)
	end
	state.progress = if state.character:GetAttribute("WeaponState") == "Drawn" then 1 else 0
end

local function targetProgress(character: Model, current: number, t: number, dt: number): number
	local weaponState = character:GetAttribute("WeaponState")
	if weaponState == "Drawn" then
		return 1
	elseif weaponState == "Deploying" then
		local endsAt = character:GetAttribute("DeployEndsAt")
		local duration = if character:GetAttribute("Loadout") == "Ghoul"
			then CombatConfig.Deploy.KaguneTime
			else CombatConfig.Deploy.QuinqueTime
		if typeof(endsAt) == "number" then
			return math.clamp(1 - (endsAt - t) / duration, 0, 1)
		end
		return current
	end
	-- Sheathing plays the transform backwards, quicker.
	return math.max(0, current - dt / CombatConfig.Deploy.SheatheTime)
end

local function onWeaponStateChanged(state: State)
	local weaponState = state.character:GetAttribute("WeaponState")
	local rig = state.rig
	if not rig or weaponState == state.lastState then
		return
	end
	state.lastState = if typeof(weaponState) == "string" then weaponState else nil
	if weaponState ~= "Deploying" then
		return
	end
	local root = if rig.kind == "Kagune" then rig.kakuhou else rig.grip
	CombatEffects.pulse(root, Palette.RcGlow, 0.5)
	if rig.kind == "Kagune" then
		CombatEffects.burst(root.Position, Palette.RcBright, 14, 8, 0.3)
	else
		-- The handle's electrical stimulus wakes the stored RC cells.
		CombatEffects.burst(root.Position, Color3.fromRGB(255, 120, 120), 10, 14, 0.12)
		CombatEffects.sound(root, CombatEffects.Sounds.Draw, 0.5)
	end
end

local function step(dt: number)
	local t = now()
	for character, state in states do
		local rig = state.rig
		if not rig then
			continue
		end
		state.progress = targetProgress(character, state.progress, t, dt)
		if rig.kind == "Kagune" then
			animateKagune(state, rig, t, dt)
		else
			animateQuinque(rig, state.progress)
		end
	end
end

function WeaponVisuals.start()
	Characters.observe(function(character)
		local state: State = { character = character, loadout = nil, rig = nil, progress = 0, lastState = nil }
		states[character] = state
		rebuild(state)

		local connections = {
			character:GetAttributeChangedSignal("Loadout"):Connect(function()
				rebuild(state)
			end),
			character:GetAttributeChangedSignal("OneEyed"):Connect(function()
				if state.loadout == "Ghoul" then
					rebuild(state)
				end
			end),
			character:GetAttributeChangedSignal("WeaponState"):Connect(function()
				onWeaponStateChanged(state)
			end),
		}
		return function()
			for _, connection in connections do
				connection:Disconnect()
			end
			destroyRig(state)
			states[character] = nil
		end
	end)
	RunService.PreSimulation:Connect(step)

	-- Meshes load after characters may already have stand-in rigs; swap
	-- them in once a batch of pieces has arrived.
	local rebuildQueued = false
	local function onAssetAdded()
		if rebuildQueued then
			return
		end
		rebuildQueued = true
		task.delay(0.5, function()
			rebuildQueued = false
			for _, state in states do
				rebuild(state)
			end
		end)
	end
	task.spawn(function()
		local assets = ReplicatedStorage:WaitForChild("Assets", 30)
		if assets then
			assets.DescendantAdded:Connect(onAssetAdded)
		end
	end)
end

return WeaponVisuals
