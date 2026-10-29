# The world

What plays when no session plan is given (`world/`, `content/adventure.tres`). From the team's notes: guide → place → its task list → level; colour as the reward. Story: the child is a young alchemist; a grey spell took the colours; the toys are treasures. All story text lives in `content/`.

- **Places, each with its own list:** the alchemy table (`Treasure hunt` = find the toys, levels 1-5) and behind the child (`Break the spell wall`, levels 1-2). `Place.where`: `table` (the work surface) or `behind` (1.5 m the other way from the eyes).
- **Find the toys levels:** 1 three toys; 2 six; 3 seven, one colour, close together (shape only); 4 five, one shape, the named one's hue 8% of the colour wheel away ("find the ball with a different colour"); 5 six, 4% away. Toys lie only where the child reaches without stretching: within 0.4 × eye height of a shoulder, within 60° of facing the table's near edge; else on a patch in front.
- **Treasure cabinet (`Cabinet`):** a shelf per task, a slot per level, 45° left of the place the child is at, 0.8 m away, 10 cm below the eyes, still. A level done the first time puts its treasure in its slot (what was found in its last solved round; a gem for the wall) and says `Adventure.new_treasure`; with the Magic module it flies there first. Empty slots show a dim dot. Saved as `treasures`; meant later as keys for new games.
- **Colour:** the room starts black and white (`Adventure.colours`: black and white → a little colour → normal). A task done the first time moves it one step.
- **Guide:** a yellow orb with an arrow at the edge of view, on the side of the place. It shows the way to the first place, and later to any place with a level the child has not yet seen open on a menu (once; no nagging). Facing a place (head left-right within 25°, held 0.5 s) enters it: turning the chair is enough, so it can be tested seated.
- **Menu (`TaskMenu`):** unfolds 40 cm ahead, 12 cm below the eyes, tilted back 30°, light rim; clear of resting hands. Per task its title, under it one 6 cm button per level, 3 cm apart. Touch or point and pinch. Open: blue with a number; done: gold dot; locked: grey, sunk, a dash, and the guide says so. After a task the same menu comes back. Turning to another place folds it and opens that one.
- **Unlocks:** `Task.requires` (the wall needs the toys done once); level 2 after level 1. Each level is its own plan (`Task.levels`): its blocks fix the difficulty and pin axes; the staircase does not move.
- **Saved** as `world` in `save.json`: levels done, levels seen, colour. Switching save (facilitator panel) rebuilds the World and Session from scratch (`Main.restart`).
- **Tests:** `tests/world_test.gd`; `tests/sim/test_world.py` (a seated child turns the chair to the table, plays, follows the guide round to the wall, plays; every button within reach of three bodies at both places). `Actor.swivel()` turns the chair.

**Not yet:** furniture, checked on a headset.
