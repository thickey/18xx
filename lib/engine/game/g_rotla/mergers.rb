# frozen_string_literal: true

module Engine
  module Game
    module GRotla
      module Mergers
        def available_majors
          @corporations.select { |corp| corp.type == :major && !corp.ipoed }
        end

        def merger_connected?(first, second)
          # The destination's own hub does not block reaching that hub. Overnight
          # also ignores intervening cities filled by other corporations.
          [first, second].any? do |source|
            target = source == first ? second : first
            nodes = graph_for_entity(source).connected_nodes(source)
            target.tokens.any? { |token| token.used && nodes[token.city] }
          end
        end

        def merger_president(first, second)
          holdings = @players.to_h { |player| [player, player.percent_of(first) + player.percent_of(second)] }
          tied = @players.select { |player| holdings[player] == holdings.values.max }
          return tied.first if tied.one?

          # Stock-track order breaks a tie between the two presidents.
          [first, second].sort.map(&:owner).find { |player| tied.include?(player) }
        end

        def merge_minors!(first, second, major)
          valid = [first, second].all? { |corp| corp.type == :minor && corp.floated? && !corp.closed? }
          valid &&= first != second && available_majors.include?(major) && merger_connected?(first, second)
          raise GameError, 'Merge two connected operating minors into an available major' unless valid

          minors = [first, second]
          president = merger_president(first, second)
          units = Hash.new(0)
          minors.each do |minor|
            shares_for_corporation(minor).each do |share|
              holder = minors.include?(share.owner) ? major : share.owner
              units[holder] += share.percent / 20
            end
          end
          price = @stock_market.market.flatten.compact.select do |space|
            space.price <= (first.share_price.price + second.share_price.price) / 2
          end.max_by(&:price)
          @stock_market.set_par(major, price)
          major.owner = president
          major.ipoed = major.floated = true
          @merged_minors ||= {}
          @merged_minors[major.id] = minors.map(&:id)
          minors.each do |minor|
            abilities(minor, :description) do |ability|
              major.add_ability(Ability::Description.new(type: :description, description: ability.description,
                                                         desc_detail: ability.desc_detail))
            end
          end
          @share_pool.transfer_shares(major.presidents_share.to_bundle, president, allow_president_change: false)
          units[president] -= 2
          singles = major.shares_of(major).reject(&:president)
          units.each do |holder, count|
            count.times do
              share = singles.shift
              next if holder == major

              @share_pool.transfer_shares(share.to_bundle, holder, allow_president_change: false)
            end
          end
          replace_merger_hubs!(minors, major)
          minors.each do |minor|
            minor.spend(minor.cash, major) if minor.cash.positive?
            minor.trains.dup.each do |train|
              minor.trains.delete(train)
              major.trains << train
              train.owner = major
            end
            close_corporation(minor, quiet: true)
          end
          @crowded_corps = nil
          clear_graph
          @log << "#{first.name} and #{second.name} merge into #{major.name}; #{president.name} is president, "\
                  "stock price #{format_currency(price.price)}. Both company powers are retained."
          major
        end

        def replace_merger_hubs!(minors, major)
          expansive_unused = minors.any? do |minor|
            minor.id == 'EA' && minor.tokens.any? { |token| !token.used && token.price == 40 }
          end
          hubs = minors.flat_map(&:tokens).select(&:used)
          major.tokens.clear
          placed_hexes = []
          hubs.each do |old|
            token = Engine::Token.new(major)
            major.tokens << token
            if placed_hexes.include?(old.hex)
              old.remove!
            else
              placed_hexes << old.hex
              old.swap!(token, check_tokenable: false)
            end
          end
          2.times { major.tokens << Engine::Token.new(major, price: 60) }
          return unless expansive_unused

          major.tokens << Engine::Token.new(major, price: 40)
        end
      end
    end
  end
end
