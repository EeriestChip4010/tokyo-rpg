-- Server entry point: starts each service once.

local CombatService = require(script.CombatService)
local TrainingDummy = require(script.TrainingDummy)

CombatService.start()
TrainingDummy.spawn(Vector3.new(-6, 5, -15))
TrainingDummy.spawn(Vector3.new(6, 5, -15), true)
