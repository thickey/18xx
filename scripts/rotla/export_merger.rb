# frozen_string_literal: true

# Replay legal setup and play through two cycles to the first Merger Round.
require_relative '../../lib/engine'
require 'json'
Engine::Logger.set_level(::Logger::WARN)

fixture = JSON.parse(File.read('data/rotla/hotseat-rounds-start.json'))
game = Engine::Game::GRotla::Game.new(%w[Alice Bob Carol], id: fixture['id'], actions: fixture['actions'])
act = lambda do |type, **args|
  game.process_action(Engine::Action.const_get(type).new(game.current_entity, **args)).maybe_raise!
end
[['AD', 300], ['EM', 125]].each do |id, bid|
  act.call(:Bid, price: bid, corporation: game.available_charters.first)
  2.times { act.call(:Pass) }
  act.call(:Choose, choice: id)
  act.call(:Choose, choice: 'home:J6') if id == 'AD'
end
3.times { act.call(:Pass) }
until game.round.merger?
  raise 'Demo did not reach a merger within two cycles' if game.turn > 2

  corp = game.current_entity
  step = game.round.active_step
  if step.is_a?(Engine::Game::GRotla::Step::LeadOffTrain)
    act.call(:BuyTrain, train: game.depot.upcoming.first, price: 100)
  elsif step.is_a?(Engine::Game::GRotla::Step::Track) && corp.id == 'AD' && game.turn == 1 && game.round.round_num == 1
    hex = game.hex_by_id(game.round.num_laid_track.zero? ? 'J6' : 'J8')
    edges = game.round.num_laid_track.zero? ? [0] : [3, 5]
    tile = step.upgradeable_tiles(corp, hex).find do |candidate|
      candidate.legal_rotations.any? do |rotation|
        candidate.rotate!(rotation)
        (edges - candidate.exits).empty?
      end
    end
    raise "No legal connecting tile at #{hex.id}" unless tile

    rotation = tile.legal_rotations.find do |orientation|
      tile.rotate!(orientation)
      (edges - tile.exits).empty?
    end
    act.call(:LayTile, hex: hex, tile: tile, rotation: rotation)
  elsif step.is_a?(Engine::Game::GRotla::Step::Route)
    act.call(:Choose, choice: 'local')
  elsif step.is_a?(Engine::Step::Dividend)
    act.call(:Dividend, kind: 'payout')
  elsif step.is_a?(Engine::Game::GRotla::Step::BuyTrain) && corp.id == 'AD' && game.phase.name == '2' && game.turn == 2
    act.call(:BuyTrain, train: game.depot.upcoming.first, price: 200)
  else
    act.call(:Pass)
  end
end
raise 'The demo minors are not connected' unless game.merger_connected?(game.corporation_by_id('AD'),
                                                                        game.corporation_by_id('EM'))

puts JSON.pretty_generate({
                            id: game.id,
                            title: 'RotLA',
                            status: 'active',
                            players: fixture['players'],
                            settings: { seed: game.seed, optional_rules: [] },
                            actions: game.raw_actions.map(&:to_h),
                          })
