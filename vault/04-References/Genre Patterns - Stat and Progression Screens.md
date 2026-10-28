---
tags: [reference, ui, draft]
---
# Genre Patterns - Stat and Progression Screens

How games in the Deepwoken and Ghoul://Re genre handle the screens players stare at most, and what that suggests for us. Ideas below are proposals. #draft

## Side by side
| Screen | Deepwoken | Ghoul://Re | Suggestion for us |
|---|---|---|---|
| Headline "level" | Power 1–20 | Rank (C → SSS / Rank 3 → Special Class) | Threat rating or CCG rank, shown big ([[Threat Ratings]], [[CCG]]) |
| Points | 15 investment points per Power | 5 skill points per rank | Attribute points from rank-ups plus training (see below) |
| Where points go | Attributes with thresholds that unlock talents and oaths | Skill tree: 4 columns, each skill needs a stat minimum | Attributes plus a small skill tree split by race |
| Level-up reward | Pick 1 of a hand of cards (or fold) | Skill points to spend | Card pick for **kagune evolution**, points for everything else |
| Rolled at start | Aspect (race), reroll costs Robux | Clan (small stat bonus), reroll costs Robux | Kagune type (already agreed, see [[Origins and Race Paths]]) |
| Rank-up needs | EXP only | EXP, grips, events, survived permadeaths | EXP plus feeding (ghoul) or arrests and kills (CCG) |
| Death UI | Health bar changes skin (stained, then void) | Not documented | Health bar skin for starving, last life, and kakuja instability |
| On wipe | Echo rank (E to S) and meta-currency | Wipe to reroll clan | A rank screen plus a small carry-over (see [[Death and Permadeath]]) |
| HUD density | Several thin bars and cooldown icons | One health bar and a skill row | Health, posture, RC (ghoul) or quinque charge (CCG), cooldowns |

## Patterns worth copying
1. **Thresholds make the stat screen matter.** In Deepwoken, a point is exciting because it moves you toward "40 Agility unlocks X". Show the next unlock next to each attribute.
2. **Status is shown by bar skin, not text.** Players read the danger at a glance.
3. **The level-up is a moment.** An icon at the top centre, a hand of cards, and a full heal. It's the high point of a session.
4. **Weaponless skills for humans.** Ghoul://Re's Strength and Dexterity trees give the human starting phase real moves. That's important for us, because everyone starts human.
5. **A rolled start with a paid reroll** is the genre-standard way to make money. Pair it with a free in-game reroll path to avoid pay-to-win complaints ([[Open Questions]] already calls for non-pay-to-win passes).
6. **Rank gates content.** Kagune sacs at B+ and kakuja at SSS make the rank feel like story, not just numbers.
7. **Telegraphs** with coloured glyphs keep high-skill PvP readable.

## Draft: our stat screen
Rough wireframe for the Tab menu. #game-original
```
┌───────────────────────────────────────────────────────┐
│ [avatar]  NAME            Rating: B   (or Rank 2)    │
│           One-eyed ghoul · Rinkaku                    │
├───────────────┬───────────────────────────────────────┤
│ STR  12  [+]  │ Next unlock: Gut Punch at 15 STR      │
│ AGI   8  [+]  │                                       │
│ END  10  [+]  │ RC 1,420 / 2,000  (to Stable stage)   │
│ RC CTRL 5 [+] │ Hunger ▓▓▓▓▓░░░                        │
├───────────────┴───────────────────────────────────────┤
│ Points: 3                    [Skill Tree] [Kagune]    │
└───────────────────────────────────────────────────────┘
```
- The **RC CTRL** attribute exists for ghouls and Quinx only. CCG gets **QUINQUE** instead.
- The **Kagune** tab shows the maturity stage ([[Progression#3. Kagune maturity]]) and the card picks taken so far.

## Tokyo:RE's angle
[[Tokyo RE - HUD and Screens|Tokyo:RE]] makes **stamina** the main combat bar instead of a mana-style resource. Hits refund stamina, and Skill Burst spends extra to cancel M1 end lag into a skill. It also splits movement by race: ghoul parkour buffs against CCG gadgets (ladder, grappling hook). Ranks come mostly from PvE, with PvP needed for the top ones.

## Other genre games worth a look
Not researched yet. Add a note for each if they turn out to be useful.
- **Rogue Lineage:** the predecessor to Deepwoken. Origin of the lives-and-wipe structure.
- **Type Soul:** Bleach-inspired, with a race-path progression similar to our human → ghoul or CCG path.
- **Ro-Ghoul:** older Tokyo Ghoul game, with kagune stages bought with RC. See [Ro-Ghoul wiki](https://roghoul-rblx.fandom.com/wiki/Nishiki?oldid=933).

## Related
[[UI References]] · [[Deepwoken - HUD and Screens]] · [[Ghoul Re - HUD and Screens]] · [[Progression]] · [[Combat System]]
