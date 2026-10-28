# tokyo-rpg

A public multiplayer Roblox RPG set in the Tokyo Ghoul universe, inspired by Deepwoken and Ghoul://Re.

## Design vault
Design and lore notes live in [`vault/`](vault/), an [Obsidian](https://obsidian.md) vault.
Open Obsidian, choose **Open folder as vault**, and pick the `vault` folder. Start at `00-Home/Home.md`.

## Game code (Rojo)
Game code lives in `src/` and syncs into Roblox Studio with [Rojo](https://rojo.space).

| Folder | Becomes in Studio |
|---|---|
| `src/shared` | `ReplicatedStorage.Shared` (config and code used by both sides) |
| `src/server` | `ServerScriptService.Server` |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` |

### First-time setup (Windows)
1. Install [Aftman](https://github.com/LPGhatguy/aftman) (or Rokit), then run `aftman install` in this folder to get the pinned Rojo version.
2. Run `rojo plugin install` to add the Rojo plugin to Roblox Studio.
3. Open a Baseplate in Studio. The game is R6: set **Game Settings > Avatar > Avatar Type** to R6 (the training dummies already spawn as R6).

### Every session
1. Run `rojo serve` in this folder.
2. In Studio, open the Rojo plugin and click **Connect**.
3. Edit code in `src/`. Changes appear in Studio live. Press Play to test.

### Controls and test dummies
| Input | Action |
|---|---|
| Left click | M1 (4-hit chain; the 4th hit knocks back) |
| Hold F | Block (uses posture; running out causes a guard break) |
| Tap F just before a hit | Parry (stuns the attacker) |
| Q while moving | Dash |
| Q while standing still | Dodge (brief invincibility) |

Two dummies spawn in front of the spawn point: a plain **Training Dummy** (left) and a **Blocking Dummy** (right) that always blocks, for testing posture and guard breaks. Hit flashes: white = hit, blue = blocked, yellow = parried, red = guard break.
