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

        attr_reader :placements, :drawn_piece, :legacy_setup

        def reset_piece_supply!
          @placements = []
          @drawn_piece = nil
          @legacy_setup = false
          @piece_deck = (0...PIECES.size).sort_by { rand }
        end

        def current_piece
          @legacy_setup ? @placements.size : @drawn_piece
        end

        def draw_map_piece!
          raise GameError, 'Cannot draw outside setup' unless @round.instance_of?(Round::Setup)
          raise GameError, 'Place the current piece before drawing again' unless @drawn_piece.nil?
          raise GameError, 'No pieces available to draw' if @legacy_setup || @map_id || @placements.size == PIECES.size

          @drawn_piece = @piece_deck[@placements.size]
        end

        def piece_cells(q, r, rotation, index = current_piece || 0)
          TRIANGLE.each_with_index.map do |(x, y), i|
            rotation.times { x, y = -y, x + y }
            [q + x, r + y, PIECES[index][i]]
          end
        end

        def placed_cells
          (@placements || []).flat_map { |p| piece_cells(p[:q], p[:r], p[:rotation], p[:piece]) }
        end

        def map_coordinate(q, r)
          "#{Engine::Hex::LETTERS[q + 12]}#{(2 * r) + q + 13}"
        end

        def legal_placement?(q, r, rotation)
          return false unless [q, r, rotation].all? { |n| n.is_a?(Integer) }
          return false if !rotation.between?(0, 5) || @placements.size >= PIECES.size
          return q.zero? && r.zero? if @placements.empty?

          cells = piece_cells(q, r, rotation).map { |x, y, _| [x, y] }
          occupied = placed_cells.map { |x, y, _| [x, y] }
          return false unless (cells & occupied).empty?

          cells.any? do |x, y|
            DIRECTIONS.any? { |dx, dy| occupied.include?([x + dx, y + dy]) }
          end
        end

        def legal_anchors(rotation)
          return [] if @placements.size == PIECES.size
          return [[0, 0]] if @placements.empty?

          offsets = piece_cells(0, 0, rotation).map { |x, y, _| [x, y] }
          candidates = placed_cells.flat_map do |x, y, _|
            DIRECTIONS.flat_map do |dx, dy|
              offsets.map { |ox, oy| [x + dx - ox, y + dy - oy] }
            end
          end
          candidates.uniq.select { |x, y| legal_placement?(x, y, rotation) }.sort
        end

        def place_map_piece!(piece, q, r, rotation, legacy: false)
          raise GameError, 'Map can only be changed during setup' unless @round.instance_of?(Round::Setup)

          expected = legacy ? @placements.size : @drawn_piece
          raise GameError, 'Wrong map piece' if expected.nil? || piece != expected || @map_id
          raise GameError, 'Cannot mix setup versions' if legacy && !@drawn_piece.nil?
          raise GameError, 'Placement must touch the map without overlapping' unless legal_placement?(q, r, rotation)

          @legacy_setup = true if legacy
          @drawn_piece = nil
          @placements << { piece: piece, q: q, r: r, rotation: rotation }
          rebuild_map!
        end

        def assembled_hexes
          cells = placed_cells
          # An empty, non-playable hex lets the normal Map tab display before setup.
          return { empty: { ['M13'] => '' } } if cells.empty?

          { white: cells.to_h { |q, r, terrain| [[map_coordinate(q, r)], TERRAIN[terrain]] } }
        end
      end
    end
  end
end
