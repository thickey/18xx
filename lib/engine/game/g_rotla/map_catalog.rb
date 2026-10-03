# frozen_string_literal: true

# Generated from data/rotla/runtime-map-v1.json. Keep this replay version immutable.
module Engine
  module Game
    module GRotla
      module MapCatalog
        VERSION = 'real_v1'
        SPECIAL = {
          9 => { revenue: 30, slots: 1, exits: [3, 4, 5, 0] },
          11 => { revenue: 20, slots: 2, exits: [4, 5, 0, 1] },
          26 => { offboard_exits: { offboard: [4] } },
          27 => { offboard_exits: { offboard: [4], offboard_join: [5, 1] } },
          28 => { offboard_exits: { offboard: [4, 0], offboard_join: [1] } },
        }.freeze
        PIECES = [
          { id: '01', number: 1, terrain: %i[minor_expansive mountain blank], home: 'EA', name: 'Expansive', home_cell: 0 },
          { id: '02', number: 2, terrain: %i[mining blank mountain], home: 'EM', name: 'Eastern Mining', home_cell: 0 },
          { id: '03', number: 3, terrain: %i[city minor_agricultural blank], home: 'AG', name: 'Agricultural', home_cell: 1 },
          { id: '04', number: 4, terrain: %i[city minor_resourceful blank], home: 'RE', name: 'Resourceful', home_cell: 1 },
          { id: '05', number: 5, terrain: %i[blank minor_express water], home: 'ER', name: 'Express', home_cell: 1 },
          { id: '06', number: 6, terrain: %i[mountain city minor_suburban], home: 'SU', name: 'Suburban', home_cell: 2 },
          { id: '07', number: 7, terrain: %i[border port city], home: 'NP', name: 'Northern Port', home_cell: 1 },
          { id: '08', number: 8, terrain: %i[mountain minor_tunneling city], home: 'TU', name: 'Tunneling', home_cell: 1 },
          { id: '09', number: 9, terrain: %i[water blank bridging], home: 'BR', name: 'Bridging', home_cell: 2 },
          { id: '10', number: 10, terrain: %i[city minor_overnight water], home: 'OV', name: 'Overnight', home_cell: 1 },
          { id: '11', number: 11, terrain: %i[water blank spacious], home: 'SP', name: 'Spacious', home_cell: 2 },
          { id: '120', number: 12, terrain: %i[blank blank blank] },
          { id: '121', number: 12, terrain: %i[blank blank blank] },
          { id: '130', number: 13, terrain: %i[blank water water] },
          { id: '131', number: 13, terrain: %i[blank water water] },
          { id: '140', number: 14, terrain: %i[mountain blank water] },
          { id: '141', number: 14, terrain: %i[mountain blank water] },
          { id: '150', number: 15, terrain: %i[city blank mountain] },
          { id: '151', number: 15, terrain: %i[city blank mountain] },
          { id: '160', number: 16, terrain: %i[city blank blank] },
          { id: '161', number: 16, terrain: %i[city blank blank] },
          { id: '170', number: 17, terrain: %i[city mountain blank] },
          { id: '180', number: 18, terrain: %i[blank city water] },
          { id: '190', number: 19, terrain: %i[city city blank] },
          { id: '200', number: 20, terrain: %i[city mountain city] },
          { id: '210', number: 21, terrain: %i[city city city] },
          { id: '220', number: 22, terrain: %i[mountain mountain mountain] },
          { id: '230', number: 23, terrain: %i[border blank blank] },
          { id: '240', number: 24, terrain: %i[border water blank] },
          { id: '250', number: 25, terrain: %i[border blank city] },
          { id: '260', number: 26, terrain: %i[border blank offboard] },
          { id: '270', number: 27, terrain: %i[border offboard offboard_join] },
          { id: '280', number: 28, terrain: %i[border offboard offboard_join] },
        ].freeze
        SHORT_REMOVED = %w[09 10 11 210 260 121 131 141].freeze
      end
    end
  end
end
