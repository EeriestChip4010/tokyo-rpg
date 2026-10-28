-- Server entry point: starts each service once.

local AssetLoader = require(script.AssetLoader)
local CombatService = require(script.CombatService)
local Loadout = require(script.Loadout)
local TrainingDummy = require(script.TrainingDummy)

Loadout.start()
CombatService.start()
AssetLoader.start()
TrainingDummy.spawn(Vector3.new(-6, 5, -15))
TrainingDummy.spawn(Vector3.new(6, 5, -15), true)
