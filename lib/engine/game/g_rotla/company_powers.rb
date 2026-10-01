# frozen_string_literal: true

module Engine
  module Game
    module GRotla
      module CompanyPowers
        BRIDGE_TILES = %w[721 722 723].freeze

        def init_graph
          @overnight_graph = Graph.new(self, no_blocking: true)
          super
        end

        def graph_for_entity(entity)
          entity&.id == 'OV' ? @overnight_graph : super
        end

        def clear_graph
          super
          @overnight_graph&.clear
        end

        def clear_graph_for_entity(_entity)
          clear_graph
        end

        def check_connected(route, corporation)
          super(route, corporation.id == 'OV' ? nil : corporation)
        end

        def visited_stops(route)
          stops = super
          return stops unless route.corporation.id == 'OV'

          stops.reject { |stop| stop.city? && stop.blocks?(route.corporation) }
        end

        def check_other(route)
          super
          return unless route.corporation.id == 'OV'

          endpoints = [route.connection_data.first&.dig(:left), route.connection_data.last&.dig(:right)].compact
          return unless endpoints.any? { |stop| stop.city? && stop.blocks?(route.corporation) }

          raise GameError, 'Overnight may pass through a blocked city, but cannot end a route there'
        end

        def rust(train)
          if train.owner&.corporation? && train.owner.id == 'RE' && !train.rusted
            train.rusted = true
            @crowded_corps = nil
            @log << "Resourceful retains its #{train.name} train for one final run"
          else
            super
          end
        end

        def num_corp_trains(entity)
          entity.trains.count { |train| !train.rusted }
        end

        def discountable_trains_for(corporation)
          super.reject { |train, _, _, _| train.rusted }
        end

        def buy_train(operator, train, price = nil)
          raise GameError, 'A rusted train cannot be sold' if train.rusted

          super
        end

        def tile_valid_for_phase?(tile, **kwargs)
          BRIDGE_TILES.include?(tile.name) || super
        end

        def suburbs
          @suburbs ||= []
        end

        def suburb_choices(entity)
          return {} if entity&.id != 'SU' || suburbs.size >= 2

          connected = graph_for_entity(entity).connected_nodes(entity)
          @hexes.each_with_object({}) do |hex, choices|
            next if !hex.tile.cities.one? || !hex.tile.label.to_s.empty?
            next if suburbs.include?(hex.id) || hex.tile.cities.first.tokened_by?(entity)
            next unless connected[hex.tile.cities.first]

            choices["suburb:#{hex.id}"] = "Place suburb at #{hex.id} (+10 per train)"
          end
        end

        def place_suburb!(entity, choice)
          unless suburb_choices(entity).key?(choice)
            raise GameError,
                  'Choose a reachable basic city without a Suburban hub or suburb'
          end

          hex = hex_by_id(choice.delete_prefix('suburb:'))
          suburbs << hex.id
          hex.tile.icons << Part::Icon.new('rotla/suburb', 'suburb', true, nil, false)
          @round.routes.each { |route| route.clear_cache!(only_routes: true) } if @round.respond_to?(:routes)
          @log << "Suburban places a suburb at #{hex.id} (#{2 - suburbs.size} remaining)"
        end

        def revenue_for(route, stops)
          revenue = super
          return revenue unless route.corporation.id == 'SU'

          revenue + (stops.count { |stop| suburbs.include?(stop.hex.id) } * 10)
        end
      end
    end
  end
end
