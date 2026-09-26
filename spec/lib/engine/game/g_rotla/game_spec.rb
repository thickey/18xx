# frozen_string_literal: true

require 'spec_helper'

module Engine
  describe Game::GRotla::Game do
    let(:game) { described_class.new(%w[Alice Bob], id: '1') }

    def choose(game, choice)
      game.process_action(Action::Choose.new(game.current_entity, choice: choice)).maybe_raise!
    end

    def place(game, rotation = 0, anchor = nil)
      choose(game, 'draw_v2') if game.drawn_piece.nil?
      q, r = anchor || game.legal_anchors(rotation).first
      choose(game, "place_v2:#{game.drawn_piece}:#{q}:#{r}:#{rotation}")
    end

    def map_signature(game)
      game.hexes.map { |hex| [hex.id, hex.tile.color, hex.tile.code] }
    end

    it 'starts with four unplaced pieces and restricts setup to the first player' do
      expect(Engine.game_by_title('RotLA')).to eq(described_class)
      expect(described_class.meta.fs_name).to eq('g_rotla')
      expect(game.placements).to be_empty
      expect(game.hexes.reject(&:empty)).to be_empty
      expect(game.legal_anchors(0)).to eq([[0, 0]])
      expect(game.round.actions_for(game.players.last)).not_to include('choose')
      expect do
        game.round.process_action(Action::Choose.new(game.players.last, choice: 'place_v1:0:0:0:0'))
      end.to raise_error(GameError)
    end

    it 'keeps every rotated piece triangular and preserves terrain order' do
      6.times do |rotation|
        cells = game.piece_cells(0, 0, rotation, 3)
        expect(cells.map(&:last)).to eq(%i[city water water])
        cells.combination(2) do |a, b|
          expect(Game::GRotla::MapBuilder::DIRECTIONS).to include([a[0] - b[0], a[1] - b[1]])
        end
      end
      expect(game.piece_cells(0, 0, 6, 3)).to eq(game.piece_cells(0, 0, 0, 3))
    end

    it 'completes exactly four pieces and builds a connected 12-hex normal map' do
      [0, 1, 3, 5].each_with_index do |rotation, index|
        place(game, rotation)
        expect(game.hexes.size).to eq((index + 1) * 3)
      end
      expect(game.round).to be_instance_of(Game::GRotla::Round::MapReady)
      expect(game.placed_cells.map(&:last).tally).to eq(blank: 7, city: 2, mountain: 1, water: 2)
      reached = [game.hexes.first]
      loop do
        expanded = (reached + reached.flat_map { |h| h.neighbors.values }).uniq
        break if expanded.size == reached.size

        reached = expanded
      end
      expect(reached.size).to eq(12)
      game.hexes.each do |hex|
        expect(game.hex_by_id(hex.id)).to equal(hex)
        hex.tile.cities.each { |city| expect(game.city_by_id(city.id)).to equal(city) }
      end
      expect { game.place_map_piece!(4, 0, 0, 0) }.to raise_error(GameError)
      expect(map_signature(game.starting_map)).to eq(map_signature(game))
    end

    it 'rejects overlap, isolated placement, invalid rotation, and out-of-order pieces without changing the map' do
      place(game)
      choose(game, 'draw_v2')
      piece = game.drawn_piece
      original = map_signature(game)
      [[piece, 0, 0, 0], [piece, 20, 20, 0], [piece, 0, 2, 6], [(piece + 1) % 4, 0, 2, 0]].each do |args|
        expect { game.place_map_piece!(*args) }.to raise_error(GameError)
        expect(map_signature(game)).to eq(original)
        expect(game.placements.size).to eq(1)
      end
      expect { choose(game, 'place_v1:1:wat:0:0') }.to raise_error(GameError)
    end

    it 'allows edge contact with any of the three cells, not just the anchor' do
      place(game)
      expect(game.legal_anchors(0)).to include([-2, 0])
      place(game, 0, [-2, 0])
      expect(game.placements.size).to eq(2)
    end

    it 'reconstructs placements, terrain, and completion from exported JSON actions' do
      [0, 2, 4, 1].each { |rotation| place(game, rotation) }
      restored = Engine::Game.load(JSON.generate({
                                                   title: 'RotLA',
                                                   id: '1',
                                                   players: [{ id: 'Alice', name: 'Alice' }, { id: 'Bob', name: 'Bob' }],
                                                   actions: game.raw_actions,
                                                 }))
      expect(restored.placements).to eq(game.placements)
      expect(map_signature(restored)).to eq(map_signature(game))
      expect(restored.round).to be_instance_of(Game::GRotla::Round::MapReady)
    end

    it 'undoes the last placement back into setup and redoes completion' do
      4.times { place(game) }
      signature = map_signature(game)
      undone = game.process_action(Action::Undo.new(game.players.first)).maybe_raise!
      expect(undone.placements.size).to eq(3)
      expect(undone.hexes.size).to eq(9)
      expect(undone.round).to be_instance_of(Game::GRotla::Round::Setup)
      redone = undone.process_action(Action::Redo.new(undone.players.first)).maybe_raise!
      expect(map_signature(redone)).to eq(signature)
      expect(redone.round).to be_instance_of(Game::GRotla::Round::MapReady)
    end

    it 'creates different maps in independent instances' do
      other = described_class.new(%w[Carol Dan], id: '2')
      4.times { place(game, 0) }
      4.times { place(other, 3) }
      expect(map_signature(other)).not_to eq(map_signature(game))
    end

    it 'can start another map and undo the restart' do
      4.times { place(game) }
      signature = map_signature(game)
      choose(game, 'reopen')
      expect(game.placements).to be_empty
      expect(game.hexes.reject(&:empty)).to be_empty
      restored = game.process_action(Action::Undo.new(game.players.first)).maybe_raise!
      expect(map_signature(restored)).to eq(signature)
    end

    it 'replays older preset-picker saves' do
      choose(game, 'corridor_v1')
      choose(game, 'confirm')
      expect(game.hexes.size).to eq(15)
      expect(game.round).to be_instance_of(Game::GRotla::Round::MapReady)
      expect(map_signature(game.starting_map)).to eq(map_signature(game))
    end

    it 'alternates players after placement, but not after drawing' do
      actors = []
      4.times do
        actor = game.current_entity
        actors << actor.name
        choose(game, 'draw_v2')
        expect(game.current_entity).to equal(actor)
        other = (game.players - [actor]).first
        expect(game.round.actions_for(other)).not_to include('choose')
        expect { game.draw_map_piece! }.to raise_error(GameError)
        place(game)
      end
      expect(actors).to eq(%w[Alice Bob Alice Bob])
      expect(game.placements.map { |p| p[:piece] }.sort).to eq([0, 1, 2, 3])
    end

    it 'uses the saved seed for repeatable draws and varies across seeds' do
      orders = (1..6).map do |seed|
        original = described_class.new(%w[Alice Bob], id: '1', seed: seed)
        same_seed = described_class.new(%w[Alice Bob], id: '99', seed: seed)
        4.times do
          place(original)
          place(same_seed)
        end
        ids = original.placements.map { |p| p[:piece] }
        expect(same_seed.placements.map { |p| p[:piece] }).to eq(ids)
        ids
      end
      expect(orders.uniq.size).to be > 1
    end

    it 'restores the drawn piece and active player when undoing or reloading mid-turn' do
      place(game)
      choose(game, 'draw_v2')
      piece = game.drawn_piece
      restored = game.clone(game.raw_actions)
      expect(restored.drawn_piece).to eq(piece)
      expect(restored.current_entity.name).to eq('Bob')
      place(game)
      undone = game.process_action(Action::Undo.new(game.current_entity)).maybe_raise!
      expect(undone.current_entity.name).to eq('Bob')
      expect(undone.drawn_piece).to eq(piece)
      undone = undone.process_action(Action::Undo.new(undone.current_entity)).maybe_raise!
      expect(undone.drawn_piece).to be_nil
      choose(undone, 'draw_v2')
      expect(undone.drawn_piece).to eq(piece)
    end

    it 'rejects placement before drawing and rejects a different piece' do
      expect { game.place_map_piece!(0, 0, 0, 0) }.to raise_error(GameError, 'Wrong map piece')
      choose(game, 'draw_v2')
      expect { game.place_map_piece!((game.drawn_piece + 1) % 4, 0, 0, 0) }.to raise_error(GameError, 'Wrong map piece')
      expect(game.placements).to be_empty
    end

    it 'continues old fixed-order placement saves without changing their map' do
      4.times do |piece|
        q, r = game.legal_anchors(0).first
        choose(game, "place_v1:#{piece}:#{q}:#{r}:0")
      end
      expect(game.placements.map { |p| p[:piece] }).to eq([0, 1, 2, 3])
      expect(map_signature(game.clone(game.raw_actions))).to eq(map_signature(game))
    end

    it 'keeps existing games starting-map behavior' do
      existing = Game::G1889::Game.new(%w[Alice Bob], id: '2')
      expect(map_signature(existing.starting_map)).to eq(map_signature(existing.clone([])))
    end
  end
end
