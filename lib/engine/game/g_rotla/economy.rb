# frozen_string_literal: true

module Engine
  module Game
    module GRotla
      module Economy
        NAMES = {
          'AD' => 'Adaptive',
          'AG' => 'Agricultural',
          'BR' => 'Bridging',
          'EM' => 'Eastern Mining',
          'EA' => 'Expansive',
          'ER' => 'Express',
          'NP' => 'Northern Port',
          'OV' => 'Overnight',
          'RE' => 'Resourceful',
          'SP' => 'Spacious',
          'SU' => 'Suburban',
          'TU' => 'Tunneling',
        }.freeze
        COLORS = %w[#8865a9 #318653 #61a798 #986440 #c76291 #b63f49 #315785 #626949 #98744b #668349 #b76995 #77716b].freeze
        POWERS = {
          'AD' => 'Choose an empty basic home city when launching.',
          'AG' => 'May lay a yellow tile after upgrading track.',
          'BR' => 'Five bridges replace yellow lays over water; track may point into water. Bridges cannot upgrade.',
          'EM' => 'Mining home has two stops and its own upgrade set.',
          'EA' => 'One extra hub costs 40 to place.',
          'ER' => 'With exactly one train, it may visit one extra stop.',
          'NP' => 'The Port halves count as one city and have their own upgrade set.',
          'OV' => 'Pass through fully tokened cities for track and routes; skipped cities earn nothing and use no stops.',
          'RE' => 'Rusted trains run once more, then are removed. They use no train slots and cannot be sold or traded in.',
          'SP' => 'One extra train slot beyond the current limit.',
          'SU' => 'Two suburbs: place during any OR step in reachable basic cities without your hub; +10 per visiting train.',
          'TU' => 'Pay the 40 mountain cost first, then receive 60 into the treasury.',
        }.freeze
        MAJORS = {
          'Con' => 'Conglomerate',
          'Exp' => 'Experiment',
          'Fed' => 'Federation',
          'Int' => 'International',
          'Syn' => 'Syndicate',
          'Unl' => 'Unlimited',
        }.freeze
        CORPORATIONS = (NAMES.map.with_index do |(sym, name), index|
          {
            sym: sym,
            name: "#{name} Company",
            shares: [40, 20, 20, 20],
            tokens: sym == 'EA' ? [0, 40] : [0],
            float_percent: 40,
            max_ownership_percent: 60,
            always_market_price: true,
            type: 'minor',
            color: COLORS[index],
            logo: "rotla/#{sym}",
            simple_logo: "rotla/#{sym}",
            abilities: [{ type: 'description', description: "#{name} power (click for details)", desc_detail: POWERS[sym] }],
          }
        end + MAJORS.map.with_index do |(sym, name), index|
          {
            sym: sym,
            name: name,
            shares: [20, 10, 10, 10, 10, 10, 10, 10, 10],
            tokens: [0, 0, 60, 60],
            float_percent: 20,
            max_ownership_percent: 60,
            always_market_price: true,
            type: 'major',
            color: COLORS[index],
            logo: "rotla/#{sym}",
            simple_logo: "rotla/#{sym}",
          }
        end).freeze
        MARKET = [%w[0c 10 20 30 40 50 60p 70p 80p 90p 100p 110p 120p 135p 150 165 180 200 220 245 270 300 330 360 400 450
                     500]].freeze
        PHASES = [
          { name: '2', train_limit: { minor: 2, major: 0 }, tiles: [:yellow], operating_rounds: 2 },
          { name: '3', on: '3', train_limit: { minor: 2, major: 4 }, tiles: %i[yellow green], operating_rounds: 2 },
          { name: '4', on: '4', train_limit: { minor: 2, major: 3 }, tiles: %i[yellow green], operating_rounds: 2 },
          { name: '5', on: '5', train_limit: { minor: 1, major: 2 }, tiles: %i[yellow green brown], operating_rounds: 2 },
          { name: '6', on: '6', train_limit: { minor: 1, major: 2 }, tiles: %i[yellow green brown], operating_rounds: 2 },
          { name: '7', on: '7', train_limit: { minor: 1, major: 2 }, tiles: %i[yellow green brown gray], operating_rounds: 2 },
        ].freeze
        TRAINS = [
          { name: '2', distance: 2, price: 100, num: 7, rusts_on: '4' },
          { name: '3', distance: 3, price: 200, num: 5, rusts_on: '6' },
          { name: '4', distance: 4, price: 300, num: 4, rusts_on: '7' },
          { name: '5', distance: 5, price: 450, num: 3 },
          { name: '6', distance: 6, price: 550, num: 2 },
          {
            name: '7',
            distance: 7,
            price: 750,
            num: 'unlimited',
            variants: [{
              name: '∞',
              distance: 99,
              price: 1000,
              discount: {
                '2' => 200,
                '3' => 200,
                '4' => 200,
                '5' => 200,
                '6' => 200,
                '7' => 200,
              },
            }],
          },
        ].freeze

        attr_reader :playing, :charter_columns

        def original_rules?
          @optional_rules.include?(:original_rules)
        end

        def game_trains
          definitions = TRAINS.map do |train|
            definition = train.dup
            name = train[:name]
            if micro_game?
              definition[:num] = { '2' => @players.size == 2 ? 3 : 5, '3' => @players.size == 2 ? 3 : 4, '4' => 4 }[name]
              definition[:num] = 3 if name == '4' && @players.size == 2
            elsif name != '7'
              extra_players = original_rules? ? 5 : 4
              definition[:num] += 1 if name == '3' && @players.size >= extra_players
              definition[:num] += 1 if name == '6' && !original_rules? && @players.size >= 4
              definition[:num] -= 1 if short_map?
            end
            definition
          end
          definitions.select { |train| train[:num] }
        end

        def start_play!
          raise GameError, 'Complete a real map before starting the stock round' if !@real_setup || !setup_complete?
          raise GameError, 'The game has already started' if @playing

          @playing = true
          @corporations.select! { |corp| corp.type == :major || setup_minor_ids.include?(corp.id) }
          @hexes.each do |hex|
            hex.tile.cities.each do |city|
              city.reservations.map! { |reservation| @corporations.find { |corp| corp.id == reservation&.id } }
            end
          end
          @corporations.each do |corp|
            next if corp.id == 'AD' || corp.type == :major

            hex = @hexes.find { |h| h.tile.cities.any? { |city| city.reserved_by?(corp) } }
            corp.coordinates = hex.id
          end
          cash = micro_game? ? 225 : { 2 => 450, 3 => 300, 4 => 275, 5 => 220 }[@players.size]
          @players.each { |player| @bank.spend(cash, player) }
          shuffle_charters!
          @players.rotate!(rand % @players.size)
          @players.each(&:unpass!)
          cache_objects
          @log << "Stock rounds begin; #{@players.first.name} has priority. Starting cash: #{format_currency(cash)}"
        end

        def shuffle_charters!
          rows = if micro_game?
                   @players.size == 2 ? 2 : 3
                 else
                   4
                 end
          @charter_columns = @corporations.select { |corp| corp.type == :minor && !corp.ipoed }
                                         .sort_by { rand }.each_slice(rows).map(&:to_a)
        end

        def available_charters
          (@charter_columns || []).filter_map(&:first)
        end

        def launch_minor!(player, corporation, bid)
          raise GameError, 'Choose an available charter' unless available_charters.include?(corporation)

          price = @stock_market.par_prices.select { |p| p.price <= [bid / 2, maximum_par].min }.max_by(&:price)
          @stock_market.set_par(corporation, price)
          @share_pool.buy_shares(player, corporation.presidents_share, exchange: :free)
          player.spend(bid, corporation)
          corporation.ipoed = true
          corporation.floated = true
          @charter_columns.find { |column| column.first == corporation }.shift
          place_home_token(corporation) unless corporation.id == 'AD'
          @log << "#{player.name} launches #{corporation.full_name} for #{format_currency(bid)}; stock price #{price.price}"
        end

        def maximum_par
          return 90 if @phase.name == '2'
          return 110 if %w[3 4].include?(@phase.name)

          135
        end

        def adaptive_home_choices
          @hexes.select do |hex|
            hex.tile.cities.one? && hex.tile.label.to_s.empty? &&
              hex.tile.cities.first.tokens.compact.empty? && hex.tile.cities.first.reservations.compact.empty?
          end
        end

        def operating_round(round_num)
          Engine::Round::Operating.new(self, [Step::Bankrupt, Step::LeadOffTrain, [Step::IssueShares, { blocks: true }],
                                              Step::Track, Step::Token, Step::Route, Step::Dividend,
                                              Step::DiscardTrain, Step::BuyTrain], round_num: round_num)
        end

        def stock_round
          @players.each(&:unpass!)
          Round::Stock.new(self, [Step::Stock])
        end

        def can_par?(_corporation, _player)
          false
        end

        def ipo_name(_entity = nil)
          'Treasury'
        end

        def train_limit(entity)
          super + (company_power?(entity, 'SP') ? 1 : 0)
        end

        def check_distance(route, visits, train = nil)
          train ||= route.train
          if company_power?(train.owner, 'ER') && train.owner.trains.one?
            raise RouteTooLong, 'Express train exceeds its boosted distance' if visits.sum(&:visit_cost) > train.distance + 1

            return
          end
          super
        end

        def check_other(route)
          super
          connections = route.connection_data
          unless connections.empty?
            nodes = [connections.first[:left]] + connections.map { |connection| connection[:right] }
            raise GameError, 'An offboard may only start or end a route' if nodes[1...-1].any?(&:offboard?)
          end
          ports = route.visited_stops.select { |stop| stop.tile.label.to_s == 'P' }
          raise GameError, 'Both halves of the Port count as the same city' if ports.group_by(&:hex).any? do |_, stops|
                                                                                 stops.size > 1
                                                                               end
        end

        def tile_lays(entity)
          [{ lay: true, upgrade: true }, { lay: company_power?(entity, 'AG') ? true : :not_if_upgraded, upgrade: false }]
        end

        def issuable_shares(entity)
          return [] unless @share_pool.percent_of(entity) + entity.share_percent <= 50

          share = entity.shares_of(entity).find { |s| !s.president }
          share ? [share.to_bundle] : []
        end

        def redeemable_shares(entity)
          share = @share_pool.shares_of(entity).first
          share && share.price <= entity.cash ? [share.to_bundle] : []
        end

        def must_buy_train?(entity)
          entity.trains.empty? && !@depot.depot_trains.empty?
        end

        def check_sale_timing(entity, bundle)
          bundle.corporation.type == :major || super
        end
      end
    end
  end
end
