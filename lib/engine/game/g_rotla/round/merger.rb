# frozen_string_literal: true

module Engine
  module Game
    module GRotla
      module Round
        class Merger < Engine::Round::Merger
          def self.round_name
            'Merger Round'
          end

          def self.short_name
            'MR'
          end

          def select_entities
            @game.operating_order.select { |corp| corp.type == :minor }
          end
        end

        class ExportDiscard < Merger
          def self.round_name
            'Train Export — Discard Excess Trains'
          end

          def self.short_name
            'Export'
          end

          def select_entities
            @game.crowded_corps.sort
          end
        end
      end
    end
  end
end
