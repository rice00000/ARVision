# Tidy up

`trials/tidy/`, the alchemy table's game. Things fell off the shelf; each cubby shows what belongs there on a black-and-white sticker. Put everything back. It replaced "find the toy I name" in the adventure; `trials/find` stays for session plans.

- **Play:** reach and pinch a thing, carry it to its sticker, then release. It keeps its contact point and turns with the hand. Right: it clicks in; wrong: it goes back with shape/size/colour feedback. Release elsewhere, tracking loss or pause returns it unscored. Brief pinch dropouts (0.12 s) are ignored. All things back ends the round.
- **Stickers** (axes `match`, `outline`): black shadow, black outline, shadows of one shape in sizes a quarter apart, or one shape in colours. `things` (3-6) is driven; six shapes bring the look-alikes.
- **Odd Color L1–L3:** pinch the different-coloured block among three. A blank cubby gets an outline after the right choice. Colour gaps shrink each level. Picks and placement are logged separately.
- **Clutter** (axis `clutter`, level 6): that many junk bits (sticks, coins, scraps; fit no sticker, cannot be picked) lie among the things, which are scattered at random instead of in a neat row. Trains picking a thing out of a messy scene.
- **Placement:** the 3 × 2 shelf faces the work surface and uses its near edge, with a seated reach limit. A virtual bench works without a table. Cards tilt toward the eyes.
- **Help:** 1 the thing hops and its sticker wiggles; 2 its cubby shines and the guide says so. Help then stays on for the next things.
- **Measured:** each put is a pick (`target` = sticker, `picked` = thing) and a `put` line in the log; `first_try` = all back with no wrong put and no help.
- **Hands:** actual fingertip and pinch joints; no virtual hand models; pointing beams appear only for UI. In passthrough the headset's own hand mesh, posed by the joints, clears whatever virtual thing is behind the hand (`rig/hand_reveal.gdshader`), so the real hand stays in front of the shelf; things in front of it still cover it. Menus are drawn over everything (no depth test); a second reveal pass after them clears them where the hand is.
- **Not yet:** checked on a headset (hand reveal, pinch tolerance, reach).
