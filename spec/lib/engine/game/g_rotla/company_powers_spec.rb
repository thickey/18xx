# frozen_string_literal: true

require 'spec_helper'
require 'json'

module Engine
  describe Game::GRotla::Game, 'company powers' do
    def ready_game
      fixture = JSON.parse(File.read('spec/fixtures/rotla/hotseat-rounds-start.json'))
      described_class.new(%w[Alice Bob Carol], id: fixture['id'], actions: fixture['actions'])
    end

    def act(game, type, **args)
      game.process_action(Action.const_get(type).new(game.current_entity, **args)).maybe_raise!
    end

    def launch(game, id)
      act(game, :Bid, price: 125, corporation: game.available_charters.first)
      2.times { act(game, :Pass) }
      act(game, :Choose, choice: id)
      game.corporation_by_id(id)
    end

    # A three-city corridor exercises actual path walking, blocking and routing.
    def corridor(game, corporation)
      corporation.tokens.first.remove!
      hexes = %w[A1 A3 A5].map.with_index do |id, index|
        exits = if index == 0
                  [0]
                else
                  index == 2 ? [3] : [0, 3]
                end
        code = "city=revenue:#{20 + (index * 10)};#{exits.map { |edge| "path=a:#{edge},b:_0" }.join(';')}"
        Hex.new(id, layout: :flat, tile: Tile.from_code("corridor#{index}", :yellow, code))
      end
      game.instance_variable_set(:@hexes, hexes)
      game.send(:connect_hexes)
      game.send(:cache_objects)
      hexes.first.tile.cities.first.place_token(corporation, corporation.tokens.first, free: true)
      game.clear_graph
      hexes
    end

    def train_for(game, corporation, name = '2')
      train = game.depot.upcoming.find { |t| t.name == name }
      game.buy_train(corporation, train, :free)
      train
    end

    it 'lays a finite blue bridge on reachable water as a yellow lay, then replays it' do
      game = ready_game
      launch(game, 'OV')
      launch(game, 'AG')
      corporation = launch(game, 'BR')
      3.times { act(game, :Pass) }
      until game.current_entity == corporation
        step = game.round.active_step
        if step.is_a?(Game::GRotla::Step::Route)
          act(game, :Choose, choice: 'local')
        elsif step.is_a?(Step::Dividend)
          act(game, :Dividend, kind: 'payout')
        elsif step.is_a?(Game::GRotla::Step::BuyTrain) && game.current_entity.trains.empty?
          act(game, :BuyTrain, train: game.depot.upcoming.first, price: 100)
        else
          act(game, :Pass)
        end
      end
      act(game, :Pass) # leadoff
      act(game, :Pass) # issue
      step = game.round.active_step
      expect(step).to be_a(Game::GRotla::Step::Track)
      hex = game.hexes.find { |h| h.tile.color == :blue && step.available_hex(corporation, h) }
      tile = game.tiles.find { |t| t.name == '721' }
      rotation = step.legal_tile_rotations(corporation, hex, tile).first
      expect(rotation).not_to be_nil
      act(game, :LayTile, hex: hex, tile: tile, rotation: rotation)
      expect(game.round.num_laid_track).to eq(1)
      expect(game.round.upgraded_track).to be(false)
      expect(game.tiles.count { |t| t.name == '721' }).to eq(1)
      expect(step.available_hex(corporation, hex)).to be_nil
      expect(game.upgrades_to?(hex.tile, game.tiles.find { |t| t.name == '14' })).to be(false)
      replay = game.clone(game.raw_actions)
      expect(replay.hex_by_id(hex.id).tile.name).to eq('721')
      expect(replay.round.num_laid_track).to eq(1)
    end

    it 'reserves bridges for Bridging and permits its track to enter water, but never the map edge' do
      game = ready_game
      br = game.corporation_by_id('BR')
      hex = corridor(game, br).first
      water = hex.neighbors[0]
      water.lay(Tile.from_code('water', :blue, ''))
      game.clear_graph
      round = Round::Operating.new(game, [Game::GRotla::Step::Track])
      step = round.steps.last
      tile = Tile.from_code('test', :yellow, 'city=revenue:30;path=a:0,b:_0')
      expect(step.legal_tile_rotation?(br, hex, tile)).to be(true)
      expect(step.legal_tile_rotation?(game.corporation_by_id('EM'), hex, tile)).to be(false)
      tile.rotate!(1)
      expect(step.legal_tile_rotation?(br, hex, tile)).to be(false)
      expect(step.potential_tiles(game.corporation_by_id('EM'), water)).to be_empty
    end

    it 'lets Overnight traverse blocked cities for track and routes while excluding their stops and revenue' do
      game = ready_game
      ov = game.corporation_by_id('OV')
      hexes = corridor(game, ov)
      blocker = game.corporation_by_id('EM')
      hexes[1].tile.cities.first.place_token(blocker, blocker.tokens.first, free: true)
      game.clear_graph
      train = train_for(game, ov)
      route = Route.new(game, game.phase, train)
      hexes.each { |hex| route.touch_node(hex.tile.cities.first) }
      expect(route.visited_stops.map { |stop| stop.hex.id }).to contain_exactly('A1', 'A5')
      expect(route.revenue).to eq(60)
      expect(game.graph_for_entity(ov).connected_nodes(ov)).to have_key(hexes.last.tile.cities.first)
      ordinary = game.corporation_by_id('AG')
      ov.tokens.first.remove!
      hexes.first.tile.cities.first.place_token(ordinary, ordinary.tokens.first, free: true)
      game.clear_graph
      expect(game.graph_for_entity(ordinary).connected_nodes(ordinary)).not_to have_key(hexes.last.tile.cities.first)
      route = Route.new(game, game.phase, train_for(game, ordinary))
      hexes.each { |hex| route.touch_node(hex.tile.cities.first) }
      expect { route.revenue }.to raise_error(GameError)
    end

    it 'rejects Overnight ending a route at the blocked city' do
      game = ready_game
      ov = game.corporation_by_id('OV')
      hexes = corridor(game, ov)
      em = game.corporation_by_id('EM')
      hexes[1].tile.cities.first.place_token(em, em.tokens.first, free: true)
      route = Route.new(game, game.phase, train_for(game, ov))
      hexes.take(2).each { |hex| route.touch_node(hex.tile.cities.first) }
      expect { game.check_other(route) }.to raise_error(GameError, /cannot end/)
    end

    it 'places two suburbs during different OR steps without using hubs, and awards only Suburban trains the bonus' do
      game = ready_game
      su = game.corporation_by_id('SU')
      hexes = corridor(game, su)
      round = Round::Operating.new(game, [Game::GRotla::Step::Track, Game::GRotla::Step::Route])
      round.entities = [su]
      track, route_step = round.steps.last(2)
      choices = track.choices
      expect(choices.keys).to eq(%w[suburb:A3 suburb:A5])
      track.process_choose(Action::Choose.new(su, choice: 'suburb:A3'))
      expect(round.num_laid_track).to eq(0)
      expect(su.tokens.size).to eq(1)
      expect(hexes[1].tile.cities.first.tokens.compact).to be_empty
      route_step.process_choose(Action::Choose.new(su, choice: 'suburb:A5'))
      expect(game.suburb_choices(su)).to be_empty
      expect { track.process_choose(Action::Choose.new(su, choice: 'suburb:A3')) }.to raise_error(GameError)
      route = Route.new(game, game.phase, train_for(game, su, '3'))
      hexes.each { |hex| route.touch_node(hex.tile.cities.first) }
      expect(route.revenue).to eq(110)
      expect(game.revenue_for(Route.new(game, game.phase, train_for(game, game.corporation_by_id('EM'), '3')),
                              hexes.map { |h| h.tile.cities.first })).to eq(90)
      replacement = Tile.from_code('upgrade', :green, 'city=revenue:40;path=a:0,b:_0;path=a:3,b:_0')
      hexes[1].lay(replacement)
      expect(replacement.icons.map(&:name)).to include('suburb')
    end

    it 'excludes capitals, mining, ports, existing suburbs and Suburban hubs from suburb choices' do
      game = ready_game
      su = game.corporation_by_id('SU')
      hexes = corridor(game, su)
      %w[C M P].each do |label|
        hexes[1].lay(Tile.from_code('special', :yellow, "city=revenue:30;path=a:0,b:_0;path=a:3,b:_0;label=#{label}"))
        game.clear_graph
        expect(game.suburb_choices(su)).not_to have_key('suburb:A3')
      end
    end

    it 'replays a suburb placement, its sticky icon, a boosted route and dividend from legal Hotseat actions' do
      fixture = JSON.parse(File.read('spec/fixtures/rotla/hotseat-company-powers.json'))
      game = described_class.new(fixture['players'].map { |p| p['name'] }, id: fixture['id'], actions: fixture['actions'])
      su = game.current_entity
      expect(su.id).to eq('SU')
      expect(game.round.active_step).to be_a(Game::GRotla::Step::Token)
      expect(game.round.active_step.choices).to have_key('suburb:H14')
      act(game, :Choose, choice: 'suburb:H14')
      expect(game.round.active_step).to be_a(Game::GRotla::Step::Route)
      route = Route.new(game, game.phase, su.trains.first)
      route.touch_node(su.tokens.first.city)
      route.touch_node(game.hex_by_id('H14').tile.cities.first)
      expect(route.revenue).to eq(50)
      act(game, :RunRoutes, routes: [route])
      act(game, :Dividend, kind: 'payout')
      expect(su.cash).to eq(55)
      replay = game.clone(game.raw_actions)
      expect(replay.suburbs).to eq(['H14'])
      expect(replay.hex_by_id('H14').tile.icons.map(&:name)).to include('suburb')
      expect(replay.corporation_by_id('SU').cash).to eq(55)
    end

    it 'retains Resourceful trains at rust, excludes them from limits and trades, then discards them after payout' do
      game = ready_game
      re = game.corporation_by_id('RE')
      # Launch directly for an isolated train lifecycle test.
      game.charter_columns.unshift([re])
      game.launch_minor!(game.players.first, re, 125)
      corridor(game, re)
      train = train_for(game, re)
      game.rust_trains!(game.depot.upcoming.find { |t| t.name == '4' }, re)
      expect(train.rusted).to be(true)
      expect(train.owner).to eq(re)
      expect(game.route_trains(re)).to include(train)
      expect(game.num_corp_trains(re)).to eq(0)
      expect { game.buy_train(game.corporation_by_id('EM'), train, 1) }.to raise_error(GameError, /cannot be sold/)
      expect(game.discountable_trains_for(re)).to be_empty
      round = Round::Operating.new(game, [Game::GRotla::Step::Track, Game::GRotla::Step::Route, Game::GRotla::Step::Dividend])
      round.entities = [re]
      route, dividend = round.steps.last(2)
      route.process_choose(Action::Choose.new(re, choice: 'local'))
      expect(round.extra_revenue).to eq(20)
      dividend.process_dividend(Action::Dividend.new(re, kind: 'payout'))
      expect(train.owner).to be_nil
      expect(re.trains).to be_empty
      expect(game.must_buy_train?(re)).to be(true)
    end

    it 'recomputes revenue when a suburb is placed after tracing routes but before the dividend' do
      fixture = JSON.parse(File.read('spec/fixtures/rotla/hotseat-company-powers.json'))
      game = described_class.new(fixture['players'].map { |p| p['name'] }, id: fixture['id'], actions: fixture['actions'])
      su = game.current_entity
      act(game, :Pass)
      route = Route.new(game, game.phase, su.trains.first)
      route.touch_node(su.tokens.first.city)
      route.touch_node(game.hex_by_id('H14').tile.cities.first)
      expect(route.revenue).to eq(40)
      act(game, :RunRoutes, routes: [route])
      expect(game.round.active_step).to be_a(Game::GRotla::Step::Dividend)
      act(game, :Choose, choice: 'suburb:H14')
      expect(game.round.routes.first.revenue).to eq(50)
      act(game, :Dividend, kind: 'payout')
      expect(su.cash).to eq(55)
      expect(game.clone(game.raw_actions).corporation_by_id('SU').cash).to eq(55)
    end

    it 'does not offer suburbs while another company is operating and Suburban must discard trains' do
      game = ready_game
      su = game.corporation_by_id('SU')
      corridor(game, su)
      3.times { train_for(game, su) }
      round = Round::Operating.new(game, [Game::GRotla::Step::DiscardTrain])
      round.entities = [game.corporation_by_id('EM'), su]
      expect(game.suburb_choices(su)).not_to be_empty
      expect(round.steps.last.actions(su)).to eq(['discard_train'])
    end
  end
end
