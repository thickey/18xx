# frozen_string_literal: true

# Export a legal OR with Suburban ready to place its first suburb.
require_relative '../../lib/engine'
require 'json'
Engine::Logger.set_level(::Logger::WARN)

fixture = JSON.parse(File.read('data/rotla/hotseat-rounds-start.json'))
game = Engine::Game::GRotla::Game.new(%w[Alice Bob Carol], id: fixture['id'], actions: fixture['actions'])
act = lambda do |type, **args|
  game.process_action(Engine::Action.const_get(type).new(game.current_entity, **args)).maybe_raise!
end
%w[EM EA NP SU].each do |id|
  act.call(:Bid, price: 125, corporation: game.available_charters.first)
  2.times { act.call(:Pass) }
  act.call(:Choose, choice: id)
end
3.times { act.call(:Pass) }
until game.current_entity.id == 'SU'
  step = game.round.active_step
  if step.is_a?(Engine::Game::GRotla::Step::Route)
    act.call(:Choose, choice: 'local')
  elsif step.is_a?(Engine::Step::Dividend)
    act.call(:Dividend, kind: 'payout')
  elsif step.is_a?(Engine::Game::GRotla::Step::BuyTrain) && game.current_entity.trains.empty?
    act.call(:BuyTrain, train: game.depot.upcoming.first, price: 100)
  else
    act.call(:Pass)
  end
end
act.call(:BuyTrain, train: game.depot.upcoming.first, price: 100)
act.call(:Pass)
home = game.hex_by_id(game.current_entity.coordinates)
act.call(:LayTile, hex: home, tile: game.tiles.find { |tile| tile.name == '5' }, rotation: 0)
hex = home.neighbors[0]
tile = game.tiles.find { |t| t.name == '5' }
rotation = game.round.active_step.legal_tile_rotations(game.current_entity, hex, tile).first
raise 'No legal connection to the suburb city' unless rotation

act.call(:LayTile, hex: hex, tile: tile, rotation: rotation)
raise 'No available suburb' if game.suburb_choices(game.current_entity).empty?

puts JSON.pretty_generate({
                            id: game.id,
                            title: 'RotLA',
                            status: 'active',
                            players: fixture['players'],
                            settings: { seed: game.seed, optional_rules: [] },
                            actions: game.raw_actions.map(&:to_h),
                          })
