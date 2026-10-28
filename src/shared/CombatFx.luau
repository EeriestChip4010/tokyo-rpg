--!strict
-- Event kinds the server broadcasts on Remotes.CombatFx so every client can
-- play animations and effects locally. The server only reports outcomes;
-- clients decide how they look.
--
--   Swing(model, movesetId, chainIndex, windupEndsAt)
--   Skill(model, movesetId, skillKey, windupEndsAt)
--   Feint(model)
--   Result(model, result, position)  -- result is one of Results below

local CombatFx = {
	Swing = "Swing",
	Skill = "Skill",
	Feint = "Feint",
	Result = "Result",

	Results = {
		Hit = "Hit",
		Blocked = "Blocked",
		Parried = "Parried",
		GuardBreak = "GuardBreak",
		Dodged = "Dodged",
	},
}

return CombatFx
