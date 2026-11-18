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
| reveal.ogg | the ripple shows the workshop | soft air swell (Cinetools Overtonics), harp glissando and C-major guitar chord (CB Sounddesign Dreamcatcher), wind bells |
| onion-touch.ogg | touching Onion | made by the team (November 7, 2026), own work |

## The hub's extra cues (merge, Nov 18)
No files of their own yet: they borrow Wei's sounds in `Sounds.BORROWS`, with pitch and level. Shelf piece = `knock`;
dots piece = `pop` at pitch 1.4; cup piece = `seat` at pitch 1.6; "found its place" = `seat`; the gear lifted =
`pop` at pitch 1.3, quiet; the gear set down away from the socket = `gear_land` (never the seating click: a drop
must not sound like success). To audition in the headset.

The calm piano (`entry/assets/calm-piano-1.mp3`, CC0, see `entry/assets/CREDITS.md`) stays under the opening (Megan,
Nov 18) until she has asked Wei why his commit removed it.

## Workshop fireplace (hub ambience, Nov 18, Megan's pick)
`workshop-fireplace-loop.ogg` = sfxmint "Low Embers Fireplace Crackling 52" (https://sfxmint.com/sounds/ambience-fireplace, CC0), a prepared 21.9 s loop, converted from the supplied WAV to Ogg Vorbis q4 (no edits; ends both ~−30 dB RMS, so the seam is clean). Plays from `HubAmbience` (entry/hub/hub_ambience.gd), not positional: fades in over 4 s to −30 dB when the hub opens, −36 dB during a game, fades out for the Virtual Workshop and the closing. Levels to tune by ear in the headset; keep it well under Onion's voice.
