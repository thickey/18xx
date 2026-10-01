# Railways of the Lost Atlas: map setup

This is a **prealpha map-setup implementation**, not yet a playable RotLA game.
Normal setup uses the real physical supply: 33 tri-hex pieces in the Long Game,
25 in the Short Game. Auctions and operating rounds are still to come.
No official artwork is included.

## Run locally

With Docker Desktop running:

```sh
docker compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.local.yml up -d
```

Open http://localhost:9292/new_game?title=RotLA, choose **Hotseat**, enter names,
and create the game. Two players automatically use Short Game; five use Long
Game. Three or four players may select **Short Game** in the optional rules.
Five-player Short Game is rejected. Two- and three-player **Micro Game** options
require their matching player counts and cannot combine with Short. Two-player
Micro selects one of three balanced stacks: 11 pieces, four minor homes, one
destination and one capital. Three-player Micro removes tile 26 and selects
one of two balanced stacks: 16 pieces, six homes, one destination and one
capital. The seed controls dealing, selection and shuffle. Tile 21 counts as
AD's home piece; AD chooses its actual home later.

Click **Start real map setup**. A seeded random player begins with the top draw
from the shuffled stack. Each player draws and resolves one piece or project,
then play proceeds around the player list. The first map piece is anchored at
M13; rotate it before placement if desired. Subsequent pieces must share at
least three edges with the existing map, cannot overlap, and cannot touch a
border cell on another piece. Internal contact within one piece is allowed.
Preprinted tracks impose no additional construction restriction (printed page 6,
Diagram 1), including when they point off-map. The prohibition on track pointing
off-map applies to track laid during operating rounds (printed page 13).

Click **Draw a piece**, rotate, select a blue anchor, and click **Place piece**.
The green outline shows the uncommitted preview. Rotation and anchor selection
are local UI state; draws and committed placements are recorded actions.
Printed tile numbers and physical copy IDs identify real pieces; the two
copies of each of tiles 12–16 remain distinct.

Capital projects are shuffled into the same stack: three in Long Game, two in
Short Game. When one is drawn, choose a placed basic city to upgrade. Minor
homes and existing capitals cannot be chosen. If no eligible city is available,
the project automatically goes to the bottom of the stack and the same player
draws again. Capitals are marked **C** and begin with one slot, zero revenue,
and no track; their later track upgrades are outside this setup implementation.

All destinations use the rulebook's recommended **30/40/70/100** card, shared by
all destinations. A two-hex destination is one stop with one value schedule and
one visible revenue cluster. Other destination cards, customization overlays,
are not included. Mountain terrain costs 40,
including the Tunneling home. Basic cities and ordinary homes begin with one
slot, zero revenue and no track. Special homes retain the approved preprinted
track, revenues and slots; company markers are reservations, not operating
hub tokens. Blue water and border cells are not ordinary playable land.

After every piece and project resolves, players may place up to twelve optional
single blank hexes around minor homes, then click **Finish setup**. Blanks must
directly adjoin a home, cannot overlap or touch a black border, and do not need
three shared edges. Unused blanks may be skipped. In Micro Games, tile 21's
cells count as possible AD home locations for this phase.

Printed page 6 describes blanks around homes without prescribing an exact
placement order. The finishing phase is an implementation choice so players
can assess the completed map. **Map Ready** is the endpoint. The ordinary **Map** tab
shows the assembled engine map, including home reservations. **Build another
map** reshuffles the same mode's supply. If all players agree a drawn piece has
no legal placement, **Restart map construction** reshuffles during setup.
Undo can restore the previous map or pending draw; redo, reload, export and
import reconstruct the same stack and capital selections.

To stop without deleting the local database:

```sh
docker compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.local.yml stop
```

## Data and replay

- `data/rotla/MAP-INVENTORY.md`: physical inventory, printed numbers and terrain.
- `data/rotla/runtime-map-v1.json`: versioned runtime audit catalog, source IDs,
  local cells, home metadata, approved special definitions and setup facts.
- `lib/engine/game/g_rotla/map_catalog.rb`: browser-compatible Ruby catalog.
- `lib/engine/game/g_rotla/real_map_builder.rb`: real setup, cell materialization,
  capital projects, reservations and common preview support.
- `lib/engine/game/g_rotla/map_builder.rb`: triangle transforms, placement rules
  and frozen legacy setup definitions.
- `assets/app/view/game/map_builder.rb`: placement UI. Real previews use the
  ordinary `Tile` component with the same codes as the normal Map renderer;
  offboard revenues are omitted in setup previews.

New setup records `start_v5`, `blank_v5:q:r`, `finish_blanks_v5`,
`draw_v4`, `place_v4:copy_id:q:r:rotation`,
`capital_v4:q:r`, and `restart_v4` through ordinary Choose actions. Keep the
`real_v1` catalog, ordering, transforms and seeded shuffle immutable for replay.
Saved `start_v4` games retain automatic completion without a blank phase.
The catalog rotates source canonical geometry three steps, preserving Hex1/2/3
order and handedness; the resulting base triangle is `(0,0),(1,0),(0,1)`.

Existing `draw_v2` / `place_v1`–`place_v3`, preset-picker saves, and
`review_tileX_v1` / `place_tileX_v1` saves retain their original definitions and
handlers. New games no longer expose special tile-review buttons. Loaded legacy
review saves retain their rotation workflow intentionally; no migration or
silent reinterpretation occurs. Continue old prototypes as prototypes, or
create a new game for the real supply.

`reference-map-3722698.json` preserves a full saved generator reference from
`data/rotla/sources/board-3722698.json`. The regression suite compares all 99
source coordinates against the runtime rotations, builds that map, and checks
preview codes against normal engine hexes. This is a generator reference, not
an official publisher preset or a source of rules. The printed component sheet
and the prior user-approved special layouts provide the physical checks.

## Validate

```sh
python3 scripts/rotla/build_runtime_catalog.py --check
docker compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.local.yml exec rack bundle exec rspec spec/lib/engine/game/g_rotla
docker compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.local.yml exec rack bundle exec rubocop lib/engine/game/g_rotla spec/lib/engine/game/g_rotla assets/app/view/game/map_builder.rb assets/app/view/game/tile.rb
```

For a complete three-player hotseat smoke-test export:

```sh
docker compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.local.yml exec -T rack bundle exec ruby scripts/rotla/assemble_map.rb > /tmp/rotla-map.json
```

Import that file through **Import hotseat game**. This assembles the seeded supply
through real Choose actions, including capital draws; it does not bypass placement
validation or load an invented preset.

See [ROTLA-TODO.md](ROTLA-TODO.md) for remaining gameplay work and
[data/rotla/README.md](../data/rotla/README.md) for research provenance.
