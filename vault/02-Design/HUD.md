---
tags: [design, agreed]
---
# HUD

Built from the patterns in [[UI References]]: thin bars, the screen kept mostly world, and **status shown by how a bar looks** rather than by text. The style is ours: ink-black panels, off-white "manga paper" trim, crimson accents, notched pixel corners. Code: `src/client/Hud.luau`.

## Current version #agreed
Only two bars, bottom center:
| Bar | Notes |
|---|---|
| Health | Pale damage trail behind the fill |
| Hunger | Reads `Hunger`/`MaxHunger`; trim turns red below 20% |

**RC is a hidden value.** It is never shown as a bar. Posture and stamina are also hidden; they still work in combat.

## Shelved ideas (from the references)
Posture bar, stamina bar, cooldown icons, combat tag skull, name plate with race tag, health bar skins for last life and starving, telegraph glyphs. See git history for the earlier version.

## Related
[[Combat System]] · [[UI References]] · [[Genre Patterns - Stat and Progression Screens]]
