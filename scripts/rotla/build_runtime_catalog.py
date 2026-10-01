"""Generate the browser-compatible Ruby catalog from the frozen real_v1 audit JSON.

Run with --check to detect drift without modifying the replay catalog.
Terrain/source rebuilding remains the responsibility of prepare_data.py.
"""
import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / 'data/rotla/runtime-map-v1.json'
OUTPUT = ROOT / 'lib/engine/game/g_rotla/map_catalog.rb'


def ruby(value):
    if isinstance(value, dict):
        return '{ ' + ', '.join(f'{key}: {ruby(item)}' for key, item in value.items()) + ' }'
    if isinstance(value, list):
        return '[' + ', '.join(ruby(item) for item in value) + ']'
    if isinstance(value, str):
        return "'" + value.replace('\\', '\\\\').replace("'", "\\'") + "'"
    return str(value)


def generate(data):
    lines = ['# frozen_string_literal: true', '',
             '# Generated from data/rotla/runtime-map-v1.json. Keep this replay version immutable.',
             'module Engine', '  module Game', '    module GRotla', '      module MapCatalog',
             f"        VERSION = {ruby(data['runtime_version'])}", '        SPECIAL = {']
    for number, special in data['special'].items():
        lines.append(f'          {number} => {ruby(special)},')
    lines.extend(['        }.freeze', '        PIECES = ['])
    for piece in data['pieces']:
        terrains = ' '.join(cell['terrain'] for cell in piece['cells'])
        fields = f"id: {ruby(piece['id'])}, number: {piece['number']}, terrain: %i[{terrains}]"
        for index, cell in enumerate(piece['cells']):
            if cell['home']:
                fields += f", home: {ruby(cell['home'])}, name: {ruby(cell['home_name'])}, home_cell: {index}"
        lines.append('          { ' + fields + ' },')
    lines.extend(['        ].freeze',
                  '        SHORT_REMOVED = %w[' + ' '.join(data['short_removed_ids']) + '].freeze',
                  '      end', '    end', '  end', 'end', ''])
    return '\n'.join(lines)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    output = generate(json.loads(DATA.read_text()))
    if args.check:
        if OUTPUT.read_text() != output:
            raise SystemExit('Runtime Ruby catalog differs from the versioned JSON')
        print('real_v1 runtime catalog agrees with its JSON source')
    else:
        OUTPUT.write_text(output)
