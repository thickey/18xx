# frozen_string_literal: true

require 'spec_helper'

module Engine
  describe Game::GRotla::Game, 'setup options and blank hexes' do
    def choose(game, choice)
      game.process_action(Action::Choose.new(game.current_entity, choice: choice)).maybe_raise!
    end

    def game_for(players, rules = [], seed = '1')
      game = described_class.new(%w[Alice Bob Carol Dave Eve].take(players), id: seed, optional_rules: rules)
      choose(game, 'start_v5')
      game
    end

    def construct(game)
      until game.construction_complete?
        choose(game, 'draw_v4')
        if game.drawn_project
          q, r = game.capital_choices.first
          choose(game, "capital_v4:#{q}:#{r}")
          next
        end
        candidates = 6.times.flat_map do |rotation|
          game.legal_anchors(rotation).map { |x, y| [x, y, rotation] }
        end
        q, r, rotation = candidates.min_by { |x, y, rot| [x.abs + y.abs + (x + y).abs, x, y, rot] }
        raise 'No legal anchor' unless q

        id = game.real_catalog[game.drawn_piece][:id]
        choose(game, "place_v4:#{id}:#{q}:#{r}:#{rotation}")
      end
    end

    it 'starts construction and draws the first piece in one action' do
      game = described_class.new(%w[Alice Bob Carol], id: '1', optional_rules: [:short_game])
      choose(game, 'start_build_v5')
      expect(game.real_setup).to be(true)
      expect(game.current_piece).not_to be_nil
      expect(game.placements).to be_empty
      expect(game.clone(game.raw_actions).current_piece).to eq(game.current_piece)
    end

    it 'exposes player-count restrictions and rejects incompatible modes before setup' do
      meta = described_class.meta
      expect(meta::OPTIONAL_RULES.find { |rule| rule[:sym] == :micro_game_2 }[:players]).to eq([2])
      expect(meta::OPTIONAL_RULES.find { |rule| rule[:sym] == :micro_game_3 }[:players]).to eq([3])
      expect(meta.check_options([:short_game], 5, 5)[:error]).to include('five')
      expect(meta.check_options([:micro_game_3], 2, 3)[:error]).to include('exactly 3')
      expect(meta.check_options(%i[short_game micro_game_2], 2, 2)[:error]).to include('only one')
      expect { game_for(4, [:micro_game_3]) }.to raise_error(GameError, /exactly 3/)
      expect { game_for(2, %i[short_game micro_game_2]) }.to raise_error(GameError, /only one/)
    end

    it 'partitions the full physical supply into balanced seeded Micro Game stacks' do
      [2, 3].each do |players|
        signatures = []
        6.times do |seed|
          game = game_for(players, ["micro_game_#{players}".to_sym], seed.to_s)
          catalog = game.real_catalog
          expect(catalog.size).to eq(players == 2 ? 11 : 16)
          expect(catalog.count { |p| p[:home] || p[:number] == 21 }).to eq(players == 2 ? 4 : 6)
          expect(catalog.count { |p| p[:number] >= 26 }).to eq(1)
          expect(catalog.count { |p| !p[:home] && p[:number] != 21 && p[:number] < 26 }).to eq(players == 2 ? 6 : 9)
          expect(catalog.map { |p| p[:id] }).not_to include('260') if players == 3
          expect(game.capital_count).to eq(1)
          expect(game.setup_minor_ids.size).to eq(players == 2 ? 4 : 6)
          expect(game.short_map?).to be(false)
          expect(game.clone(game.raw_actions).real_catalog).to eq(catalog)
          signatures << catalog.map { |p| p[:id] }
        end
        expect(signatures.uniq.size).to be > 1
      end
    end

    it 'retains base Short and Long supply choices and holds new setups open for optional blanks' do
      [[2, [], 25], [3, [:short_game], 25], [4, [], 33], [5, [], 33]].each do |players, rules, count|
        game = game_for(players, rules)
        expect(game.piece_count).to eq(count)
        expect(game.blank_hex_phase?).to be(false)
        expect { choose(game, 'blank_v5:0:0') }.to raise_error(GameError)
      end
      [2, 3].each do |players|
        game = game_for(players, ["micro_game_#{players}".to_sym], '3722698')
        construct(game)
        expect(game.blank_hex_phase?).to be(true)
        expect(game.setup_complete?).to be(false)
        expect(game.round).to be_instance_of(Game::GRotla::Round::Setup)
        choose(game, 'finish_setup_v5')
        expect(game.setup_complete?).to be(true)
        expect(game.round).to be_instance_of(Game::GRotla::Round::Stock)
        expect(game.playing).to be(true)
      end
    end

    it 'adds at most twelve single blank hexes, without requiring three shared edges, and preserves replay/undo' do
      game = game_for(3, [], '3722698')
      construct(game)
      original_count = game.hexes.size
      q, r = game.blank_hex_anchors.first
      expect(q).not_to be_nil
      choose(game, "blank_v5:#{q}:#{r}")
      expect(game.hexes.size).to eq(original_count + 1)
      hex = game.hex_by_id(game.map_coordinate(q, r))
      expect(hex.tile.code).to eq('')
      expect(hex.tile.color).to eq(:white)
      expect(hex.empty).to be(false)
      expect(game.legal_blank_hex?(q, r)).to be(false)
      expect(game.legal_blank_hex?(50, 50)).to be(false)
      replay = game.clone(game.raw_actions)
      expect(replay.blank_hexes).to eq(game.blank_hexes)
      undone = game.process_action(Action::Undo.new(game.current_entity)).maybe_raise!
      expect(undone.blank_hexes).to be_empty
      game = undone.process_action(Action::Redo.new(undone.current_entity)).maybe_raise!
      expect(game.blank_hexes).to eq([[q, r]])
      while game.blank_hexes.size < 12 && !game.blank_hex_anchors.empty?
        x, y = game.blank_hex_anchors.first
        expect(x).not_to be_nil
        choose(game, "blank_v5:#{x}:#{y}")
      end
      placed = game.blank_hexes.size
      expect(placed).to be <= 12
      expect(game.blank_hex_anchors).to be_empty
      choose(game, 'finish_setup_v5')
      expect(game.clone(game.raw_actions).hexes.size).to eq(original_count + placed)
    end

    it 'rejects a thirteenth blank even when an otherwise legal home-adjacent cell remains' do
      game = game_for(3)
      index = game.real_catalog.index { |piece| piece[:id] == '01' }
      game.instance_variable_set(:@placements, [{ piece: index, q: 0, r: 0, rotation: 0 }])
      allow(game).to receive(:construction_complete?).and_return(true)
      expect(game.legal_blank_hex?(-1, 0)).to be(true)
      game.instance_variable_set(:@blank_hexes, Array.new(12) { |i| [20, i] })
      expect { choose(game, 'blank_v5:-1:0') }.to raise_error(GameError, /maximum 12/)
      expect(game.blank_hexes.size).to eq(12)
    end

    it 'excludes blanks adjacent to border cells, including empty cells beside a Port home' do
      game = game_for(3)
      index = game.real_catalog.index { |piece| piece[:id] == '07' }
      game.instance_variable_set(:@placements, [{ piece: index, q: 0, r: 0, rotation: 0 }])
      allow(game).to receive(:construction_complete?).and_return(true)
      # Port (1,0) is adjacent to (1,-1), which is also adjacent to border (0,0).
      expect(game.legal_blank_hex?(1, -1)).to be(false)
      expect(game.legal_blank_hex?(2, 0)).to be(true)
      expect(game.legal_blank_hex?(1, 1)).to be(true)
    end
  end
end
