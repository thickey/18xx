# frozen_string_literal: true

module Engine
  module Game
    module GRotla
      module Map
        LAYOUT = :flat
        TILES = {}.freeze

        # Versioned, illustrative layouts, NOT transcriptions of official RotLA maps.
        # Keep old versions stable: saved games reconstruct their map from actions.
        PRESETS = {
          'compact_v1' => {
            name: 'Compact basin (illustrative)',
            hexes: {
              white: {
                %w[B2 B4 C1 C5 D2 D4] => '',
                %w[C3] => 'city=revenue:0',
                %w[B6 D6] => 'town=revenue:0',
                %w[C7] => 'upgrade=cost:40,terrain:mountain',
              },
            },
          },
          'corridor_v1' => {
            name: 'Long valley (illustrative)',
            hexes: {
              white: {
                %w[B2 B4 C3 C5 D4 D6 E5 E7 F6 F8] => '',
                %w[C1 F10] => 'city=revenue:0',
                %w[D2 E9] => 'town=revenue:0',
                %w[D8] => 'upgrade=cost:40,terrain:mountain',
              },
            },
          },
          'fork_v1' => {
            name: 'Three branches (illustrative)',
            hexes: {
              white: {
                %w[B2 B4 C3 C5 D4 D6 E3 E5 F2 F4] => '',
                %w[C1 D8 F6] => 'city=revenue:0',
                %w[E7] => 'town=revenue:0',
                %w[D2] => 'upgrade=cost:20,terrain:water',
              },
            },
          },
        }.freeze
      end
    end
  end
end
