# frozen_string_literal: true

require_relative '../../../round/choices'

module Engine
  module Game
    module GRotla
      module Round
        class Setup < Engine::Round::Choices
          def name
            'Map Setup'
          end

          def self.short_name
            'Setup'
          end

          def select_entities
            @game.players
          end
        end

        class MapReady < Setup
          def name
            'Map Ready'
          end

          def self.short_name
            'Map'
          end
        end
      end
    end
  end
end
