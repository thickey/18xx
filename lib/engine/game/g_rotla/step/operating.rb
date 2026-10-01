# frozen_string_literal: true

module Engine
  module Game
    module GRotla
      module Step
        # Add choices to every OR step so either suburb can be placed at any time.
        module Suburbs
          def actions(entity)
            result = super
            return result if entity != current_entity || @game.suburb_choices(entity).empty?
            return result if entity != @round.entities[@round.entity_index]

            result = ['pass'] if result.empty?
            (result + ['choose']).uniq
          end

          def choice_name
            'Company choices'
          end

          def choices
            existing = defined?(super) ? super : {}
            existing.merge(@game.suburb_choices(current_entity))
          end

          def process_choose(action)
            return super unless action.choice.start_with?('suburb:')

            @game.place_suburb!(action.entity, action.choice)
          end
        end

        class BuyTrain < Engine::Step::BuyTrain
          def can_sell?(entity, bundle)
            return super if @game.original_rules?
            return false if entity != current_entity.owner || !must_buy_train?(current_entity)
            return false if !bundle || bundle.num_shares != 1 || !@game.check_sale_timing(entity, bundle)
            return false if entity.cash + current_entity.cash >= @depot.min_depot_price

            sellable_bundle?(bundle)
          end

          def process_sell_shares(action)
            return super if @game.original_rules?
            unless can_sell?(action.entity, action.bundle)
              raise GameError, 'Sell one legal share at a time to fund the mandatory train'
            end

            @game.share_pool.sell_shares(action.bundle)
            @emergency_sales ||= []
            @emergency_sales << action.bundle.corporation unless @emergency_sales.include?(action.bundle.corporation)
          end

          def finish_emergency_sales!
            (@emergency_sales || []).each do |corp|
              old = corp.share_price
              @game.stock_market.move_left(corp)
              @game.log_share_price(corp, old)
            end
            @emergency_sales = []
            @round.recalculate_order if @round.respond_to?(:recalculate_order)
          end

          def actions(entity)
            result = super
            result.delete('pass') if entity == current_entity && @game.must_buy_train?(entity)
            result
          end

          def process_pass(action)
            raise GameError, 'A trainless company must buy a train' if @game.must_buy_train?(action.entity)

            super
          end

          def buyable_trains(entity)
            super.reject(&:rusted)
          end

          def process_buy_train(action)
            raise GameError, 'A rusted train cannot be traded in' if action.exchange&.rusted

            super
            finish_emergency_sales! unless @game.original_rules?
          end
        end

        class Bankrupt < Engine::Step::Base
          def blocks?
            false
          end

          def description
            'Declare bankruptcy'
          end

          def actions(entity)
            return [] if @game.original_rules? || entity != current_entity
            return [] unless @game.can_go_bankrupt?(entity.owner, entity)

            ['bankrupt']
          end

          def process_bankrupt(action)
            unless actions(action.entity).any?
              raise GameError, 'Finish all available forced share sales before declaring bankruptcy'
            end

            @round.active_step.finish_emergency_sales!
            @game.declare_bankrupt(action.entity.owner)
            @log << "#{action.entity.owner.name} cannot fund a mandatory train and declares bankruptcy"
          end
        end

        class LeadOffTrain < BuyTrain
          def actions(entity)
            return [] if entity != current_entity || entity.type != :minor || entity.operated?

            result = can_buy_train?(entity) ? %w[buy_train pass] : ['pass']
            result << 'choose' if @game.suburb_choices(entity).any?
            result
          end

          def description
            'Optional first-OR leadoff train'
          end

          def president_may_contribute?(_entity, _shell = nil)
            false
          end

          def must_buy_train?(_entity)
            false
          end

          def buyable_trains(entity)
            @depot.depot_trains.select { |train| train.price <= entity.cash }
          end

          def process_buy_train(action)
            super
            pass!
          end

          def process_pass(action)
            log_pass(action.entity)
            pass!
          end
        end

        class IssueShares < Engine::Step::IssueShares
          def process_sell_shares(action)
            unless issuable_shares(action.entity).any? { |bundle| bundle.shares == action.bundle.shares }
              raise GameError, 'Issue one treasury share within the 50% bank pool limit'
            end

            old = action.entity.share_price
            super
            @game.stock_market.move_left(action.entity)
            @game.log_share_price(action.entity, old)
          end

          def process_buy_shares(action)
            unless redeemable_shares(action.entity).any? { |bundle| bundle.shares == action.bundle.shares }
              raise GameError, 'Redeem one affordable bank pool share'
            end

            super
          end
        end

        class Track < Engine::Step::Track
          def potential_tile_colors(entity, hex)
            colors = super
            colors << :blue if @game.company_power?(entity, 'BR') && hex.tile.color == :blue && hex.tile.paths.empty?
            colors
          end

          def potential_tiles(entity, hex)
            super.reject { |tile| @game.class::BRIDGE_TILES.include?(tile.name) && !@game.company_power?(entity, 'BR') }
          end

          def available_hex(entity, hex)
            return nil if @game.class::BRIDGE_TILES.include?(hex.tile.name)

            if hex.tile.color == :blue
              return nil if !@game.company_power?(entity, 'BR') || !hex.tile.paths.empty? || !get_tile_lay(entity)&.dig(:lay)

              return hex_neighbors(entity, hex)
            end
            super
          end

          def track_upgrade?(from, to, hex)
            return false if @game.class::BRIDGE_TILES.include?(to.name)

            super
          end

          def process_lay_tile(action)
            if @game.class::BRIDGE_TILES.include?(action.tile.name)
              raise GameError, 'Only Bridging can lay bridges' unless @game.company_power?(action.entity, 'BR')
              raise GameError, 'A bridge replaces a yellow lay' unless get_tile_lay(action.entity)&.dig(:lay)
            end
            mountain = action.hex.tile.upgrades.any? { |upgrade| upgrade.terrains.include?(:mountain) }
            super
            return if !@game.company_power?(action.entity, 'TU') || !mountain

            @game.bank.spend(60, action.entity)
            @log << 'Tunneling receives 60 after paying the mountain cost'
          end

          def legal_tile_rotation?(entity, hex, tile)
            return false if tile.exits.any? do |edge|
              neighbor = hex.all_neighbors[edge]
              !neighbor || neighbor.empty ||
                (neighbor.tile.color == :blue && neighbor.tile.paths.empty? && !@game.company_power?(entity, 'BR')) ||
                neighbor.tile.color == :gray ||
                (neighbor.tile.color == :red && !neighbor.tile.exits.include?(hex.invert(edge)))
            end

            super
          end
        end

        class Token < Engine::Step::Token
        end

        class DiscardTrain < Engine::Step::DiscardTrain
          def trains(entity)
            super.reject(&:rusted)
          end
        end

        class Route < Engine::Step::Route
          def actions(entity)
            return [] if entity != current_entity || @game.route_trains(entity).empty?

            %w[run_routes choose]
          end

          def choice_name
            'Local routes'
          end

          def choices
            { 'local' => 'Run every train locally at a hub' }
          end

          def choice_explanation
            ['Local routes count one hub city without using track. You can also trace routes on the map. '\
             'Any trains without a traced route run locally at their highest-value hub.']
          end

          def process_choose(action)
            raise GameError, 'Unknown local-route option' unless action.choice == 'local'

            entity = action.entity
            city = entity.tokens.select(&:used).map(&:city).max_by { |c| c.route_revenue(@game.phase, entity.trains.first) }
            raise GameError, 'Local routes require a hub' unless city

            @round.extra_revenue = @game.route_trains(entity).sum { |train| city.route_revenue(@game.phase, train) }
            @round.routes = []
            @log << "#{entity.name} runs local routes at #{city.hex.id} for #{@round.extra_revenue}"
            pass!
          end

          def process_run_routes(action)
            raise GameError, 'Route revenue must come from traced routes' unless action.extra_revenue.to_i.zero?

            super
            unused = @game.route_trains(action.entity) - action.routes.map(&:train)
            cities = action.entity.tokens.select(&:used).map(&:city)
            @round.extra_revenue = unused.sum do |train|
              cities.map { |city| city.route_revenue(@game.phase, train) }.max || 0
            end
            @log << "#{action.entity.name} also earns #{@round.extra_revenue} from local routes" if unused.any?
          end
        end

        class Dividend < Engine::Step::Dividend
          def process_dividend(action)
            retained = action.entity.trains.select(&:rusted)
            super
            retained.each do |train|
              @game.rust(train)
              @log << "Resourceful discards its #{train.name} train after its final run"
            end
          end

          def share_price_change(entity, revenue)
            return { share_direction: :left, share_times: 1 } if revenue.zero?
            return { share_direction: :right, share_times: 2 } if revenue >= entity.share_price.price * 2
            return { share_direction: :right, share_times: 1 } if revenue >= entity.share_price.price

            { share_direction: :right, share_times: 0 }
          end

          def change_share_price(entity, payout)
            super
            return unless payout[:share_times].zero?

            prices = entity.share_price.corporations
            prices.delete(entity)
            prices << entity
          end
        end

        [BuyTrain, IssueShares, Track, Token, Route, Dividend, DiscardTrain].each do |step|
          step.prepend(Suburbs)
        end
      end
    end
  end
end
