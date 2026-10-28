-- Client entry point: starts each controller once.

local CombatController = require(script.CombatController)
local Hud = require(script.Hud)

CombatController.start()
Hud.start()
