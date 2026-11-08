# Home and rewards

- Point at the house and pinch on the right. Furniture, rooms and games open directly; no facilitator menu.
- Browse one rotating model at a time. Hear its name/price; count the stones. Buying needs a separate check-mark press. Sunny room is free; two more rooms cost 4/6 stones.
- My things → Place. Pinch furniture, move/twist, release. A check/cross shows a valid/blocked spot. While holding, aim at the box with the other hand and pinch to store it. Each room remembers its layout.
- Home pauses training and preserves its real-world view and pending speech. Closing resumes that activity. Purchased rooms are leisure spaces, not replacements for measured AR surfaces.
- Every fully successful level/replay earns 2 stones. Skip, timeout, abandonment, missing modules and probes earn none. `Task.reward_stones` sets adventure rewards.

Modules: `Inventory` owns transactions; `Rooms` owns the selected room; `Decor` owns layouts; `Home` owns UI. Contracts live in `Events`; room rendering belongs to Reality. Each module can be removed. Item `.tres` files define models/prices. Logs include purchases, declined purchases, rewards, room changes and furniture moves.

Sources: furniture visuals/inventory/layout adapted from local XRVision. Room meshes: [Kenney Furniture Kit](https://kenney.nl/assets/furniture-kit), CC0, original license in `content/rooms/kenney/License.txt`; downloaded from [Kenney's OpenGameArt release](https://opengameart.org/content/furniture-kit). Three room layouts assembled here. Wall animation adapts the delay/gravity/rotation approach of [miwls' simple glass broken](https://godotshaders.com/shader/simple-glass-broken/), CC0, to a single mesh of actual 3D Voronoi pieces; the pieces' jagged outline is the hole. Sweep wind adapts [dip's Dynamic Wind Trail With Loops](https://godotshaders.com/shader/dynamic-wind-trail-with-loops/), CC0. Shatter (split into left/right mono, played from the hole's edges) and dot shimmer: the team's own sounds in `trials/motion/sounds/`. Onion touch uses [Godot's elastic Tween](https://docs.godotengine.org/en/stable/classes/class_tween.html) (engine MIT); its sound is synthesized locally. No downloaded character animation or rig retargeting.

Checks: `python tools/test.py`; render `res://tools/home_capture.tscn` with `--xr-mode off -- --profile=test_home_capture` → `build/home_review/`. Headset reach, stereo appearance, frame time and child comprehension still need a worn-headset check.
