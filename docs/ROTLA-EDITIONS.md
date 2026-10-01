# RotLA rule editions

New games default to the publisher’s [second-printing rulebook](https://www.asterisk-games.com/s/Railways-EN-2nd-Rulebook.pdf), checked 2026-10-01. The original source PDF remains documented in `data/rotla/sources.json`; the second-printing source and hash are recorded separately.

## Changes applied

- Printed page 7: four- and five-player games add one 3-train and one 6-train. Long Game totals are six 3s and three 6s. Short Game removes one of each 2–6 afterward, giving five 3s and two 6s at four players. Micro rosters are unchanged.
- Printed page 14: an offboard may start or end a route, but cannot be an intermediate destination, including when a company power skips blocked cities.
- Printed page 17: mandatory train purchases use company funds, then president cash and legal sales of individual shares. Sales retain their starting price; each company sold drops once when the train is bought or bankruptcy is declared. Sales cannot change the operating company's presidency or exceed the bank-pool limit. Bankruptcy is unavailable while a legal sale can still raise funds.
- Bankruptcy ends the game immediately. The revised rules describe this as common practice and also allow the remaining players to continue. This implementation chooses immediate ending; that optional continuation is still pending.

Other revised clarifications already covered by the implementation include the gray-phase 135 par, two ORs per cycle, both Port halves counting as one city, immovable suburbs, and Overnight routes never repeating a city.

The scheduled six Long / four Short or Micro cycles still apply; a depleted bank does not end the default game.

## Original printing setting

Select **Original printing rules** in game settings to retain the historical train roster and emergency-sale behavior. This is primarily a replay compatibility setting, not a claim that every original rule is implemented. Four-player saves created before this change may need `original_rules` added to their JSON `optional_rules` to preserve the old train IDs and roster. Three-player supplied Hotseat fixtures have unchanged train rosters.
