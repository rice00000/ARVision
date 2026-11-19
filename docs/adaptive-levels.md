# Adaptive levels

Every menu level adapts to the child, within its own range, so it keeps its purpose (Clutter Search is about clutter, Odd Color about close colours) but is never too easy or too hard for long.

## How

A level's block names what adapts and its easiest and hardest values (`Block.drive`), and its own staircase (`Block.staircase`, e.g. `visual_matching.clutter`). Each child has a level 0 to 1 on that staircase; 0 plays the easiest values, 1 the hardest. `Block.difficulty` is where a new child starts (0).

- **Moving:** 2 right in a row (first try, no help) → one step (0.1) harder; a miss → one step easier. Settles near 71% right.
- **Quick start:** until the child's first miss on a level, every right round steps up twice as far, so a strong child reaches their level in a few rounds.
- **Fair to slow children:** a round solved first time with only the help that came by itself after a wait does not move the level (`outcome` "neutral" in the log). Help the child asked for (raised hand), a wrong try or a fail moves it down. The research log keeps the strict `first_try` either way.
- **Finished** (reward, medal) when at least half the level's rounds were solved; check-ins and skipped levels never finish.
- **Menu follows the child:** a gold bar on each played card shows how far up its range the child has climbed. The card that glows ("play next") is the first level not yet finished, or finished but not yet climbed to 70% (`World.READY_AT`): practise it, then move on. Every level stays open.
- **Staff:** Vision page → Difficulty moves this level's staircase; **Adaptive off** plays every level fixed at its start plus the child's offset. Training → Easier / Harder pins the level for the session, as before.

Research session plans (`content/sessions/`) keep the textbook staircase (by skill, no quick start); only blocks with `drive` are adaptive levels.

## The levels

| Level | Adapts | Easiest → hardest | Rounds |
|---|---|---|---|
| Shadow Match | things | 3 → 5 | 5 |
| Similar Shadows | things | 5 → 6 (6 brings look-alikes) | 5 |
| Size Match | sizes | 3 → 5 | 5 |
| Color Match | colours | 3 → 6 | 5 |
| Clutter Search | junk bits (4 things) | 2 → 12 | 5 |
| Odd Color 1 / 2 | colour step | big → medium / medium → small | 6 |
| Odd Color Adaptive | colour gap (its own skill staircase, endless) | | until ended |
| Ready to Study | props (notebook and pencil always) | 3 → 5 | 2 |
| Bookshelf Match | objects | 3 → 5 | 3 |
| Make a Sandwich | fillings | 1 → 3 | 2 |
| Steady Flow / Mixed Flow | dots moving together | 90% → 50% / 60% → 15% | 8 |
| Butterfly Circle / Both Ways | speed, m/s | 0.12 → 0.3 / 0.15 → 0.4 | 2 |
| Butterfly Swarm / Busy Swarm | butterflies flying together | 90% → 55% / 60% → 20% | 6 |

**Inside a round:** catch-all butterflies also adapt as the child plays: each catch makes the flock 10% faster, each wrong swing 15% slower (0.08 to 0.45 m/s); attempts log the speed, the round its `end_speed`.

The first visit's shelf level (with Onion) stays at 2 rounds (`ShelfReminder.TUTORIAL_ROUNDS`).

## Changing a level

In Godot, open the task in `content/tasks/`, the level's plan, its block: edit **Drive** (axis → Vector2(easiest, hardest)), **Staircase** (keep it unique and keep the name once children have played, or their place on it is lost) and **Rounds**. Axes a level can drive are each trial's `TrialAxis` names (`trials/*/*.tres`). Tests: `tests/adaptive_test.gd`, `tests/vision_test.gd`, `tests/world_test.gd`.
