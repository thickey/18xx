# RotLA track catalog

The runtime supply in `lib/engine/game/g_rotla/map.rb` now contains all 54
reference designs and 135 physical track tiles. Counts agree with the saved
FWTWR inventory (`data/rotla/track-tiles.json`) and the rulebook component total.
IDs are FWTWR reference labels; the physical tiles are unnumbered.

| Engine color | Physical color | Designs | Copies |
| --- | --- | ---: | ---: |
| Yellow | Yellow | 9 | 55 |
| Green | Green | 24 | 43 |
| Brown | Purple | 15 | 27 |
| Gray | Gray | 3 | 5 |
| Blue | Blue | 3 | 5 |

Yellow counts were already correct. Capital 291 is the broad curve, 292 the
sharp curve, and 293 the straight: 291 and 292 were swapped in the prototype.
Each has one copy, one slot, and revenue 40. Ordinary yellow cities pay 20.

Green removes prototype tile 18, adds 17/21/22/30/31/619/624, and corrects
19 to one copy and 23/24 to four copies each. Capital 294/295/296 have two slots
and revenue 50, with counts 2/2/1. They use the track patterns of 14/15/619.
Brown capital 297 has five exits, three slots, revenue 60 and two copies.
Gray capital LA6 preserves the same five exits as 297, with three slots, revenue 70 and one copy.

Mining has two connected stops. LA1 pays 50/30 with one slot at each;
LA4 pays 60/40 with one/two slots; LA7 pays 70/50 with one/two slots.
There is one of each. Brown/gray dual-city revenue labels sit above and to the
right of their two-slot city, clear of the track exits. Its special upgrade rule preserves existing hex exits,
allowing the two placements shown in the rulebook rather than requiring the
internal track and city positions to stay fixed. This applies to any company.

Port LA2 pays 60 at each half, with one slot per half. LA5 pays 80 at each half,
with two slots per half. There is one of each. Both upgrades render water on
the two blank sides, following tile rotation in the catalog and on the map. The halves remain separate in
track connectivity and count as the same city for a train's route, using the
existing Port route restriction. Port ends in brown; Mining and capitals reach
gray. Ordinary brown city 125 upgrades to gray 51. Plain brown tracks and blue
bridges have no later upgrades. Gray track can be approached from neighboring
hexes; gray map hexes without track remain blocked.

Verification: visually checked the supplied rulebook PDF pages 3 and 14
(printed pages 2 and 13), plus FWTWR capital and LA1–LA7 tile images. Standard
numeric track IDs use the engine's existing definitions. RotLA regression
specs include supply equality, capital patterns, special revenues/slots,
Mining rotations and terminal tiles. Browser previews are available at
`http://localhost:9292/tiles/RotLA/all`.

Sources: saved inventory and upgrade HTML in `data/rotla/sources/`, the supplied
`RailwaysRulebook-CleanFonts.pdf`, and tile images linked from
http://www.fwtwr.com/18xx/info/inv-rotla.asp.
