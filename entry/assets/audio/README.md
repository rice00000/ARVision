# Opening sounds

Built by `tools/sound/design.py` (`opening`) from the team's SFX library, November 17, 2026. Played by `entry/sounds.gd`.

| File | Moment | Made from |
| --- | --- | --- |
| pre_rattle.ogg | the cauldron trembles before Onion appears | a run of pan-lid and earthenware clinks (Articulated Sound, Essential Kitchen) |
| rattle_soft.ogg | the faint rattle while waiting for a tap; the closing | pan-lid clinks |
| device_rattle.ogg | the heavier tremble before the gear; the socket carriage | earthenware clinks, plastic gear clicks (Cinetools Clinks & Clanks), a low thud |
| knock.ogg | the jolt inside the cauldron; the gear dropping back | a placement thud slowed and muffled (Cinetools Books & Magazines), a lid clink |
| pop.ogg | Onion rises over the rim | a mouth pop (Deb Sound), bubbles (FilmCow), a glass C6, shaken bells (CB Sounddesign) |
| gear_land.ogg | the gear lands on the table | tiny gear click (Bluezone, Sonniss GDC 2024), a wooden placement |
| seat.ogg | the gear seats in the socket | gear clicks, a wooden thud, celesta G5→C6 |
| reveal.ogg | the light spreads from the socket (5 s front, 2 s afterglow) | a deep C2/G2 bloom, harp glissando, C-major strings pad and enchanted bells swelling to a crest mid-front (CB Sounddesign Dreamcatcher), glitter thinning as the front slows, wind bells as it settles |
| power_up.ogg | the gear seated: the mechanism runs (after `seat`; also the hub's gear set back) | a weighty clunk, plastic gear clicks winding faster (Cinetools Clinks & Clanks), a glass C-G hum swelling, celesta C-E-G-C |
| glint.ogg | each glint of light on a real surface during the reveal, from where it lights | celesta C6 with a glass octave; pitched up the pentatonic as the light spreads (`Entry._glint_sound`) |
| onion-touch.ogg | touching Onion | made by the team (November 7, 2026), own work |

## The hub (Nov 18)
Built by `design.py hub`, in C major. `hover_tink` = glass pluck, pitched up the pentatonic bubble by bubble
(`Sounds.step`). `bubble_pop` = a small bubble burst (aXLsound UI) with a pop and glint. `chosen_chime` = a rolled
celesta C-E-G with wind bells. `locked_bonk` = a chest lock jiggling, muffled, on a low wooden D (never a buzzer);
`lock_click` = one chest-lock click (Cinetools Treasure Chest); `unlock` = C-G-C plucks, harp, glitter. `brew_rise` = a bloop
leaving the brew, air, a quick C-E-G (front-loaded, like the rise's ease-out); `brew_sink` = air drawn in, G-E-C
falling, a low gulp at 0.42 s (`Sounds.BREW_LAND`) that `ImpressionRing.sink` lands on the bubbles meeting the brew. `stone_clink` = a gem clink and G6. `gear_lift` = a book
pick-up and a tiny gear tick. `impression_<kind>` = each bubble's own two-note pluck motif over a hint of its game
(a book thud, droplets, a gear tick, a door knock, wing beats). "Found its place" borrows `seat`; the gear set down
borrows `gear_land` (a drop must not sound like success). To audition in the headset.

The calm piano (`entry/assets/calm-piano-1.mp3`, CC0, see `entry/assets/CREDITS.md`) stays under the opening (Megan,
Nov 18) until she has asked Wei why his commit removed it.

## Workshop fireplace (hub ambience, Nov 18, Megan's pick)
`workshop-fireplace-loop.ogg` = sfxmint "Low Embers Fireplace Crackling 52" (https://sfxmint.com/sounds/ambience-fireplace, CC0), a prepared 21.9 s loop, converted from the supplied WAV to Ogg Vorbis q4 (no edits; ends both ~−30 dB RMS, so the seam is clean). Plays from `HubAmbience` (entry/hub/hub_ambience.gd), not positional: fades in over 4 s to −30 dB when the hub opens, −36 dB during a game, fades out for the Virtual Workshop and the closing. Levels to tune by ear in the headset; keep it well under Onion's voice.
