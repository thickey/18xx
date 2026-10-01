# frozen_string_literal: true

# Export a legally assembled map ready for the initial Stock Round.
require_relative '../../lib/engine'
require 'json'
Engine::Logger.set_level(::Logger::WARN)

game = Engine::Game::GRotla::Game.new(%w[Alice Bob Carol], id: '3722698')
choose = lambda do |choice|
  game.process_action(Engine::Action::Choose.new(game.current_entity, choice: choice)).maybe_raise!
end
choose.call('start_v5')
until game.construction_complete?
  choose.call('draw_v4')
  if game.drawn_project
    q, r = game.capital_choices.first
    choose.call("capital_v4:#{q}:#{r}")
  else
    candidates = 6.times.flat_map do |rotation|
      game.legal_anchors(rotation).map { |x, y| [x, y, rotation] }
    end
    q, r, rotation = candidates.min_by { |x, y, rot| [x.abs + y.abs + (x + y).abs, x, y, rot] }
    raise 'No legal placement; map construction must restart' unless q

    id = game.real_catalog[game.drawn_piece][:id]
    choose.call("place_v4:#{id}:#{q}:#{r}:#{rotation}")
  end
end
choose.call('finish_blanks_v5')
choose.call('play_v1')
puts JSON.pretty_generate({
                            id: game.id,
                            title: 'RotLA',
                            status: 'active',
                            players: game.players.map { |player| { id: player.id, name: player.name } },
                            settings: { seed: game.seed, optional_rules: [] },
                            actions: game.raw_actions.map(&:to_h),
                          })
