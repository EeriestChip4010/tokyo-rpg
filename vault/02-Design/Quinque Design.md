---
tags: [design, draft]
---
# Quinque Design

Investigators fight with [[Quinques]] instead of kagune.

## How quinques work in-game
- The quinque is carried in a case. Drawing it takes a short "deploy" animation that is interruptible, which gives investigators a real risk before a fight.
- Quinque skills use **quinque charge**, which refills over time and on hits, so investigators don't depend on feeding.
- Each quinque has a **type** inherited from its source kagune, so it gets the same matchup cycle as ghouls.
- Each quinque has a **rating** (C to S) tied to the source ghoul's [[Threat Ratings|rating]].

## Where quinques come from (the hook)
Quinques are crafted from **kakuhou** dropped by defeated ghouls, NPC or player. This ties both sides together: every ghoul a player creates is potential quinque material for someone else.
- A kakuhou carries the source ghoul's type, rating, and (for player ghouls) the player's name, so you can carry a weapon made from a rival.
- Starter investigators get a standard C-rate issue quinque from the CCG.

## First-playable scope
One C-rate Bikaku-type issue quinque: the **CCG Issue Blade (Tsunagi pattern)**, after canon's mass-produced Tsunagi. 3.8 studs, no crossguard, nine dark-red plates on the spine as the Bikaku touch. Built (`assets/`, `tools/blender/build_blade.py`). #agreed
- M1 chain: 3 slashes and a lunging thrust finisher.
- E **Rising Slash**: launches and deals heavy posture damage.
- R **Tail Sweep**: a spin around the user that is built to guard break.
- Quinque charge (hidden) refills over time and on hits.

## The case
A plain silver CCG case (1.6 x 1.2 x 0.4 studs) with a small tone-on-tone "CCG" plate and a trigger on the handle. Investigators carry it in the right hand. G deploys in 0.7 s and getting hit interrupts it:
1. The trigger sparks (the electrical stimulus).
2. The two shells hinge open from the bottom edge and fold into the collar.
3. RC pours out along the blade axis, overshoots, then hardens into the blade.
The handle stays in the hand and becomes the hilt. Sheathing plays it backwards, faster. The folding into the collar and the trigger glow are our stylisation.

## Related
[[Combat System]] · [[Progression]] · [[CCG]]
