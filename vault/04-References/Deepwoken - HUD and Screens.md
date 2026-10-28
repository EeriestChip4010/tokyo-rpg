---
tags: [reference, ui]
game: Deepwoken (Roblox)
collected: 2026-10-27
---
# Deepwoken - HUD and Screens

The main genre reference for HUD, stat screens and level-up flow. Images are hotlinked from the Deepwoken Fandom wiki, so they need an internet connection to show. Our versions go in [[Genre Patterns - Stat and Progression Screens]].

## Full HUD
![Deepwoken HUD (Verse 2)](https://static.wikia.nocookie.net/project-deepwoken/images/a/a1/Verse2GUI.png/revision/latest)

**Layout takeaways**
- Bars are stacked bottom-centre/left and kept thin. The screen is mostly world, not UI.
- Status is shown by **changing how a bar looks**, not by adding text. The health bar has four skins: normal, stained (died once), rusted (in a danger zone), and void (in the Depths). One glance tells you how close you are to losing the character.
- Percentages are hidden until you hover (a setting can show them all the time).
- A "Cinematic mode" setting hides all UI for screenshots and videos.

### Health bar states
| Normal | Stained (1 life left) | Rusted (danger zone) | Void (last chance) |
|---|---|---|---|
| ![](https://static.wikia.nocookie.net/project-deepwoken/images/b/bf/HDHP.png/revision/latest) | ![](https://static.wikia.nocookie.net/project-deepwoken/images/7/7c/Stained_Health_Bar.png/revision/latest) | ![](https://static.wikia.nocookie.net/project-deepwoken/images/1/13/Healthbar_rusted.png/revision/latest) | ![](https://static.wikia.nocookie.net/project-deepwoken/images/e/ef/Void_Threshold.png/revision/latest) |

> Idea for us: a ghoul's health bar could change skin when **starving** or when **kakuja** is building, the same way Deepwoken shows "stained". See [[Death and Permadeath]] and [[Feeding]].

### Posture bar
![Posture bar near break](https://static.wikia.nocookie.net/project-deepwoken/images/6/6c/Posturebarweak.gif/revision/latest)
![Block exhaust](https://static.wikia.nocookie.net/project-deepwoken/images/b/b3/Block_Exhaust_bar.png/revision/latest)

- Posture fills up as you block. Full posture means the next blocked hit **guard breaks** you (about a 1 s stun).
- Parrying, not blocking, and taunting bring it back down.
- The bar glows red during "shaky block", the moment after being hit when you can't block properly yet.

### Cooldown icons
![Cooldown indicators](https://static.wikia.nocookie.net/project-deepwoken/images/4/41/Cooldown_Indicators_.gif/revision/latest)

Small icons for dodge, parry, block, feint, resonance, and the weapon critical. Each one greys out while it's on cooldown. Effects procced by talents get their own named timer bars ("Cooldown Bars" setting).

| Dodge | Parry | Block | Feint | Critical |
|---|---|---|---|---|
| ![](https://static.wikia.nocookie.net/project-deepwoken/images/d/d3/Dodge_CD_indicator.png/revision/latest) | ![](https://static.wikia.nocookie.net/project-deepwoken/images/b/b9/Parry_CD_indicator.png/revision/latest) | ![](https://static.wikia.nocookie.net/project-deepwoken/images/0/00/Block_CD_indicator.png/revision/latest) | ![](https://static.wikia.nocookie.net/project-deepwoken/images/f/f7/Feint_CD_indicator.png/revision/latest) | ![](https://static.wikia.nocookie.net/project-deepwoken/images/a/aa/Critical_CD_indicator.png/revision/latest) |

> For us: dash, dodge, parry, and kagune skill cooldowns. This maps straight onto our Q dash/dodge split in [[Combat System]].

### Resource bars
| Ether (mana) | Tempo | Armor |
|---|---|---|
| ![](https://static.wikia.nocookie.net/project-deepwoken/images/e/ed/HDEther.png/revision/latest) | ![](https://static.wikia.nocookie.net/project-deepwoken/images/f/fa/Tempo.png/revision/latest) | ![](https://static.wikia.nocookie.net/project-deepwoken/images/0/00/HDArmor.png/revision/latest) |

- **Ether** is the skill resource. Our equivalent is **RC**.
- **Tempo** fills when you hit or get hit. At 40 or more you can **Vent** (G), a burst that pushes everyone back and breaks combos. It's the anti-gank tool. Worth considering for a game with open PvP.

### Survival bars
![Survival bars](https://static.wikia.nocookie.net/project-deepwoken/images/7/7b/Survivalbars.png/revision/latest)

Blood, water, and stomach, shown bottom-left and smaller than the combat bars. Running out of food stops health regeneration. Our **hunger** meter for ghouls ([[Ghoul Diet]]) can use the same small-bar style.

## Telegraphs (attack warnings)
Dangerous attacks flash a **coloured glyph** with a matching outline and sound. The glyph tells you the right answer. A "Simple Telegraphs" setting shows only the coloured outline.

| Guard break | High posture | Parry it | Block it | Dodge it | Jump | Duck |
|---|---|---|---|---|---|---|
| ![](https://static.wikia.nocookie.net/project-deepwoken/images/3/3d/GuardbreakTelegraph.png/revision/latest) | ![](https://static.wikia.nocookie.net/project-deepwoken/images/3/3e/HighPostureTelegraph.png/revision/latest) | ![](https://static.wikia.nocookie.net/project-deepwoken/images/a/ae/ParryTelegraph.png/revision/latest) | ![](https://static.wikia.nocookie.net/project-deepwoken/images/7/7f/BlockTelegraph.png/revision/latest) | ![](https://static.wikia.nocookie.net/project-deepwoken/images/d/d0/DodgeTelegraph.png/revision/latest) | ![](https://static.wikia.nocookie.net/project-deepwoken/images/b/b0/JumpTelegraph.png/revision/latest) | ![](https://static.wikia.nocookie.net/project-deepwoken/images/4/42/DuckTelegraph.png/revision/latest) |

> For us: Koukaku heavy slams and quinque criticals could use a guard-break telegraph tinted in the kagune's colour.

## Stat (attribute) screen
![Tab menu with Power and stats (Verse One)](https://static.wikia.nocookie.net/project-deepwoken/images/8/8e/PlayerTabMenuStatExampleLongFileNameFunnyThisGameSucks.png/revision/latest)

- **Power** (level) runs from 1 to 20. Each Power level gives **15 investment points**, and you level up once you've spent them and have enough EXP.
- Points go into **base attributes** (Strength, Fortitude, Agility, Intelligence, Willpower, Charisma), **weapon attributes** (Heavy, Medium, Light) and **attunements** (elements).
- Attribute totals gate talents, oaths and weapons. That's what makes the screen matter: you plan around thresholds like "40 Agility".
- Training items (ankle weights, books) let you invest a point without fighting. That's useful for a quiet "human" phase.

## Level-up: talent cards
| Hand of talent cards | Mantra cards (older version) |
|---|---|
| ![](https://static.wikia.nocookie.net/project-deepwoken/images/9/9f/Talent_Hands_Updaed.png/revision/latest) | ![](https://static.wikia.nocookie.net/project-deepwoken/images/a/a9/Mantra_Card_example.png/revision/latest) |

![Power-up icon at top centre](https://static.wikia.nocookie.net/project-deepwoken/images/c/cc/Power_Card_Icon.png/revision/latest)

- When you power up, an icon appears at the top centre. Opening it shows a **hand of cards** (talents or mantras) and you pick one.
- **Fold** skips the hand and gives you an extra hand next time.
- Powering up also fully heals you, refills hunger, and **unstains** your health bar. The level-up doubles as the way to earn a life back.

> For us: kagune **evolution** could be a card pick. At each RC milestone, choose 1 of 3 kagune traits filtered by kagune type. See [[Kagune Design]] and [[Progression]].

## Character creation
![Character creation screen](https://static.wikia.nocookie.net/project-deepwoken/images/b/b5/DeepwokenCCscreen.png/revision/latest)

- **Race (Aspect)** is rolled randomly, and rerolling costs Robux. That's the same model as our rolled kagune ([[Origins and Race Paths#Kagune roll]]).
- You pick up to two attunements, or none (which gives free training points instead).
- You pick a starting weapon class (Heavy, Medium, or Light).
- **Boons and Flaws:** at least 1 of each, at most 2 of each. A flaw "pays" for a boon.
- **Origins** are spawn points. More unlock across characters.
- The **Echo shop** tab spends meta-currency earned from previous wipes.

## Death and wipe flow
- Two lives in practice. The first death stains your health bar and drops roughly half your money and unequipped items. Soulbound items are kept.
- Dying while stained sends you to **the Depths**, a hard zone where a death **wipes** the character. Escaping restores your lives.
- **Echoes** are earned on wipe, scaled by "Triumphs" (achievements like killing a boss or getting an oath). They buy account-wide unlocks, and you get a letter rank from E to S for the run.
- **Combat tag** shows as a skull icon at the top of the screen: blue for PvE, orange for a boss, red for PvP. Leaving while tagged in PvP counts as a death.

> For us: [[Death and Permadeath]] still has "what carries over" open. The Echo model (meta-currency scaled by achievements, plus a rank screen on wipe) answers that.

## Default PC controls (for reference)
| Key | Action |
|---|---|
| M1 / M2 | Attack / feint |
| R or M3 | Critical |
| F | Parry (tap) / block (hold) |
| Q | Dodge (roll) |
| G | Vent |
| B | Execute (finish a knocked player) |
| V | Carry a knocked player |
| T | Taunt |
| Tab | Backpack / journal |
| Ctrl | Crouch (crouch + M1 from behind = assassination) |

## Sources
- [Deepwoken Wiki: Combat Mechanics](https://deepwoken.fandom.com/wiki/Combat_Mechanics) (HUD, bars, telegraphs, parry, block and feint rules)
- [Deepwoken Wiki: Power](https://deepwoken.fandom.com/wiki/Power) (levels and investment points)
- [Deepwoken Wiki: Talents](https://deepwoken.fandom.com/wiki/Talents) (card hands)
- [Deepwoken Wiki: Character Creation](https://deepwoken.fandom.com/wiki/Character_Creation)
- [Deepwoken Wiki: Death](https://deepwoken.fandom.com/wiki/Death), [Echoes](https://deepwoken.fandom.com/wiki/Echoes), [Combat Tag](https://deepwoken.fandom.com/wiki/Combat_Tag)
- [Deepwoken Wiki: Settings](https://deepwoken.fandom.com/wiki/Settings) (keybinds, interface options)

Wiki text is CC-BY-SA, and the screenshots belong to the Deepwoken developers. They're for internal reference only, so don't ship them.

## Related
[[UI References]] · [[Ghoul Re - HUD and Screens]] · [[Genre Patterns - Stat and Progression Screens]]
