# frozen_string_literal: true

require_relative 'meta'
require_relative '../base'
require_relative 'map'
require_relative 'map_builder'
require_relative 'real_map_builder'
require_relative 'extended_setup'
require_relative 'economy'
require_relative 'company_powers'
require_relative 'mergers'
require_relative 'round/merger'
require_relative 'step/merger'
require_relative 'step/stock'
require_relative 'step/operating'
require_relative 'round/setup'
require_relative 'step/map_setup'

module Engine
  module Game
    module GRotla
      class Game < Game::Base
        include_meta(GRotla::Meta)
        include Map
        include MapBuilder
        include RealMapBuilder
        include ExtendedSetup
        include Economy
        include CompanyPowers
        include Mergers

        BANK_CASH = 24_500
        STARTING_CASH = { 2 => 450, 3 => 300, 4 => 275, 5 => 220 }.freeze
        CERT_LIMIT = 99
        MARKET = Economy::MARKET
        PHASES = Economy::PHASES
        CORPORATIONS = Economy::CORPORATIONS
        TRAINS = Economy::TRAINS
        CAPITALIZATION = :incremental
        SELL_BUY_ORDER = :sell_buy
        SELL_AFTER = :operate
        SELL_MOVEMENT = :left_block
        MUST_SELL_IN_BLOCKS = true
        SOLD_OUT_INCREASE = true
        HOME_TOKEN_TIMING = :par
        MUST_BUY_TRAIN = :always
        CLOSED_CORP_TRAINS_REMOVED = false
        TRACK_RESTRICTION = :city_permissive
        GAME_END_CHECK = {}.freeze

        attr_reader :map_id

        def game_hexes
          @map_id ? Map::PRESETS[@map_id][:hexes] : assembled_hexes
        end

        def map_name
          return "#{piece_name} review" if @review_tile

          @map_id ? Map::PRESETS[@map_id][:name] : "Custom map (#{@placements&.size || 0}/#{piece_count} pieces)"
        end

        def init_starting_cash(_players, _bank); end

        def upgrades_to?(from, to, special = false, selected_company: nil)
          return from.color == :blue && from.paths.empty? if CompanyPowers::BRIDGE_TILES.include?(to.name)
          return false if from.color == :blue
          return false if from.color == :gray

          super
        end

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
          # Rebuild from setup pieces; no player-laid track or tokens exist yet.
          @hexes = init_hexes(@companies, @corporations)
          if @review_tile && (home = @hexes.find do |hex|
                                hex.tile.cities.any? && (@review_tile != 7 || hex.tile.label.to_s == 'P')
                              end)
            @review_home ||= Engine::Minor.new(sym: review_definition[:sym], name: review_definition[:name],
                                               tokens: [], color: '#57b8b0')
            home.tile.cities.first.add_reservation!(@review_home, @review_tile == 11 ? 1 : 0)
            home.location_name = review_definition[:name]
          end
          reserve_real_homes!
          @cities = (@hexes.map(&:tile) + @tiles).flat_map(&:cities)
          @graph = init_graph
          cache_objects
          connect_hexes
        end

        def starting_map
          return clone(raw_actions.take_while { |action| action['choice'] != 'play_v1' }) if @playing

          return clone(raw_actions) unless @map_id

          game = clone([])
          game.select_map!(@map_id)
          game
        end

        def init_round
          Round::Setup.new(self, [Step::MapSetup])
        end

        def cycle_limit
          micro_game? || short_map? ? 4 : 6
        end

        def game_end_check_values
          original_rules? ? {} : { bankrupt: :immediate }
        end

        def can_go_bankrupt?(player, corporation)
          return super if original_rules?

          step = @round.active_step
          return false if !step.is_a?(Step::BuyTrain) || step.is_a?(Step::LeadOffTrain)
          return false if corporation != step.current_entity || !must_buy_train?(corporation)
          return false if player.cash + corporation.cash >= @depot.min_depot_price

          @corporations.none? do |corp|
            bundles_for_corporation(player, corp).any? { |bundle| step.can_sell?(player, bundle) }
          end
        end

        def game_ending_description
          return unless @playing
          return super if @finished && @game_end_reason != :fixed_round

          @finished ? "Game ended after #{cycle_limit} cycles" : "Game ends after #{cycle_limit} complete cycles"
        end

        def result
          order = operating_order
          ranked = @players.sort_by do |player|
            [-player_value(player), order.index { |corp| corp.owner == player } || order.size, @players.index(player)]
          end
          ranked.to_h { |player| [player.id, player_value(player)] }
        end

        def advance_cycle!
          if @turn >= cycle_limit
            @log << "The final cycle (#{cycle_limit}) is complete"
            end_game!(:fixed_round)
          else
            @turn += 1
            @round = stock_round
          end
        end

        def next_round!
          if @playing
            if @round.instance_of?(Round::ExportDiscard)
              advance_cycle!
            elsif @round.instance_of?(Round::MapReady)
              @round = stock_round
            elsif @round.stock?
              if @corporations.none?(&:ipoed)
                shuffle_charters!
                @round = stock_round
                @log << 'No companies launched; reshuffle charters and restart the initial Stock Round'
              else
                reorder_players
                @round = operating_round(1)
              end
            elsif @round.operating? && @round.round_num == 1
              @round = operating_round(2)
            elsif @round.operating? && @phase.name != '2'
              @round = Round::Merger.new(self, [Step::Merger])
            else
              if !micro_game? && !@depot.upcoming.empty?
                @depot.upcoming.first.name == '2' ? @depot.export_all!('2') : @depot.export!
              end
              if crowded_corps.any?
                @round = Round::ExportDiscard.new(self, [Step::ExportDiscard])
              else
                advance_cycle!
              end
            end
            return
          end

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
