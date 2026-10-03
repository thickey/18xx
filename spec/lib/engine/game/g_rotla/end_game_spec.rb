# frozen_string_literal: true

require 'spec_helper'
require 'json'

module Engine
  describe Game::GRotla::Game, 'end of game' do
    def ready_game
      fixture = JSON.parse(File.read('spec/fixtures/rotla/hotseat-merger-ready.json'))
      described_class.new(%w[Alice Bob Carol], id: fixture['id'], actions: fixture['actions'])
    end

    def act(game, type, **args)
      game.process_action(Action.const_get(type).new(game.current_entity, **args)).maybe_raise!
    end

    def finish_game(game)
      act(game, :Choose, choice: 'merge:EM')
      act(game, :Choose, choice: 'accept')
      act(game, :Choose, choice: 'major:Con')
      until game.finished
        raise 'Game exceeded its cycle limit' if game.turn > game.cycle_limit

        case game.round.active_step
        when Game::GRotla::Step::Route
          act(game, :Choose, choice: 'local')
        when Step::Dividend
          act(game, :Dividend, kind: 'payout')
        else
          act(game, :Pass)
        end
      end
    end

    it 'uses six Long Game cycles and four Short or Micro Game cycles' do
      [[3, [], 6], [2, [], 4], [3, [:short_game], 4],
       [2, [:micro_game_2], 4], [3, [:micro_game_3], 4]].each do |count, options, limit|
        game = described_class.new(Array.new(count) { |index| "Player #{index}" }, id: '1', optional_rules: options)
        expect(game.cycle_limit).to eq(limit)
      end
    end

    it 'ends after the sixth complete cycle, exports once, scores personal holdings, and replays the ending' do
      game = ready_game
      finish_game(game)
      expect(game.turn).to eq(6)
      expect(game.game_end_reason).to eq(:fixed_round)
      expect(game.game_ending_description).to eq('Game ended after 6 cycles')
      expect(game.corporation_by_id('Con').operating_history.size).to eq(8)
      expect(game.result).to eq(game.players.to_h { |player| [player.id, player.cash + player.shares.sum(&:price)] })
      replay = game.clone(game.raw_actions)
      expect(replay.finished).to be(true)
      expect(replay.turn).to eq(6)
      expect(replay.result).to eq(game.result)
      expect { act(game, :Pass) }.to raise_error(GameIsOver)
    end

    it 'ends Short and Micro Games at cycle four without starting another stock round' do
      [[:short_game], [:micro_game_3]].each do |options|
        game = ready_game
        game.instance_variable_set(:@optional_rules, options)
        finish_game(game)
        expect(game.finished).to be(true)
        expect(game.turn).to eq(4)
        expect(game.game_end_reason).to eq(:fixed_round)
        expect(game.corporation_by_id('Con').operating_history.size).to eq(4)
      end
    end

    it 'ignores a depleted bank and finishes the scheduled remaining cycles' do
      game = ready_game
      game.bank.spend(game.bank.cash + 1, game.players.last)
      expect(game.bank.cash).to be_negative
      game.bank.break!
      expect(game.bank.broken?).to be(true)
      expect(game.send(:game_end_check)).to be_nil
      expect(game.finished).to be(false)
      finish_game(game)
      expect(game.turn).to eq(6)
      expect(game.game_end_reason).to eq(:fixed_round)
    end

    it 'breaks equal scores by the earliest operating company presidency and excludes treasury cash' do
      game = ready_game
      alice = game.players.find { |player| player.name == 'Alice' }
      bob = game.players.find { |player| player.name == 'Bob' }
      alice.set_cash(300 - alice.shares.sum(&:price), game.bank)
      bob.set_cash(300 - bob.shares.sum(&:price), game.bank)
      expect(game.result.keys.first).to eq(alice.id)
      before = game.result
      game.bank.spend(1000, game.corporation_by_id('AD'))
      expect(game.result).to eq(before)
    end

    it 'allows the final merger to finish before ending the game' do
      game = ready_game
      game.instance_variable_set(:@turn, 6)
      act(game, :Choose, choice: 'merge:EM')
      act(game, :Choose, choice: 'accept')
      expect(game.finished).to be(false)
      act(game, :Choose, choice: 'major:Con')
      expect(game.finished).to be(true)
      expect(game.turn).to eq(6)
      expect(game.corporation_by_id('Con').ipoed).to be(true)
    end

    it 'waits for final export discards before scoring and does not export twice' do
      game = ready_game
      act(game, :Choose, choice: 'merge:EM')
      act(game, :Choose, choice: 'accept')
      act(game, :Choose, choice: 'major:Con')
      major = game.corporation_by_id('Con')
      3.times { game.buy_train(major, game.depot.upcoming.find { |train| train.name == '3' }, :free) }
      game.instance_variable_set(:@turn, 6)
      game.instance_variable_set(:@round, Game::GRotla::Round::Merger.new(game, [Game::GRotla::Step::Merger]))
      game.next_round!
      expect(game.round).to be_a(Game::GRotla::Round::ExportDiscard)
      expect(game.finished).to be(false)
      exports = game.depot.upcoming.size
      act(game, :Choose, choice: "discard:#{major.trains.first.id}")
      expect(game.finished).to be(true)
      expect(game.turn).to eq(6)
      expect(game.depot.upcoming.size).to eq(exports)
    end
  end
end
