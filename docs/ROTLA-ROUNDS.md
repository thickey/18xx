# RotLA: early rounds in Hotseat

The rounds prototype supports the initial minor launch auctions, starting
companies, treasury and bank-pool share purchases, share sales, and Operating
Rounds and normal minor mergers. It defaults to the publisher’s second-printing rules; see [edition details](ROTLA-EDITIONS.md). The stock track is visually transcribed from the table setup
image on printed page 9. This is an early-round implementation, not a complete
RotLA game: headquarters, hostile mergers, optional continuation after bankruptcy,
and the remaining special/later-phase tile definitions are still pending.
Minor operating powers include Bridging, Suburban, Overnight and Resourceful;
see [company powers](ROTLA-COMPANY-POWERS.md) for behavior and a test save.
See [mergers](ROTLA-MERGERS.md) for a saved game with connected minors ready to merge.
Four- and five-player games add one extra 3-train and one extra 6-train;
Micro Games have their reduced train rosters, starting cash and no exports.
Long Games end after six complete cycles; Short and Micro Games end after four.
Finish both ORs, any Merger Round, the train export and required discards before
scoring. Scores include personal cash and shares, excluding company treasuries;
ties favor the president whose company operates earliest. Bank depletion does
not end the default game. Bankruptcy ends play immediately after forced share sales. The Bank Break variant is not yet offered in settings.

## Load the supplied game yourself

1. Start the local Docker services as described in [ROTLA.md](ROTLA.md).
2. Open http://localhost:9292/new_game?title=RotLA.
3. Select **Import hotseat game**.
4. Click **Upload file**, choose `data/rotla/hotseat-rounds-start.json` from this
   repository, and click **Create**. Alternatively, paste that file's complete
   JSON into the text box and click **Create**.

This file starts at Stock Round 1 with a completed map and $300 for each of
Alice, Bob and Carol. No account is needed. The map was assembled using legal
setup actions, not by injecting placements. Each import creates a separate
local Hotseat save.

To use your own map, create a Hotseat game, finish tri-hex/capital/blank setup,
then click **Start auctions and Stock Round** on Map Ready. Existing real-map
saves can also start rounds with that button. Prototype tile reviews do not
start rounds. Refresh an already open page to load the new code.

## A reproducible walkthrough

For the supplied import, Alice acts first and the initial available charters
are Eastern Mining, Overnight and Adaptive. Charter columns are seeded; only
the first remaining charter in each column can be chosen.

1. Alice enters **125** in the bid box and clicks **Place Bid**. Bob and Carol
   each click **Pass auction**. Alice chooses **Eastern Mining Company**.
   Alice receives its 40% president certificate. The company receives $125,
   starts at stock price $60, and places its home hub at K9. The next charter
   in that column becomes available.
2. On Bob's turn, click the **Eastern Mining Company** card, then **Buy Treasury
   Share**. Bob pays $60 into the company's treasury for 20%. Click **Done
   (Share)**. Each subsequent player clicks **Pass (Share)** until three
   consecutive passes end the Stock Round. You can instead launch additional
   companies or buy more shares, one purchase per turn, up to 60% ownership.
3. OR 1.1 starts. Buy the **2-train** for $100 during the optional leadoff step.
   It can run this OR. Skip issuing/redeeming and, for the shortest smoke test,
   skip track placement. You may instead click a reachable map hex to choose
   and rotate a legal tile, with up to two yellow lays or one upgrade.
4. At Routes, click **Run every train locally at a hub** to run the 2-train for
   $30. Alternatively, click the two Mining revenue centers at K9 and submit
   the traced $50 route. Trains without traced routes automatically run local
   routes at their highest-value hub. Mining's two stops are separate; the
   Port's halves are one city.
5. Click **Pay Out** or **Withhold**. A $30 payout pays $12 to Alice, $6 to Bob
   and $12 to the company for its two treasury shares. The stock price stays
   at $60. Withholding pays the company $30 and moves its stock price left.
   Buy another train if desired and affordable, or skip the final train step.
6. Repeat the operating actions in OR 1.2. After both ORs, the base game exports
   all remaining depot 2-trains together and returns to Stock Round 2. Later
   cycles export one train, after a Merger Round when already in the green
   phase. Micro Games do not export.
7. Shares can now be sold because Eastern Mining has operated. Pass as Carol
   and Alice to reach Bob, select the company card and click **Sell 1 ($60)**.
   The share enters the bank pool and stock price moves to $50. Bob cannot buy
   this company's shares again during this Stock Round. Click **Done (Share)**.
8. Carol selects the company card and clicks **Buy Market Share** for $50.
   That payment goes to the bank, rather than the company. You have now
   exercised auctions, launch, treasury purchase, two ORs, sale and market buy.

Hotseat automatically changes the acting player; the Stock Round heading names
that player. Operating order follows stock price and token order. Passing in a
launch auction removes you from that auction only. Passing in a Stock Round
does not prevent acting later unless everyone passes consecutively.

## Saves and validation

Hotseat saves live in this browser's local storage. Use the normal Tools export
and Import Hotseat flow to keep a portable copy. Undo/redo, reload and import
reconstruct the economics, holdings, hubs, track, trains and current round from
actions. Starting Map shows the map before rounds, rather than the laid track.

Regenerate the starting fixture with:

```sh
docker compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.local.yml exec -T rack bundle exec ruby scripts/rotla/export_rounds.rb > data/rotla/hotseat-rounds-start.json
```

Run engine validation with:

```sh
docker compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.local.yml exec -T rack bundle exec rspec spec/lib/engine/game/g_rotla
```
