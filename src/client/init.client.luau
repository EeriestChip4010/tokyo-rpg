-- Client entry point: starts each controller once.

local CharacterAnimator = require(script.CharacterAnimator)
local Characters = require(script.Characters)
local CombatController = require(script.CombatController)
local CombatEffects = require(script.CombatEffects)
local Hud = require(script.Hud)
local WeaponVisuals = require(script.WeaponVisuals)

CharacterAnimator.start()
WeaponVisuals.start()
CombatEffects.start()
Characters.start()
CombatController.start()
Hud.start()
