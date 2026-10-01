# RotLA — next steps

## Current state

This is a local setup and early-rounds prototype; full RotLA gameplay is still incomplete.
Normal setup now uses the real 33-piece Long Game / 25-piece Short Game supply,
capital projects, and printed minor homes. See [ROTLA.md](ROTLA.md) for setup,
replay compatibility, sources and commands.

Completed work (removed from the active TODO list):

- Cataloged all 33 physical tri-hex pieces / 99 hexes from two Standard generator
  responses, including terrain, geometry and source orientation; removed random
  capital overlays. Saved sources, hashes and an offline validator.
- Prepared 12 minor and 6 major records, minor-power summaries, 54 track designs /
  135 tiles, and 111 lay/upgrade relationships. Documented edition differences.
- Implemented and visually approved the special layouts: 2 Mining, 7 Port,
  9 Bridging, 11 Spacious, and offboards 26–28. Review JSON files preserve the
  confirmed geometry, exits, cities, slots, labels and home reservations.
- Implemented the three-shared-edge minimum after the first piece, overlap
  prevention, and exclusion of external contact with border hexes. Borders are
  unreachable during gameplay; internal contact within a tri-hex is allowed.
- Shared offboards use one destination group, one in-game revenue cluster, and
  no visible dividing edge. Routes cannot visit both halves of one destination.
  Setup previews omit revenues; in-game 30/40/70/100 values are placeholders.
- Seeded draws, turns, rotation, replay, reload and undo/redo work. Last focused
  validation: 28 engine tests passed, with formatting and browser checks.

## Completed: real map supply (2026-10-01)

- [x] Consolidate the approved special-tile definitions and sourced terrain
  catalog into one versioned runtime catalog of all 33 real tri-hex pieces.
  Replace the four invented pieces in normal setup; retain stable IDs and
  deterministic draw order for replay.
- [x] Finish the ordinary cells: standard cities, starting/capital cities, minor
  homes and terrain. Confirm ordinary-city revenues, slots, terrain costs,
  reservations and capital-overlay selection rules. Include border cells on
  the remaining pieces (23–25 as well as the approved offboard pieces).
- [x] Confirm actual setup composition by player count and game mode, starting
  piece selection, draw/placement order and completion conditions. Reuse the
  implemented three-edge and border restrictions rather than reimplementing them.
- [x] Look up offboard value assignment during setup and replace the temporary
  30/40/70/100 schedule. Assign one value schedule per shared destination.
- [x] Assemble and inspect a full real-piece map, then compare at least one
  official preset/reference layout to catch orientation and coordinate errors.
- [x] Extend tests to the complete supply: quantities, all rotations, home/capital
  resolution, player-count setup, legal placement, deterministic replay and
  agreement between setup previews and the normal Map renderer.

## Completed: retire reviews from normal new games

- [x] Once the full catalog is integrated, remove the special **Review tile X** /
  single-tile preview entry points, review-only instructions, and **Try another
  rotation** flow from the normal player UI. Keep ordinary placement previews.
- [x] Move tile-specific rendering and review-only engine helpers into reusable
  catalog/rendering support where needed. Preserve the approved geometry,
  shared offboard appearance and regression coverage.
- [x] Decide how to retain or migrate saved `review_tile*_v1` / `place_tile*_v1`
  games before removing their handlers. Preserve older setup replay support or
  explicitly document a migration; do not silently invalidate existing saves.
- [x] Replace the per-tile walkthroughs in ROTLA.md with normal setup instructions.
  Keep confirmed tile descriptions and provenance in the data catalog.

Implementation notes:

- Runtime catalog: `real_v1`, with `start_v4` / `draw_v4` / `place_v4` /
  `capital_v4` / `restart_v4` actions. New setup starts with start_v5; prior
  prototype and tile-review handlers remain available for saved-game replay.
- Basic cities and ordinary homes have one slot, zero revenue and no track.
  Tunneling includes a 40-cost mountain. Capitals are selected from basic cities
  already placed, excluding homes and existing capitals. Early projects defer.
- Two players use Short, five use Long; three/four may choose either. The first
  player and stack are seeded; all physical pieces and projects must resolve.
- All destinations share the recommended 30/40/70/100 revenue card from printed
  page 6. Other revenue cards remain a later optional feature.
- Preprinted track may lead off-map: printed page 6 expressly imposes no
  preprinted-track restriction during map construction. Printed page 13 forbids
  track laid during operating rounds from pointing off-map; implement that with
  track laying, not map construction. Optional single-hex shoring overlays now have a finishing phase.
- Focused validation: 38 engine examples passed, including all rotations,
  player counts, project deferral, replay, reservations, preview agreement,
  undo/redo, restart, and legal preprinted track pointing off-map.
- A full 99-hex map was assembled through legal real actions and visually checked
  in the browser. The saved generator reference is compared cell-for-cell across
  all 33 pieces; it is identified as a generator reference, not a publisher preset.
- Old review games intentionally retain their reopening/rotation controls;
  they are no longer offered by normal new-game setup.

## Completed: setup variants and blank hexes

- [x] Expose Short and exact-count two/three-player Micro options; reject
  incompatible modes and validate the actual Hotseat player count.
- [x] Seed balanced Micro stacks and choose/shuffle one with the required
  home, destination and capital quantities.
- [x] Add an optional finishing phase for up to twelve blank hexes around homes,
  with preview, border/overlap checks, finish, replay and undo/redo. Timing is
  an implementation choice because the rules do not specify placement order.
- [x] Validate with 44 engine examples and clean formatting. New setup uses
  `start_v5`; saved v4 games retain their previous automatic completion.
  Micro train, cash and round changes are included in the playable rounds below.

## Completed: first playable rounds

- [x] Map Ready can explicitly start funded Stock Round 1, preserving old map
  saves and providing seeded charter columns with map-dependent availability.
- [x] Minor launch auctions bid in clockwise order, exclude passed bidders,
  choose an available charter, capitalize its treasury, set its stock price,
  place its home hub and return to the turn after the initiator. Adaptive chooses
  a basic unreserved home city.
- [x] Treasury/market purchases, sales after operation, ownership limits,
  presidency changes, sold-out movement and stock-to-two-OR transitions.
- [x] Leadoff train, issue/redeem, reachable track, hub placement, traced/local
  routes, payout/withhold, mandatory trains and train export between cycles.
- [x] Second-printing and Micro rosters/cash; basic Agricultural, Express, Expansive,
  Spacious and Tunneling effects. Original roster remains an optional setting.
- [x] Reusable Hotseat import and user walkthrough in ROTLA-ROUNDS.md; browser
  validation of auction, launch, treasury purchase, both ORs, sale and market buy.
- [x] Implement Bridging's five finite water tiles and water-facing track,
  Suburban's two persistent suburbs with +10 per visiting train, Overnight's
  blocked-city passage, and Resourceful's final run after rust. Include legal
  action replay, late suburb placement before dividends and a Hotseat demo.
- [x] Green-phase Merger Rounds after both ORs: connected minor proposals,
  president consent, six major identities, share exchanges, stock averaging,
  pooled treasuries/trains, converted hubs, excess-train discards and inherited
  powers. Includes a legal replayable merger-ready Hotseat demo and major ORs.
- [x] Export all remaining 2-trains together; begin merger rounds only after
  a pair of ORs in the green phase, not immediately when an export changes phase.

## Remaining gameplay work

- [ ] Finish the green, brown and gray track catalog, including company-specific
  tiles and remaining destination-card research.
- [x] End after six complete Long Game cycles or four Short/Micro cycles,
  including the final merger/export/discard steps. Score personal cash and
  shares; break ties by operating presidency order. Bank depletion does not end play.
- [ ] Implement headquarters, hostile mergers and optional continuation after bankruptcy.
- [ ] Offer the Bank Break variant separately (8,000 bank, Long Game setup,
  player-count certificate limits, end after both ORs when the bank runs out).
- [ ] Complete Mining and Port upgrade sets as part of the special tile catalog.
- [x] Default to second-printing train counts, enforce offboard route endpoints,
  and implement forced share sales and immediate bankruptcy ending. Preserve
  the original train roster as a setting; see ROTLA-EDITIONS.md.
- [ ] Investigate the background queue service before online/background testing;
  earlier shutdown inspection found it exited with code 1. Hotseat testing works.
- [ ] Review and commit the local changes when ready.

## Resume locally

From the repository root, with Docker Desktop running:

```sh
docker compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.local.yml up -d
```

If images need rebuilding, add `--build`. Open:
http://localhost:9292/new_game?title=RotLA

Use Hotseat for account-free testing. The local override uses a Docker-managed
PostgreSQL volume to avoid macOS bind-mount ownership problems. Stopping the
services preserves that volume. Hotseat saves live in the browser's local storage.

```sh
docker compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.local.yml stop
```
