# frozen_string_literal: true

require_relative '../../../step/buy_sell_par_shares'
require_relative '../../../round/stock'

module Engine
  module Game
    module GRotla
      module Round
        class Stock < Engine::Round::Stock
          def corporations_to_move_price
            @game.corporations.select(&:floated?)
          end
        end
      end

      module Step
        class Stock < Engine::Step::BuySellParShares
          def setup
            @bidders ||= []
            super
          end

          def active_entities
            return [@winner] if @winner
            return [@bidders[@bid_index]] unless (@bidders || []).empty?

            super
          end

          def actions(entity)
            return [] unless entity == current_entity
            return ['choose'] if @winner
            return %w[bid pass] unless @bidders.empty?

            actions = super
            actions << 'bid' if !bought? && !sold? && !@game.available_charters.empty? && entity.cash >= 120
            (actions + ['pass']).uniq
          end

          def description
            return "#{@winner.name}: choose a basic city for Adaptive Company" if @adaptive
            return "#{@winner.name}: choose a minor company to launch" if @winner
            return "Minor launch auction — #{@high_bid.entity.name} leads at #{@high_bid.price}" unless @bidders.empty?

            "#{current_entity.name}: auction a minor, sell shares, buy one share, or pass"
          end

          def pass_description
            @bidders.empty? ? super : 'Pass auction'
          end

          def help
            'Bids start at 120 in steps of 5. The winner chooses an available charter. '\
              'Only the first charter in each column is available. Shares cannot be sold before a company operates.'
          end

          def visible_corporations
            @game.corporations.select(&:ipoed)
          end

          def choice_available?(entity)
            entity == current_entity && !!@winner
          end

          def choice_name
            @adaptive ? 'Choose Adaptive home' : "Launch a company for #{@high_bid.price}"
          end

          def choices
            return @game.adaptive_home_choices.to_h { |hex| ["home:#{hex.id}", hex.id] } if @adaptive

            @game.available_charters.to_h { |corp| [corp.id, corp.full_name] }
          end

          def choice_explanation
            columns = @game.charter_columns.map { |column| column.map(&:id).join(' → ') }.join(' | ')
            ["Charter columns (available first): #{columns}"]
          end

          def can_bid?(entity)
            actions(entity).include?('bid') && entity.cash >= min_bid(nil)
          end

          def bid_entity
            @game.available_charters.first
          end

          def min_increment
            5
          end

          def min_bid(_corporation)
            @high_bid ? @high_bid.price + 5 : 120
          end

          def max_bid(entity, _corporation)
            entity.cash - (entity.cash % 5)
          end

          def bid_description
            'Bid for the right to choose an available minor: ' + @game.available_charters.map(&:full_name).join(', ')
          end

          def committed_cash(_entity, _show_hidden = false)
            0
          end

          def process_bid(action)
            if action.price < min_bid(nil) || action.price > max_bid(action.entity, nil) || !(action.price % 5).zero?
              raise GameError, 'Bid at least 120, then increase by multiples of 5 within your cash'
            end

            if @bidders.empty?
              @initiator = action.entity
              @bidders = entities.rotate(entity_index).dup
              @bid_index = 0
            end
            @high_bid = action
            @log << "#{action.entity.name} bids #{@game.format_currency(action.price)} for a minor launch"
            @bid_index = (@bid_index + 1) % @bidders.size
          end

          def process_pass(action)
            return super if @bidders.empty?

            @log << "#{action.entity.name} leaves the launch auction"
            @bidders.delete(action.entity)
            @bid_index %= @bidders.size
            @winner = @high_bid.entity if @bidders.one?
          end

          def process_choose(action)
            raise GameError, 'Choose an available option' unless choices.key?(action.choice)

            if @adaptive
              hex = @game.hex_by_id(action.choice.delete_prefix('home:'))
              @adaptive.coordinates = hex.id
              @game.place_home_token(@adaptive)
              @adaptive = nil
              finish_auction!
              return
            end
            corporation = @game.corporation_by_id(action.choice)
            @game.launch_minor!(@winner, corporation, @high_bid.price)
            if corporation.id == 'AD'
              @adaptive = corporation
            else
              finish_auction!
            end
          end

          def finish_auction!
            @round.last_to_act = @initiator
            @round.current_actions << @high_bid
            @winner = @high_bid = nil
            @bidders = []
            entities.each(&:unpass!)
            @round.goto_entity!(@initiator)
            pass!
          end

          def can_buy?(entity, bundle)
            bundle&.corporation&.ipoed && super
          end

          def can_sell?(entity, bundle)
            bundle && sold_this_turn(bundle.corporation).zero? && super
          end

          def can_ipo_any?(_entity)
            false
          end
        end
      end
    end
  end
end
