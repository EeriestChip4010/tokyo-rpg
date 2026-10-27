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
3. Open a Baseplate in Studio.

### Every session
1. Run `rojo serve` in this folder.
2. In Studio, open the Rojo plugin and click **Connect**.
3. Edit code in `src/`. Changes appear in Studio live. Press Play to test (there's a training dummy in front of spawn).
