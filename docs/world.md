# The world

The task menus inside Find the object (`content/adventure.tres`) and Global motion (`content/motion_adventure.tres`). The child is a young alchemist. All story text lives in `content/`.

- Find the object has six shelf levels ([tidy up](tidy.md)). Global motion has two spell-wall levels.
- **View:** normal colour from the start, unchanged by progress.
- **Guide:** a yellow orb with an arrow at the edge of view, on the side of the place. It shows the way to the first place, and later to any place with a level the child has not yet seen open on a menu (once; no nagging). Facing a place (head left-right within 25°, held 0.5 s) enters it: turning the chair is enough, so it can be tested seated.
- The menu unfolds 58 cm ahead and 12 cm below the eyes. Aim and pinch any card. The next card glows, and finished cards show a medal. The card and voice give the reward for the next successful play.
- In Godot, open a resource in `content/tasks/` and expand **Levels**. Edit each level's **Title**, **Project**, **First Reward** and **Repeat Reward**. Use the same Project value for levels in the same sequence. The menu numbers each project from L1. Keep an existing level's **Id** when renaming or reordering it.
- Saves track completion by level ID. Onion's first visit uses the same completion and reward as Shadow Match.
- **Tests:** `tests/scene_test.gd`, `tests/world_test.gd`, `tests/sim/test_world.py`: switch scenes, play both activities, retain progress, and reach every level button with three body sizes.

**Not yet:** furniture, checked on a headset.
