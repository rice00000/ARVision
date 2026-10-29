# The world

What plays when no session plan is given (`world/`, `content/adventure.tres`). Built from the team's notes: guide → place → task menu → level; colour as the reward.

- **Colour:** the room starts black and white (`Adventure.colours`: black and white → a little colour → normal). A task done the first time moves it one step (`Task.colour`).
- **Guide:** a yellow orb with an arrow at the edge of view, on the side of the place. Facing the place (head left-right within 25°, held 0.5 s) enters it. Only turning counts for now, so it can be tested in a chair. Every place is the table for now.
- **Menu (`TaskMenu`):** unfolds 40 cm ahead, 12 cm below the eyes, tilted back 30°, clear of resting hands. One row per task, one 6 cm button per level. Touch or point and pinch. Open: blue with a number; done: gold medal; locked: grey, sunk, a dash, and the guide says so. After a task the same menu comes back without turning again.
- **Unlocks:** a task opens when every task in `Task.requires` is done at some level; level n+1 when level n is done. A chosen level pins the difficulty (`Task.levels`); the staircase does not move.
- **Rewards:** magic stones per new level (`Task.stones`), shown on the menu; for furniture later.
- **Saved** as `world` in `save.json`: levels done per task, colour, stones.
- **Tests:** `tests/world_test.gd`; `tests/sim/test_world.py` (a seated child turns, picks, plays; every button within reach of the three bodies).

**Not yet:** other places, buying with stones, save slots on the facilitator panel, checked on a headset.
