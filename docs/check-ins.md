# Check-ins and progress

The design brief measures success by "no-help check-ins on new objects, not game scores". A check-in is a few rounds with no help, at fixed difficulties, on things the child never trains on. The same rounds each time, so a rising score means the child sees better, not that they learned the game.

## When

`modules/check_ins/check_ins.gd` (`CheckIns`) makes a plan due on the following schedule:

- the first visit to the place: the **baseline**;
- then once **7 days** (`every_days`) have passed since the last finished one;
- a check-in that was skipped or left unfinished is not asked again for 12 hours;
- staff can make one due through **Menu → Staff tools → Progress → Check-in next time**.

In the Workshop Hub, **Quick check-in** appears above the game buttons once the child has played at the relevant place. Shelf and Odd Color use the table plan. Dots and Butterflies use the motion plan. The button shows the subject and the number of rounds. Choosing a game opens that game. Choosing the check-in shows instructions and progress for the full plan. **Back to games** returns to the same menu at any time.

In the World place menus, a due check-in runs before the menu opens. Probe rounds leave the training level and stone balance unchanged.

## What

Each `Place` names its plan (`check_in`), in `content/check_ins/`:

| Place | Rounds | Skill |
|---|---|---|
| Alchemy table (`table.tres`) | shelf with **new shapes** (pyramid, prism, capsule, disc, bar; tidy axis `novel`) at 3, 4 and 5 things; odd colour, 2 rounds each at two colour gaps | `visual_matching`, `colour_discrimination` |
| Spell wall (`motion.tres`) | moving dots, 2 rounds each at coherence levels 0.2, 0.5, 0.8 | `global_motion` |

Change a plan only between studies: results are comparable only while the rounds stay the same.

## Results

Saved with the child (`check_ins` in `save.json`): place, time, finished or not, and per skill the rounds, the rounds right first time, and the same by difficulty; plus the vision profile it ran under. Each one is also a `check_in` event in the log.

- **In the headset:** Staff tools → **Progress**: each skill's training level and its first and latest check-in score.
- **The report:** `python3 tools/progress.py local` (this computer) or `pull` (the Quest, over adb) → `build/progress/index.html`, a page per child with check-in scores over time, training levels by day, practice (rounds, right first time, help, time), and vision settings; plus `build/progress/progress.csv` for a spreadsheet. `--root <folder>` reads a copy of another headset's user data; `--tests` includes test saves.

**Limits:** each check-in is short (3 to 6 rounds a skill), so one score moves in big steps; read the trend over several. Butterflies, Find it, desk, bookshelf and sandwich have no check-in yet.

Tests: `tests/check_ins_test.gd`, `tests/sim/test_progress.py`.
