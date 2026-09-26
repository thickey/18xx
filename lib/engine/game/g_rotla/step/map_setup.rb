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

            verb = @game.current_piece.nil? ? 'Draw' : 'Place'
            "#{current_entity.name}: #{verb} triangular piece #{@game.placements.size + 1} of 4"
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
            ['Setup prototype only. These are illustrative maps, not official RotLA presets.',
             'Choose a layout, inspect the Map tab, then confirm. The first player controls this shared setup.',
             'Auctions, minors, majors, trains, and company powers are not implemented yet.']
          end

          def process_choose(action)
            if action.choice == 'draw_v2'
              @game.draw_map_piece!
              terrain = MapBuilder::PIECES[@game.drawn_piece].join(', ')
              @log << "#{action.entity.name} draws piece #{@game.drawn_piece + 1} (#{terrain})"
              return
            end

            if action.choice.start_with?('place_v1:', 'place_v2:')
              parts = action.choice.split(':')
              if parts.size != 5 || parts.drop(1).any? { |part| !part.match?(/\A-?\d+\z/) }
                raise GameError, 'Invalid placement action'
              end

              piece, q, r, rotation = parts.drop(1).map(&:to_i)
              legacy = parts.first == 'place_v1'
              @game.place_map_piece!(piece, q, r, rotation, legacy: legacy)
              @log << "#{action.entity.name} places piece #{piece + 1} at #{@game.map_coordinate(q, r)}, "\
                      "rotation #{rotation * 60}°"
              if @game.placements.size == MapBuilder::PIECES.size
                pass!
              elsif !legacy
                @round.next_entity_index!
              end
              return
            end

            # Preserve replay of saved preset-picker prototypes.
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
            'Map ready — gameplay is not implemented'
          end

          def choice_name
            @game.map_name
          end

          def choices
            { 'reopen' => @game.map_id ? 'Reopen map setup' : 'Build another map' }
          end

          def choice_explanation
            ['The confirmed map is available in the regular Map tab. Save/export and undo/redo preserve your selection.',
             'All setup is complete. Gameplay is not implemented. '\
             'Build another map to start over, or use Undo to revise a placement.']
          end

          def process_choose(action)
            raise GameError, 'Unknown map choice' unless action.choice == 'reopen'

            @log << "#{action.entity.name} reopens map setup"
            pass!
          end
        end
      end
    end
  end
end
