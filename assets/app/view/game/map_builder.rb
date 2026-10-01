# frozen_string_literal: true

require 'view/game/actionable'
require 'view/game/tile'

module View
  module Game
    class MapBuilder < Snabberb::Component
      include Actionable

      needs :rotla_rotation, default: 0, store: true
      needs :rotla_anchor, default: nil, store: true
      needs :rotla_context, default: nil, store: true

      COLORS = {
        blank: '#e9e1ca',
        city: '#e9e1ca',
        mountain: '#cdb993',
        water: '#9fd6e8',
        bridging: '#9fd6e8',
        spacious: '#aaa9a5',
        mining: '#f4d35e',
        port: '#f4d35e',
        border: '#33404d',
        offboard: '#d94b48',
        offboard_join: '#d94b48',
      }.freeze
      LABELS = {
        border: 'Border',
        blank: '',
        city: 'City',
        mountain: 'Mountain',
        water: 'Water',
        bridging: '30',
        spacious: '20',
      }.freeze

      def render
        context = [@game.id, @game.current_action_id]
        if @rotla_context != context
          @rotla_rotation = 0
          @rotla_anchor = nil
          store(:rotla_context, context, skip: true)
          store(:rotla_rotation, 0, skip: true)
          store(:rotla_anchor, nil, skip: true)
        end
        return render_blank_hex_setup if @game.blank_hex_phase?

        if @game.drawn_project
          return h(:div, [
            h(:h3, "#{@game.current_entity.name}: Capital project"),
            h(:p, 'Upgrade a placed basic city to a capital. Reserved minor homes cannot be chosen.'),
            *@game.capital_choices.map do |q, r|
              coordinate = @game.map_coordinate(q, r)
              h(:button, {
                  on: {
                    click: lambda {
                      process_action(Engine::Action::Choose.new(@game.current_entity,
                                                                choice: "capital_v4:#{q}:#{r}"))
                    },
                  },
                },
                "Capital at #{coordinate}")
            end,
          ])
        end
        if @game.current_piece.nil?
          fresh = !@game.real_setup && @game.placements.empty?
          count = fresh ? @game.setup_piece_count : @game.piece_count
          action = if fresh
                     'start_v5'
                   else
                     (@game.real_setup ? 'draw_v4' : 'draw_v2')
                   end
          return h(:div, [
            h(:h3, "#{@game.current_entity.name}'s turn — #{@game.placements.size}/#{count} pieces placed"),
            h(:p, if fresh
                    "#{@game.setup_mode_name}: #{count} pieces and #{@game.capital_count} capital projects. "\
                      'A random player starts; all destinations use the recommended 30/40/70/100 revenue card.'
                  else
                    'Draw the next piece or capital project, then resolve it.'
                  end),
            h(:button, { on: { click: -> { process_action(Engine::Action::Choose.new(@game.current_entity, choice: action)) } } },
              fresh ? 'Start real map setup' : 'Draw a piece'),
          ])
        end
        @anchors = @game.legal_anchors(@rotla_rotation)
        @rotla_anchor = nil unless @anchors.include?(@rotla_anchor)
        @occupied = @game.placed_cells
        @preview = @rotla_anchor ? @game.piece_cells(*@rotla_anchor, @rotla_rotation) : []

        h(:div, { style: { width: '100%', maxWidth: '960px' } }, [
          h(:h3, if @game.review_tile
                   @game.piece_name
                 else
                   "#{@game.current_entity.name} places — #{@game.placements.size}/#{@game.piece_count} pieces placed"
                 end),
          h(:p, if @game.review_tile
                  "Rotate tile #{@game.review_tile}, select the blue anchor, then place it to inspect it in the Map tab."
                else
                  'Each player draws and places one random triangular piece, then passes to the next player. '\
                    'Select a blue anchor, rotate, then place. '\
                    'Each new piece must share at least three edges with the map and avoid border hexes.'
                end),
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
          if @game.real_setup
            h(:div, [
              h(:p, 'If all players agree a piece cannot be placed, restart map construction with a new shuffle.'),
              h(:button, {
                  on: {
                    click: lambda {
                      process_action(Engine::Action::Choose.new(@game.current_entity,
                                                                choice: 'restart_v4'))
                    },
                  },
                },
                'Restart map construction'),
            ])
          end,
          h(:p, if @game.review_tile
                  case @game.review_tile
                  when 2
                    'EM = Mining home: revenue 30, joined to a separate revenue-20 city. M identifies the mining tile.'
                  when 26, 27, 28
                    'Red = offboard. Revenue is shown on the in-game map, once per destination.'
                  when 7
                    'NP = Port home. Two separate revenue-30 cities; P marks Port. Border hexes are unreachable.'
                  when 11
                    'SP = Spacious home: one connected city with two token slots, revenue 20. Gray means no upgrades.'
                  else
                    'BR = Bridging home: one city slot, revenue 30. All four track branches meet that city.'
                  end
                else
                  'Mountain terrain costs 40. Blue water is unreachable except through bridge track. '\
                    'C marks a capital. Destinations share the recommended 30/40/70/100 card. '\
                    'The map is ready when every piece and capital project is resolved.'
                end),
        ])
      end

      def rotate(delta)
        store(:rotla_rotation, (@rotla_rotation + delta) % 6)
      end

      def render_blank_hex_setup
        @anchors = @game.blank_hex_anchors
        @rotla_anchor = nil unless @anchors.include?(@rotla_anchor)
        @occupied = @game.placed_cells
        @preview = @rotla_anchor ? [[*@rotla_anchor, :blank]] : []
        h(:div, [
          h(:h3, "Optional blank hexes — #{@game.blank_hexes.size}/12 placed"),
          h(:p, 'Add empty land next to minor homes that need room to grow. Select a blue anchor to preview. '\
                'Blanks cannot overlap or touch a border hex. You may finish without using all 12.'),
          h(:button, {
              attrs: { disabled: !@rotla_anchor },
              on: {
                click: lambda {
                         q, r = @rotla_anchor
                         process_action(Engine::Action::Choose.new(@game.current_entity, choice: "blank_v5:#{q}:#{r}"))
                       },
              },
            }, 'Place blank hex'),
          h(:button, {
              on: {
                click: lambda {
                  process_action(Engine::Action::Choose.new(@game.current_entity,
                                                            choice: 'finish_blanks_v5'))
                },
              },
            },
            'Finish setup'),
          render_board,
        ])
      end

      def place
        return unless @rotla_anchor

        q, r = @rotla_anchor
        version = @game.legacy_setup ? 'place_v1' : 'place_v3'
        version = "place_tile#{@game.review_tile}_v1" if @game.review_tile
        piece = @game.current_piece
        if @game.real_setup
          version = 'place_v4'
          piece = @game.real_catalog[piece][:id]
        end
        choice = "#{version}:#{piece}:#{q}:#{r}:#{@rotla_rotation}"
        process_action(Engine::Action::Choose.new(@game.current_entity, choice: choice))
      end

      def center(q, r)
        [54 * q, 62.354 * (r + (q / 2.0))]
      end

      def render_piece
        cells = @game.piece_cells(0, 0, @rotla_rotation)
        xs, ys = cells.map { |q, r, _| center(q, r) }.transpose
        h(:div, [
          h(:strong, "#{@game.piece_name}: #{cells.map { |_, _, t| t.to_s }.join(', ')}"),
          h(:svg, {
              attrs: {
                viewBox: "#{xs.min - 42} #{ys.min - 42} #{xs.max - xs.min + 84} #{ys.max - ys.min + 84}",
                width: @game.review_tile || @game.real_setup ? 260 : 190,
                height: @game.review_tile || @game.real_setup ? 210 : 150,
                role: 'img',
                'aria-label': 'Current triangular piece',
              },
              style: { display: 'block' },
            }, cells.map { |q, r, terrain| render_hex(q, r, terrain, preview: true, rotation: @rotla_rotation) }),
        ])
      end

      def render_board
        coords = (@anchors + @occupied.map { |q, r, _| [q, r] } + @preview.map { |q, r, _| [q, r] }).uniq
        xs, ys = coords.map { |q, r| center(q, r) }.transpose
        cells = @anchors.map { |q, r| render_anchor(q, r) }
        cells.concat(@occupied.map { |q, r, terrain| render_hex(q, r, terrain) })
        cells.concat(@preview.map { |q, r, terrain| render_hex(q, r, terrain, preview: true, rotation: @rotla_rotation) })
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

      def render_real_hex(q, r, terrain, preview:, rotation:)
        placement = preview ? nil : @game.placement_at(q, r)
        index = placement ? placement[:piece] : (@game.current_piece || 0)
        rotation = placement[:rotation] if placement
        hex = @game.real_preview_hex(q, r, terrain, rotation, index)
        x, y = center(q, r)
        vertices = [[36, 0], [18, 31.177], [-18, 31.177], [-36, 0], [-18, -31.177], [18, -31.177]]
        points = vertices.map { |dx, dy| "#{x + dx},#{y + dy}" }.join(' ')
        color = COLORS[terrain] || COLORS[:city]
        children = [h(:polygon, attrs: { points: points, fill: color, stroke: 'none' })]
        if terrain == :port
          [2, 3].each do |edge|
            a = vertices[(edge + rotation + 1) % 6]
            b = vertices[(edge + rotation + 2) % 6]
            children << h(:polygon, attrs: {
                            points: "#{x},#{y} #{x + a[0]},#{y + a[1]} #{x + b[0]},#{y + b[1]}",
                            fill: COLORS[:water],
                          })
          end
        end
        invisible = hex.tile.borders.select { |border| border.type.nil? }.map(&:edge)
        (0..5).each do |edge|
          next if invisible.include?(edge)

          a = vertices[(edge + 1) % 6]
          b = vertices[(edge + 2) % 6]
          children << h(:polyline, attrs: {
                          points: "#{x + a[0]},#{y + a[1]} #{x + b[0]},#{y + b[1]}",
                          fill: 'none',
                          stroke: preview ? '#49ecb3' : '#665c49',
                          'stroke-width': preview ? 3 : 1,
                        })
        end
        unless terrain == :border
          children << h(:g, { attrs: { transform: "translate(#{x} #{y}) scale(0.36)" } }, [
            h(Tile, tile: hex.tile, game: @game, hide_revenue: hex.tile.color == :red),
          ])
        end
        h(:g, { style: { pointerEvents: 'none' } }, children)
      end

      def render_hex(q, r, terrain, preview: false, rotation: 0)
        return render_real_hex(q, r, terrain, preview: preview, rotation: rotation) if @game.real_setup

        x, y = center(q, r)
        points = [[36, 0], [18, 31.177], [-18, 31.177], [-36, 0], [-18, -31.177], [18, -31.177]]
                 .map { |dx, dy| "#{x + dx},#{y + dy}" }.join(' ')
        shared_edge = @game.offboard_shared_edge(terrain, rotation)
        outline_color = preview ? '#49ecb3' : '#665c49'
        children = [h(:polygon, {
                        attrs: {
                          points: points,
                          fill: COLORS[terrain],
                          stroke: shared_edge ? 'none' : outline_color,
                          'stroke-width': preview ? 3 : 1,
                          opacity: preview ? 0.75 : 1,
                        },
                      })]
        if shared_edge
          vertices = points.split
          (0..5).each do |edge|
            next if edge == shared_edge

            children << h(:polyline, attrs: {
                            points: "#{vertices[(edge + 1) % 6]} #{vertices[(edge + 2) % 6]}",
                            fill: 'none',
                            stroke: outline_color,
                            'stroke-width': preview ? 3 : 1,
                            opacity: preview ? 0.75 : 1,
                          })
          end
        end
        case terrain
        when :bridging, :spacious
          # Edge midpoints in the engine's flat-hex numbering (0 = south).
          edges = [[0, 31.177], [-27, 15.5885], [-27, -15.5885], [0, -31.177], [27, -15.5885], [27, 15.5885]]
          @game.review_exits(rotation).each do |edge|
            dx, dy = edges[edge]
            children << h(:line, { attrs: { x1: x, y1: y, x2: x + dx, y2: y + dy, stroke: '#222', 'stroke-width': 4 } })
          end
          if terrain == :spacious
            # A shared city body makes the two token slots visibly one connected city.
            children << h(:rect, {
                            attrs: {
                              x: x - 18,
                              y: y - 10,
                              width: 36,
                              height: 20,
                              rx: 10,
                              fill: '#222',
                              transform: "rotate(#{rotation * 60} #{x} #{y})",
                            },
                          })
            angle = rotation * Math::PI / 3
            [-8, 8].each_with_index do |offset, slot|
              sx = x + (offset * Math.cos(angle))
              sy = y + (offset * Math.sin(angle))
              children << h(:circle, { attrs: { cx: sx, cy: sy, r: 8, fill: '#f6edd5', stroke: '#222' } })
              next unless slot == 1

              children << h(:text, { attrs: { x: sx, y: sy + 3, 'text-anchor': 'middle', fill: '#222', 'font-size': 7 } }, 'SP')
            end
          else
            children << h(:circle, { attrs: { cx: x, cy: y, r: 10, fill: '#f6edd5', stroke: '#222', 'stroke-width': 2 } })
            children << h(:text, { attrs: { x: x, y: y + 3, 'text-anchor': 'middle', fill: '#222', 'font-size': 8 } }, 'BR')
          end
        when :offboard, :offboard_join
          @game.offboard_exits(terrain, rotation).each do |edge|
            angle = (90 + (edge * 60)) * Math::PI / 180
            ux = Math.cos(angle)
            uy = Math.sin(angle)
            children << h(:line, {
                            attrs: {
                              x1: x + (31.177 * ux),
                              y1: y + (31.177 * uy),
                              x2: x + (17 * ux),
                              y2: y + (17 * uy),
                              stroke: '#222',
                              'stroke-width': 4,
                            },
                          })
            points = [[12 * ux, 12 * uy], [(20 * ux) - (4 * uy), (20 * uy) + (4 * ux)],
                      [(20 * ux) + (4 * uy), (20 * uy) - (4 * ux)]]
            children << h(:polygon, { attrs: { points: points.map { |dx, dy| "#{x + dx},#{y + dy}" }.join(' '), fill: '#222' } })
          end
        when :port
          vertices = [[36, 0], [18, 31.177], [-18, 31.177], [-36, 0], [-18, -31.177], [18, -31.177]]
          [2, 3].each do |edge|
            a = vertices[(edge + rotation + 1) % 6]
            b = vertices[(edge + rotation + 2) % 6]
            children << h(:polygon,
                          { attrs: { points: "#{x},#{y} #{x + a[0]},#{y + a[1]} #{x + b[0]},#{y + b[1]}", fill: '#9fd6e8' } })
          end
          nodes = [0, 4.5].map do |edge|
            angle = (90 + (60 * (edge + rotation))) * Math::PI / 180
            [x + (15 * Math.cos(angle)), y + (15 * Math.sin(angle))]
          end
          [[0, 0], [4, 1], [5, 1]].each do |edge, node|
            angle = (90 + (60 * (edge + rotation))) * Math::PI / 180
            cx, cy = nodes[node]
            children << h(:line,
                          {
                            attrs: {
                              x1: cx,
                              y1: cy,
                              x2: x + (31.177 * Math.cos(angle)),
                              y2: y + (31.177 * Math.sin(angle)),
                              stroke: '#222',
                              'stroke-width': 4,
                            },
                          })
          end
          label_angle = rotation * Math::PI / 3
          nodes.each_with_index do |(cx, cy), i|
            children << h(:circle, { attrs: { cx: cx, cy: cy, r: 8, fill: '#f6edd5', stroke: '#222', 'stroke-width': 2 } })
            children << h(:text, { attrs: { x: cx, y: cy + 2, 'text-anchor': 'middle', 'font-size': 6 } }, 'NP') if i.zero?
            children << h(:text, {
                            attrs: {
                              x: cx - (12 * Math.cos(label_angle)),
                              y: cy - (12 * Math.sin(label_angle)) + 3,
                              'text-anchor': 'middle',
                              'font-size': 8,
                            },
                          }, '30')
          end
          label_angle -= Math::PI / 6
          children << h(:text, {
                          attrs: {
                            x: x + (22 * Math.sin(label_angle)),
                            y: y - (22 * Math.cos(label_angle)) + 3,
                            'text-anchor': 'middle',
                            'font-size': 11,
                            'font-weight': 'bold',
                          },
                        }, 'P')
        when :mining
          angle = (rotation + 1) * Math::PI / 3
          dx = 13 * Math.cos(angle)
          dy = 13 * Math.sin(angle)
          edge_angle = ((rotation * 60) + 30) * Math::PI / 180
          children << h(:line, {
                          attrs: {
                            x1: x - dx,
                            y1: y - dy,
                            x2: x + dx,
                            y2: y + dy,
                            stroke: '#222',
                            'stroke-width': 4,
                          },
                        })
          children << h(:line, {
                          attrs: {
                            x1: x + dx,
                            y1: y + dy,
                            x2: x + (31.177 * Math.cos(edge_angle)),
                            y2: y + (31.177 * Math.sin(edge_angle)),
                            stroke: '#222',
                            'stroke-width': 4,
                          },
                        })
          [1, -1].each do |side|
            cx = x + (side * dx)
            cy = y + (side * dy)
            children << h(:circle, { attrs: { cx: cx, cy: cy, r: 8, fill: '#f6edd5', stroke: '#222', 'stroke-width': 2 } })
            children << h(:text, { attrs: { x: cx, y: cy + 2, 'text-anchor': 'middle', 'font-size': 6 } }, 'EM') if side == 1
            children << h(:text, {
                            attrs: {
                              x: cx - (12 * Math.sin(angle)),
                              y: cy + (12 * Math.cos(angle)) + 3,
                              'text-anchor': 'middle',
                              'font-size': 8,
                            },
                          }, side == 1 ? '30' : '20')
          end
          children << h(:text, {
                          attrs: {
                            x: x + (22 * Math.sin(angle)),
                            y: y - (22 * Math.cos(angle)) + 3,
                            'text-anchor': 'middle',
                            'font-size': 11,
                            'font-weight': 'bold',
                          },
                        }, 'M')
        when :city
          children << h(:circle, { attrs: { cx: x, cy: y - 6, r: 9, fill: 'white', stroke: '#333' } })
        when :mountain
          children << h(:polygon, { attrs: { points: "#{x},#{y - 17} #{x - 10},#{y} #{x + 10},#{y}", fill: '#80512f' } })
        end
        label_x = x
        label_y = y + 16
        if %i[bridging spacious].include?(terrain)
          # Keep the revenue in the track-free wedge throughout rotation.
          label_rotation = (rotation + (terrain == :spacious ? 1 : 0)) % 6
          dx, dy = [[-22, 0], [-11, -19.052], [11, -19.052], [22, 0], [11, 19.052], [-11, 19.052]][label_rotation]
          label_x += dx
          label_y = y + dy + 3
        end
        label_color = terrain == :border ? '#eee' : '#182732'
        children << h(:text, { attrs: { x: label_x, y: label_y, 'text-anchor': 'middle', fill: label_color, 'font-size': 10 } },
                      LABELS[terrain])
        h(:g, { style: { pointerEvents: 'none' } }, children)
      end
    end
  end
end
