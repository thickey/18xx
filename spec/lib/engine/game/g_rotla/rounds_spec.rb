# frozen_string_literal: true

require 'spec_helper'
require 'json'

module Engine
  describe Game::GRotla::Game, 'rounds' do
    def ready_game
      fixture = JSON.parse(File.read('data/rotla/hotseat-rounds-start.json'))
      described_class.new(%w[Alice Bob Carol], id: fixture['id'], actions: fixture['actions'])
    end

    def act(game, type, **args)
      game.process_action(Action.const_get(type).new(game.current_entity, **args)).maybe_raise!
    end

    def launch(game, id = nil, bid = 125)
      act(game, :Bid, price: bid, corporation: game.available_charters.first)
      2.times { act(game, :Pass) }
      corp = id ? game.corporation_by_id(id) : game.available_charters.find { |c| c.id != 'AD' }
      act(game, :Choose, choice: corp.id)
      act(game, :Choose, choice: "home:#{game.adaptive_home_choices.first.id}") if corp.id == 'AD'
      corp
    end

    def finish_stock(game)
      3.times { act(game, :Pass) }
    end

    def finish_operator(game, run: true)
      while game.round.operating?
        step = game.round.active_step
        if step.is_a?(Game::GRotla::Step::Route)
          act(game, :Choose, choice: 'local')
        elsif step.is_a?(Step::Dividend)
          act(game, :Dividend, kind: run ? 'payout' : 'withhold')
        elsif step.is_a?(Game::GRotla::Step::BuyTrain) && game.current_entity.trains.empty?
          act(game, :BuyTrain, train: game.depot.upcoming.first, price: game.depot.upcoming.first.price)
        else
          act(game, :Pass)
        end
      end
    end

    it 'starts a funded Stock Round with randomized charter columns and actual home reservations' do
      game = ready_game
      expect(game.round).to be_a(Game::GRotla::Round::Stock)
      expect(game.players.map(&:cash)).to eq([300, 300, 300])
      expect(game.charter_columns.map(&:size)).to eq([4, 4, 4])
      expect(game.available_charters.map(&:id)).to eq(%w[EM OV AD])
      expect(game.corporations.count { |corp| corp.type == :minor }).to eq(12)
      expect(game.available_majors.size).to eq(6)
      expect(game.depot.upcoming.map(&:name).tally).to include('2' => 7, '3' => 5, '4' => 4)
    end

    it 'bids clockwise, excludes passed bidders, funds the winning charter and resumes after the initiator' do
      game = ready_game
      initiator = game.current_entity
      act(game, :Bid, price: 125, corporation: game.available_charters.first)
      winner = game.current_entity
      act(game, :Bid, price: 135, corporation: game.available_charters.first)
      act(game, :Pass)
      act(game, :Pass)
      expect(game.current_entity).to eq(winner)
      act(game, :Choose, choice: 'EM')
      corp = game.corporation_by_id('EM')
      expect(corp.owner).to eq(winner)
      expect(corp.cash).to eq(135)
      expect(corp.share_price.price).to eq(60)
      expect(winner.cash).to eq(165)
      expect(winner.percent_of(corp)).to eq(40)
      expect(corp.percent_of(corp)).to eq(60)
      expect(corp.tokens.first.city.reserved_by?(corp)).to be(false)
      expect(corp.tokens.first.used).to be(true)
      expect(game.current_entity).to eq(game.players[(game.players.index(initiator) + 1) % 3])
      replay = game.clone(game.raw_actions)
      expect(replay.corporation_by_id('EM').cash).to eq(135)
      expect(replay.current_entity.id).to eq(game.current_entity.id)
    end

    it 'validates bid increments, affordable bids and unavailable charter choices' do
      game = ready_game
      expect { act(game, :Bid, price: 121, corporation: game.available_charters.first) }.to raise_error(GameError, /multiples/)
      game = ready_game
      act(game, :Bid, price: 120, corporation: game.available_charters.first)
      2.times { act(game, :Pass) }
      unavailable = game.corporations.find { |corp| !game.available_charters.include?(corp) }
      expect { act(game, :Choose, choice: unavailable.id) }.to raise_error(GameError, /available/)
    end

    it 'launches Adaptive at a chosen unreserved basic city' do
      game = ready_game
      corp = launch(game, 'AD')
      expect(game.hex_by_id(corp.coordinates).tile.label).to be_nil
      expect(corp.tokens.first.used).to be(true)
      expect(corp.tokens.first.city.reservations.compact).to be_empty
    end

    it 'supports treasury purchases, a first leadoff train, two local ORs, share sales and market purchases' do
      game = ready_game
      corp = launch(game)
      buyer = game.current_entity
      share = corp.shares_of(corp).first
      act(game, :BuyShares, shares: share)
      expect(corp.cash).to eq(185)
      expect(buyer.percent_of(corp)).to eq(20)
      expect(game.round.active_step.can_sell?(buyer, share.to_bundle)).to be(false)
      act(game, :Pass)
      finish_stock(game)
      expect(game.round.round_num).to eq(1)
      act(game, :BuyTrain, train: game.depot.upcoming.first, price: 100)
      expect(corp.trains.size).to eq(1)
      expect(corp.cash).to eq(85)
      finish_operator(game)
      expect(game.round.stock?).to be(true)
      expect(game.turn).to eq(2)
      expect(corp.operating_history.size).to eq(2)
      expect(corp.cash).to eq(109) # 40% treasury holdings receive 12 per OR.
      expect(corp.share_price.price).to eq(60)
      act(game, :Pass) until game.current_entity == buyer
      act(game, :SellShares, shares: buyer.shares_of(corp))
      expect(corp.share_price.price).to eq(50)
      expect(game.share_pool.percent_of(corp)).to eq(20)
      expect(game.round.active_step.can_buy?(buyer, game.share_pool.shares_of(corp).first.to_bundle)).to be(false)
      act(game, :Pass)
      purchaser = game.current_entity
      act(game, :BuyShares, shares: game.share_pool.shares_of(corp).first)
      expect(purchaser.percent_of(corp)).to eq(20)
      expect(game.share_pool.percent_of(corp)).to eq(0)
      replay = game.clone(game.raw_actions)
      expect(replay.corporation_by_id(corp.id).cash).to eq(corp.cash)
      expect(replay.players.map(&:cash)).to eq(game.players.map(&:cash))
    end

    it 'allows one issue or redemption and pays the treasury without a presidency change' do
      game = ready_game
      corp = launch(game)
      finish_stock(game)
      act(game, :Pass) # optional leadoff train
      expect(game.round.active_step).to be_a(Game::GRotla::Step::IssueShares)
      act(game, :SellShares, shares: game.issuable_shares(corp).first.shares)
      expect(corp.cash).to eq(185)
      expect(corp.share_price.price).to eq(50)
      expect(game.share_pool.percent_of(corp)).to eq(20)
      expect(game.round.active_step).to be_a(Game::GRotla::Step::Track)
      expect(corp.owner.name).to eq('Alice')
    end

    it 'transfers presidency on a larger holding, respects 60% ownership, and increases sold-out stock once' do
      game = ready_game
      corp = launch(game)
      buyer = game.current_entity
      3.times do |index|
        act(game, :BuyShares, shares: corp.shares_of(corp).find { |share| !share.president })
        expect(corp.owner.name).to eq('Alice') if index < 2
        act(game, :Pass)
        2.times { act(game, :Pass) }
      end
      expect(corp.owner).to eq(buyer)
      expect(buyer.percent_of(corp)).to eq(60)
      expect(game.players.find { |player| player.name == 'Alice' }.percent_of(corp)).to eq(40)
      expect(corp.holding_ok?(buyer, 20)).to be(false)
      act(game, :Pass)
      expect(game.round.operating?).to be(true)
      expect(corp.share_price.price).to eq(70)
      expect(game.players.first.name).to eq('Carol')
    end

    it 'redeems a bank share at current stock value without moving the price' do
      game = ready_game
      corp = launch(game)
      finish_stock(game)
      act(game, :BuyTrain, train: game.depot.upcoming.first, price: 100)
      act(game, :SellShares, shares: game.issuable_shares(corp).first.shares)
      act(game, :Pass)
      act(game, :Choose, choice: 'local')
      act(game, :Dividend, kind: 'payout')
      # Treasury is below the price of a second train, so train buying skips.
      expect(game.round.round_num).to eq(2)
      cash = corp.cash
      price = corp.share_price.price
      act(game, :BuyShares, shares: game.redeemable_shares(corp).first.shares)
      expect(corp.cash).to eq(cash - price)
      expect(corp.share_price.price).to eq(price)
      expect(game.share_pool.percent_of(corp)).to eq(0)
    end

    it 'keeps all-pass initial stock rounds funded only once and reshuffles charters' do
      game = ready_game
      previous = game.charter_columns.map { |column| column.map(&:id) }
      finish_stock(game)
      expect(game.round.stock?).to be(true)
      expect(game.players.map(&:cash)).to eq([300, 300, 300])
      expect(game.charter_columns.map { |column| column.map(&:id) }).not_to eq(previous)
    end

    it 'runs a traced two-stop Mining route and preserves its revenue on replay' do
      game = ready_game
      corp = launch(game)
      finish_stock(game)
      act(game, :BuyTrain, train: game.depot.upcoming.first, price: 100)
      act(game, :Pass)
      act(game, :Pass)
      home = game.hex_by_id(corp.coordinates)
      route = Route.new(game, game.phase, corp.trains.first)
      home.tile.cities.each { |city| route.touch_node(city) }
      expect(route.revenue).to eq(50)
      act(game, :RunRoutes, routes: [route])
      expect(game.round.active_step.total_revenue).to eq(50)
      replay = game.clone(game.raw_actions)
      expect(replay.round.active_step.total_revenue).to eq(50)
      act(game, :Dividend, kind: 'payout')
      expect(corp.cash).to eq(55) # Three treasury shares earn 10 each.
    end

    it 'lays reachable yellow track, keeps the home hub, and rejects exits leading off-map' do
      game = ready_game
      corp = launch(game, 'AD')
      finish_stock(game)
      act(game, :BuyTrain, train: game.depot.upcoming.first, price: 100)
      act(game, :Pass) # issuing
      step = game.round.active_step
      expect(step).to be_a(Game::GRotla::Step::Track)
      home = game.hex_by_id(corp.coordinates)
      tile = step.upgradeable_tiles(corp, home).find { |candidate| candidate.name == '5' }
      expect(tile).not_to be_nil
      rotation = tile.legal_rotations.first
      act(game, :LayTile, hex: home, tile: tile, rotation: rotation)
      expect(home.tile.color).to eq(:yellow)
      expect(home.tile.cities.first.tokened_by?(corp)).to be(true)
      expect(game.round.num_laid_track).to eq(1)
      edge_hex = game.hexes.find { |hex| !hex.empty && hex.tile.color == :white && hex.all_neighbors.size < 6 }
      candidate = game.tiles.find { |t| t.name == '9' }
      illegal = 6.times.find do |rot|
        candidate.rotate!(rot)
        candidate.exits.any? { |edge| !edge_hex.all_neighbors[edge] }
      end
      candidate.rotate!(illegal)
      expect(step.legal_tile_rotation?(corp, edge_hex, candidate)).to be(false)
      replay = game.clone(game.raw_actions)
      expect(replay.hex_by_id(home.id).tile.name).to eq(home.tile.name)
    end
  end
end
