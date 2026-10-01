# frozen_string_literal: true

module Engine
  module Game
    module GRotla
      # v5 adds Micro Game supply selection and an optional end-of-construction phase.
      # Existing v4 actions retain their supply and automatic completion behavior.
      module ExtendedSetup
        attr_reader :setup_version, :blank_hexes

        def init_optional_rules(optional_rules)
          error = self.class.meta.check_options(optional_rules, @players.size, @players.size)&.[](:error)
          raise GameError, error if error

          super
        end

        def micro_game?
          @optional_rules.include?(:micro_game_2) || @optional_rules.include?(:micro_game_3)
        end

        def short_map?
          return false if micro_game?

          super
        end

        def setup_mode_name
          return "#{@players.size}-player Micro Game" if micro_game?

          short_map? ? 'Short Game' : 'Long Game'
        end

        def setup_piece_count
          if micro_game?
            @players.size == 2 ? 11 : 16
          else
            real_catalog.size
          end
        end

        def real_catalog
          @real_supply || super
        end

        def capital_count
          micro_game? ? 1 : super
        end

        def setup_minor_ids
          ids = real_catalog.filter_map { |piece| piece[:home] }
          ids << 'AD' if micro_game? && real_catalog.any? { |piece| piece[:number] == 21 }
          ids << 'AD' if !micro_game? && !short_map?
          ids.sort
        end

        def start_extended_setup!
          error = self.class.meta.check_options(@optional_rules, @players.size, @players.size)&.[](:error)
          raise GameError, error if error
          if !@round.instance_of?(Round::Setup) || !@placements.empty? || @drawn_piece || @review_tile || @map_id || @real_setup
            raise GameError, 'Start real setup before drawing or placing pieces'
          end

          @setup_version = 5
          @real_supply = select_micro_supply if micro_game?
          start_real_setup!
        end

        def select_micro_supply
          catalog = MapCatalog::PIECES
          piles = Array.new(@players.size == 2 ? 3 : 2) { [] }
          homes, remaining = catalog.partition { |piece| piece[:home] || piece[:number] == 21 }
          destinations, others = remaining.partition { |piece| piece[:number] >= 26 }
          destinations = destinations.reject { |piece| piece[:number] == 26 } if @players.size == 3
          [homes, destinations, others].each do |group|
            group.sort_by { rand }.each_with_index { |piece, index| piles[index % piles.size] << piece }
          end
          selected = piles[rand % piles.size].map { |piece| piece[:id] }
          catalog.select { |piece| selected.include?(piece[:id]) }
        end

        def reset_piece_supply!
          super
          return unless @setup_version == 5

          @blank_hexes = []
          @blank_hexes_finished = false
        end

        def construction_complete?
          @placements.size == piece_count && @capital_cells.size == capital_count
        end

        def blank_hex_phase?
          @setup_version == 5 && construction_complete? && !@blank_hexes_finished
        end

        def draw_real_piece!
          raise GameError, 'Add optional blank hexes or finish setup; all tri-hex pieces are placed' if blank_hex_phase?

          super
        end

        def setup_complete?
          return super unless @setup_version == 5

          construction_complete? && @blank_hexes_finished
        end

        def placed_cells
          cells = super
          @setup_version == 5 ? cells + (@blank_hexes || []).map { |q, r| [q, r, :blank] } : cells
        end

        def minor_home_cells
          @placements.flat_map do |p|
            piece = real_catalog[p[:piece]]
            cells = piece_cells(p[:q], p[:r], p[:rotation], p[:piece])
            next cells if micro_game? && piece[:number] == 21
            next [] unless piece[:home]

            [cells[piece[:home_cell]]]
          end
        end

        def legal_blank_hex?(q, r)
          return false unless blank_hex_phase?
          return false unless [q, r].all? { |n| n.is_a?(Integer) }
          return false if @blank_hexes.size >= 12 || !(q + 12).between?(-26, 51)

          cells = placed_cells.to_h { |x, y, terrain| [[x, y], terrain] }
          return false if cells.key?([q, r])
          return false if MapBuilder::DIRECTIONS.any? { |dx, dy| cells[[q + dx, r + dy]] == :border }

          minor_home_cells.any? { |x, y, _| MapBuilder::DIRECTIONS.include?([q - x, r - y]) }
        end

        def blank_hex_anchors
          return [] unless blank_hex_phase?

          candidates = minor_home_cells.flat_map do |q, r, _|
            MapBuilder::DIRECTIONS.map { |dx, dy| [q + dx, r + dy] }
          end
          candidates.uniq.select { |q, r| legal_blank_hex?(q, r) }.sort
        end

        def place_blank_hex!(q, r)
          unless legal_blank_hex?(q, r)
            raise GameError,
                  'Place blank hexes next to a minor home, without overlap or border contact (maximum 12)'
          end

          @blank_hexes << [q, r]
          rebuild_map!
        end

        def finish_blank_hexes!
          raise GameError, 'Finish map construction before placing optional blank hexes' unless blank_hex_phase?

          @blank_hexes_finished = true
        end

        def assembled_hexes
          hexes = super
          return hexes unless @setup_version == 5

          @blank_hexes&.each { |q, r| hexes[:white][[map_coordinate(q, r)]] = '' }
          hexes
        end
      end
    end
  end
end
