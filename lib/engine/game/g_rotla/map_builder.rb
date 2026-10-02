# frozen_string_literal: true

module Engine
  module Game
    module GRotla
      module MapBuilder
        # Axial coordinates. Every pair in this triangle shares an edge.
        TRIANGLE = [[0, 0], [1, 0], [0, 1]].freeze
        DIRECTIONS = [[1, 0], [0, 1], [-1, 1], [-1, 0], [0, -1], [1, -1]].freeze
        PIECES = [
          %i[blank blank blank],
          %i[blank city blank],
          %i[mountain blank blank],
          %i[city water water],
        ].freeze
        TERRAIN = {
          blank: '',
          city: 'city=revenue:0',
          mountain: 'upgrade=cost:40,terrain:mountain',
          water: 'upgrade=cost:20,terrain:water',
        }.freeze

        # Tile 9: water, plain, Bridging, in the same handedness as the physical piece.
        TILE9_PIECES = [%i[water blank bridging]].freeze
        # From Bridging at (0, 1), water is edge 3 and plain is edge 4.
        # Continue toward the plain side for two more exits: 5 and 0.
        BRIDGING_EXITS = [3, 4, 5, 0].freeze
        REVIEW_TILES = {
          2 => {
            name: 'Mining',
            sym: 'EM',
            pieces: [%i[mining blank mountain]],
            exits: [5],
            color: :yellow,
          },
          7 => {
            name: 'Port',
            sym: 'NP',
            pieces: [%i[border port city]],
            exits: [4, 5, 0],
            color: :yellow,
          },
          9 => {
            name: 'Bridging',
            sym: 'BR',
            pieces: TILE9_PIECES,
            exits: BRIDGING_EXITS,
            revenue: 30,
            slots: 1,
            color: :blue,
          },
          # Plain is edge 4; continue outwards through 5, 0, 1, excluding water (3).
          11 => {
            name: 'Spacious',
            sym: 'SP',
            pieces: [%i[water blank spacious]],
            exits: [4, 5, 0, 1],
            revenue: 20,
            slots: 2,
            color: :gray,
          },
          26 => {
            name: 'Offboard 26',
            pieces: [%i[border blank offboard]],
            offboard_exits: { offboard: [4] },
          },
          27 => {
            name: 'Offboard 27',
            pieces: [%i[border offboard offboard_join]],
            offboard_exits: { offboard: [4], offboard_join: [5, 1] },
          },
          28 => {
            name: 'Offboard 28',
            pieces: [%i[border offboard offboard_join]],
            offboard_exits: { offboard: [4, 0], offboard_join: [1] },
          },
        }.freeze

        attr_reader :placements, :drawn_piece, :legacy_setup, :review_tile

        def tile9_review
          @review_tile == 9
        end

        def review_definition
          REVIEW_TILES[@review_tile]
        end

        def map_pieces
          review_definition ? review_definition[:pieces] : PIECES
        end

        def piece_count
          map_pieces.size
        end

        def review_tile9!
          review_tile!(9)
        end

        def review_tile!(number)
          raise GameError, 'Unknown review tile' unless REVIEW_TILES.key?(number)
          if !@round.instance_of?(Round::Setup) || !@placements.empty? || !@drawn_piece.nil? || @map_id
            raise GameError, 'Start tile review before drawing or placing any pieces'
          end

          @review_tile = number
          reset_piece_supply!
        end

        def piece_name(index = current_piece)
          @review_tile ? "Tile #{@review_tile} — #{review_definition[:name]}" : "Piece ##{index + 1}"
        end

        def bridging_exits(rotation)
          BRIDGING_EXITS.map { |edge| (edge + rotation) % 6 }
        end

        def review_exits(rotation)
          review_definition[:exits].map { |edge| (edge + rotation) % 6 }
        end

        def water_edges_for(hex)
          return [] if @review_tile != 7 || hex.tile.label.to_s != 'P'

          rotation = @placements.first[:rotation]
          [2, 3].map { |edge| (edge + rotation) % 6 }
        end

        def offboard_shared_edge(terrain, rotation)
          return unless [27, 28].include?(@review_tile)
          return unless %i[offboard offboard_join].include?(terrain)

          ((terrain == :offboard ? 1 : 4) + rotation) % 6
        end

        def offboard_exits(terrain, rotation)
          review_definition[:offboard_exits][terrain].map { |edge| (edge + rotation) % 6 }
        end

        def reset_piece_supply!
          @placements = []
          @drawn_piece = @review_tile ? 0 : nil
          @legacy_setup = false
          @piece_deck = (0...piece_count).sort_by { rand }
        end

        def current_piece
          @legacy_setup ? @placements.size : @drawn_piece
        end

        def draw_map_piece!
          raise GameError, 'Cannot draw outside setup' unless @round.instance_of?(Round::Setup)
          raise GameError, 'Place the current piece before drawing again' unless @drawn_piece.nil?
          raise GameError, 'No pieces available to draw' if @legacy_setup || @map_id || @placements.size == piece_count

          @drawn_piece = @piece_deck[@placements.size]
        end

        def piece_cells(q, r, rotation, index = current_piece || 0)
          TRIANGLE.each_with_index.map do |(x, y), i|
            rotation.times { x, y = -y, x + y }
            [q + x, r + y, map_pieces[index][i]]
          end
        end

        def placed_cells
          (@placements || []).flat_map { |p| piece_cells(p[:q], p[:r], p[:rotation], p[:piece]) }
        end

        def map_coordinate(q, r)
          "#{Engine::Hex::LETTERS[q + 12]}#{(2 * r) + q + 13}"
        end

        def legal_placement?(q, r, rotation, strict: true, existing: nil)
          return false unless [q, r, rotation].all? { |n| n.is_a?(Integer) }
          return false if !rotation.between?(0, 5) || @placements.size >= piece_count
          return q.zero? && r.zero? if @placements.empty?

          cells = piece_cells(q, r, rotation).map { |x, y, _| [x, y] }
          existing ||= placed_cells.to_h { |x, y, terrain| [[x, y], terrain] }
          return false if cells.any? { |cell| existing.key?(cell) }

          contacts = 0
          piece_cells(q, r, rotation).each do |x, y, terrain|
            DIRECTIONS.each do |dx, dy|
              neighbor = existing[[x + dx, y + dy]]
              next unless neighbor
              return false if strict && (terrain == :border || neighbor == :border)

              contacts += 1
            end
          end
          contacts >= (strict ? 3 : 1)
        end

        def legal_anchors(rotation, strict: true)
          return [] if @placements.size == piece_count
          return [[0, 0]] if @placements.empty?

          offsets = piece_cells(0, 0, rotation).map { |x, y, _| [x, y] }
          candidates = placed_cells.flat_map do |x, y, _|
            DIRECTIONS.flat_map do |dx, dy|
              offsets.map { |ox, oy| [x + dx - ox, y + dy - oy] }
            end
          end
          existing = placed_cells.to_h { |x, y, terrain| [[x, y], terrain] }
          candidates.uniq.select { |x, y| legal_placement?(x, y, rotation, strict: strict, existing: existing) }.sort
        end

        def place_map_piece!(piece, q, r, rotation, legacy: false, strict: true)
          raise GameError, 'Map can only be changed during setup' unless @round.instance_of?(Round::Setup)

          expected = legacy ? @placements.size : @drawn_piece
          raise GameError, 'Wrong map piece' if expected.nil? || piece != expected || @map_id
          raise GameError, 'Cannot mix setup versions' if legacy && !@drawn_piece.nil?
          unless legal_placement?(q, r, rotation, strict: strict)
            raise GameError, 'Placement must share three edges, avoid border hexes, and not overlap'
          end

          @legacy_setup = true if legacy
          @drawn_piece = nil
          @placements << { piece: piece, q: q, r: r, rotation: rotation }
          rebuild_map!
        end

        def assembled_hexes
          cells = placed_cells
          # An empty, non-playable hex lets the normal Map tab display before setup.
          return { empty: { ['M13'] => '' } } if cells.empty?

          return { white: cells.to_h { |q, r, terrain| [[map_coordinate(q, r)], TERRAIN[terrain]] } } unless @review_tile

          hexes = { white: {}, blue: {}, gray: {}, yellow: {}, empty: {}, red: {} }
          @placements.each do |placement|
            piece_cells(placement[:q], placement[:r], placement[:rotation], placement[:piece]).each do |q, r, terrain|
              home = %i[bridging spacious mining port].include?(terrain)
              code = if %i[offboard offboard_join].include?(terrain)
                       hidden = terrain == :offboard_join ? ',hide:1' : ''
                       "offboard=revenue:yellow_30|green_40|brown_70|gray_100,rows:2,groups:ROTLA#{@review_tile}#{hidden};" +
                         offboard_exits(terrain, placement[:rotation]).map { |edge| "path=a:#{edge},b:_0" }.join(';')
                     elsif terrain == :port
                       rotation = placement[:rotation]
                       "city=revenue:30,loc:#{rotation % 6};city=revenue:30,loc:#{(4.5 + rotation) % 6};" \
                         "path=a:#{rotation % 6},b:_0;path=a:#{(4 + rotation) % 6},b:_1;" \
                         "path=a:#{(5 + rotation) % 6},b:_1;label=P"
                     elsif terrain == :mining
                       rotation = placement[:rotation]
                       "city=revenue:30,loc:#{(5.5 + rotation) % 6};" \
                         "city=revenue:20,loc:#{(2.5 + rotation) % 6};" \
                         "path=a:_0,b:_1;path=a:#{review_exits(rotation).first},b:_0;label=M"
                     elsif home
                       "city=revenue:#{review_definition[:revenue]},slots:#{review_definition[:slots]};" +
                         review_exits(placement[:rotation]).map { |edge| "path=a:#{edge},b:_0" }.join(';')
                     else
                       %i[mountain city].include?(terrain) ? TERRAIN[terrain] : ''
                     end
              shared_edge = offboard_shared_edge(terrain, placement[:rotation])
              code += ";border=edge:#{shared_edge}" if shared_edge
              color = terrain == :water ? :blue : :white
              color = review_definition[:color] if home
              color = :empty if terrain == :border
              color = :red if %i[offboard offboard_join].include?(terrain)
              hexes[color][[map_coordinate(q, r)]] = code
            end
          end
          hexes
        end
      end
    end
  end
end
