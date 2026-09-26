# frozen_string_literal: true

require_relative '../meta'

module Engine
  module Game
    module GRotla
      module Meta
        include Game::Meta

        DEV_STAGE = :prealpha
        GAME_TITLE = 'RotLA'
        GAME_DISPLAY_TITLE = 'Railways of the Lost Atlas (setup prototype)'
        GAME_ALIASES = ['Railways of the Lost Atlas'].freeze
        GAME_INFO_URL = 'https://www.asterisk-games.com/railwaysofthelostatlas'
        GAME_RULES_URL = 'https://www.asterisk-games.com/rulebook'
        PLAYER_RANGE = [2, 5].freeze
      end
    end
  end
end
