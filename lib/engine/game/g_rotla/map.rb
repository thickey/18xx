# frozen_string_literal: true

module Engine
  module Game
    module GRotla
      module Map
        LAYOUT = :flat
        # Empty water has no paths; connecting its edges lets Bridging reach it.
        IMPASSABLE_HEX_COLORS = %i[gray red].freeze
        # FWTWR reference IDs; purple physical tiles use the engine brown phase.
        # FWTWR reference IDs; purple physical tiles use the engine brown phase.
        TILES = {
          '5' => 5,
          '6' => 7,
          '7' => 6,
          '8' => 14,
          '9' => 13,
          '57' => 7,
          '291' => {
            'count' => 1,
            'color' => 'yellow',
            'code' => 'city=revenue:40;path=a:0,b:_0;path=a:2,b:_0;label=C',
          },
          '292' => {
            'count' => 1,
            'color' => 'yellow',
            'code' => 'city=revenue:40;path=a:0,b:_0;path=a:1,b:_0;label=C',
          },
          '293' => {
            'count' => 1,
            'color' => 'yellow',
            'code' => 'city=revenue:40;path=a:0,b:_0;path=a:3,b:_0;label=C',
          },
          '14' => 4,
          '15' => 5,
          '16' => 1,
          '17' => 1,
          '19' => 1,
          '20' => 1,
          '21' => 1,
          '22' => 1,
          '23' => 4,
          '24' => 4,
          '25' => 2,
          '26' => 1,
          '27' => 1,
          '28' => 1,
          '29' => 1,
          '30' => 1,
          '31' => 1,
          '294' => {
            'count' => 2,
            'color' => 'green',
            'code' => 'city=revenue:50,slots:2;path=a:0,b:_0;path=a:1,b:_0;path=a:3,b:_0;path=a:4,b:_0;label=C',
          },
          '295' => {
            'count' => 2,
            'color' => 'green',
            'code' => 'city=revenue:50,slots:2;path=a:0,b:_0;path=a:1,b:_0;path=a:2,b:_0;path=a:3,b:_0;label=C',
          },
          '296' => {
            'count' => 1,
            'color' => 'green',
            'code' => 'city=revenue:50,slots:2;path=a:0,b:_0;path=a:2,b:_0;path=a:3,b:_0;path=a:4,b:_0;label=C',
          },
          '619' => 4,
          '624' => 1,
          'LA1' => {
            'count' => 1,
            'color' => 'green',
            'code' => 'city=revenue:50,loc:3;city=revenue:30,loc:0;path=a:_0,b:_1;path=a:0,b:_1;path=a:1,b:_1;label=M',
          },
          'LA2' => {
            'count' => 1,
            'color' => 'green',
            'code' => 'city=revenue:60,slots:1,loc:1;city=revenue:60,slots:1,loc:5;path=a:0,b:_0;' \
                      'path=a:1,b:_0;path=a:4,b:_1;path=a:5,b:_1;label=P',
          },
          '39' => 1,
          '40' => 1,
          '41' => 2,
          '42' => 2,
          '43' => 2,
          '44' => 1,
          '45' => 2,
          '46' => 2,
          '47' => 2,
          '70' => 1,
          '125' => 6,
          '297' => {
            'count' => 2,
            'color' => 'brown',
            'code' => 'city=revenue:60,slots:3;path=a:0,b:_0;path=a:1,b:_0;path=a:2,b:_0;path=a:3,b:_0;path=a:4,b:_0;label=C',
          },
          'LA3' => {
            'count' => 1,
            'color' => 'brown',
            'code' => 'path=a:3,b:1;path=a:3,b:0;path=a:3,b:5',
          },
          'LA4' => {
            'count' => 1,
            'color' => 'brown',
            'code' => 'city=revenue:60,loc:3;city=revenue:40,slots:2,loc:0;path=a:_0,b:_1;' \
                      'path=a:0,b:_1;path=a:1,b:_1;path=a:2,b:_1;label=M',
          },
          'LA5' => {
            'count' => 1,
            'color' => 'brown',
            'code' => 'city=revenue:80,slots:2,loc:1;city=revenue:80,slots:2,loc:4;path=a:0,b:_0;' \
                      'path=a:1,b:_0;path=a:4,b:_1;path=a:5,b:_1;label=P',
          },
          '51' => 3,
          'LA6' => {
            'count' => 1,
            'color' => 'gray',
            'code' => 'city=revenue:70,slots:3;path=a:0,b:_0;path=a:1,b:_0;path=a:2,b:_0;' \
                      'path=a:3,b:_0;path=a:4,b:_0;label=C',
          },
          'LA7' => {
            'count' => 1,
            'color' => 'gray',
            'code' => 'city=revenue:70,loc:3;city=revenue:50,slots:2,loc:0;path=a:_0,b:_1;path=a:0,b:_1;' \
                      'path=a:1,b:_1;path=a:2,b:_1;path=a:5,b:_1;label=M',
          },
          '721' => {
            'count' => 2,
            'color' => 'blue',
            'code' => 'path=a:0,b:3',
          },
          '722' => {
            'count' => 2,
            'color' => 'blue',
            'code' => 'path=a:0,b:2',
          },
          '723' => {
            'count' => 1,
            'color' => 'blue',
            'code' => 'path=a:0,b:1',
          },
        }.freeze

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
