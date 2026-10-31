# The world

The task menus inside Find the object (`content/adventure.tres`) and Global motion (`content/motion_adventure.tres`). The child is a young alchemist. All story text lives in `content/`.

- **One place per scene:** Find the object has the alchemy table (`Tidy the shelf`, levels 1-5); Global motion has `Break the spell wall`, levels 1-2. Both menus appear toward the table. Switch scenes from the facilitator's Scenes tab; turning around no longer enters motion.
- **Tidy the shelf** ([tidy up](tidy.md)), two rounds a level, by sticker: 1 three shadows; 2 six shadows with look-alikes (egg and ball, drum and block); 3 five outlines; 4 four sizes of one shape; 5 five colours of one shape.
- **View:** normal colour from the start, unchanged by progress.
- **Guide:** a yellow orb with an arrow at the edge of view, on the side of the place. It shows the way to the first place, and later to any place with a level the child has not yet seen open on a menu (once; no nagging). Facing a place (head left-right within 25°, held 0.5 s) enters it: turning the chair is enough, so it can be tested seated.
- **Menu (`TaskMenu`):** unfolds 40 cm ahead, 12 cm below the eyes, tilted back 30°, light rim; clear of resting hands. Per task its title, under it one 6 cm button per level, 3 cm apart. Touch or point and pinch. Next level to play: bigger, yellow, breathing in a glow; done: blue with a gold dot; locked: grey, sunk, a dash, and the guide says so. A fingertip within 7 cm lifts a button and the guide reads it out ("Level 2. Still locked."). After a task the same menu comes back. Turning to another place folds it and opens that one.
- **Unlocks:** each scene's first level is open; later levels follow the previous one. Each level is its own plan (`Task.levels`): its blocks fix the difficulty and pin axes; the staircase does not move.
- **Saved** as `world` in `save.json`: levels done and levels seen. Switching save (facilitator panel) rebuilds the World and Session from scratch (`Main.restart`).
- **Tests:** `tests/scene_test.gd`, `tests/world_test.gd`, `tests/sim/test_world.py`: switch scenes, play both activities, retain progress, and reach every level button with three body sizes.

**Not yet:** furniture, checked on a headset.
