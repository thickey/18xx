# frozen_string_literal: true

require 'spec_helper'
require 'json'

module Engine
  describe Game::GRotla::Game, 'second printing rules' do
    def emergency_game(cash: 0)
      fixture = JSON.parse(File.read('data/rotla/hotseat-merger-ready.json'))
      game = described_class.new(%w[Alice Bob Carol], id: fixture['id'], actions: fixture['actions'])
      corp = game.corporation_by_id('AD')
      corp.trains.dup.each { |train| game.rust(train) }
      corp.set_cash(0, game.bank)
      corp.owner.set_cash(cash, game.bank)
      other = game.corporation_by_id('EM')
      2.times do
        share = other.shares_of(other).find { |candidate| !candidate.president }
        game.share_pool.transfer_shares(share.to_bundle, corp.owner, allow_president_change: false)
      end
      round = Round::Operating.new(game, [Game::GRotla::Step::Bankrupt, Game::GRotla::Step::BuyTrain], round_num: 1)
      game.instance_variable_set(:@round, round)
      round.setup
      [game, corp, other]
    end

    def sell(game, corp, other)
      share = corp.owner.shares_of(other).find { |candidate| !candidate.president }
      game.process_action(Action::SellShares.new(corp.owner, shares: [share])).maybe_raise!
    end

    it 'adds a 3 and a 6 at four and five players, before Short Game removals' do
      [[3, [], 5, 2], [4, [], 6, 3], [5, [], 6, 3],
       [4, [:short_game], 5, 2],
       [2, [:micro_game_2], 3, nil], [3, [:micro_game_3], 4, nil]].each do |count, options, threes, sixes|
        game = described_class.new(Array.new(count) { |index| "Player #{index}" }, id: '1', optional_rules: options)
        roster = game.game_trains.to_h { |train| [train[:name], train[:num]] }
        expect(roster['3']).to eq(threes)
        expect(roster['6']).to eq(sixes)
      end
    end

    it 'sells single shares at the unchanged price and drops each company once after buying' do
      game, corp, other = emergency_game(cash: 80)
      price = other.share_price
      expect(game.round.active_step.current_entity).to eq(corp)
      sell(game, corp, other)
      sell(game, corp, other)
      expect(corp.owner.cash).to eq(200)
      expect(other.share_price).to eq(price)
      train = game.depot.min_depot_train
      game.process_action(Action::BuyTrain.new(corp, train: train, price: train.price)).maybe_raise!
      expect(other.share_price.price).to eq(50)
      expect(corp.trains).to include(train)
      expect(game.finished).to be(false)
    end

    it 'requires exhausting legal forced sales before bankruptcy and ends immediately' do
      game, corp, other = emergency_game
      expect(game.can_go_bankrupt?(corp.owner, corp)).to be(false)
      sell(game, corp, other)
      expect(game.can_go_bankrupt?(corp.owner, corp)).to be(false)
      sell(game, corp, other)
      expect(game.can_go_bankrupt?(corp.owner, corp)).to be(true)
      game.process_action(Action::Bankrupt.new(corp)).maybe_raise!
      expect(corp.owner.bankrupt).to be(true)
      expect(other.share_price.price).to eq(50)
      expect(game.finished).to be(true)
      expect(game.game_end_reason).to eq(:bankrupt)
    end

    it 'rejects bundled emergency sales and dumping the operating presidency' do
      game, corp, other = emergency_game
      step = game.round.active_step
      expect(step.can_sell?(corp.owner, ShareBundle.new(corp.owner.shares_of(other)))).to be(false)
      expect(step.can_sell?(corp.owner, corp.presidents_share.to_bundle)).to be(false)
    end

    it 'allows offboard endpoints but rejects passing through an offboard' do
      game = described_class.new(%w[Alice Bob Carol], id: '1')
      city = instance_double(Part::City, offboard?: false)
      offboard = instance_double(Part::Offboard, offboard?: true)
      route = instance_double(Route, corporation: game.corporation_by_id('AD'), visited_stops: [],
                                     connection_data: [{ left: offboard, right: city }])
      expect { game.check_other(route) }.not_to raise_error
      allow(route).to receive(:connection_data).and_return([{ left: city, right: offboard }, { left: offboard, right: city }])
      expect { game.check_other(route) }.to raise_error(GameError, /offboard/)
    end
  end
end
