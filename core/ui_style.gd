class_name UIStyle
## The two UI families (Megan chose "B: child vs grown-up", Nov 16):
## * the CHILD's UI (Menu, games, room, shop) is Wei's cream-and-ink kit, in HomeUI (INK, CREAM, GOLD);
## * the GROWN-UP's UI (the setup panel and staff tools) shares this slate-and-sage look, so an adult panel
##   is told apart at a glance and a child isn't drawn to its buttons.
## Change the grown-up colours here, not in each panel.

## Panel backing (opaque: a see-through plate gets drawn over the words).
const STAFF_PANEL := Color(0.13, 0.15, 0.19)
## Header bar and accents.
const STAFF_HEADER := Color(0.62, 0.74, 0.6)
## Ordinary buttons.
const STAFF_BUTTON := Color(0.30, 0.40, 0.33)
## The one main action on a page (e.g. Start).
const STAFF_PRIMARY := Color(0.25, 0.65, 0.35)
## A button that can't be pressed now.
const STAFF_DISABLED := Color(0.16, 0.17, 0.2)
