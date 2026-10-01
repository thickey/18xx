# frozen_string_literal: true

require_relative 'map_catalog'

module Engine
  module Game
    module GRotla
      # The real_v1 catalog and v4 actions are separate from all prototype saves.
      module RealMapBuilder
        attr_reader :real_setup, :drawn_project, :capital_cells

        def short_map?
          @players.size == 2 || @optional_rules.include?(:short_game)
        end

        def real_catalog
          MapCatalog::PIECES.reject { |piece| short_map? && MapCatalog::SHORT_REMOVED.include?(piece[:id]) }
        end

        def map_pieces
          @real_setup ? real_catalog.map { |piece| piece[:terrain] } : super
        end

        def piece_name(index = current_piece)
          return super unless @real_setup
          return 'Capital project' if @drawn_project
          return 'Real map' unless index

          piece = real_catalog[index]
          "Tile #{piece[:number]} (#{piece[:id]})#{piece[:name] ? " — #{piece[:name]}" : ''}"
        end

        def start_real_setup!
          if !@round.instance_of?(Round::Setup) || !@placements.empty? || @drawn_piece || @review_tile || @map_id
            raise GameError, 'Start real setup before drawing or placing prototype pieces'
          end
          raise GameError, 'Short Game is not available for five players' if @players.size == 5 && short_map?
          raise GameError, 'Real setup already started' if @real_setup

          @real_setup = true
          reset_piece_supply!
          @round.entity_index = rand % @players.size
        end

        def reset_piece_supply!
          return super unless @real_setup

          @placements = []
          @drawn_piece = nil
          @drawn_project = nil
          @legacy_setup = false
          @capital_cells = []
          @home_markers = {}
          # Physical copy IDs stay in the catalog; projects are stack instructions.
          @piece_deck = ((0...piece_count).to_a + Array.new(capital_count, :capital)).sort_by { rand }
        end

        def capital_count
          short_map? ? 2 : 3
        end

        def map_coordinate(q, r)
          return super unless @real_setup

          column = q + 12
          letter = column.negative? ? Engine::Hex::NEGATIVE_LETTERS[-column] : Engine::Hex::LETTERS[column]
          "#{letter}#{(2 * r) + q + 13}"
        end

        def legal_placement?(q, r, rotation, **kwargs)
          if @real_setup
            return false unless [q, r, rotation].all? { |n| n.is_a?(Integer) }
            return false unless rotation.between?(0, 5)
            return false unless piece_cells(q, r, rotation).all? { |x, _, _| (x + 12).between?(-26, 51) }
          end
          super
        end

        def setup_complete?
          @placements.size == piece_count && (!@real_setup || @capital_cells.size == capital_count)
        end

        def capital_choices
          return [] unless @real_setup

          placed_cells.filter_map do |q, r, terrain|
            [q, r] if terrain == :city && !@capital_cells.include?([q, r])
          end
        end

        def draw_real_piece!
          raise GameError, 'Start real setup first' if !@real_setup || !@round.instance_of?(Round::Setup)
          raise GameError, 'Resolve the current draw first' if @drawn_piece || @drawn_project
          raise GameError, 'Setup is complete' if setup_complete?

          @piece_deck.size.times do
            item = @piece_deck.shift
            if item == :capital
              if capital_choices.empty?
                @piece_deck << item
                next
              end
              @drawn_project = true
            else
              @drawn_piece = item
            end
            return
          end
          raise GameError, 'No basic city is available for the remaining capital projects'
        end

        def resolve_capital!(q, r)
          raise GameError, 'No capital project drawn' if !@drawn_project || !@round.instance_of?(Round::Setup)
          raise GameError, 'Choose a placed basic city without a capital overlay' unless capital_choices.include?([q, r])

          @capital_cells << [q, r]
          @drawn_project = nil
          rebuild_map!
        end

        def place_real_piece!(id, q, r, rotation)
          expected = @drawn_piece && real_catalog[@drawn_piece][:id]
          raise GameError, 'Wrong real map piece' unless expected == id

          place_map_piece!(@drawn_piece, q, r, rotation)
        end

        def placement_at(q, r)
          @placements.find { |p| piece_cells(p[:q], p[:r], p[:rotation], p[:piece]).any? { |x, y, _| x == q && y == r } }
        end

        # One code path serves setup previews and the normal engine map.
        def real_cell_definition(terrain, rotation, index, capital: false)
          piece = real_catalog[index]
          number = piece[:number]
          home = terrain.to_s.start_with?('minor_') || %i[mining port bridging spacious].include?(terrain)
          color = {
            water: :blue,
            bridging: :blue,
            spacious: :gray,
            mining: :yellow,
            port: :yellow,
            border: :empty,
            offboard: :red,
            offboard_join: :red,
          }.fetch(terrain, :white)
          edge = ->(e) { (e + rotation) % 6 }
          code = case terrain
                 when :city
                   "city=revenue:0#{capital ? ';label=C' : ''}"
                 when :mountain
                   'upgrade=cost:40,terrain:mountain'
                 when :mining
                   "city=revenue:30,loc:#{edge.call(5.5)};city=revenue:20,loc:#{edge.call(2.5)};" \
                   "path=a:_0,b:_1;path=a:#{edge.call(5)},b:_0;label=M"
                 when :port
                   "city=revenue:30,loc:#{edge.call(0)};city=revenue:30,loc:#{edge.call(4.5)};" \
                   "path=a:#{edge.call(0)},b:_0;path=a:#{edge.call(4)},b:_1;path=a:#{edge.call(5)},b:_1;label=P"
                 when :bridging, :spacious
                   definition = MapCatalog::SPECIAL[number]
                   "city=revenue:#{definition[:revenue]},slots:#{definition[:slots]};" +
                     definition[:exits].map { |e| "path=a:#{edge.call(e)},b:_0" }.join(';')
                 when :offboard, :offboard_join
                   hidden = terrain == :offboard_join ? ',hide:1' : ''
                   exits = MapCatalog::SPECIAL[number][:offboard_exits][terrain]
                   result = "offboard=revenue:yellow_30|green_40|brown_70|gray_100,rows:2,groups:ROTLA#{piece[:id]}#{hidden};" +
                     exits.map { |e| "path=a:#{edge.call(e)},b:_0" }.join(';')
                   result += ";border=edge:#{edge.call(terrain == :offboard ? 1 : 4)}" if [27, 28].include?(number)
                   result
                 else
                   home ? 'city=revenue:0' : ''
                 end
          code += ';upgrade=cost:40,terrain:mountain' if terrain == :minor_tunneling
          {
            color: color,
            code: code,
            home: home ? piece[:home] : nil,
            name: home ? piece[:name] : nil,
            slot: terrain == :spacious ? 1 : 0,
          }
        end

        def real_preview_hex(q, r, terrain, rotation, index)
          definition = real_cell_definition(terrain, rotation, index, capital: @capital_cells.include?([q, r]))
          empty = definition[:color] == :empty
          color = empty ? :white : definition[:color]
          tile = Engine::Tile.from_code(map_coordinate(q, r), color, definition[:code], preprinted: true)
          hex = Engine::Hex.new(map_coordinate(q, r), layout: :flat, tile: tile, empty: empty)
          hex.instance_variable_set(:@rotla_port_rotation, rotation) if terrain == :port
          reserve_real_home!(hex, definition)
          hex
        end

        def reserve_real_home!(hex, definition)
          return unless definition[:home]

          marker = @home_markers[definition[:home]] ||= Engine::Minor.new(
            sym: definition[:home], name: definition[:name], tokens: [], color: '#57b8b0'
          )
          hex.tile.cities.first.add_reservation!(marker, definition[:slot])
          hex.location_name = definition[:name]
        end

        def assembled_hexes
          return super if !@real_setup || @placements.empty?

          hexes = { white: {}, blue: {}, gray: {}, yellow: {}, empty: {}, red: {} }
          @placements.each do |p|
            piece_cells(p[:q], p[:r], p[:rotation], p[:piece]).each do |q, r, terrain|
              definition = real_cell_definition(terrain, p[:rotation], p[:piece], capital: @capital_cells.include?([q, r]))
              hexes[definition[:color]][[map_coordinate(q, r)]] = definition[:code]
            end
          end
          hexes
        end

        def reserve_real_homes!
          return unless @real_setup

          @placements.each do |p|
            piece_cells(p[:q], p[:r], p[:rotation], p[:piece]).each do |q, r, terrain|
              hex = @hexes.find { |h| h.id == map_coordinate(q, r) }
              reserve_real_home!(hex, real_cell_definition(terrain, p[:rotation], p[:piece]))
            end
          end
        end

        def water_edges_for(hex)
          return tile_water_edges(hex.tile) if %w[LA2 LA5].include?(hex.tile.name)

          return super unless @real_setup

          rotation = hex.instance_variable_get(:@rotla_port_rotation)
          return [2, 3].map { |e| (e + rotation) % 6 } if rotation

          p = @placements.find do |placement|
            piece_cells(placement[:q], placement[:r], placement[:rotation], placement[:piece]).any? do |q, r, terrain|
              terrain == :port && map_coordinate(q, r) == hex.id
            end
          end
          p ? [2, 3].map { |e| (e + p[:rotation]) % 6 } : []
        end

        def tile_water_edges(tile)
          return [] unless %w[LA2 LA5].include?(tile.name)

          [2, 3].map { |edge| (edge + tile.rotation) % 6 }
        end

        def tile_city_revenue_position(tile, city)
          return unless %w[LA4 LA7].include?(tile.name)
          return unless city == tile.cities[1]

          { x: 52, y: -38 }
        end

        def tile_label_position(tile)
          if %w[LA2 LA5].include?(tile.name)
            angle = (240 + (60 * tile.rotation)) * Math::PI / 180
            return { x: 61 * Math.cos(angle), y: 61 * Math.sin(angle), region_weights: {} }
          end

          return super unless @real_setup
          return if tile.label.to_s != 'P' || !tile.hex

          edges = water_edges_for(tile.hex)
          return if edges.empty?

          angle = (240 + (60 * ((edges.first - 2) % 6))) * Math::PI / 180
          { x: 61 * Math.cos(angle), y: 61 * Math.sin(angle), region_weights: {} }
        end
      end
    end
  end
end
