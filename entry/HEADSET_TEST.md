# Scene one: headset test sheet

For Megan, in the Quest 3, seated at a real table, the way a child would sit. One section per beat. Each has:
what you should **see** and **hear** (the lines are the story's own words, as the build speaks them now), what to
**judge or measure**, and a box to tick. Mark anything odd in "Notes"; a phone photo of the room helps.

**Build:** branch `megan-native-quest-AR` as merged on Oct 31 (round 5), with `entry-layout-5` on top if it is merged.
**Not built yet** is marked ⚠ so you don't test what isn't there.

What changed in round 5: the PANEL and the GEAR do not move at the reveal where the table allows it (long reach: the
shelf then stands up to 30 degrees to the side and the cauldron on a far side; the Output line says `[panel stays put]` or
`[panel glides at the reveal...]`); the cauldron may sink as the ripple STARTS; the first round's THINGS arrive with the
shelf (they grow in and settle onto the bench as the ring passes), and the shelf level starts with the same things, already
in place; Onion now stands BESIDE the socket for the set-in; the "Zones" button draws 3D wireframes.

What changed since the first sheet (round 3): Onion now moves for each beat (beside the mouth for the tap, aside for the
gear, lifted for the reveal); the teaching hand is the real hand (translucent, scale 0.6); the story's lines and staging
were revised (Hello has a search, a knock and a startled hop; "Nearly ready." without "Uh..."); the gear glows softly while
the pinch is shown; the pop sound is A only (no audition button); the cauldron is HIDDEN during the first shelf level; on a
desktop the simulated room's loose props are hidden; Onion floats only a few millimetres and no longer turns by itself;
setup is skipped by default.

Before you start:

- [ ] Sit as a child would: back against the chair, not leaning in. Hands in the lap.
- [ ] Table: about how deep is the table in front of you? ______ cm. How far is its near edge from your eyes? ______ cm
      (a rough guess is fine: one hand-span is about 18 cm).
- [ ] Your eyes above the table top: ______ cm (the layout is happiest at 40 to 55 cm).
- [ ] The room: bright / dim (circle one). Light behind you, in front, beside?
- [ ] Volume on the headset: ______ of 15 (keep it the same for the whole test).

A beat can be replayed on its own from the **DEV jump buttons**: turn your head well to the LEFT (they stand about
60 degrees out, above the table): Hello, Tap, Gear, Pick up / Set in, Reveal, Shelf, Dots, and "Pop sound: A/C" under
them (the pop A/C button is gone: pop A is final). **Restart / Exit app / Zones** are well to the RIGHT (70 degrees out). "Zones" draws the layout on the table: blue = things,
yellow = where hands work, violet = moved aside after the reveal, **red = an overlap** (tell us if you ever see red).

---

## 1. Setup (for the grown-up)

`SKIP_SETUP` is on by default: the app goes straight to **"All set"** with a green **Start** (the panel only says "All set";
there are no checks). To test the four setup steps, set `SKIP_SETUP := false` in `entry/entry.gd` first.
Without the setup steps the layout uses the usual reach (60 cm); on your real table it still uses the table the headset found.

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
Onion (a small blue wisp) pops up out of it, overshoots a little and settles, glowing. Onion leans over the opening and
searches a little while it talks; the cauldron jolts once (the knock); Onion gives a small startled hop, peeks at an angle,
glances back at you, straightens up and faces you; then turns to the cauldron and back. A **"?"** appears above Onion for
about two and a half seconds (cream with a dark outline, 6 degrees tall), no flashing. Onion floats only a few millimetres
and does not turn by itself.
**Hear:** quiet piano; a soft rattle from the cauldron, the pop (A), then:
"Oh! Hello there." / "I was getting things ready." / *(knock)* / "Nearly ready." / "I'm Onion, by the way." /
"Could you help me with something?" Subtitles show the same words.
⚠ The knock borrows the seat click, played lower: a placeholder sound.

Judge:
- [ ] The cauldron stands ON the table (not floating, not sunk in). Gap: ______ mm.
- [ ] Cauldron size feels right next to real things (it is 22 cm wide). Too big / right / too small.
- [ ] You can see the cauldron's opening from your seat without leaning (you see the green brew).
- [ ] The **"?"** is easy to read against your room. Size: too small / right / too big. It stays clear of Onion.
- [ ] Onion's voice is clearly on top of the piano and the rattle.
- [ ] The rattle is noticeable (not lost under the piano), but not loud.
- [ ] Pop A (final): loud enough to notice, not startling; finished before "Oh! Hello there."? yes / no
- [ ] The searching lean over the opening reads as searching, not as sinking into the cauldron.
- [ ] Subtitles: easy to read, not covering the cauldron or Onion.

Notes:

---

## 3. Tap (DEV "Tap")

**See:** the cauldron glows slowly. Onion moves to the left of the opening (7 cm out, a little toward you), turns to the
rim and leans a little toward it. The see-through teaching hand (the real hand, about 14 cm long) taps the front of the
cauldron's rim twice (6 s), rests (4 s), and shows it again; if you do nothing for 10 s Onion straightens toward you once,
slowly, then stays still. The hand comes in from the RIGHT, its fingers pointing left. A real tap with your fingertip on the
cauldron stops the glow and the hand. Onion dips slightly (listening), turns to you for "Thank you.", then back to the
opening and leans in.
**Hear:** "Give the cauldron a little tap." / after your tap: nothing is said; Onion dips and peers in for a second

Judge:
- [ ] The cauldron's front is reachable seated, without leaning forward. Reach to it: ______ cm.
- [ ] Your tap counted the first time.
- [ ] The teaching hand does not hide the cauldron's opening (it should cover at most about a third of the rim, and
      only for a moment).
- [ ] The hand reads as "a hand showing me", not as your own hand. Size: too big / right / too small (it is `HAND_SCALE`
      0.6 in `entry/demo_hand.gd`; 0.5 to 0.55 was suggested for a 0.4-0.6 m view).
- [ ] Onion and the hand never touch (Onion is on the LEFT of the opening, the hand on the right). Gap at the closest:
      about 1 cm is intended; any overlap: ______

Notes:

---

## 4. Gear (DEV "Gear")

**See:** Onion moves aside (beside the cauldron, away from the panel) and watches the mouth, leaning back slightly as the
rattle builds. The cauldron rattles harder; a small brass planetary gear pops up out of it, small at first, clears the rim,
hops in a low arc and grows as it lands on the table **between the cauldron and the panel**. Onion gives a small
backward hop with a **"!"** and follows the gear's flight with its look. A shallow sage panel with a dark round
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

**See:** the gear lying on the table. Onion looks at it with a small curious lean. A **soft yellow glow covers the gear**
while the hand shows the pinch (it goes the moment you grab it). The teaching hand (the real hand, from the right) pinches
the gear and lifts it a little, looping (the real gear does not move). Pinch the real gear with thumb and finger: it follows your hand, stopped.
If you wait about 14 seconds without touching it, the teaching hand comes back to show the pinch again.
**Hear:** "Would you pick it up for me?" / "Pinch your fingers together, and keep them closed." / once you hold it:
"There you go." / "Quite a little thing, isn't it?" then a quiet moment. Onion makes a small pleased lift and follows the
held gear with its look.

Judge:
- [ ] You picked it up at the first or second try. Tries: ______
- [ ] Reaching it was comfortable seated (no stretch).
- [ ] The teaching hand does not hide the gear: you still see most of it.
- [ ] The glow is soft (not a flash) and clearly says "this one": ______. It disappears when you grab.
- [ ] Holding it and turning it in your hand feels natural; it does not jump.
- [ ] The quiet moment after "Quite a little thing" is long enough / too long / too short.

Notes:

---

## 6. Set in (DEV "Set in")

**See:** Onion moves beside the socket (about 20-25 cm from it, just over the panel's edge, never in the hand's way),
leans a little and looks down at it. The teaching hand lowers over the socket and opens its fingers, looping (it fades
out and in between rounds); its body lies to your right, Onion is on the left or behind. Bring the
gear over the socket and let go: it aligns itself, clicks, and the gears and the panel's little cog start turning.
Onion rises slightly (about 2 cm and then up to the lifted spot), looks at the mechanism, and turns to the room. Let go anywhere else: the gear floats down onto the table within reach, no fuss.
**Hear:** "Set it in here, then open your fingers." / a click, once (no line after it: "Ah. There we go." was cut)
⚠ No lead-in line before the instruction (not approved yet).
Note: when you jump straight to "Set in" without holding the gear, after about 14 s the hand goes back to showing the
pinch on the gear; that is the reminder, not a bug.

Judge:
- [ ] The socket is reachable seated. Distance: ______ cm. Its far edge is still on the table.
- [ ] It seated at the first try. Tries: ______. Did it ever seat when you did not mean it to? yes / no
- [ ] The click is a gentle click (not a crack); heard once.
- [ ] The turning gears are visible from your seat.
- [ ] Onion is clear of the socket, the panel's edge and the teaching hand while you set the gear in, and still reads as
      "beside the socket": yes / too far / in the way.

Notes:

---

## 7. Reveal (DEV "Reveal")

**See:** if the Output line said `[panel stays put]`, NOTHING moves (panel, gear, turning cog stay where they are); if it
said `[panel glides at the reveal...]` the cauldron and the panel (still turning) glide aside, about a second, and Onion
(lifted) glides along. If the cauldron would stand in the shelf's way it sinks as the ripple STARTS; otherwise right after
it. Onion straightens and turns to look at the shelf as it grows in. A soft ring of light
spreads from the socket across the table and the room; faint glints on real surfaces; a wooden bench and a shelf with
six cubbies grow in, in front of you a little to the right (up to 30 degrees on a long reach), **together with Wei's first
round of things**, which grow in and settle the last few cm onto the bench as the ring reaches each one, and a soft doorway
of light further off. Onion looks around,
then at things scattered by the shelf, leans in and hops.
**Hear:** a soft magical pad (fades after about 3 s); "I've been looking forward to showing you this." (Onion turns back
to you and holds a welcoming pose) / a pause of about 3 s / Onion looks down at the things and leans in /
"Oh!" / "Things come through, but they don't always land in the right place." / "Would you help me put them where they belong?"
⚠ The workshop is placeholders (the shelf is Wei's; the doorway of light is a stand-in). No reveal music yet.

Judge:
- [ ] The glide aside (if it happens) reads as "making room", not as a glitch. If the panel stayed put: nothing looked
      odd about the shelf standing off to the side (you turned your head to it: ______ degrees).
- [ ] The cauldron and the shelf never visibly overlap while the ripple passes.
- [ ] The things arrive WITH the shelf, softly (no pop, no drop with a bounce).
- [ ] After the reveal: the shelf's nearest edge is within reach: ______ cm. Its top cubbies are within reach: yes / no.
- [ ] The bench's top is AT your table's height, not floating above it. Floating by about ______ cm.
      (Wei's bench keeps 28-42 cm below the eyes: if you sit high, it floats; that is a known issue for Wei.)
- [ ] The whole shelf is in view without turning your head more than a little.
- [ ] Cauldron and panel after the move: still visible, not hidden behind the shelf.
- [ ] The ripple is soft (no flash). It is still three flat rings (the "travels along the room's things" version is only a
      proposal in DEV_NOTES): does it look as if it passes THROUGH the cauldron and over the table's edge? yes / no
- [ ] Onion is in view and clear of the shelf, the things and the cauldron after the glide.

Notes:

---

## 8. First visit (DEV "Shelf", or after the reveal)

**See:** the scene switches (Onion and the panel stay; **the cauldron is hidden**, so the bench has the middle of the table).
The things you saw arrive with the shelf are still exactly where they were (nothing is replaced or drops in again);
cards in the cubbies show their shapes. Onion waits beside the shelf's end, up high. Put a thing into the cubby with its
shape: it clicks in; a wrong one goes back. At the end Onion looks across the shelf, speaks, and does a little cheer;
then quiet.
**Hear:** "The shapes on the shelf show where things go." / "Can you find a place for one of these?" / at the first
right one only: "It fits. Let's find places for the others." / at the end: "There. Everything's found its place." /
"Thank you for helping."

Judge:
- [ ] The things on the bench are the SAME ones (same shapes, colours, places) as at the reveal; no flicker at the switch.
- [ ] Every thing on the bench is reachable seated. The farthest: ______ cm.
- [ ] Every cubby is reachable seated (the top row too).
- [ ] **Subtitles:** while you look at the things, does the line cover the shelf? none / top row / more. While you look
      at Onion? (A proposal is in DEV_NOTES: Wei's `Voice.above_gaze` 25 -> 36 and `above_horizon` 20 -> 12.)
- [ ] Onion never sits in front of a cubby or over a thing.
- [ ] Nothing from the opening (the panel behind the shelf; the cauldron is hidden) is in the way of the things or your hands.
      The panel is partly hidden behind the shelf from a seat: noticed / fine.

Notes:

---

## 9. Hands in detail (pinch, tap, carry, tracking loss): what a headset does that a mouse does not

Everything the mouse does the same way is tested without a headset; these are the parts that differ with real hands
(and cannot be checked without one). Do them seated, once with each hand, and note counts rather than feelings where
you can. The code paths are `Carry` (the gear), Wei's tidy trial (the shapes), `Entry._poke_cauldron` (the tap).

**Pinch (the gear).** The pinch point is the middle of the thumb tip and the index tip; the gear is taken when that
point is within about 9 cm of the gear's middle (pinch its shaft, its rim or its base: all count). A pinch that closes
just before the hand arrives still counts for a quarter of a second.
- [ ] Pinch the gear 10 times. It was taken ______ of 10. (A miss: how far off was the pinch point? ______ cm)
- [ ] It is held while the pinch is closed and drops within a blink (about 0.1 s) of opening your fingers. Dropped on
      its own while pinching: never / ______ times.
- [ ] Turn your wrist about the vertical (like turning a key): the gear turns with it, staying upright.
- [ ] Roll your wrist (palm to face, then palm down): the gear tips along but never more than about 35 degrees, and never
      flips over.
- [ ] The gear stays in your fingers where you grabbed it (it does not jump to the middle of your hand).
- [ ] **Left hand:** with the palm toward your face, a pinch may be the headset's own menu gesture (it opens the
      grown-up panel). Does grabbing the gear with the LEFT hand ever open the panel? yes / no. (If yes, say which palm
      direction.) Right hand: same question.
- [ ] Both hands pinching the gear at once: the first one holds it, the other does not steal it.

**Tap by fingertip (the cauldron).** In the Tap beat the index fingertip going into a ball about 13 cm round the
cauldron's middle counts once (it covers the pot and a little more); a finger that stays in does not tap again; a hand
held outside does nothing; before the beat asks for it nothing counts. A pinch aimed at the cauldron from afar counts as well.
- [ ] A tap with the fingertip counted at the first try ______ of 5 times.
- [ ] A hand that only passes by (reaching toward the table, resting beside the pot) does not tap: false taps ______.
- [ ] Tapping with the far hand or from a distance by pinch also works. yes / no.

**Tracking lost (the gear).** Cover your hand with the other, or pull it out of view, while carrying.
- [ ] A dropout shorter than a quarter of a second is ignored (the gear stays in the hand): yes / no.
- [ ] Longer: the gear is set down on the table, upright, within your reach, in about a second. It never lands in the
      cauldron or on the panel (where you let go over the panel's edge, it goes to the near side).
- [ ] When the hand is back, a new pinch picks it up again.
- [ ] Letting go over the socket (about 12 cm sideways) docks it: one click; further away it floats down to the table.
- [ ] Opening the grown-up panel (left palm up pinch) while carrying lets go of the gear cleanly.

**The shapes in the first visit (Wei's carry).** A pinch within about 6 cm of a shape takes it (a bit more for big
ones); two hands carry two shapes; letting go at a cubby clicks it in (right) or sends it back (wrong); letting go
elsewhere, losing the hand or a pause sends it home, never counted as a try.
- [ ] Pinch 10 shapes. Taken ______ of 10. Taken by accident (hand only passing) ______.
- [ ] **The reminder:** after Onion's last line ("Pick whichever one you'd like to start with.") do nothing for about
      12 seconds. A see-through hand comes straight down on ONE shape (the nearest to you), pinches it, lifts it a few
      centimetres and puts it down, over and over, without leaning toward the shelf. It goes the moment you take any
      shape. It never shows a cubby. Came after about ______ s. Chose a shape nearest to me: yes / no.
- [ ] Wei's own help (the right sticker wiggles) did NOT come before the reminder. It should come about 40 s after the
      round starts if you are still doing nothing; after you have taken a shape it goes back to his normal 10 s.

**Desktop only (ignore in the headset):** the G key, the mouse click on the cauldron, W/A/S/D/Q/E and the arrow keys
(the headset moves and turns with your head).

Notes:

---

## At the end

- [ ] Total time seated: ______ min. Any neck strain from looking down? yes / no
- [ ] Anything you had to stand or lean for: ________________
- [ ] One thing to change first: ________________
