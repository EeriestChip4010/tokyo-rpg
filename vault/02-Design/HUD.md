---
tags: [design, draft]
---
# HUD

Built from the patterns in [[UI References]]: thin bars, the screen kept mostly world, and **status shown by how a bar looks** rather than by text. The style is ours: ink-black panels, off-white "manga paper" trim, crimson accents, notched pixel corners. Code: `src/client/Hud.luau`.

## Layout
| Where | What | Shown when |
|---|---|---|
| Bottom center | STUNNED text | Stunned |
| | Posture (fills up as you take blocked hits; flashes red at 75%+) | Blocking or posture built up |
| | Health (10 segments, pale damage trail) | Always |
| | Stamina (near center, per [[Tokyo RE - HUD and Screens]]) | Always |
| | RC (ghouls) or quinque charge (CCG) | When the character has it |
| Right of the bars | Dash and dodge icons (grey out with a cooldown sweep) | Always |
| Bottom left | Name plate with race tag | Always |
| | Hunger (small survival bar, per [[Deepwoken - HUD and Screens]]) | Ghouls |
| Top center | Combat tag skull: blue PvE, red PvP | 20 s after hitting or being hit |

## Health bar skins
| Skin | Trigger | Look |
|---|---|---|
| Normal | Default | Crimson fill, paper trim |
| Stained | Last life (`Lives` = 1) | Crimson trim and dark specks on the fill |
| Starving | Hunger under 20% | Ashen fill; hunger bar trim turns crimson |

Later ideas: a kakuja-instability skin, telegraph glyphs, a cinematic mode that hides the HUD, and an option to show numbers.

## Attributes the HUD reads
`Posture`, `MaxPosture`, `Stamina`, `MaxStamina`, `Blocking`, `StunnedUntil`, `CombatTag`, `CombatTagUntil` (all published now), plus `Race`, `Lives`, `Hunger`/`MaxHunger`, `RC`/`MaxRC`, `QuinqueCharge`/`MaxQuinqueCharge` (shown once those systems exist).

## Related
[[Combat System]] · [[UI References]] · [[Genre Patterns - Stat and Progression Screens]]
