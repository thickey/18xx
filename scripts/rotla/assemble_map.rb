# frozen_string_literal: true

# Offline full-map smoke test and hotseat export: bundle exec ruby scripts/rotla/assemble_map.rb
require_relative '../../lib/engine'
require 'json'
Engine::Logger.set_level(::Logger::WARN)

names = %w[Alice Bob Carol]
game = Engine::Game::GRotla::Game.new(names, id: '3722698')
choose = lambda do |choice|
  game.process_action(Engine::Action::Choose.new(game.current_entity, choice: choice)).maybe_raise!
end
choose.call('start_v4')
until game.setup_complete?
  choose.call('draw_v4')
  if game.drawn_project
    q, r = game.capital_choices.first
    choose.call("capital_v4:#{q}:#{r}")
    next
  end
  candidates = 6.times.flat_map do |rotation|
    game.legal_anchors(rotation).map { |x, y| [x, y, rotation] }
  end
  q, r, rotation = candidates.min_by { |x, y, rot| [x.abs + y.abs + (x + y).abs, x, y, rot] }
  raise 'No legal placement; map construction must restart' unless q

  id = game.real_catalog[game.drawn_piece][:id]
  choose.call("place_v4:#{id}:#{q}:#{r}:#{rotation}")
end
export = {
  id: game.id,
  title: 'RotLA',
  status: 'active',
  players: game.players.map { |player| { id: player.id, name: player.name } },
  settings: { seed: game.seed, optional_rules: [] },
  actions: game.raw_actions.map(&:to_h),
}
puts JSON.generate(export)
