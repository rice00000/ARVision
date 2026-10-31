# The world

What plays when no session plan is given (`world/`, `content/adventure.tres`). From the team's notes: guide → place → its task list → level. The child is a young alchemist tidying the workshop. All story text lives in `content/`.

- **Places, each with its own list:** the alchemy table (`Tidy the shelf`, levels 1-5) and behind the child (`Break the spell wall`, levels 1-2). `Place.where`: `table` (the work surface) or `behind` (1.5 m the other way from the eyes).
- **Tidy the shelf** ([tidy up](tidy.md)), two rounds a level, by sticker: 1 three shadows; 2 six shadows with look-alikes (egg and ball, drum and block); 3 five outlines; 4 four sizes of one shape; 5 five colours of one shape.
- **View:** normal colour from the start, unchanged by progress.
- **Guide:** a yellow orb with an arrow at the edge of view, on the side of the place. It shows the way to the first place, and later to any place with a level the child has not yet seen open on a menu (once; no nagging). Facing a place (head left-right within 25°, held 0.5 s) enters it: turning the chair is enough, so it can be tested seated.
- **Menu (`TaskMenu`):** unfolds 40 cm ahead, 12 cm below the eyes, tilted back 30°, light rim; clear of resting hands. Per task its title, under it one 6 cm button per level, 3 cm apart. Touch or point and pinch. Next level to play: bigger, yellow, breathing in a glow; done: blue with a gold dot; locked: grey, sunk, a dash, and the guide says so. A fingertip within 7 cm lifts a button and the guide reads it out ("Level 2. Still locked."). After a task the same menu comes back. Turning to another place folds it and opens that one.
- **Unlocks:** `Task.requires` (the wall needs the toys done once); level 2 after level 1. Each level is its own plan (`Task.levels`): its blocks fix the difficulty and pin axes; the staircase does not move.
- **Saved** as `world` in `save.json`: levels done and levels seen. Switching save (facilitator panel) rebuilds the World and Session from scratch (`Main.restart`).
- **Tests:** `tests/world_test.gd`; `tests/sim/test_world.py` (a seated child turns the chair to the table, plays, follows the guide round to the wall, plays; every button within reach of three bodies at both places). `Actor.swivel()` turns the chair.

**Not yet:** furniture, checked on a headset.
