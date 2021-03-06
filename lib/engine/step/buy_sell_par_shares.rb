# frozen_string_literal: true

require_relative 'base'
require_relative 'share_buying'
require_relative 'programmer'
require_relative '../action/buy_company'
require_relative '../action/buy_shares'
require_relative '../action/par'

module Engine
  module Step
    class BuySellParShares < Base
      include ShareBuying
      include Programmer

      PURCHASE_ACTIONS = [Action::BuyCompany, Action::BuyShares, Action::Par].freeze

      def actions(entity)
        return [] unless entity == current_entity
        return ['sell_shares'] if must_sell?(entity)

        actions = []
        actions << 'buy_shares' if can_buy_any?(entity)
        actions << 'par' if can_ipo_any?(entity)
        actions << 'buy_company' unless purchasable_companies(entity).empty?
        actions << 'sell_shares' if can_sell_any?(entity)

        actions << 'pass' unless actions.empty?
        actions
      end

      def log_pass(entity)
        return @log << "#{entity.name} passes" if @current_actions.empty?
        return if bought? && sold?

        action = bought? ? 'to sell' : 'to buy'
        @log << "#{entity.name} declines #{action} shares"
      end

      def log_skip(entity)
        @log << "#{entity.name} has no valid actions and passes"
      end

      def description
        case @game.class::SELL_BUY_ORDER
        when :sell_buy_or_buy_sell
          'Buy or Sell Shares'
        when :sell_buy
          'Sell then Buy Shares'
        when :sell_buy_sell
          'Sell/Buy/Sell Shares'
        end
      end

      def pass_description
        if @current_actions.empty?
          'Pass (Share)'
        else
          'Done (Share)'
        end
      end

      def round_state
        { players_sold: Hash.new { |h, k| h[k] = {} } }
      end

      def setup
        # player => corporation => :now or :prev
        # this differentiates between preventing users from buying shares they sold
        # and preventing users from selling the same shares separately in the some action
        @round.players_sold.each do |_player, corps|
          corps.each { |corp, _k| corps[corp] = :prev }
        end

        @current_actions = []
      end

      # Returns if a share can be bought via a normal buy actions
      # If a player has sold shares they cannot buy in many 18xx games
      # Some 18xx games can only buy one share per turn.
      def can_buy?(entity, bundle)
        return unless bundle&.buyable

        corporation = bundle.corporation
        entity.cash >= bundle.price &&
          !@round.players_sold[entity][corporation] &&
          (can_buy_multiple?(entity, corporation) || !bought?) &&
          can_gain?(entity, bundle)
      end

      def must_sell?(entity)
        return false if @game.can_hold_above_limit?(entity)

        @game.num_certs(entity) > @game.cert_limit ||
          !@game.corporations.all? { |corp| corp.holding_ok?(entity) }
      end

      def can_sell?(entity, bundle)
        return unless bundle

        corporation = bundle.corporation

        timing = @game.check_sale_timing(entity, corporation)

        timing &&
          !(@game.class::MUST_SELL_IN_BLOCKS && @round.players_sold[entity][corporation] == :now) &&
          can_sell_order? &&
          @game.share_pool.fit_in_bank?(bundle) &&
          bundle.can_dump?(entity)
      end

      def can_sell_order?
        case @game.class::SELL_BUY_ORDER
        when :sell_buy_or_buy_sell
          !(@current_actions.uniq(&:class).size == 2 &&
            self.class::PURCHASE_ACTIONS.include?(@current_actions.last.class))
        when :sell_buy
          !bought?
        when :sell_buy_sell
          true
        end
      end

      def did_sell?(corporation, entity)
        @round.players_sold[entity][corporation]
      end

      def process_buy_shares(action)
        buy_shares(action.entity, action.bundle, swap: action.swap)
        @round.last_to_act = action.entity
        @current_actions << action
      end

      def process_sell_shares(action)
        sell_shares(action.entity, action.bundle, swap: action.swap)
        @round.last_to_act = action.entity
        @current_actions << action
      end

      def process_par(action)
        share_price = action.share_price
        corporation = action.corporation
        entity = action.entity
        raise GameError, "#{corporation.name} cannot be parred" unless @game.can_par?(corporation, entity)

        @game.stock_market.set_par(corporation, share_price)
        share = corporation.shares.first
        buy_shares(entity, share.to_bundle)
        @game.after_par(corporation)
        @round.last_to_act = entity
        @current_actions << action
      end

      def pass!
        super
        if @current_actions.any?
          @round.pass_order.delete(current_entity)
          current_entity.unpass!
        else
          @round.pass_order |= [current_entity]
          current_entity.pass!
        end
      end

      def can_buy_multiple?(_entity, corporation)
        corporation.buy_multiple? &&
         @current_actions.none? { |x| x.is_a?(Action::Par) } &&
         @current_actions.none? { |x| x.is_a?(Action::BuyShares) && x.bundle.corporation != corporation }
      end

      def can_sell_any?(entity)
        @game.corporations.any? do |corporation|
          bundles = @game.bundles_for_corporation(entity, corporation)
          bundles.any? { |bundle| can_sell?(entity, bundle) }
        end
      end

      def can_buy_shares?(entity, shares)
        min_share = nil

        shares.each do |share|
          next unless share.buyable

          min_share = share if !min_share || share.percent < min_share.percent
        end

        can_buy?(entity, min_share&.to_bundle)
      end

      def can_buy_any_from_market?(entity)
        @game.share_pool.shares.group_by(&:corporation).each do |_, shares|
          return true if can_buy_shares?(entity, shares)
        end

        false
      end

      def can_buy_any_from_ipo?(entity)
        @game.corporations.each do |corporation|
          next unless corporation.ipoed
          return true if can_buy_shares?(entity, corporation.shares)
        end

        false
      end

      def can_buy_any?(entity)
        (can_buy_any_from_market?(entity) ||
        can_buy_any_from_ipo?(entity))
      end

      def can_ipo_any?(entity)
        !bought? && @game.corporations.any? do |c|
          @game.can_par?(c, entity) && can_buy?(entity, c.shares.first&.to_bundle)
        end
      end

      def ipo_type(_entity)
        :par
      end

      def purchasable_companies(entity)
        return [] if bought? ||
          !entity.cash.positive? ||
          !@game.phase.status.include?('can_buy_companies_from_other_players')

        @game.purchasable_companies(entity)
      end

      def get_par_prices(entity, _corp)
        @game
          .stock_market
          .par_prices
          .select { |p| p.price * 2 <= entity.cash }
      end

      def sell_shares(entity, shares, swap: nil)
        raise GameError, "Cannot sell shares of #{shares.corporation.name}" if !can_sell?(entity, shares) && !swap

        @round.players_sold[shares.owner][shares.corporation] = :now
        @game.sell_shares_and_change_price(shares, swap: swap)
      end

      def bought?
        @current_actions.any? { |x| self.class::PURCHASE_ACTIONS.include?(x.class) }
      end

      def sold?
        @current_actions.any? { |x| x.instance_of?(Action::SellShares) }
      end

      def process_buy_company(action)
        entity = action.entity
        company = action.company
        price = action.price
        owner = company.owner

        raise GameError, "Cannot buy #{company.name} from #{owner.name}" if owner&.corporation?

        company.owner = entity
        owner&.companies&.delete(company)

        entity.companies << company
        entity.spend(price, owner.nil? ? @game.bank : owner)
        @current_actions << action
        @log << "#{owner ? '-- ' : ''}#{entity.name} buys #{company.name} from "\
                "#{owner ? owner.name : 'the market'} for #{@game.format_currency(price)}"
      end

      def auto_actions(entity)
        programmed_auto_actions(entity)
      end

      def activate_program_buy_shares(entity, program)
        # TODO: non-ipo? non-10% shares
        available_actions = actions(entity)
        if available_actions.include?('buy_shares')
          corporation = program.corporation
          # check if end condition met
          if program.until_condition == 'float'
            return [Action::ProgramDisable.new(entity,
                                               reason: "#{corporation.name} is floated")] if corporation.floated?
            # TODO: until n shares
          end
          share = corporation.ipo_shares.first
          if can_buy?(entity, share.to_bundle)
            [Action::BuyShares.new(entity, shares: share)]
          else
            [Action::ProgramDisable.new(entity, reason: "Cannot buy #{corporation.name}")]
          end
        elsif bought? && available_actions.include?('pass')
          # Buy-then-Sell games need the pass
          [Action::Pass.new(entity)]
        end
      end
    end
  end
end
