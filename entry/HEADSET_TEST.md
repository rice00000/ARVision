# Scene one: headset test sheet

For Megan, in the Quest 3, seated at a real table, the way a child would sit. One section per beat. Each has:
what you should **see** and **hear** (the lines are the story's own words, as the build speaks them now), what to
**judge or measure**, and a box to tick. Mark anything odd in "Notes"; a phone photo of the room helps.

**Build:** branch `megan-native-quest-AR` as merged on Oct 31 (round 3), with `entry-layout-3` on top if it is merged.
**Not built yet** is marked ⚠ so you don't test what isn't there.

Before you start:

- [ ] Sit as a child would: back against the chair, not leaning in. Hands in the lap.
- [ ] Table: about how deep is the table in front of you? ______ cm. How far is its near edge from your eyes? ______ cm
      (a rough guess is fine: one hand-span is about 18 cm).
- [ ] Your eyes above the table top: ______ cm (the layout is happiest at 40 to 55 cm).
- [ ] The room: bright / dim (circle one). Light behind you, in front, beside?
- [ ] Volume on the headset: ______ of 15 (keep it the same for the whole test).

A beat can be replayed on its own from the **DEV jump buttons**: turn your head well to the LEFT (they stand about
60 degrees out, above the table): Hello, Tap, Gear, Pick up / Set in, Reveal, Shelf, Dots, and "Pop sound: A/C" under
them. **Restart / Exit app / Zones** are well to the RIGHT. "Zones" draws the layout on the table: blue = things,
yellow = where hands work, violet = moved aside after the reveal, **red = an overlap** (tell us if you ever see red).

---

## 1. Setup (for the grown-up)

`SKIP_SETUP` is on by default: the app goes straight to **"All set"** with a green **Start**. To test the four setup
steps, set `SKIP_SETUP := false` in `entry/entry.gd` first.

**See:** a dark panel just above eye level, straight ahead: a sage bar "SETUP · for the grown-up", "Step N of 4" and
dots, a title, one or two lines, check lines with dots, buttons. At the foot: "To press: touch a button with a
fingertip, or point at it and pinch."
Steps: 1 "Check the hands", 2 "Find the table" (an outline on the table; "Yes, that's the table" / "No, point at it"),
3 "Find the reach" (slide a hand out along the table, then "Done", or "Use usual spot"), 4 "Sound and room" (a soft
chime; "Yes, I heard it" / "Play again"), then "All set" + Start.
**Hear:** quiet; the chime in step 4.

Judge:
- [ ] Without reading the words, could you tell which step you are on and what to do now? (The waiting line stays
      bright with a breathing dot; done lines dim and get a tick.)
- [ ] The panel is easy to read without leaning: text sharp, not too high. Too high / right / too low (circle).
- [ ] Every button pressed at the first try, by poke AND by point-and-pinch.
- [ ] Step 2: the outline sits on your real table (within a few cm). Off by about ______ cm.
- [ ] Step 2 check line says "Room for everything" (or what did it say? ________________).
- [ ] Step 3: the reach it shows: ______ cm. Does that match an easy (not stretched) reach? yes / no
- [ ] The DEV buttons (far left and right) never get in the way of the panel or the table.

Notes:

---

## 2. Hello (press Start, or DEV "Hello")

**See:** the cream-and-sage cauldron on the table, left of the middle. After about 2 seconds it shakes a little; then
Onion (a small blue wisp) pops up out of it, overshoots a little and settles, glowing. Onion glances into the cauldron,
the cauldron jolts once (a knock), Onion turns back to you, then to the cauldron and back. A **"?"** appears above Onion
for about two seconds (cream with a dark outline), no flashing.
**Hear:** quiet piano; a soft rattle from the cauldron, the pop (A or C, see the DEV button), then:
"Oh! Hello there." / "I was getting things ready." / *(knock)* / "Uh... nearly ready." / "I'm Onion, by the way." /
"Could you help me with something?" Subtitles show the same words.
⚠ The knock borrows the seat click, played lower: a placeholder sound.

Judge:
- [ ] The cauldron stands ON the table (not floating, not sunk in). Gap: ______ mm.
- [ ] Cauldron size feels right next to real things (it is 22 cm wide). Too big / right / too small.
- [ ] You can see the cauldron's opening from your seat without leaning (you see the green brew).
- [ ] The **"?"** is easy to read against your room. Size: too small / right / too big. It stays clear of Onion.
- [ ] Onion's voice is clearly on top of the piano and the rattle.
- [ ] The rattle is noticeable (not lost under the piano), but not loud.
- [ ] Pop A vs Pop C (press "Pop sound" to switch, then "Hello" again): prefer A / C, and why: ____________
- [ ] Subtitles: easy to read, not covering the cauldron or Onion.

Notes:

---

## 3. Tap (DEV "Tap")

**See:** the cauldron glows slowly. A see-through teaching hand (pale, about the size of a child's hand) taps the front
of the cauldron's rim, over and over. A real tap with your fingertip on the cauldron stops the glow and the hand.
Onion leans in and looks inside.
**Hear:** "Give the cauldron a little tap." / after your tap: "Thank you. Something's caught in there." / "That should
loosen it."
⚠ The teaching hand is still the stand-in made from simple shapes; the asset chat's hand (right_hand_demo.glb) is not
in yet.

Judge:
- [ ] The cauldron's front is reachable seated, without leaning forward. Reach to it: ______ cm.
- [ ] Your tap counted the first time.
- [ ] The teaching hand does not hide the cauldron's opening (it should cover at most about a third of the rim, and
      only for a moment).
- [ ] The hand reads as "a hand showing me", not as your own hand.

Notes:

---

## 4. Gear (DEV "Gear")

**See:** Onion moves aside (beside the cauldron, away from the panel). The cauldron rattles harder; a small brass
planetary gear pops up out of it, small at first, clears the rim, hops in a low arc and grows as it lands on the table
**beside the cauldron, on the panel's side**. Onion hops back with a **"!"**. A shallow sage panel with a dark round
socket and a little window lies on the table (it was there from the start).
**Hear:** a rattle, then "There it is! The table's missing piece." / Onion looks at the socket: "I've been looking for that."

Judge:
- [ ] The gear lands where you can reach it **without standing or leaning**. Distance to it: ______ cm.
- [ ] Its hop does not pass over the panel. (On a very shallow table it may; the log then says "it hops over the panel".)
- [ ] The panel lies flat ON the table; the socket is easy to see. Socket distance: ______ cm.
- [ ] Nothing overlaps: cauldron, gear, panel, Onion each have space (press "Zones": no red).
- [ ] The "!" is readable and brief.

Notes:

---

## 5. Pick up (DEV "Pick up")

**See:** the gear lying beside the cauldron. Onion asks; the teaching hand pinches the gear and lifts it a little,
looping (the real gear does not move). Pinch the real gear with thumb and finger: it follows your hand, stopped.
If you wait about 14 seconds without touching it, the teaching hand comes back to show the pinch again.
**Hear:** "Would you pick it up for me?" / "Pinch your fingers together, and keep them closed." / once you hold it:
"There you go." / "Quite a little thing, isn't it?" then a quiet moment.

Judge:
- [ ] You picked it up at the first or second try. Tries: ______
- [ ] Reaching it was comfortable seated (no stretch).
- [ ] The teaching hand does not hide the gear: you still see most of it.
- [ ] Holding it and turning it in your hand feels natural; it does not jump.
- [ ] The quiet moment after "Quite a little thing" is long enough / too long / too short.

Notes:

---

## 6. Set in (DEV "Set in")

**See:** Onion looks at the socket. The teaching hand lowers over the socket and opens its fingers, looping. Bring the
gear over the socket and let go: it aligns itself, clicks, and the gears and the panel's little cog start turning.
Onion rises and turns to the room. Let go anywhere else: the gear floats down onto the table within reach, no fuss.
**Hear:** "Set it in here, then open your fingers." / a click, once / "Ah. There we go."
⚠ No lead-in line before the instruction (not approved yet).
Note: when you jump straight to "Set in" without holding the gear, after about 14 s the hand goes back to showing the
pinch on the gear; that is the reminder, not a bug.

Judge:
- [ ] The socket is reachable seated. Distance: ______ cm. Its far edge is still on the table.
- [ ] It seated at the first try. Tries: ______. Did it ever seat when you did not mean it to? yes / no
- [ ] The click is a gentle click (not a crack); heard once.
- [ ] The turning gears are visible from your seat.

Notes:

---

## 7. Reveal (DEV "Reveal")

**See:** the cauldron and the panel (still turning) glide aside, about a second, to make room. A soft ring of light
spreads from the socket across the table and the room; faint glints on real surfaces; a wooden bench and a shelf with
six cubbies grow in, in front of you a little to the right, and a soft doorway of light further off. Onion looks around,
then at things scattered by the shelf, leans in and hops.
**Hear:** a soft magical pad (fades after about 3 s); "I've been looking forward to showing you this." / a pause /
"Oh!" / "Things come through, but they don't always land in the right place." / "Would you help me put them where they belong?"
⚠ The workshop is placeholders (the shelf is Wei's; the doorway of light is a stand-in). No reveal music yet.

Judge:
- [ ] The glide aside reads as "making room", not as a glitch. Keep it / prefer they stay (they then overlap the shelf).
- [ ] After the reveal: the shelf's nearest edge is within reach: ______ cm. Its top cubbies are within reach: yes / no.
- [ ] The bench's top is AT your table's height, not floating above it. Floating by about ______ cm.
      (Wei's bench keeps 28-42 cm below the eyes: if you sit high, it floats; that is a known issue for Wei.)
- [ ] The whole shelf is in view without turning your head more than a little.
- [ ] Cauldron and panel after the move: still visible, not hidden behind the shelf.
- [ ] The ripple is soft (no flash).

Notes:

---

## 8. First visit (DEV "Shelf", or after the reveal)

**See:** the scene switches (the cauldron, panel and Onion stay). Wei's things lie on the bench in front of the shelf;
cards in the cubbies show their shapes. Onion waits beside the shelf's end, up high. Put a thing into the cubby with its
shape: it clicks in; a wrong one goes back. At the end Onion looks across the shelf, speaks, and does a little cheer;
then quiet.
**Hear:** "The shapes on the shelf show where things go." / "Can you find a place for one of these?" / at the first
right one only: "It fits. Let's find places for the others." / at the end: "There. Everything's found its place." /
"Thank you for helping."

Judge:
- [ ] Every thing on the bench is reachable seated. The farthest: ______ cm.
- [ ] Every cubby is reachable seated (the top row too).
- [ ] **Subtitles:** while you look at the things, does the line cover the shelf? none / top row / more. While you look
      at Onion? (A proposal is in DEV_NOTES: Wei's `Voice.above_gaze` 25 -> 36 and `above_horizon` 20 -> 12.)
- [ ] Onion never sits in front of a cubby or over a thing.
- [ ] Nothing from the opening (cauldron, panel) is in the way of the things or your hands.

Notes:

---

## At the end

- [ ] Total time seated: ______ min. Any neck strain from looking down? yes / no
- [ ] Anything you had to stand or lean for: ________________
- [ ] One thing to change first: ________________
