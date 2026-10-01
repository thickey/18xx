# Physical map-piece inventory

Derived from two Standard/no-random-start/no-Landmarks API responses.
Hex order is the generator’s Hex1, Hex2, Hex3; see README for coordinates and caveats.

| Printed number | API copy IDs | Hex 1 | Hex 2 | Hex 3 |
| --- | --- | --- | --- | --- |
| 1 | 01 | minor expansive | mountain | plain |
| 2 | 02 | minor mining | plain | mountain |
| 3 | 03 | standard city | minor agricultural | plain |
| 4 | 04 | standard city | minor resourceful | plain |
| 5 | 05 | plain | minor express | water |
| 6 | 06 | mountain | standard city | minor suburban |
| 7 | 07 | border | minor port | standard city |
| 8 | 08 | mountain | minor tunneling | standard city |
| 9 | 09 | water | plain | minor bridging |
| 10 | 10 | standard city | minor overnight | water |
| 11 | 11 | water | plain | minor spacious |
| 12 | 120, 121 | plain | plain | plain |
| 13 | 130, 131 | plain | water | water |
| 14 | 140, 141 | mountain | plain | water |
| 15 | 150, 151 | standard city | plain | mountain |
| 16 | 160, 161 | standard city | plain | plain |
| 17 | 170 | standard city | mountain | plain |
| 18 | 180 | plain | standard city | water |
| 19 | 190 | standard city | standard city | plain |
| 20 | 200 | standard city | mountain | standard city |
| 21 | 210 | standard city | standard city | standard city |
| 22 | 220 | mountain | mountain | mountain |
| 23 | 230 | border | plain | plain |
| 24 | 240 | border | water | plain |
| 25 | 250 | border | plain | standard city |
| 26 | 260 | border | plain | offboard |
| 27 | 270 | border | offboard | offboard |
| 28 | 280 | border | offboard | offboard |

33 physical pieces, 28 printed numbers. Capital markers are excluded from fixed terrain.
Runtime track paths, revenues, slots and home reservations are integrated in
`runtime-map-v1.json`, `map_catalog.rb` and `real_map_builder.rb`. The runtime
base pose rotates the canonical source geometry three steps; no piece is reflected.
