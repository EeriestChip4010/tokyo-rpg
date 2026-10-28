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
| Right click during a swing's windup | Feint |
| Hold F | Block (uses posture; running out causes a guard break) |
| Tap F just before a hit | Parry (stuns the attacker) |
| Q while moving | Dash |
| Q while standing still | Dodge (brief invincibility) |
| G | Release the kagune (ghouls) or open the quinque case (investigators) |
| E / R | Weapon skills while the kagune or quinque is out |
| P (Studio only) | Swap between the ghoul and investigator test loadouts |

Two dummies spawn in front of the spawn point: a plain **Training Dummy** (left) and a **Blocking Dummy** (right) that always blocks, for testing posture and guard breaks. Hit flashes: white = hit, blue = blocked, yellow = parried, red = guard break.

Each player rolls an origin on join (60% human, 39% ghoul, 1% one-eyed). Humans start as investigators carrying the CCG case; ghouls get a Rinkaku kagune. In Studio, press P to swap.

### Weapon models
Models are built with headless Blender from `tools/blender/` into `assets/`. See [`assets/README.md`](assets/README.md) for how to regenerate them and how to get them into Studio. Until they're imported, the game uses plain-part stand-ins.
