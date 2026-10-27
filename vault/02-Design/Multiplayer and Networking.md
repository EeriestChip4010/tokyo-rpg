---
tags: [design, draft]
---
# Multiplayer and Networking

The game targets a **public multiplayer release** on Roblox, so combat must hold up against exploiters and lag.

## Rules
1. **The server is authoritative.** The client asks to do an action; the server decides whether it happens. The client never deals damage or grants RC, XP or items.
2. **Client-side prediction for feel.** The client plays the animation and effects immediately. The server validates and replies. Mispredictions are corrected quietly.
3. **Server-side hit detection.** The server checks every hit's range, cooldown, stun state and line of sight, using hitboxes with a small lag allowance.
4. **Rate-limit all remotes.** Every RemoteEvent has a per-player budget. Spam is dropped and logged.
5. **Never trust client values.** Damage, cooldowns and resource costs live in server-only modules.

## Data
- Player data saved with DataStore (or ProfileStore) using session locking, so items can't be duplicated by rejoining.
- Save on leave, at intervals, and on server shutdown.

## Tooling
- Code lives in this git repo and syncs into Roblox Studio with **Rojo** (step 2 of the [[Roadmap]]).

## Related
[[Combat System]] · [[Roadmap]]
