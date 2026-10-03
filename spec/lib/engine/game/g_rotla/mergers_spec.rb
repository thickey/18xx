# frozen_string_literal: true

require 'spec_helper'
require 'json'

module Engine
  describe Game::GRotla::Game, 'mergers' do
    def merger_game
      fixture = JSON.parse(File.read('spec/fixtures/rotla/hotseat-merger-ready.json'))
      described_class.new(%w[Alice Bob Carol], id: fixture['id'], actions: fixture['actions'])
    end

    def act(game, type, **args)
      game.process_action(Action.const_get(type).new(game.current_entity, **args)).maybe_raise!
    end

    def form_major(game)
      act(game, :Choose, choice: 'merge:EM')
      act(game, :Choose, choice: 'accept')
      act(game, :Choose, choice: 'major:Con')
      game.corporation_by_id('Con')
    end

    def transfer(game, minor, holder)
      share = minor.shares_of(minor).find { |candidate| !candidate.president }
      game.share_pool.transfer_shares(share.to_bundle, holder, allow_president_change: false)
    end

    def connected_pair(game, first_id, second_id, blocked: false)
      minors = [first_id, second_id].map { |id| game.corporation_by_id(id) }
      hexes = %w[A1 A3 A5].map.with_index do |id, index|
        edges = if index == 1
                  [0, 3]
                else
                  [index.zero? ? 0 : 3]
                end
        code = "city=revenue:20;#{edges.map { |edge| "path=a:#{edge},b:_0" }.join(';')}"
        Hex.new(id, layout: :flat, tile: Tile.from_code("merger#{index}", :yellow, code))
      end
      game.instance_variable_set(:@hexes, hexes)
      game.send(:connect_hexes)
      minors.zip([hexes.first, hexes.last]).each do |minor, hex|
        game.stock_market.set_par(minor, game.stock_market.par_prices.last)
        game.share_pool.transfer_shares(minor.presidents_share.to_bundle, game.players.first, allow_president_change: false)
        minor.owner = game.players.first
        minor.ipoed = minor.floated = true
        minor.tokens.first.remove!
        hex.tile.cities.first.place_token(minor, minor.tokens.first, free: true)
      end
      if blocked
        blocker = game.corporation_by_id('AD')
        blocker.tokens.first.remove!
        hexes[1].tile.cities.first.place_token(blocker, blocker.tokens.first, free: true)
      end
      game.clear_graph
      minors
    end

    it 'replays two full cycles into a green-phase Merger Round with a legal track connection' do
      game = merger_game
      adaptive = game.corporation_by_id('AD')
      mining = game.corporation_by_id('EM')
      expect(game.round).to be_a(Game::GRotla::Round::Merger)
      expect(game.turn).to eq(2)
      expect(game.phase.name).to eq('3')
      expect(adaptive.operating_history.size).to eq(4)
      expect(mining.operating_history.size).to eq(4)
      expect(game.hex_by_id('J8').tile.exits.sort).to eq([3, 5])
      expect(game.merger_connected?(adaptive, mining)).to be(true)
      expect(game.round.active_step.choices.keys).to eq(['merge:EM'])
      expect(game.depot.upcoming.none? { |train| train.name == '2' }).to be(true)
    end

    it 'offers both charter names and preserves the chosen side while consuming the pair' do
      game = merger_game
      act(game, :Choose, choice: 'merge:EM')
      act(game, :Choose, choice: 'accept')
      choices = game.round.active_step.choices
      expect(choices.values).to match_array((Game::GRotla::Economy::MAJORS.values +
        Game::GRotla::Economy::MAJOR_ALTERNATE_NAMES.values).map { |name| "Form #{name}" })
      act(game, :Choose, choice: 'major:Unl:alternate')
      major = game.corporation_by_id('Unl')
      expect(major.full_name).to eq('Union')
      expect(major.color).to eq('#e28d53')
      expect(game.available_majors).not_to include(major)
      expect(game.available_majors.size).to eq(5)
      expect(game.clone(game.raw_actions).corporation_by_id('Unl').full_name).to eq('Union')
    end

    it 'lists only unstarted minors in the bank section of Entities' do
      game = merger_game
      expect(game.unstarted_corporation_summary.last).to all(have_attributes(type: :minor, ipoed: false))
      major = form_major(game)
      expect(major.ipoed).to be(true)
      expect(major.owner).not_to be_nil
      expect(game.unstarted_corporation_summary.last).not_to include(major)
    end

    it 'waits for the next pair of ORs when the first green train is exported' do
      fixture = JSON.parse(File.read('spec/fixtures/rotla/hotseat-merger-ready.json'))
      actions = fixture['actions'].take_while { |action| action['train'] != '3-0' }
      game = described_class.new(%w[Alice Bob Carol], id: fixture['id'], actions: actions)
      expect(game.phase.name).to eq('2')
      until game.round.stock?
        step = game.round.active_step
        case step
        when Game::GRotla::Step::Route
          act(game, :Choose, choice: 'local')
        when Step::Dividend
          act(game, :Dividend, kind: 'payout')
        else
          act(game, :Pass)
        end
      end
      expect(game.turn).to eq(3)
      expect(game.phase.name).to eq('3')
      expect(game.log.any? { |line| line.message.include?('A 3 train exports') }).to be(true)
    end

    it 'inherits Spacious and Express into a major with the boosted limit and train distance' do
      game = merger_game
      first, second = connected_pair(game, 'SP', 'ER')
      train = game.depot.upcoming.find { |candidate| candidate.name == '3' }
      game.buy_train(first, train, :free)
      major = game.merge_minors!(first, second, game.available_majors.first)
      expect(game.train_limit(major)).to eq(5)
      route = Route.new(game, game.phase, train)
      visits = [game.hexes.first.tile.cities.first] * 4
      expect { game.check_distance(route, visits) }.not_to raise_error
      expect { game.check_distance(route, visits + visits) }.to raise_error(RouteTooLong)
    end

    it 'uses Overnight to cross intervening blocked cities for mergers and inherited hub reachability' do
      game = merger_game
      first, second = connected_pair(game, 'AG', 'SU', blocked: true)
      expect(game.merger_connected?(first, second)).to be(false)
      game = merger_game
      first, second = connected_pair(game, 'OV', 'SU', blocked: true)
      expect(game.merger_connected?(first, second)).to be(true)
      major = game.merge_minors!(first, second, game.available_majors.first)
      expect(game.token_graph_for_entity(major)).to eq(game.graph_for_entity(major))
      expect(game.company_power?(major, 'SU')).to be(true)
      expect(game.company_power?(major, 'OV')).to be(true)
    end

    it 'requires consent, selects the leading president on a tie, and pools shares, hubs, cash and trains' do
      game = merger_game
      adaptive = game.corporation_by_id('AD')
      mining = game.corporation_by_id('EM')
      cash = adaptive.cash + mining.cash
      trains = adaptive.trains + mining.trains
      act(game, :Choose, choice: 'merge:EM')
      expect(game.current_entity).to eq(mining.owner)
      expect(game.round.active_step.choices.keys).to eq(%w[accept decline])
      act(game, :Choose, choice: 'accept')
      expect(game.current_entity).to eq(adaptive.owner)
      expect(game.round.active_step.choices.size).to eq(12)
      act(game, :Choose, choice: 'major:Con')
      major = game.corporation_by_id('Con')
      expect(major.owner.name).to eq('Alice')
      expect(major.owner.percent_of(major)).to eq(20)
      expect(game.players.find { |player| player.name == 'Bob' }.percent_of(major)).to eq(20)
      expect(major.percent_of(major)).to eq(60)
      expect(game.shares_for_corporation(major).map(&:percent)).to eq([20] + ([10] * 8))
      expect(major.cash).to eq(cash)
      expect(major.trains).to match_array(trains)
      expect(major.trains.map(&:owner).uniq).to eq([major])
      expect(major.tokens.select(&:used).map { |token| token.hex.id }).to match_array(%w[J6 K9])
      expect(major.tokens.reject(&:used).map(&:price)).to eq([60, 60])
      expect(major.share_price.price).to eq(70) # Average of 90 and 60, rounded down to a stock space.
      expect(adaptive.closed?).to be(true)
      expect(mining.closed?).to be(true)
      expect(game.players.flat_map(&:shares).none? { |share| [adaptive, mining].include?(share.corporation) }).to be(true)
      expect(game.company_power?(major, 'AD')).to be(true)
      expect(game.company_power?(major, 'EM')).to be(true)
      expect(game.round.stock?).to be(true)
      expect(game.turn).to eq(3)
      replay = game.clone(game.raw_actions)
      expect(replay.corporation_by_id('Con').cash).to eq(major.cash)
      expect(replay.corporation_by_id('Con').tokens.select(&:used).map { |token| token.hex.id }).to match_array(%w[J6 K9])
    end

    it 'prevents a declined pair being proposed again from the other minor in the same round' do
      game = merger_game
      act(game, :Choose, choice: 'merge:EM')
      act(game, :Choose, choice: 'decline')
      expect(game.round.active_step.source.id).to eq('EM')
      expect(game.round.active_step.choices).to be_empty
      act(game, :Pass)
      expect(game.round.stock?).to be(true)
      expect(game.operating_order.map(&:id)).to match_array(%w[AD EM])
    end

    it 'rejects an unconnected or unavailable partner' do
      game = merger_game
      expect { act(game, :Choose, choice: 'merge:EA') }.to raise_error(GameError, /available merger/)
      game = merger_game
      game.corporation_by_id('EM').tokens.first.remove!
      game.clear_graph
      expect(game.round.active_step.choices).to be_empty
    end

    it 'assigns presidency to the largest combined holder and preserves market-held certificates' do
      game = merger_game
      adaptive = game.corporation_by_id('AD')
      mining = game.corporation_by_id('EM')
      carol = game.players.find { |player| player.name == 'Carol' }
      2.times { transfer(game, adaptive, carol) }
      transfer(game, mining, carol)
      transfer(game, mining, game.share_pool)
      major = form_major(game)
      expect(major.owner).to eq(carol)
      expect(carol.percent_of(major)).to eq(30)
      expect(carol.shares_of(major).map(&:percent)).to eq([20, 10])
      expect(game.share_pool.percent_of(major)).to eq(10)
      expect(major.percent_of(major)).to eq(20)
    end

    it 'lets one president merge their own companies without a redundant consent action' do
      game = merger_game
      adaptive = game.corporation_by_id('AD')
      mining = game.corporation_by_id('EM')
      game.share_pool.transfer_shares(mining.presidents_share.to_bundle, adaptive.owner, allow_president_change: false)
      mining.owner = adaptive.owner
      act(game, :Choose, choice: 'merge:EM')
      expect(game.round.active_step.choices.keys).to include('major:Con')
      act(game, :Choose, choice: 'major:Con')
      expect(game.corporation_by_id('Con').owner.percent_of(game.corporation_by_id('Con'))).to eq(40)
    end

    it 'uses phase-specific major limits and allows inherited Spacious to add one slot' do
      game = merger_game
      major = form_major(game)
      expect(game.train_limit(major)).to eq(4)
      game.phase.buying_train!(major, game.depot.upcoming.find { |train| train.name == '4' }, game.depot)
      expect(game.train_limit(major)).to eq(3)
      game.phase.buying_train!(major, game.depot.upcoming.find { |train| train.name == '5' }, game.depot)
      expect(game.train_limit(major)).to eq(2)
      game.instance_variable_get(:@merged_minors)[major.id] << 'SP'
      expect(game.train_limit(major)).to eq(3)
    end

    it 'keeps a duplicate hub as a free token and retains Expansive’s unused 40 token' do
      game = merger_game
      adaptive = game.corporation_by_id('AD')
      expansive = game.corporation_by_id('EA')
      major = game.corporation_by_id('Con')
      home = adaptive.tokens.first.city
      home.tokens << expansive.tokens.first
      expansive.tokens.first.place(home)
      game.replace_merger_hubs!([adaptive, expansive], major)
      expect(major.tokens.count(&:used)).to eq(1)
      expect(major.tokens.reject(&:used).map(&:price)).to eq([0, 60, 60, 40])
      expect(home.tokens.compact.map(&:corporation)).to eq([major])
    end

    it 'requires the president to discard an excess train before completing the merger round' do
      game = merger_game
      adaptive = game.corporation_by_id('AD')
      mining = game.corporation_by_id('EM')
      game.phase.buying_train!(adaptive, game.depot.upcoming.find { |train| train.name == '4' }, game.depot)
      [adaptive, mining, mining].each do |minor|
        game.buy_train(minor, game.depot.upcoming.find { |train| train.name == '3' }, :free)
      end
      major = form_major(game)
      expect(game.round.merger?).to be(true)
      expect(major.trains.size).to eq(4)
      train = major.trains.first
      act(game, :Choose, choice: "discard:#{train.id}")
      expect(major.trains.size).to eq(3)
      expect(game.depot.discarded).to include(train)
      expect(game.round.stock?).to be(true)
    end

    it 'resolves an export’s reduced train limit before the next stock round without exporting twice' do
      game = merger_game
      major = form_major(game)
      3.times do
        game.buy_train(major, game.depot.upcoming.find { |train| train.name == '3' }, :free)
      end
      # Four green trains are legal in phase 3. The export of the first 4-train
      # rusts the yellow trains and reduces the major limit to three.
      game.instance_variable_set(:@round, Game::GRotla::Round::Merger.new(game, [Game::GRotla::Step::Merger]))
      game.next_round!
      expect(game.round).to be_a(Game::GRotla::Round::ExportDiscard)
      expect(game.phase.name).to eq('4')
      expect(major.trains.size).to eq(4)
      exports = game.depot.upcoming.size
      act(game, :Choose, choice: "discard:#{major.trains.first.id}")
      expect(game.round.stock?).to be(true)
      expect(major.trains.size).to eq(3)
      expect(game.depot.upcoming.size).to eq(exports)
    end

    it 'lets the new major trade shares, issue one 10% share and operate without a minor leadoff train' do
      game = merger_game
      major = form_major(game)
      bob = game.players.find { |player| player.name == 'Bob' }
      expect(game.check_sale_timing(bob, bob.shares_of(major).first.to_bundle)).to be(true)
      3.times { act(game, :Pass) }
      expect(game.current_entity).to eq(major)
      expect(game.round.active_step).to be_a(Game::GRotla::Step::IssueShares)
      cash = major.cash
      act(game, :SellShares, shares: game.issuable_shares(major).first.shares)
      expect(game.share_pool.percent_of(major)).to eq(10)
      expect(major.cash).to eq(cash + 70)
      expect(major.share_price.price).to eq(60)
      act(game, :Pass) # track
      act(game, :Pass) if game.round.active_step.is_a?(Game::GRotla::Step::Token)
      act(game, :Choose, choice: 'local')
      act(game, :Dividend, kind: 'payout')
      expect(major.operated?).to be(true)
      expect(major.operating_history.size).to eq(1)
    end
  end
end
