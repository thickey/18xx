# frozen_string_literal: true

require 'view/game/actionable'

module View
  module Game
    class MapBuilder < Snabberb::Component
      include Actionable

      needs :rotla_rotation, default: 0, store: true
      needs :rotla_anchor, default: nil, store: true
      needs :rotla_context, default: nil, store: true

      COLORS = { blank: '#e9e1ca', city: '#e9e1ca', mountain: '#cdb993', water: '#9fd6e8' }.freeze
      LABELS = { blank: '', city: 'City', mountain: 'Mountain', water: 'Water' }.freeze

      def render
        context = [@game.id, @game.current_action_id]
        if @rotla_context != context
          @rotla_rotation = 0
          @rotla_anchor = nil
          store(:rotla_context, context, skip: true)
          store(:rotla_rotation, 0, skip: true)
          store(:rotla_anchor, nil, skip: true)
        end
        if @game.current_piece.nil?
          return h(:div, [
            h(:h3, "#{@game.current_entity.name}'s turn — #{@game.placements.size}/4 pieces placed"),
            h(:p,
              "Draw a random piece (#{4 - @game.placements.size} remaining), then rotate and place it."),
            h(:button, {
                on: {
                  click: lambda {
                    process_action(Engine::Action::Choose.new(@game.current_entity, choice: 'draw_v2'))
                  },
                },
              },
              'Draw a piece'),
          ])
        end
        @anchors = @game.legal_anchors(@rotla_rotation)
        @rotla_anchor = nil unless @anchors.include?(@rotla_anchor)
        @occupied = @game.placed_cells
        @preview = @rotla_anchor ? @game.piece_cells(*@rotla_anchor, @rotla_rotation) : []

        h(:div, { style: { width: '100%', maxWidth: '960px' } }, [
          h(:h3, "#{@game.current_entity.name} places — #{@game.placements.size}/4 pieces placed"),
          h(:p, 'Each player draws and places one random triangular piece, then passes to the next player. '\
                'Select a blue anchor, rotate, then place. Each new piece must share an edge with the map.'),
          render_piece,
          h(:div, [
            h(:button, { on: { click: -> { rotate(-1) } } }, 'Rotate left ↶'),
            h(:button, { on: { click: -> { rotate(1) } } }, 'Rotate right ↷'),
            h(:span, " #{@rotla_rotation * 60}° "),
            h(:button, {
                attrs: { disabled: !@rotla_anchor },
                on: { click: -> { place } },
              }, "Place piece #{@game.placements.size + 1}"),
          ]),
          h(:p, if @rotla_anchor
                  "Preview anchored at #{@game.map_coordinate(*@rotla_anchor)}. Green outlines show the new piece."
                else
                  'Choose a blue anchor on the board to preview a placement.'
                end),
          render_board,
          h(:p, 'City = circle · Mountain = triangle · Water = blue. Terrain costs are placeholders. '\
                'After the fourth placement, your 12-hex map is ready in the regular Map tab. Undo can revise any placement.'),
        ])
      end

      def rotate(delta)
        store(:rotla_rotation, (@rotla_rotation + delta) % 6)
      end

      def place
        return unless @rotla_anchor

        q, r = @rotla_anchor
        version = @game.legacy_setup ? 'place_v1' : 'place_v2'
        choice = "#{version}:#{@game.current_piece}:#{q}:#{r}:#{@rotla_rotation}"
        process_action(Engine::Action::Choose.new(@game.current_entity, choice: choice))
      end

      def center(q, r)
        [54 * q, 62.354 * (r + (q / 2.0))]
      end

      def render_piece
        cells = @game.piece_cells(0, 0, @rotla_rotation)
        xs, ys = cells.map { |q, r, _| center(q, r) }.transpose
        h(:div, [
          h(:strong, "Drawn piece ##{@game.current_piece + 1}: #{cells.map { |_, _, t| t.to_s }.join(', ')}"),
          h(:svg, {
              attrs: {
                viewBox: "#{xs.min - 42} #{ys.min - 42} #{xs.max - xs.min + 84} #{ys.max - ys.min + 84}",
                width: 190,
                height: 150,
                role: 'img',
                'aria-label': 'Current triangular piece',
              },
            }, cells.map { |q, r, terrain| render_hex(q, r, terrain) }),
        ])
      end

      def render_board
        coords = (@anchors + @occupied.map { |q, r, _| [q, r] } + @preview.map { |q, r, _| [q, r] }).uniq
        xs, ys = coords.map { |q, r| center(q, r) }.transpose
        cells = @anchors.map { |q, r| render_anchor(q, r) }
        cells.concat(@occupied.map { |q, r, terrain| render_hex(q, r, terrain) })
        cells.concat(@preview.map { |q, r, terrain| render_hex(q, r, terrain, preview: true) })
        h(:svg, {
            attrs: {
              viewBox: "#{xs.min - 45} #{ys.min - 45} #{xs.max - xs.min + 90} #{ys.max - ys.min + 90}",
              role: 'img',
              'aria-label': 'Map assembly board',
            },
            style: {
              display: 'block', width: '100%', height: '480px', background: '#17232e', borderRadius: '8px'
            },
          }, cells)
      end

      def render_anchor(q, r)
        x, y = center(q, r)
        select = -> { store(:rotla_anchor, [q, r]) }
        h(:g, {
            attrs: { role: 'button', tabindex: 0, 'aria-label': "Preview at #{@game.map_coordinate(q, r)}" },
            style: { cursor: 'pointer' },
            on: {
              click: select,
              keydown: ->(event) { select.call if %w[Enter Space].include?(event.code) },
            },
          }, [
          h(:circle, { attrs: { cx: x, cy: y, r: 14, fill: '#316e99', stroke: '#8bccfa', 'stroke-width': 2 } }),
          h(:text, {
              attrs: { x: x, y: y + 4, 'text-anchor': 'middle', fill: 'white', 'font-size': 13 },
              style: { pointerEvents: 'none' },
            }, '+'),
        ])
      end

      def render_hex(q, r, terrain, preview: false)
        x, y = center(q, r)
        points = [[36, 0], [18, 31.177], [-18, 31.177], [-36, 0], [-18, -31.177], [18, -31.177]]
                 .map { |dx, dy| "#{x + dx},#{y + dy}" }.join(' ')
        children = [h(:polygon, {
                        attrs: {
                          points: points,
                          fill: COLORS[terrain],
                          stroke: preview ? '#49ecb3' : '#665c49',
                          'stroke-width': preview ? 3 : 1,
                          opacity: preview ? 0.75 : 1,
                        },
                      })]
        case terrain
        when :city
          children << h(:circle, { attrs: { cx: x, cy: y - 6, r: 9, fill: 'white', stroke: '#333' } })
        when :mountain
          children << h(:polygon, { attrs: { points: "#{x},#{y - 17} #{x - 10},#{y} #{x + 10},#{y}", fill: '#80512f' } })
        end
        children << h(:text, { attrs: { x: x, y: y + 16, 'text-anchor': 'middle', fill: '#182732', 'font-size': 10 } },
                      LABELS[terrain])
        h(:g, { style: { pointerEvents: 'none' } }, children)
      end
    end
  end
end
