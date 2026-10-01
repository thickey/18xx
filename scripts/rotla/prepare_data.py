#!/usr/bin/env python3
"""Rebuild the research catalog offline from saved source responses (stdlib only)."""
import hashlib
import html
import json
import re
from collections import Counter, defaultdict
from pathlib import Path
from urllib.parse import urljoin

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'data/rotla'
SOURCE = OUT / 'sources'
INVENTORY_URL = 'http://www.fwtwr.com/18xx/info/inv-rotla.asp'
UPGRADES_URL = 'http://www.fwtwr.com/18xx/info/tuc-rotla.asp'


def write(name, data):
    (OUT / name).write_text(json.dumps(data, indent=2, ensure_ascii=False) + '\n')


def rows(path):
    # Leaf rows only: the source uses nested layout tables.
    source = path.read_text(encoding='cp1252')
    for row in re.findall(r'<tr\b[^>]*>((?:(?!<tr\b).)*?)</tr>', source, re.S | re.I):
        cells = re.findall(r'<td\b[^>]*>(.*?)</td>', row, re.S | re.I)
        text = [' '.join(html.unescape(re.sub('<[^>]*>', ' ', c)).split()) for c in cells]
        if text:
            yield text, cells


def rotate(point):
    q, r = point
    return -r, q + r


def canonical(cells):
    """Translation/rotation invariant geometry, retaining Hex1/2/3 order; no reflection."""
    origin = cells[0][0]
    points = [(p[0] - origin[0], p[1] - origin[1]) for p, _ in cells]
    choices = []
    for turns in range(6):
        choices.append((tuple(points), turns))
        points = [rotate(p) for p in points]
    return min(choices)


def board_catalog():
    catalog = {}
    samples = []
    for path in sorted(SOURCE.glob('board-*.json')):
        seed = int(path.stem.split('-')[1])
        board = json.loads(path.read_text())
        data = board['data']
        assert len(data) == 99
        groups = defaultdict(list)
        for coordinate, cell in data.items():
            cube = tuple(map(int, coordinate.split('_')))
            assert len(cube) == 3 and sum(cube) == 0
            groups[cell['tile_id']].append((cube[:2], cell))
        assert len(groups) == 33
        sample = {'seed': seed, 'hex_count': len(data), 'piece_count': len(groups),
                  'capital_overlays': sorted(c['setup_tile'] for c in data.values() if c['terrain'] == 'capital_city')}
        samples.append(sample)
        for tile_id, cells in sorted(groups.items()):
            cells.sort(key=lambda item: item[1]['setup_tile'])
            assert len(cells) == 3
            assert [c['setup_tile'] for _, c in cells] == [f'{tile_id}_Hex{i}' for i in range(1, 4)]
            points, turns = canonical(cells)
            for a in points:
                for b in points:
                    if a != b:
                        dq, dr = a[0] - b[0], a[1] - b[1]
                        assert max(abs(dq), abs(dr), abs(dq + dr)) == 1
            hexes = []
            for point, (_, c) in zip(points, cells):
                terrain = 'standard_city' if c['terrain'] == 'capital_city' else c['terrain'].lower()
                hexes.append({'id': c['setup_tile'], 'axial': point, 'terrain': terrain,
                              'source_tile_name': c['tile_name'],
                              'canonical_facing': ['nn', 'ne', 'se', 'ss', 'sw', 'nw'][
                                  (['nn', 'ne', 'se', 'ss', 'sw', 'nw'].index(c['orientation'])
                                   + 2 * c['rotation'] + turns) % 6]})
            number = int(tile_id) if len(tile_id) == 2 else int(tile_id[:-1])
            fixed = {'generator_tile_id': tile_id, 'printed_number': number,
                     'quantity': 1, 'hexes': hexes}
            if tile_id in catalog:
                assert catalog[tile_id]['fixed'] == fixed, f'Conflicting fixed data: {tile_id}'
            else:
                catalog[tile_id] = {'fixed': fixed, 'observations': []}
            catalog[tile_id]['observations'].append({
                'seed': seed, 'canonical_rotation_steps': turns,
                'hexes': [{'coordinate': list(p), **c} for p, c in cells],
            })
    expected = Counter({i: (2 if 12 <= i <= 16 else 1) for i in range(1, 29)})
    assert Counter(c['fixed']['printed_number'] for c in catalog.values()) == expected
    write('map-pieces.json', {'schema_version': 1, 'status': 'research; not engine tile codes',
          'coordinate_convention': 'Axial q,r from API cube x,y,z; rotate(q,r)=(-r,q+r). Hex1 is origin; lexicographically smallest rotation, never reflected.',
          'normalization': 'capital_city becomes standard_city; capital markers belong to generated setup. Terrain names lowercased; source names retained.',
          'printed_number_mapping': '01..11 map directly; 120..280 use all but last digit; final digit distinguishes copies. Checked against rulebook component sheet counts.',
          'orientation_warning': 'canonical_facing uses the client orientation lookup (orientation + 2*rotation modulo 6), then applies geometry normalization. Matches both samples. This describes source artwork facing, not engine exits.',
          'pieces': [v for _, v in sorted(catalog.items())]})
    return samples


def inventory():
    companies, track, components, economics, trains = [], [], [], {}, []
    mode = None
    color = None
    pending_ids = []
    for text, raw in rows(SOURCE / 'inventory.html'):
        first = text[0]
        if first == 'Components': mode = 'components'; continue
        if first in ('Minor Companies', 'Public Companies'):
            mode = 'minor' if first == 'Minor Companies' else 'major'; continue
        if first == 'Starting Cash': mode = 'cash'; continue
        if first == 'Certificate Limits': mode = 'limits'; continue
        if first in ('Stock Market', 'Game Map'): mode = None
        if first.endswith(' Tiles') and len(text) > 2 and text[1] == 'Number':
            color = first.split()[0].lower(); mode = 'track'
        if first == 'Trains':
            mode = 'trains'; train_types = text[2:]; continue
        if mode == 'components' and len(text) == 3:
            components.append(dict(zip(['name', 'quantity', 'notes'], text)))
        elif mode in ('minor', 'major') and len(text) == 7:
            count, percent = map(int, re.findall(r'\d+', text[3]))
            shares = [int(text[2].rstrip('%'))] + [percent] * count
            assert sum(shares) == 100
            home = re.search(r'tile (\d+)', text[4])
            companies.append({'id': first, 'name': text[1], 'type': mode, 'shares_percent': shares,
                              'home_source': text[4], 'home_printed_tile': int(home[1]) if home else None,
                              'station_tokens': int(text[5]), 'ability_summary_source': text[6],
                              'source': INVENTORY_URL, 'status': 'inventory transcription; powers require rulebook implementation'})
        elif mode in ('cash', 'limits') and len(text) == 2 and '-player' in first:
            economics.setdefault(mode, {})[first] = text[1]
        elif mode == 'track':
            if 'Number' in text:
                pending_ids = [t for t in text[text.index('Number') + 1:] if re.fullmatch(r'(?:\d+|LA\d+)', t)]
            if 'Tiles' in text:
                images = [urljoin(INVENTORY_URL, s) for s in re.findall(r'<img[^>]*src="([^"]+)"', ''.join(raw), re.I)]
            if 'Qty' in text:
                quantities = [int(t) for t in text[text.index('Qty') + 1:] if t.isdigit()]
                assert len(pending_ids) == len(quantities) == len(images)
                track.extend({'id': i, 'quantity': q, 'source_color': color,
                              'game_color': 'purple' if color == 'brown' else color,
                              'reference_image_url': image} for i, q, image in zip(pending_ids, quantities, images))
        elif mode == 'trains':
            if 'Cost' in text: costs = text[text.index('Cost') + 1:]
            if 'Qty' in text:
                trains = [{'type': t, 'cost_source': c, 'quantity_source': q} for t, c, q in zip(train_types, costs, text[text.index('Qty') + 1:])]
    assert Counter(c['type'] for c in companies) == {'minor': 12, 'major': 6}
    assert sum(c['station_tokens'] for c in companies) == 37
    totals = Counter()
    for tile in track: totals[tile['game_color']] += tile['quantity']
    assert totals == {'yellow': 55, 'green': 43, 'purple': 27, 'grey': 5, 'blue': 5}
    assert len({t['id'] for t in track}) == len(track)
    pieces = json.loads((OUT / 'map-pieces.json').read_text())['pieces']
    for company in companies:
        homes = [h['id'] for piece in pieces
                 if piece['fixed']['printed_number'] == company['home_printed_tile']
                 for h in piece['fixed']['hexes'] if h['terrain'].startswith('minor_')]
        assert len(homes) == (1 if company['home_printed_tile'] else 0)
        company['home_setup_hex'] = homes[0] if homes else None
    write('companies.json', {'schema_version': 1, 'companies': companies})
    write('track-tiles.json', {'schema_version': 1, 'source': INVENTORY_URL,
          'id_warning': 'FWTWR reference IDs, not printed game IDs. Engine geometry/revenues have not been verified, including numeric IDs.',
          'totals': dict(totals), 'tiles': track})
    write('components-and-economy.json', {'source': INVENTORY_URL, 'components': components,
          'economics_source': economics, 'trains_original_printing': trains,
          'edition_warning': 'Inventory header describes 2026 revision kit, but train table retains original 5-player-only extra 3 and two 6 trains. Do not treat as a unified revised inventory.',
          'revision_kit_2026': {'extra_3_train_min_players': 4, 'additional_6_train_min_players': 4,
                              'also_replaces': ['rulebook', 'setup summary', 'five turn/phase summaries'], 'adds': ['solo rulebook']}})
    return track


def upgrades(track):
    entries = []
    for text, raw in rows(SOURCE / 'upgrades.html'):
        if len(text) != 18: continue
        if text[0]:
            entry = {'source_label': text[0], 'source_id': text[0] if text[0].startswith('Map') else text[0].split()[0],
                     'quantity_source': text[2], 'target_ids': [], 'explicit_no_upgrade': False}
            entries.append(entry)
        else:
            assert entries
            entry = entries[-1]
        entry['target_ids'].extend(t for t in text[4::2] if t)
        entry['explicit_no_upgrade'] |= 'alt="No upgrade"' in ''.join(raw)
    ids = {t['id'] for t in track}
    assert {e['source_id'] for e in entries if not e['source_id'].startswith('Map')} == ids
    for entry in entries:
        assert set(entry['target_ids']) <= ids
        assert entry['target_ids'] or entry['explicit_no_upgrade']
        if entry['source_id'] in ids:
            assert int(entry['quantity_source'].strip('{}')) == next(t['quantity'] for t in track if t['id'] == entry['source_id'])
        if entry['source_label'] == 'Map Tri-Hex Tile 11 Tunneling Minor':
            entry['warning'] = 'Source mislabels tile 11 as Tunneling. Inventory and rulebook identify Spacious on 11; Tunneling on 8. Do not use this row as a Tunneling rule.'
    write('tile-upgrades.json', {'schema_version': 1, 'source': UPGRADES_URL,
          'status': 'reference adjacency; rotation, connectivity, special powers and capital restrictions still apply', 'entries': entries})
    return len(entries), sum(len(e['target_ids']) for e in entries)


def main():
    samples = board_catalog()
    facts = json.loads((OUT / 'rulebook-facts.json').read_text())
    assert len(facts['company_abilities']['companies']) == 12
    assert facts['setup']['base_trihex_quantity'] == samples[0]['piece_count']
    track = inventory()
    row_count, edge_count = upgrades(track)
    report = {'board_samples': samples, 'companies': 18, 'track_designs': len(track), 'track_quantity': 135,
              'upgrade_source_rows': row_count, 'upgrade_edges': edge_count,
              'checks': ['99 unique cube coordinates and 33 complete pieces per sample',
                         'all three cells mutually adjacent; geometry matches under rotations without reflection',
                         'terrain and names agree after removing capital overlays',
                         'printed IDs 1..28; two copies each of 12..16',
                         'company shares sum to 100%; station tokens total 37',
                         'all track quantities match color subtotals and upgrade chart',
                         'upgrade continuations merged; all targets exist in inventory']}
    write('validation.json', report)
    files = sorted(SOURCE.iterdir())
    pdf = ROOT / 'RailwaysRulebook-CleanFonts.pdf'
    write('sources.json', {'retrieved_date': '2026-09-26',
          'map_api': {'url_template': 'https://lost-atlas-api.fly.dev/boards/{seed}?variant=std&random_minors=false&random_start_tile=false&landmarks=false',
                      'method': 'GET', 'authentication': 'Bearer key from user-supplied URL; deliberately not stored',
                      'client_version_observed': 'v1.4.0 production',
                      'client_script_url': 'https://lost-atlas-ui.fly.dev/_next/static/chunks/app/page-aa3c13d4e02c338f.js'},
          'inventory_url': INVENTORY_URL, 'upgrade_chart_url': UPGRADES_URL,
          'rulebook': {'path': pdf.name, 'sha256': hashlib.sha256(pdf.read_bytes()).hexdigest(),
                       'edition': 'Copyright 2024; revision not conclusively identified', 'component_sheet_pdf_page': 3, 'component_sheet_printed_page': 2},
          'snapshots': [{'path': str(p.relative_to(OUT)), 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()} for p in files]})
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
