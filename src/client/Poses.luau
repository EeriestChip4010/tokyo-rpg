--!strict
-- Procedural R6 poses, so combat animates without uploaded animation assets.
-- Each pose is a set of joint rotations applied on top of whatever the
-- default Animate script is playing (see CharacterAnimator).
--
-- Joint keys: RS/LS = right/left shoulder, RH/LH = hips, Root = RootJoint,
-- Neck. The helpers below take angles in degrees with body-relative
-- meaning, so poses read the same for both sides:
--   arm(forward, inward, twist): forward raises the arm in front,
--     inward swings it across the chest, twist rolls it along its length
--     (a held blade turns from vertical to horizontal at twist 90).
--   torso(lean, turn): lean tips forward, turn rotates toward the left.

export type JointSet = { [string]: CFrame }

export type AttackPose = {
	windup: JointSet,
	strike: JointSet,
	strikeTime: number?, -- seconds from windup end to the strike pose (default 0.1)
	spin: boolean?, -- adds a full turn of the torso during the strike
}

local rad = math.rad

local function rightArm(forward: number, inward: number, twist: number?): CFrame
	return CFrame.Angles(rad(inward), rad(twist or 0), rad(forward))
end

local function leftArm(forward: number, inward: number, twist: number?): CFrame
	return CFrame.Angles(rad(inward), -rad(twist or 0), -rad(forward))
end

local function rightLeg(forward: number): CFrame
	return CFrame.Angles(0, 0, rad(forward))
end

local function leftLeg(forward: number): CFrame
	return CFrame.Angles(0, 0, -rad(forward))
end

local function torso(lean: number, turn: number): CFrame
	return CFrame.Angles(rad(lean), 0, rad(turn))
end

local Poses = {}

Poses.JointNames = {
	RS = "Right Shoulder",
	LS = "Left Shoulder",
	RH = "Right Hip",
	LH = "Left Hip",
	Neck = "Neck",
	Root = "RootJoint",
}

Poses.Attacks = {
	-- Fists
	FistJabR = {
		windup = { RS = rightArm(40, 10), Root = torso(0, 15) },
		strike = { RS = rightArm(95, 15), LS = leftArm(30, 20), Root = torso(5, -20) },
	},
	FistJabL = {
		windup = { LS = leftArm(40, 10), Root = torso(0, -15) },
		strike = { LS = leftArm(95, 15), RS = rightArm(30, 20), Root = torso(5, 20) },
	},
	FistHook = {
		windup = { RS = rightArm(60, -40), Root = torso(0, 30) },
		strike = { RS = rightArm(90, 50), LS = leftArm(30, 20), Root = torso(5, -35) },
	},
	FistFinisher = {
		windup = { RS = rightArm(-20, 0), Root = torso(15, 20), RH = rightLeg(-10), LH = leftLeg(15) },
		strike = { RS = rightArm(170, 10), Root = torso(-10, -15), LH = leftLeg(-10) },
		strikeTime = 0.12,
	},

	-- Kagune: the body leans into it; the tentacles do the work (KaguneRig).
	KaguneStrikeR = {
		windup = { Root = torso(-5, 10), RS = rightArm(20, -20) },
		strike = { Root = torso(10, -10), RS = rightArm(60, -30) },
	},
	KaguneStrikeL = {
		windup = { Root = torso(-5, -10), LS = leftArm(20, -20) },
		strike = { Root = torso(10, 10), LS = leftArm(60, -30) },
	},
	KaguneSweep = {
		windup = { Root = torso(0, 35), RS = rightArm(30, -40), LS = leftArm(30, 30) },
		strike = { Root = torso(5, -40), RS = rightArm(30, 30), LS = leftArm(30, -40) },
		strikeTime = 0.15,
	},
	KaguneSlam = {
		windup = { Root = torso(-15, 0), RS = rightArm(150, -10), LS = leftArm(150, -10) },
		strike = { Root = torso(20, 0), RS = rightArm(40, 10), LS = leftArm(40, 10) },
		strikeTime = 0.12,
	},
	KaguneBarrage = {
		windup = { Root = torso(-8, 0), RS = rightArm(10, -30), LS = leftArm(10, -30) },
		strike = { Root = torso(12, 0), RS = rightArm(30, -40), LS = leftArm(30, -40) },
		strikeTime = 0.45,
	},
	KaguneGrab = {
		windup = { Root = torso(10, 0), RS = rightArm(80, -20), LS = leftArm(80, -20) },
		strike = { Root = torso(-12, 0), RS = rightArm(60, 20), LS = leftArm(60, 20) },
		strikeTime = 0.2,
	},

	-- Quinque blade (held in the right hand; vertical when the arm is level)
	BladeSlash1 = {
		windup = { RS = rightArm(90, -70, 90), Root = torso(0, 40) },
		strike = { RS = rightArm(90, 60, 90), Root = torso(5, -40) },
	},
	BladeSlash2 = {
		windup = { RS = rightArm(90, 70, 90), Root = torso(0, -35) },
		strike = { RS = rightArm(90, -60, 90), Root = torso(5, 35) },
	},
	BladeSlash3 = {
		windup = { RS = rightArm(170, 10), Root = torso(-10, 0) },
		strike = { RS = rightArm(45, 10), Root = torso(15, 0) },
	},
	BladeThrust = {
		windup = { RS = rightArm(-30, 0), Root = torso(0, 20), RH = rightLeg(-15) },
		strike = { RS = rightArm(20, 0), Root = torso(10, -15), RH = rightLeg(30), LH = leftLeg(-20) },
	},
	BladeRising = {
		windup = { RS = rightArm(-40, -20, 90), Root = torso(10, 30) },
		strike = { RS = rightArm(160, 10, 90), Root = torso(-10, -20) },
		strikeTime = 0.14,
	},
	BladeSpin = {
		windup = { RS = rightArm(90, -80, 90), Root = torso(5, 60) },
		strike = { RS = rightArm(90, -80, 90), Root = torso(5, 60) },
		strikeTime = 0.35,
		spin = true,
	},
} :: { [string]: AttackPose }

-- Held poses, blended in and out while a state lasts.
Poses.Holds = {
	BlockFists = { RS = rightArm(100, 60), LS = leftArm(100, 60), Root = torso(5, 0) },
	BlockKagune = { RS = rightArm(100, 60), LS = leftArm(100, 60), Root = torso(8, 0) },
	BlockBlade = { RS = rightArm(80, 45, 90), LS = leftArm(60, 50), Root = torso(5, 10) },
	BladeReady = { RS = rightArm(35, 10) },
	DeployQuinque = { RS = rightArm(70, 10), Root = torso(5, 0) },
	DeployKagune = { RS = rightArm(20, -30), LS = leftArm(20, -30), Root = torso(15, 0) },
	Stunned = { RS = rightArm(15, -25), LS = leftArm(15, -25), Root = torso(-12, 0) },
} :: { [string]: JointSet }

return Poses
