---
tags: [design, draft]
---
# Combat System

Goal for the first playable: responsive, skill-based melee in the style of Deepwoken and Ghoul://Re, where reading your opponent matters more than stats.

## Core verbs
| Input (PC default) | Action | Purpose |
|---|---|---|
| LMB | **M1** | Basic attack chain |
| RMB during an M1 windup | **Feint** | Cancels the swing to bait a parry (1.5 s cooldown) |
| F (hold) | **Block** | Reduce damage, costs posture |
| F (tap on hit) | **Parry** | Perfect block window, staggers attacker |
| Q while moving | **Dash** | Fast move in the direction you're moving, for gap closing and repositioning |
| Q while standing still | **Dodge** | Short sidestep/backstep with i-frames, the panic button |
| E / R | Weapon skills | Kagune or quinque moves (see [[Kagune Design]], [[Quinque Design]]) |
| G | Draw / sheathe | Release the kagune, or open the quinque case |

Dash and dodge share the Q key; whether you're moving decides which one fires. They have separate cooldowns. #agreed

## Attack timing
Built in the combat rewrite. #draft
- Every attack runs **windup -> hit -> recovery**. The hitbox is checked on the server when the windup ends.
- Getting hit during a windup interrupts it, so the faster attack wins a trade.
- Dodging cancels your own windup.
- Each weapon has its own moveset (timings, hitboxes, damage, skills) in `src/shared/Movesets.luau`: fists, the Rinkaku kagune, and the Tsunagi-pattern quinque.
- Animations are procedural R6 poses (`src/client/Poses.luau`) until real animations are made.

## M1 chain
- 4-hit chain. The 4th hit is a knockback finisher.
- Missing an M1 or being parried resets the chain.
- **Uppercut / downslam variants:** jump + M1 and M1 while holding space for combo routes.

## Posture (block meter)
Built in the prototype. #draft
- Blocking drains **posture** instead of HP. When posture breaks, the player is **guard broken**: stunned and open to a critical.
- Posture regenerates when not blocking.
- Heavy attacks (Koukaku, heavy quinques) deal extra posture damage.

## Stun and hit rules
- Every hit applies a short hitstun. M1s cannot stunlock forever: after a full chain, the target gets a brief "combo break" grace.
- Getting hit while dashing cancels the dash.
- Parry beats M1 and light skills, M1 beats a slow startup skill, and dodge beats everything but costs a long cooldown.

## Resources
| Resource | Who | Used for |
|---|---|---|
| HP | Everyone | Dying |
| Posture | Everyone | Blocking |
| Stamina | Everyone | Dash, dodge, sprint |
| **RC** | Ghouls, Quinx | Kagune skills and regeneration (see [[RC Cells]]) |
| **Quinque charge** | Investigators | Quinque skills; recharges over time and on landing hits |

## Starting tuning (placeholders)
| Value | Placeholder |
|---|---|
| M1 damage | 4 per hit |
| M1 swing interval | 0.35 s |
| Parry window | 0.20 s |
| Dash cooldown | 2.0 s |
| Dodge cooldown | 6.0 s, 0.3 s i-frames |
| Guard break stun | 1.5 s |

## Related
[[Kagune Design]] · [[Quinque Design]] · [[Multiplayer and Networking]]
