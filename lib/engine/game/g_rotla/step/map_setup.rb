# frozen_string_literal: true

require_relative '../../../step/base'

module Engine
  module Game
    module GRotla
      module Step
        class MapSetup < Engine::Step::Base
          def actions(entity)
            entity == current_entity ? ['choose'] : []
          end

          def description
            return 'Choose and confirm a map' unless map_builder?
            return 'Add optional blank hexes around minor homes, or finish setup' if @game.blank_hex_phase?
            return "#{current_entity.name}: choose a basic city for the capital" if @game.drawn_project
            if !@game.real_setup && !@game.review_tile && @game.current_piece.nil? && @game.placements.empty?
              return 'Start real map setup'
            end

            verb = @game.current_piece.nil? ? 'Draw' : 'Place'
            return "Review #{@game.piece_name}" if @game.review_tile

            "#{current_entity.name}: #{verb} triangular piece #{@game.placements.size + 1} of #{@game.piece_count}"
          end

          def map_builder?
            !@game.map_id
          end

          def choice_name
            "Map preview: #{@game.map_name}"
          end

          def choices
            Map::PRESETS.transform_values { |preset| preset[:name] }.merge('confirm' => 'Confirm this map')
          end

          def choice_explanation
            ['Legacy setup preview only. These are illustrative maps, not official RotLA presets.',
             'Choose a layout, inspect the Map tab, then confirm. The first player controls this shared setup.',
             'Start a new game to use the current map supply and full game flow.']
          end

          def process_choose(action)
            if %w[start_v5 start_build_v5].include?(action.choice)
              @game.start_extended_setup!
              @log << "Real map setup begins (#{@game.setup_mode_name}); #{current_entity.name} starts"
              if action.choice == 'start_build_v5'
                @game.draw_real_piece!
                @log << "#{current_entity.name} draws #{@game.piece_name}"
              end
              return
            end

            if %w[finish_blanks_v5 finish_setup_v5].include?(action.choice)
              @game.finish_blank_hexes!
              @game.start_play! if action.choice == 'finish_setup_v5'
              @log << "#{action.entity.name} finishes optional blank-hex placement"
              pass!
              return
            end

            if action.choice.start_with?('blank_v5:')
              parts = action.choice.split(':')
              if parts.size != 3 || parts.drop(1).any? { |part| !part.match?(/\A-?\d+\z/) }
                raise GameError, 'Invalid blank-hex action'
              end

              q, r = parts.drop(1).map(&:to_i)
              @game.place_blank_hex!(q, r)
              @log << "#{action.entity.name} places a blank hex at #{@game.map_coordinate(q, r)}"
              @round.next_entity_index!
              return
            end

            if action.choice == 'start_v4'
              @game.start_real_setup!
              @log << "Real map setup begins (#{@game.short_map? ? 'Short' : 'Long'} Game); #{current_entity.name} starts"
              return
            end

            if action.choice == 'draw_v4'
              @game.draw_real_piece!
              @log << "#{action.entity.name} draws #{@game.piece_name}"
              return
            end

            if action.choice == 'restart_v4'
              raise GameError, 'No real map setup to restart' unless @game.real_setup

              @game.reset_piece_supply!
              @game.rebuild_map!
              @round.entity_index = @game.rand % @game.players.size
              @log << 'The players restart map construction with a reshuffled supply'
              return
            end

            if action.choice.start_with?('place_v4:', 'capital_v4:')
              parts = action.choice.split(':')
              capital = parts.first == 'capital_v4'
              numbers = parts.drop(capital ? 1 : 2)
              if parts.size != (capital ? 3 : 5) || numbers.any? { |part| !part.match?(/\A-?\d+\z/) }
                raise GameError, 'Invalid real setup action'
              end
              raise GameError, 'Start real setup first' unless @game.real_setup

              if capital
                @game.resolve_capital!(*numbers.map(&:to_i))
                @log << "#{action.entity.name} upgrades #{@game.map_coordinate(*numbers.map(&:to_i))} to a capital"
              else
                @game.place_real_piece!(parts[1], *numbers.map(&:to_i))
                @log << "#{action.entity.name} places tile #{parts[1]} at #{@game.map_coordinate(*numbers.take(2).map(&:to_i))}"
              end
              @game.setup_complete? ? pass! : @round.next_entity_index!
              return
            end

            raise GameError, 'Cannot mix real and legacy setup actions' if @game.real_setup

            if MapBuilder::REVIEW_TILES.keys.any? { |n| action.choice == "review_tile#{n}_v1" }
              number = action.choice.delete_prefix('review_tile').delete_suffix('_v1').to_i
              @game.review_tile!(number)
              @log << "#{action.entity.name} starts the tile #{number} review"
              return
            end

            if action.choice == 'draw_v2'
              @game.draw_map_piece!
              terrain = @game.map_pieces[@game.drawn_piece].join(', ')
              @log << "#{action.entity.name} draws piece #{@game.drawn_piece + 1} (#{terrain})"
              return
            end

            if action.choice.start_with?('place_v1:', 'place_v2:', 'place_v3:', 'place_tile7_v1:', 'place_tile2_v1:',
                                         'place_tile9_v1:', 'place_tile11_v1:', 'place_tile26_v1:',
                                         'place_tile27_v1:', 'place_tile28_v1:')
              parts = action.choice.split(':')
              if parts.size != 5 || parts.drop(1).any? { |part| !part.match?(/\A-?\d+\z/) }
                raise GameError, 'Invalid placement action'
              end

              piece, q, r, rotation = parts.drop(1).map(&:to_i)
              legacy = parts.first == 'place_v1'
              valid_version = if @game.review_tile
                                parts.first == "place_tile#{@game.review_tile}_v1"
                              else
                                %w[place_v1 place_v2 place_v3].include?(parts.first)
                              end
              raise GameError, 'Placement version does not match the selected piece set' unless valid_version

              @game.place_map_piece!(piece, q, r, rotation, legacy: legacy, strict: !%w[place_v1 place_v2].include?(parts.first))
              @log << "#{action.entity.name} places #{@game.piece_name(piece)} at #{@game.map_coordinate(q, r)}, "\
                      "rotation #{rotation * 60}°"
              if @game.placements.size == @game.piece_count
                pass!
              elsif !legacy
                @round.next_entity_index!
              end
              return
            end

            # Preserve replay of saved preset-picker games.
            raise GameError, 'Place all four pieces to finish setup' if action.choice == 'confirm' && !@game.map_id
            raise GameError, 'Unknown map choice' unless choices.key?(action.choice)

            if action.choice == 'confirm'
              @log << "#{action.entity.name} confirms #{@game.map_name}"
              pass!
            else
              @game.select_map!(action.choice)
              @log << "#{action.entity.name} previews #{@game.map_name}"
            end
          end
        end

        class MapReady < Engine::Step::Base
          def actions(entity)
            entity == current_entity ? ['choose'] : []
          end

          def description
            @game.real_setup ? 'Map ready — start the Stock Round' : 'Map ready'
          end

          def choice_name
            @game.map_name
          end

          def choices
            return { 'reopen' => 'Try another rotation' } if @game.review_tile

            choices = { 'reopen' => @game.map_id ? 'Reopen map setup' : 'Build another map' }
            choices['play_v1'] = 'Start auctions and Stock Round' if @game.real_setup
            choices
          end

          def choice_explanation
            ['The confirmed map is available in the regular Map tab. Save/export and undo/redo preserve your selection.',
             'Start the Stock Round to auction minor companies and trade shares, then operate them. '\
             'Build another map to start over, or use Undo to revise a placement.']
          end

          def process_choose(action)
            if action.choice == 'play_v1'
              @game.start_play!
              pass!
              return
            end

            raise GameError, 'Unknown map choice' unless action.choice == 'reopen'

            @log << "#{action.entity.name} reopens map setup"
            pass!
          end
        end
      end
    end
  end
end
