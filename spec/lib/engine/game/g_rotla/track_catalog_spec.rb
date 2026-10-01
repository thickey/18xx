# frozen_string_literal: true

require 'spec_helper'
require 'json'

module Engine
  describe Game::GRotla::Game, 'track catalog' do
    let(:game) { described_class.new(%w[Alice Bob Carol], id: '1') }

    def tile(name)
      game.tiles.find { |candidate| candidate.name == name }.dup
    end

    it 'matches all 54 source designs and all 135 physical copies' do
      source = JSON.parse(File.read('data/rotla/track-tiles.json'))
      expect(game.tiles.group_by(&:name).transform_values(&:size)).to eq(source['tiles'].to_h do |entry|
        [entry['id'], entry['quantity']]
      end)
      expect(game.tiles.group_by(&:color).transform_values(&:size)).to eq(
        yellow: 55, green: 43, brown: 27, gray: 5, blue: 5
      )
    end

    it 'uses the capital track shapes, revenues and slots from the reference artwork' do
      {
        '291' => '6',
        '292' => '5',
        '293' => '57',
        '294' => '14',
        '295' => '15',
        '296' => '619',
        '297' => '125',
        'LA6' => '125',
      }.each do |name, standard|
        capital = tile(name)
        expect(capital.exits).to eq(Tile.for(standard).exits) if standard
        revenue, slots = { yellow: [40, 1], green: [50, 2], brown: [60, 3], gray: [70, 3] }[capital.color]
        expect(capital.cities.one?).to be(true)
        expect(capital.cities.first.revenue[capital.color]).to eq(revenue)
        expect(capital.cities.first.slots).to eq(slots)
        expect(capital.label.to_s).to eq('C')
      end
      expect(tile('LA6').exits).to eq(tile('297').exits)
    end

    it 'keeps Mining stops connected and Port halves separate through their upgrades' do
      {
        'LA1' => [[50, 30], [1, 1]],
        'LA4' => [[60, 40], [1, 2]],
        'LA7' => [[70, 50], [1, 2]],
        'LA2' => [[60, 60], [1, 1]],
        'LA5' => [[80, 80], [2, 2]],
      }.each do |name, (revenues, slots)|
        upgrade = tile(name)
        expect(upgrade.cities.map { |city| city.revenue[upgrade.color] }).to eq(revenues)
        expect(upgrade.cities.map(&:slots)).to eq(slots)
        expect(upgrade.paths.any? { |path| path.nodes.size == 2 }).to eq(upgrade.label.to_s == 'M')
      end
    end

    it 'allows both Mining rotations at every upgrade and rejects lost exits' do
      step = Game::GRotla::Step::Track.new(game, game.round)
      home = Tile.from_code('mining', :yellow, game.real_cell_definition(:mining, 0, 1)[:code])
      [[home, tile('LA1')], [tile('LA1'), tile('LA4')], [tile('LA4'), tile('LA7')]].each do |from, to|
        expect(game.upgrades_to?(from, to)).to be(true)
        hex = Struct.new(:tile).new(from)
        rotations = (0..5).select do |rotation|
          to.rotate!(rotation)
          step.old_paths_maintained?(hex, to)
        end
        expect(rotations.size).to eq(2)
      end
      expect(game.upgrades_to?(tile('LA1'), tile('LA5'))).to be(false)
    end

    it 'allows the full capital and Port chains and keeps terminal tiles terminal' do
      %w[291 292 293].product(%w[294 295 296]).each do |from, to|
        expect(game.upgrades_to?(tile(from), tile(to))).to be(true)
      end
      [%w[294 297], %w[295 297], %w[296 297], %w[297 LA6], %w[LA2 LA5], %w[125 51]].each do |from, to|
        expect(game.upgrades_to?(tile(from), tile(to))).to be(true)
      end
      %w[LA5 LA6 LA7 51 721 722 723].each do |name|
        expect(game.tiles.none? { |candidate| game.upgrades_to?(tile(name), candidate) }).to be(true)
      end
    end

    it 'supports every tile-to-tile relationship in the source upgrade chart' do
      entries = JSON.parse(File.read('data/rotla/tile-upgrades.json'))['entries']
      entries.reject { |entry| entry['source_id'].start_with?('Map') }.each do |entry|
        entry['target_ids'].each do |target|
          expect(game.upgrades_to?(tile(entry['source_id']), tile(target))).to be(true),
                                                                               "#{entry['source_id']} -> #{target}"
        end
      end
    end

    it 'keeps water on both blank Port sides in every rotation' do
      %w[LA2 LA5].each do |name|
        port = tile(name)
        (0..5).each do |rotation|
          port.rotate!(rotation)
          expect(game.tile_water_edges(port).sort).to eq(((0..5).to_a - port.exits).sort)
          expect(game.water_edges_for(Struct.new(:tile).new(port))).to eq(game.tile_water_edges(port))
        end
      end
    end
  end
end
