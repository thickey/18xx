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
      q, r = anchor || game.legal_anchors(rotation, strict: false).first
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
      expect(game.legal_anchors(0, strict: false)).to include([-2, 0])
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
        q, r = game.legal_anchors(0, strict: false).first
        choose(game, "place_v1:#{piece}:#{q}:#{r}:0")
      end
      expect(game.placements.map { |p| p[:piece] }).to eq([0, 1, 2, 3])
      expect(map_signature(game.clone(game.raw_actions))).to eq(map_signature(game))
    end

    it 'keeps existing games starting-map behavior' do
      existing = Game::G1889::Game.new(%w[Alice Bob], id: '2')
      expect(map_signature(existing.starting_map)).to eq(map_signature(existing.clone([])))
    end

    it 'requires three shared edges for new placements while preserving older action replay' do
      place(game)
      choose(game, 'draw_v2')
      directions = Game::GRotla::MapBuilder::DIRECTIONS
      occupied = game.placed_cells.map { |x, y, _| [x, y] }
      6.times do |rotation|
        game.legal_anchors(rotation, strict: false).each do |q, r|
          contacts = game.piece_cells(q, r, rotation).sum do |x, y, _|
            directions.count { |dx, dy| occupied.include?([x + dx, y + dy]) }
          end
          expect(game.legal_placement?(q, r, rotation)).to eq(contacts >= 3)
        end
      end
      expect { choose(game, "place_v3:#{game.drawn_piece}:-2:0:0") }.to raise_error(GameError)
      rotation = (0..5).find { |r| game.legal_anchors(r).any? }
      q, r = game.legal_anchors(rotation).first
      choose(game, "place_v3:#{game.drawn_piece}:#{q}:#{r}:#{rotation}")
      expect(map_signature(game.clone(game.raw_actions))).to eq(map_signature(game))
    end

    it 'rejects external contact with either new or existing border hexes' do
      allow(game).to receive(:piece_count).and_return(10)
      game.instance_variable_set(:@placements, [{ piece: 0, q: 0, r: 0, rotation: 0 }])
      allow(game).to receive(:piece_cells).and_return([[1, 0, :blank], [1, 1, :blank], [2, 0, :blank]])
      allow(game).to receive(:placed_cells).and_return([[0, 0, :blank], [0, 1, :blank], [2, -1, :border]])
      expect(game.legal_placement?(1, 0, 0)).to be(false)
      allow(game).to receive(:placed_cells).and_return([[0, 0, :blank], [0, 1, :blank], [2, -1, :blank]])
      expect(game.legal_placement?(1, 0, 0)).to be(true)
      allow(game).to receive(:piece_cells).and_return([[1, 0, :border], [1, 1, :blank], [2, 0, :blank]])
      expect(game.legal_placement?(1, 0, 0)).to be(false)
    end

    it 'rotates the three offboard patterns with one in-game revenue cluster per destination' do
      { 26 => [[], [], [4]], 27 => [[], [4], [5, 1]], 28 => [[], [4, 0], [1]] }.each do |number, exits|
        6.times do |rotation|
          review = described_class.new(%w[Alice Bob], id: "tile#{number}")
          choose(review, "review_tile#{number}_v1")
          choose(review, "place_tile#{number}_v1:0:0:0:#{rotation}")
          cells = review.piece_cells(0, 0, rotation).map do |q, r, _|
            review.hex_by_id(review.map_coordinate(q, r))
          end
          expect(cells.first.empty).to be(true)
          if number != 26
            [cells[1], cells[2]].each do |hex|
              other = hex == cells[1] ? cells[2] : cells[1]
              expect(hex.tile.borders.select { |border| border.type.nil? }.map(&:edge))
                .to eq([hex.neighbor_direction(other)])
            end
          end
          expect(cells.flat_map { |hex| hex.tile.offboards }.count { |stop| !stop.hide }).to eq(1)
          cells.each_with_index do |hex, index|
            expected = exits[index].map { |edge| (edge + rotation) % 6 }.sort
            expect(hex.tile.exits.sort).to eq(expected)
            next if expected.empty?

            expect(hex.tile.color).to eq(:red)
            expect(hex.tile.offboards.size).to eq(1)
            expect(hex.tile.offboards.first.groups).to eq(["ROTLA#{number}"])
            expect(hex.tile.offboards.first.revenue).to eq(yellow: 30, green: 40, brown: 70, gray: 100)
          end
          expect(cells.last.neighbor_direction(cells[1])).to eq(cells.last.tile.exits.first) if number == 26
          expect(map_signature(review.clone(review.raw_actions))).to eq(map_signature(review))
        end
      end
    end

    it 'rejects routes returning to the other half of the same offboard destination' do
      [27, 28].each do |number|
        review = described_class.new(%w[Alice Bob], id: "tile#{number}")
        choose(review, "review_tile#{number}_v1")
        choose(review, "place_tile#{number}_v1:0:0:0:0")
        stops = review.hexes.flat_map { |hex| hex.tile.offboards }
        train = Train.new(name: '8', distance: 8, price: 0)
        route = Route.new(review, review.phase, train, connection_data: [])
        allow(route).to receive(:visited_stops).and_return(stops)
        allow(review).to receive(:city_tokened_by?).and_return(false)
        expect { route.revenue(supress_route_token_check: true) }
          .to raise_error(GameError, "Cannot use group ROTLA#{number} more than once")
      end
    end

    it 'rotates Port water sides and disconnected city exits with its border and standard city' do
      6.times do |rotation|
        review = described_class.new(%w[Alice Bob], id: 'tile7')
        choose(review, 'review_tile7_v1')
        choose(review, "place_tile7_v1:0:0:0:#{rotation}")
        border, port, standard = review.piece_cells(0, 0, rotation).map do |q, r, _|
          review.hex_by_id(review.map_coordinate(q, r))
        end
        expect(border.empty).to be(true)
        expect(port.tile.color).to eq(:yellow)
        expect(port.tile.label.to_s).to eq('P')
        expect(port.tile.cities.map { |city| city.revenue.values.uniq }).to eq([[30], [30]])
        home, ordinary = port.tile.cities
        expect(home.reservations.map(&:id)).to eq(['NP'])
        expect(ordinary.reservations).to be_empty
        expect(port.tile.paths.map { |path| path.nodes.size }).to eq([1, 1, 1])
        expect(home.exits).to eq([rotation % 6])
        expect(ordinary.exits.sort).to eq([4, 5].map { |e| (e + rotation) % 6 }.sort)
        expect(review.water_edges_for(port)).to eq([2, 3].map { |e| (e + rotation) % 6 })
        expect(port.neighbor_direction(border)).to eq((2 + rotation) % 6)
        expect(port.neighbor_direction(standard)).to eq((1 + rotation) % 6)
        expect(standard.tile.cities.size).to eq(1)
        expect(standard.tile.cities.first.reservations).to be_empty
        expect(map_signature(review.clone(review.raw_actions))).to eq(map_signature(review))
      end
    end

    it 'rotates tile 9 with four branches to one reserved 30-revenue city' do
      6.times do |rotation|
        review = described_class.new(%w[Alice Bob], id: 'tile9')
        choose(review, 'review_tile9_v1')
        expect(review.piece_count).to eq(1)
        choose(review, "place_tile9_v1:0:0:0:#{rotation}")
        water, plain, home = review.piece_cells(0, 0, rotation, 0).map do |q, r, _|
          review.hex_by_id(review.map_coordinate(q, r))
        end
        city = home.tile.cities.fetch(0)
        expect(city.slots).to eq(1)
        expect(city.revenue.values.uniq).to eq([30])
        expect(city.reservations.map(&:id)).to eq(['BR'])
        expect(city.tokens.compact).to be_empty
        expect(home.tile.paths.size).to eq(4)
        expect(home.tile.paths.all? { |path| path.nodes == [city] }).to be(true)
        water_edge = home.neighbor_direction(water)
        plain_edge = home.neighbor_direction(plain)
        expect(plain_edge).to eq((water_edge + 1) % 6)
        expect(home.tile.exits.sort).to eq([water_edge, plain_edge, (plain_edge + 1) % 6, (plain_edge + 2) % 6].sort)
        expect(water.tile.color).to eq(:blue)
        expect(water.tile.paths).to be_empty
        expect(water.tile.upgrades).to be_empty
        expect(plain.tile.color).to eq(:white)
        expect(review.round).to be_instance_of(Game::GRotla::Round::MapReady)
        expect(map_signature(review.clone(review.raw_actions))).to eq(map_signature(review))
        expect(map_signature(review.starting_map)).to eq(map_signature(review))
      end
    end

    it 'undoes tile 9 placement and can reopen the review for another rotation' do
      choose(game, 'review_tile9_v1')
      choose(game, 'place_tile9_v1:0:0:0:2')
      signature = map_signature(game)
      undone = game.process_action(Action::Undo.new(game.players.first)).maybe_raise!
      expect(undone.tile9_review).to be(true)
      expect(undone.drawn_piece).to eq(0)
      expect(undone.placements).to be_empty
      redone = undone.process_action(Action::Redo.new(undone.players.first)).maybe_raise!
      expect(map_signature(redone)).to eq(signature)
      choose(game, 'reopen')
      expect(game.tile9_review).to be(true)
      expect(game.drawn_piece).to eq(0)
      choose(game, 'place_tile9_v1:0:0:0:5')
      expect(game.placements.first[:rotation]).to eq(5)
    end

    it 'keeps tile 9 actions separate from the original piece catalog' do
      expect { choose(game, 'place_tile9_v1:0:0:0:0') }.to raise_error(GameError)
      choose(game, 'review_tile9_v1')
      expect { choose(game, 'place_v2:0:0:0:0') }.to raise_error(GameError)
      expect { choose(game, 'place_v1:0:0:0:0') }.to raise_error(GameError)
      expect { choose(game, 'review_tile9_v1') }.to raise_error(GameError)
    end

    it 'preserves Mining cities, revenues, home and plain exit through all rotations and replay' do
      6.times do |rotation|
        review = described_class.new(%w[Alice Bob], id: 'tile2')
        choose(review, 'review_tile2_v1')
        choose(review, "place_tile2_v1:0:0:0:#{rotation}")
        home, plain, mountain = review.piece_cells(0, 0, rotation, 0).map do |q, r, _|
          review.hex_by_id(review.map_coordinate(q, r))
        end
        expect(home.tile.color).to eq(:yellow)
        expect(home.tile.label.to_s).to eq('M')
        expect(home.tile.cities.map { |city| city.revenue.values.uniq }).to eq([[30], [20]])
        first, second = home.tile.cities
        expect(first.reservations.map(&:id)).to eq(['EM'])
        expect(second.reservations).to be_empty
        expect(home.tile.paths.size).to eq(2)
        expect(home.tile.paths.any? { |path| path.nodes == [first, second] }).to be(true)
        exit_path = home.tile.paths.find { |path| path.exits.any? }
        expect(exit_path.nodes).to eq([first])
        expect(exit_path.exits).to eq([home.neighbor_direction(plain)])
        expect(home.tile.exits).not_to include(home.neighbor_direction(mountain))
        expect(map_signature(review.clone(review.raw_actions))).to eq(map_signature(review))
      end
    end

    it 'rotates tile 11 with one shared two-slot city and no exit toward water' do
      6.times do |rotation|
        review = described_class.new(%w[Alice Bob], id: 'tile11')
        choose(review, 'review_tile11_v1')
        choose(review, "place_tile11_v1:0:0:0:#{rotation}")
        water, plain, home = review.piece_cells(0, 0, rotation, 0).map do |q, r, _|
          review.hex_by_id(review.map_coordinate(q, r))
        end
        expect(home.tile.color).to eq(:gray)
        expect(home.tile.cities.size).to eq(1)
        city = home.tile.cities.first
        expect(city.slots).to eq(2)
        expect(city.revenue.values.uniq).to eq([20])
        expect(city.reservations.map { |reservation| reservation&.id }).to eq([nil, 'SP'])
        expect(city.available_slots).to eq(1)
        expect(city.tokens.compact).to be_empty
        expect(home.tile.paths.size).to eq(4)
        expect(home.tile.paths.all? { |path| path.nodes == [city] }).to be(true)
        plain_edge = home.neighbor_direction(plain)
        expect(home.tile.exits.sort).to eq((0..3).map { |offset| (plain_edge + offset) % 6 }.sort)
        expect(home.tile.exits).not_to include(home.neighbor_direction(water))
        Tile::COLORS.each do |color|
          replacement = Tile.from_code('replacement', color, home.tile.code)
          expect(review.upgrades_to?(home.tile, replacement)).to be(false)
        end
        expect(water.tile.color).to eq(:blue)
        expect(plain.tile.color).to eq(:white)
        restored = review.clone(review.raw_actions)
        expect(map_signature(restored)).to eq(map_signature(review))
        restored_city = restored.hexes.flat_map { |hex| hex.tile.cities }.first
        expect(restored_city.reservations.map { |reservation| reservation&.id }).to eq([nil, 'SP'])
        expect(map_signature(review.starting_map)).to eq(map_signature(review))
      end
    end

    it 'restores the Spacious review after undo, redo and restarting' do
      choose(game, 'review_tile11_v1')
      choose(game, 'place_tile11_v1:0:0:0:4')
      signature = map_signature(game)
      undone = game.process_action(Action::Undo.new(game.players.first)).maybe_raise!
      expect(undone.review_tile).to eq(11)
      expect(undone.drawn_piece).to eq(0)
      expect(undone.placements).to be_empty
      redone = undone.process_action(Action::Redo.new(undone.players.first)).maybe_raise!
      expect(map_signature(redone)).to eq(signature)
      choose(game, 'reopen')
      expect(game.review_tile).to eq(11)
      choose(game, 'place_tile11_v1:0:0:0:1')
      expect(game.placements.first[:rotation]).to eq(1)
    end

    it 'rejects mixing review tile versions or changing the piece after drawing' do
      expect { choose(game, 'place_tile11_v1:0:0:0:0') }.to raise_error(GameError)
      choose(game, 'review_tile11_v1')
      %w[place_v1 place_v2 place_tile9_v1].each do |version|
        expect { choose(game, "#{version}:0:0:0:0") }.to raise_error(GameError)
      end
      expect { choose(game, 'review_tile9_v1') }.to raise_error(GameError)
      expect { choose(game, 'review_tile11_v1') }.to raise_error(GameError)
    end
  end
end
