---
tags: [reference, ui]
game: "Tokyo:RE (Roblox, by 9sGames)"
collected: 2026-10-27
---
# Tokyo RE - HUD and Screens

[Tokyo:RE on Roblox](https://www.roblox.com/games/13026442119/Tokyo-RE) by **9sGames**. It's a Tokyo Ghoul game focused on deliberate, parry-based combat, atmosphere, and long-term progression. As of Oct 2026 the page title says **[Stasis]**. The developer says they've moved on and want to hand the game to someone else, but it stays playable. Numbers at collection time: 655K+ visits, 16K favourites, about 14 active players, maturity "Moderate".

> [!note] Thin coverage
> The game went through closed testing with a media ban, so there are very few public screenshots of its HUD or menus. Most of what's below comes from the dev team's "Tokyo: RE Direct" livestream (26 Sep 2025), as summarised by BloxInformer. To get real UI references, **play it** (it's still open) or watch gameplay videos, and fill in the checklist at the bottom.

## Look and feel
| Combat preview | Opening tutorial mission |
|---|---|
| ![](https://bloxinformer.com/wp-content/uploads/2025/10/Tokyo-Re-combat.webp) | ![](https://bloxinformer.com/wp-content/uploads/2025/10/tutorial.png) |

![Ghoul parkour movement](https://bloxinformer.com/wp-content/uploads/2025/10/ghoulmovement-ezgif.com-video-to-gif-converter.gif)

- Cold blue night lighting on clean, realistic Tokyo streets. Kagune glow purple against it. The style is atmospheric rather than cartoony.
- The game icon is grayscale manga-style art, a split portrait of two characters. That's a strong, recognisable identity that doesn't use Roblox avatars.
- The description puts **"learning through play rather than constant hand holding"** first. Expect very little on-screen tutorial text.

## Systems that shape the UI
### Stamina is the core combat resource
Stamina is the main resource bar, unlike Deepwoken's Ether or our RC.
- M1s cost a little stamina, **landing a hit gives stamina back**, and M1s still work at zero stamina.
- Skills need a minimum amount of stamina, or they won't fire.
- **Skill Burst:** after an M1 lands, spend extra stamina to cancel its end lag into a skill. It's animation cancelling with a cost.
- The design goal is to reward accurate aggression and punish spamming.

> For us: our [[Combat System]] has stamina only for dash, dodge and sprint. A "hits refund stamina" rule and a Skill Burst-style cancel are worth trying. If we add them, the stamina bar needs to sit near the centre of the screen, where players look during a fight.

### Offence and defence
- **Offence:** M1s, criticals (high posture damage), aerial attacks, running attacks, and skills. Some kagune and weapons have aerial variants.
- **Defence:** block, parry, dodge, and a **vanish dodge** ("C dodge", a dodge on the spot).
- **Posture:** when it maxes out, you're staggered.

### Movement
- A full **parkour** system.
- **Ghouls** climb, run and jump faster and better.
- **CCG** get **gadgets** to keep up: confirmed are a **ladder** and a **grappling hook**.

> For us: gadget slots for investigators are a good balance answer to ghoul mobility. They'd need their own hotbar icons. Relevant to [[Quinque Design]] and [[Origins and Race Paths]].

### Progression
- Most progression is **PvE**. The **late game and top ranks need PvP**.
- Missions differ by race (ghoul or CCG).
- **Faction ranks** set strength and are earned from missions and PvP.
- Ghouls get **kakuja**, and the CCG gets **quinques**. Weapons upgrade and evolve through play.
- The first mission is the combat tutorial: save an NPC from a gang enforcer.

> For us: a "save someone from a thug" opening fits our everyone-starts-human idea ([[Origins and Race Paths]]). It teaches combat before the player chooses a path.

### Business model
- The plan was closed test waves (Sep–Dec 2025), one free week, then **paid access for 200 Robux** from Jan 2026. That's worth knowing when thinking about monetisation ([[Open Questions]]).

## To check in-game
- [ ] Health, posture, and stamina bar layout, and where the stamina bar sits
- [ ] How Skill Burst is shown (flash, sound, or bar change)
- [ ] Rank screen and mission UI per faction
- [ ] Kagune and quinque upgrade screen
- [ ] Gadget hotbar for the CCG
- [ ] Death and permadeath screen, if there is one

## Sources
- [Roblox game page: Tokyo:RE](https://www.roblox.com/games/13026442119/Tokyo-RE) (description, stats, Stasis note)
- [BloxInformer: Tokyo: RE wiki](https://bloxinformer.com/wikis/tokyo-re/)
- [BloxInformer: Development Progress and Update](https://bloxinformer.com/wikis/tokyo-re/development-progress-and-update) (Direct livestream summary, test timeline, images credited to the YouTube channel "Noxxy")
- Discord: [discord.com/invite/tokyore](https://discord.com/invite/tokyore)
- Video search: [YouTube "Tokyo RE roblox"](https://www.youtube.com/results?search_query=Tokyo+RE+roblox), [YouTube "Tokyo RE Direct"](https://www.youtube.com/results?search_query=Tokyo+RE+Direct+roblox)

## Related
[[UI References]] · [[Deepwoken - HUD and Screens]] · [[Ghoul Re - HUD and Screens]] · [[Genre Patterns - Stat and Progression Screens]]
