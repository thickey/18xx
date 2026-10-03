# frozen_string_literal: true

require 'spec_helper'
require 'json'

module Engine
  describe Game::GRotla::Game, 'real map supply' do
    def choose(game, choice)
      game.process_action(Action::Choose.new(game.current_entity, choice: choice)).maybe_raise!
    end

    def new_real_game(players = 3, **kwargs)
      game = described_class.new(%w[Alice Bob Carol Dave Eve].take(players), id: '3722698', **kwargs)
      choose(game, 'start_v4')
      game
    end

    def assemble(game)
      until game.setup_complete?
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

    it 'matches the sourced 33-piece physical inventory and runtime audit catalog' do
      source = JSON.parse(File.read('spec/fixtures/rotla/map-pieces.json'))['pieces']
      runtime = JSON.parse(File.read('spec/fixtures/rotla/runtime-map-v1.json'))['pieces']
      catalog = Game::GRotla::MapCatalog::PIECES
      expect(catalog.map { |p| p[:id] }).to eq(source.map { |p| p['fixed']['generator_tile_id'] })
      expect(catalog.size).to eq(33)
      expect(catalog.sum { |p| p[:terrain].size }).to eq(99)
      catalog.zip(runtime).each do |piece, audit|
        expect(piece[:terrain].map(&:to_s)).to eq(audit['cells'].map { |cell| cell['terrain'] })
        expect(piece[:number]).to eq(audit['number'])
      end
      expect(catalog.map { |p| p[:number] }.tally.select { |_, count| count == 2 }.keys).to eq([12, 13, 14, 15, 16])
    end

    it 'uses Short Game for two players, Long Game for five, and selectable modes for three/four' do
      expect(new_real_game(2).piece_count).to eq(25)
      expect(new_real_game(5).piece_count).to eq(33)
      [3, 4].each do |players|
        expect(new_real_game(players).piece_count).to eq(33)
        short = new_real_game(players, optional_rules: [:short_game])
        expect(short.piece_count).to eq(25)
        expect(short.capital_count).to eq(2)
        expect(short.real_catalog.map { |p| p[:id] }).not_to include(*Game::GRotla::MapCatalog::SHORT_REMOVED)
      end
      expect { new_real_game(5, optional_rules: [:short_game]) }.to raise_error(GameError, /five players/)
    end

    it 'keeps all 33 pieces triangular through every rotation, with eleven distinct printed homes' do
      game = new_real_game
      game.real_catalog.each_with_index do |_, index|
        6.times do |rotation|
          cells = game.piece_cells(0, 0, rotation, index)
          cells.combination(2) do |a, b|
            expect(Game::GRotla::MapBuilder::DIRECTIONS).to include([a[0] - b[0], a[1] - b[1]])
          end
        end
      end
      expect(game.real_catalog.filter_map { |p| p[:home] }.sort).to eq(%w[AG BR EA EM ER NP OV RE SP SU TU])
    end

    it 'materializes revenues, slots, terrain, homes and shared destinations through all six rotations' do
      game = new_real_game
      game.real_catalog.each_with_index do |piece, index|
        6.times do |rotation|
          piece[:terrain].each do |terrain|
            hex = game.real_preview_hex(0, 0, terrain, rotation, index)
            tile = hex.tile
            if terrain == :city || terrain.to_s.start_with?('minor_')
              expect(tile.cities.first.revenue.values.uniq).to eq([0])
              expect(tile.cities.first.slots).to eq(1)
              expect(tile.paths).to be_empty
            end
            expect(tile.upgrades.map(&:cost)).to eq([40]) if %i[mountain minor_tunneling].include?(terrain)
            expect(hex.empty).to be(true) if terrain == :border
            if %i[bridging spacious].include?(terrain)
              definition = Game::GRotla::MapCatalog::SPECIAL[piece[:number]]
              expect(tile.exits.sort).to eq(definition[:exits].map { |edge| (edge + rotation) % 6 }.sort)
              expect(tile.cities.first.slots).to eq(definition[:slots])
              expect(tile.cities.first.revenue.values.uniq).to eq([definition[:revenue]])
            end
            next unless %i[offboard offboard_join].include?(terrain)

            expect(tile.offboards.first.groups).to eq(["ROTLA#{piece[:id]}"])
            expect(tile.offboards.first.revenue).to eq(yellow: 30, green: 40, brown: 70, gray: 100)
            expect(tile.exits.sort).to eq(Game::GRotla::MapCatalog::SPECIAL[piece[:number]][:offboard_exits][terrain]
              .map { |edge| (edge + rotation) % 6 }.sort)
          end
        end
      end
    end

    it 'applies each distant destination revenue card to both halves of every destination' do
      {
        nil => [30, 40, 70, 100],
        :distant_revenue_20_30_50_80 => [20, 30, 50, 80],
        :distant_revenue_30_60_90_30 => [30, 60, 90, 30],
      }.each do |option, revenues|
        game = new_real_game(optional_rules: [option].compact)
        game.real_catalog.each_with_index do |piece, index|
          piece[:terrain].each do |terrain|
            next unless %i[offboard offboard_join].include?(terrain)

            hex = game.real_preview_hex(0, 0, terrain, 0, index)
            expect(hex.tile.offboards.first.revenue).to eq(%i[yellow green brown gray].zip(revenues).to_h)
          end
        end
      end
    end

    it 'rejects selecting multiple distant destination revenue cards' do
      expect do
        new_real_game(optional_rules: %i[distant_revenue_20_30_50_80 distant_revenue_30_60_90_30])
      end.to raise_error(GameError, /only one distant destination revenue card/)
    end

    it 'preserves a pending draw through undo/redo and can undo a reshuffled restart' do
      game = new_real_game
      choose(game, 'draw_v4')
      id = game.real_catalog[game.drawn_piece][:id]
      choose(game, "place_v4:#{id}:0:0:0")
      undone = game.process_action(Action::Undo.new(game.current_entity)).maybe_raise!
      expect(undone.placements).to be_empty
      expect(undone.real_catalog[undone.drawn_piece][:id]).to eq(id)
      redone = undone.process_action(Action::Redo.new(undone.current_entity)).maybe_raise!
      expect(redone.placements).to eq(game.placements)
      game = redone
      prior_placements = game.placements.dup
      choose(game, 'restart_v4')
      expect(game.placements).to be_empty
      expect(game.capital_cells).to be_empty
      expect(game.drawn_piece).to be_nil
      restored = game.process_action(Action::Undo.new(game.current_entity)).maybe_raise!
      expect(restored.placements).to eq(prior_placements)
    end

    it 'converts every cell of the saved generator reference without reflections or coordinate errors' do
      game = new_real_game
      reference = JSON.parse(File.read('spec/fixtures/rotla/reference-map-3722698.json'))['placements']
      placements = reference.map do |p|
        index = game.real_catalog.index { |piece| piece[:id] == p['id'] }
        cells = game.piece_cells(p['q'], p['r'], p['rotation'], index)
        expect(cells.map { |q, r, _| [q, r] }).to eq(p['coordinates'])
        { piece: index, q: p['q'], r: p['r'], rotation: p['rotation'] }
      end
      game.instance_variable_set(:@placements, placements)
      game.rebuild_map!
      expect(game.hexes.size).to eq(99)
      expect(game.hexes.count(&:empty)).to eq(7)
      expect(game.hexes.flat_map { |h| h.tile.cities.flat_map(&:reservations) }.compact.map(&:id).sort)
        .to eq(%w[AG BR EA EM ER NP OV RE SP SU TU])
      game.placements.each do |p|
        game.piece_cells(p[:q], p[:r], p[:rotation], p[:piece]).each do |q, r, terrain|
          preview = game.real_preview_hex(q, r, terrain, p[:rotation], p[:piece])
          actual = game.hex_by_id(game.map_coordinate(q, r))
          expect([preview.tile.color, preview.tile.code]).to eq([actual.tile.color, actual.tile.code])
          expect(preview.tile.cities.map(&:reservations)).to eq(actual.tile.cities.map(&:reservations))
        end
      end
    end

    it 'resolves capital projects only on placed ordinary cities and returns early projects to the stack' do
      game = new_real_game
      city_piece = game.real_catalog.index { |p| p[:id] == '03' }
      game.instance_variable_set(:@piece_deck, [:capital, city_piece, :capital])
      choose(game, 'draw_v4')
      expect(game.drawn_piece).to eq(city_piece)
      choose(game, 'place_v4:03:0:0:0')
      choose(game, 'draw_v4')
      expect(game.drawn_project).to be(true)
      expect(game.capital_choices).to eq([[0, 0]])
      expect { choose(game, 'capital_v4:1:0') }.to raise_error(GameError, /basic city/)
      choose(game, 'capital_v4:0:0')
      expect(game.hex_by_id(game.map_coordinate(0, 0)).tile.label.to_s).to eq('C')
      expect(game.capital_choices).to be_empty
      expect(game.placements.size).to eq(1)
      expect(game.round).to be_instance_of(Game::GRotla::Round::Setup)
    end

    it 'assembles complete legal maps, resolves every project, and replays the same supply and homes' do
      [2, 3, 4, 5].each do |players|
        game = new_real_game(players)
        assemble(game)
        expect(game.hexes.size).to eq(players == 2 ? 75 : 99)
        expect(game.capital_cells.size).to eq(players == 2 ? 2 : 3)
        expect(game.round).to be_instance_of(Game::GRotla::Round::MapReady)
        expect(game.placements.map { |p| p[:piece] }.uniq.size).to eq(game.piece_count)
        replay = game.clone(game.raw_actions)
        expect(replay.placements).to eq(game.placements)
        expect(replay.capital_cells).to eq(game.capital_cells)
        signature = lambda { |g|
          g.hexes.map do |h|
            [h.id, h.tile.color, h.tile.code, h.tile.cities.map(&:reservations).map do |r|
                                                r.map { |marker| marker&.id }
                                              end]
          end
        }
        expect(signature.call(replay)).to eq(signature.call(game))
        expect(signature.call(game.starting_map)).to eq(signature.call(game))
      end
    end

    it 'allows preprinted Port track to lead off-map during construction' do
      game = new_real_game
      port_index = game.real_catalog.index { |piece| piece[:id] == '07' }
      game.instance_variable_set(:@piece_deck, [port_index])
      choose(game, 'draw_v4')
      6.times { |rotation| expect(game.legal_placement?(0, 0, rotation)).to be(true) }
      choose(game, 'place_v4:07:0:0:0')
      port = game.hexes.find { |hex| hex.tile.label.to_s == 'P' }
      expect(port.tile.exits.any? { |edge| !port.neighbors[edge] }).to be(true)
      expect(port.tile.cities.first.reservations.first.id).to eq('NP')
    end

    it 'rejects mixed legacy setup actions and keeps old saves on the four-piece supply' do
      game = new_real_game
      expect { choose(game, 'draw_v2') }.to raise_error(GameError, /mix/)
      legacy = described_class.new(%w[Alice Bob], id: '1')
      choose(legacy, 'draw_v2')
      expect(legacy.piece_count).to eq(4)
      expect(legacy.clone(legacy.raw_actions).drawn_piece).to eq(legacy.drawn_piece)
    end
  end
end
