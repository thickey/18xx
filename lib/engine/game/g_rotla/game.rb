# frozen_string_literal: true

require_relative 'meta'
require_relative '../base'
require_relative 'map'
require_relative 'map_builder'
require_relative 'round/setup'
require_relative 'step/map_setup'

module Engine
  module Game
    module GRotla
      class Game < Game::Base
        include_meta(GRotla::Meta)
        include Map
        include MapBuilder

        # Neutral scaffolding for map exploration; these are not RotLA economic rules.
        BANK_CASH = 10_000
        STARTING_CASH = { 2 => 0, 3 => 0, 4 => 0, 5 => 0 }.freeze
        CERT_LIMIT = 99
        MARKET = [%w[50]].freeze
        PHASES = [{ name: 'Setup', train_limit: 0, tiles: [:yellow], operating_rounds: 1 }].freeze
        GAME_END_CHECK = {}.freeze

        attr_reader :map_id

        def game_hexes
          @map_id ? Map::PRESETS[@map_id][:hexes] : assembled_hexes
        end

        def map_name
          @map_id ? Map::PRESETS[@map_id][:name] : "Custom map (#{@placements&.size || 0}/4 pieces)"
        end

        def init_starting_cash(_players, _bank); end

        def setup
          reset_piece_supply!
        end

        def select_map!(map_id)
          raise GameError, 'Map can only be changed during setup' unless @round.instance_of?(Round::Setup)
          raise GameError, 'Unknown map preset' unless Map::PRESETS.key?(map_id)

          @map_id = map_id
          rebuild_map!
        end

        def rebuild_map!
          # Rebuild the normal engine map from the placed pieces. No tokens or
          # track exist during this setup prototype.
          @hexes = init_hexes(@companies, @corporations)
          @cities = (@hexes.map(&:tile) + @tiles).flat_map(&:cities)
          @graph = init_graph
          cache_objects
          connect_hexes
        end

        def starting_map
          return clone(raw_actions) unless @map_id

          game = clone([])
          game.select_map!(@map_id)
          game
        end

        def init_round
          Round::Setup.new(self, [Step::MapSetup])
        end

        def next_round!
          @round = if @round.instance_of?(Round::Setup)
                     Round::MapReady.new(self, [Step::MapReady])
                   else
                     reset_piece_supply! unless @map_id
                     rebuild_map!
                     init_round
                   end
        end
      end
    end
  end
end
