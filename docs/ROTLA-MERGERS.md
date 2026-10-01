# RotLA merger Hotseat walkthrough

Normal minor mergers are implemented using the supplied original rulebook,
printed pages 16, 18–19 and 24. Headquarters and hostile mergers remain future
work. Existing Mining/Port upgrade catalog gaps remain unchanged.

## Load the ready game

1. Start the local Docker services as described in ROTLA-ROUNDS.md.
2. Open http://localhost:9292/new_game?title=RotLA.
3. Select **Import hotseat game**, then **Upload file** and choose
   `data/rotla/hotseat-merger-ready.json`. Alternatively paste its JSON into
   the import box. Click **Create**.

The save replays legal map setup, two launch auctions, two stock rounds and
four operating rounds. It opens at **Phase 3 — Merger Round 2**, immediately
after OR 2.2. Alice owns Adaptive, Bob owns Eastern Mining, and Carol has no
shares. Adaptive's hub at **J6** connects through the yellow track at **J8**
to Eastern Mining's hub at **K9**. The map uses seed 3722698.

## Try the merger

1. As Alice, click **Propose merger with EM (Bob)**.
2. As Bob, click **Agree to merger**. Declining prevents this pair from being
   proposed again in this merger round.
3. As Alice, choose a major, for example **Form Conglomerate**.

Alice wins the presidency tie because Adaptive acts first on the stock track.
Each president's two minor shares become two major shares: Alice receives the
20% president certificate and Bob receives two 10% certificates. The remaining
60% stays in the new treasury. The average of 90 and 60 rounds down to the 70
stock space. The new major inherits $157, two 2-trains and one 3-train, both
home hubs and both powers. Two additional hubs cost 60 each.

The game exports one 3-train and enters Stock Round 3. Pass for all three
players to operate the new major. It can issue or redeem one 10% share, build
track, place hubs, run trains, pay dividends and buy trains. New majors do not
receive the optional minor leadoff train step.

Hotseat saves automatically in this browser. Reloading replays the same actions.
Import the fixture again whenever you want a fresh merger attempt.

## Rules handled

- Merger rounds occur after both ORs once the first green train was purchased
  or exported. The export following a yellow-phase cycle never inserts an
  immediate merger round.
- Only floated, connected minors can merge. Overnight's blocking exception
  applies to merger reachability and, after merging, to hub reachability.
- Proposal order follows descending stock price and stock-marker arrival order.
  Both presidents consent; a common president proceeds directly to identity choice.
- The largest combined share holding receives the major presidency; the leading
  minor's president breaks a tie. Players, treasury and bank retain share units.
- Majors inherit both powers, cash and trains. Major train limits are 4 in phase
  3, 3 in phase 4 and 2 afterward, plus Spacious's extra slot if inherited.
  Excess merger trains must be discarded by the president before play continues.
- Hubs convert to the major's identity. Two hubs on one hex become one placed
  hub and one unused free hub. Expansive's unused 40-cost hub is retained.
- Majors cannot merge further through the normal minor-merger procedure.
- When a 2-train exports, all remaining depot 2-trains export together.
- If an export lowers train limits, excess trains must be discarded before the
  next Stock Round. Exporting a train happens only once in that cycle.

## Regenerate the fixture

```sh
docker compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.local.yml exec -T rack bundle exec ruby scripts/rotla/export_merger.rb > data/rotla/hotseat-merger-ready.json
```
