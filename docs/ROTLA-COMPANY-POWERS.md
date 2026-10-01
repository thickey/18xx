# RotLA company powers

Operating powers follow printed page 24 of the supplied original rulebook.
Company cards show a short power heading; click it to expand the explanation.

| Company | Implemented minor behavior |
| --- | --- |
| Adaptive | Choose an empty, unreserved basic home city at launch. |
| Agricultural | Lay yellow after an upgrade. |
| Bridging | Two straight, two broad-curve and one sharp-curve blue bridge tiles. Each replaces a yellow lay on reachable water. Bridges cannot upgrade; Bridging's track may point into water, but cannot point off the map. Other companies may use completed bridges. |
| Eastern Mining | Two home revenue centers are separate stops. Its special upgrade set remains pending. |
| Expansive | One extra hub costing 40, using ordinary hub placement rules. |
| Express | A single owned train may visit one extra stop. |
| Northern Port | Both home halves count as one city. Its special upgrade set remains pending. |
| Overnight | Route and track reachability pass fully tokened cities. Those cities contribute no stop or revenue; routes must continue through them. |
| Resourceful | Rusted trains remain for one additional operating run, then are removed after dividends and before final train buying. They do not use train slots and cannot be sold or exchanged for infinity trains. |
| Spacious | One extra train slot. |
| Suburban | Two free suburb markers, placed during any OR step in reachable basic cities without its hub. Maximum one per hex; exclude capitals, Mining and Port. Each visiting Suburban train receives +10. Markers persist through upgrades and do not occupy hub slots or provide connectivity. |
| Tunneling | Pay the mountain cost of 40 first; receive 60 after the lay. |

Merger inheritance is still pending with mergers. Powers are tied to minor
identities in this implementation. The complete later-phase track catalog is
also pending.

## Try Suburban yourself

1. Refresh the local application and open
   http://localhost:9292/new_game?title=RotLA.
2. Choose **Import hotseat game**, upload
   `data/rotla/hotseat-company-powers.json`, and click **Create**.
3. This legal action save is in Suburban's first OR. Its home at H12 is connected
   to the basic city at H14. Click **Place suburb at H14 (+10 per train)**.
4. Trace the 2-train route by clicking the city at H12 and then H14. Its revenue
   is 50: two cities worth 20 each, plus the suburb's 10. Submit the route.
5. Pay out: Alice receives 20 and Suburban receives 30 for its three treasury
   shares, bringing its treasury to 55. The stock price stays at 60.

You may instead skip the marker initially, submit the 40 route, and place the
suburb during the dividend step. Revenue recalculates to 50 before payment.
Placing it after payment affects future runs. Choices are available whenever
there is a legal location and a marker remains.

Regenerate the demo from the repository root:

```sh
docker compose -f docker-compose.yml -f docker-compose.dev.yml -f docker-compose.local.yml exec -T rack bundle exec ruby scripts/rotla/export_powers.rb > data/rotla/hotseat-company-powers.json
```

Tests exercise bridge consumption and replay; water/map-boundary restrictions;
blocked-city connectivity, distance, revenue and endpoints; suburb eligibility,
limits, map icons and revenue for each train; legal Hotseat replay; and rust
retention, limits, sale restrictions and disposal after payout.
