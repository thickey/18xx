# frozen_string_literal: true

require_relative '../meta'

module Engine
  module Game
    module GRotla
      module Meta
        include Game::Meta

        DEV_STAGE = :prealpha
        GAME_TITLE = 'RotLA'
        GAME_DISPLAY_TITLE = 'Railways of the Lost Atlas'
        GAME_ALIASES = ['Railways of the Lost Atlas'].freeze
        GAME_INFO_URL = 'https://www.asterisk-games.com/railwaysofthelostatlas'
        GAME_RULES_URL = 'https://www.asterisk-games.com/rulebook'
        PLAYER_RANGE = [2, 5].freeze
        OPTIONAL_RULES = [
          {
            sym: :distant_revenue_20_30_50_80,
            short_name: 'Distant destinations: 20, 30, 50, 80',
            desc: 'Use this revenue card instead of the default 30, 40, 70, 100 (yellow, green, brown, gray).',
          },
          {
            sym: :distant_revenue_30_60_90_30,
            short_name: 'Distant destinations: 30, 60, 90, 30',
            desc: 'Use this revenue card instead of the default 30, 40, 70, 100 (yellow, green, brown, gray).',
          },
          {
            sym: :short_game,
            short_name: 'Short Game',
            desc: '25 map pieces and two capitals (required for two players; unavailable for five).',
            players: [2, 3, 4],
          },
          {
            sym: :micro_game_2,
            short_name: '2-player Micro Game',
            desc: 'Choose one of three random balanced stacks: 11 map pieces, four minor homes, one destination and one capital.',
            players: [2],
          },
          {
            sym: :micro_game_3,
            short_name: '3-player Micro Game',
            desc: 'Randomly choose one of two balanced stacks: 16 map pieces, six minor homes, one destination and one capital.',
            players: [3],
          },
        ].freeze

        MUTEX_RULES = [
          %i[distant_revenue_20_30_50_80 distant_revenue_30_60_90_30],
          %i[short_game micro_game_2 micro_game_3],
        ].freeze

        # The creation form also passes a hidden lobby minimum in hotseat mode.
        # Validate the selected size here; init_optional_rules checks the actual players.
        def self.check_options(options, _min_players, max_players)
          rules = (options || []).map(&:to_sym)
          if (rules & %i[distant_revenue_20_30_50_80 distant_revenue_30_60_90_30]).size > 1
            return { error: 'Choose only one distant destination revenue card.' }
          end

          modes = rules & %i[short_game micro_game_2 micro_game_3]
          return { error: 'Choose only one of Short Game, 2-player Micro Game, or 3-player Micro Game.' } if modes.size > 1

          return { error: 'Short Game is not available for five players.' } if rules.include?(:short_game) && max_players == 5

          [2, 3].each do |players|
            if rules.include?("micro_game_#{players}".to_sym) && (max_players && max_players != players)
              return { error: "The #{players}-player Micro Game requires exactly #{players} players." }
            end
          end
          nil
        end
      end
    end
  end
end
