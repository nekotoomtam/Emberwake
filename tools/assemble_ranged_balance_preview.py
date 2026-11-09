"""Assemble source-backed native ranged-balance stills and chronological fireball GIF."""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--capture', type=Path, required=True)
parser.add_argument('--output-dir', type=Path, required=True)
parser.add_argument('--gif', action='store_true')
args = parser.parse_args()
capture, out = args.capture.resolve(), args.output_dir.resolve()
manifest = json.loads((capture / 'capture-manifest.json').read_text(encoding='utf-8'))
assert manifest['failures'] == [], manifest['failures']
safe, physics = manifest['native_window'], manifest['physics_context']
assert safe['unfocusable'] and safe['native_no_focus_flag'] and safe['checked_every_frame_and_tick']
assert safe['actual_position'] == [20000, 20000]
assert physics['outside_physics_ticks'] == 0
assert abs(physics['min_physics_delta'] - 1 / 120) < 1e-6
assert abs(physics['max_physics_delta'] - 1 / 120) < 1e-6
cases = {row['case']: row for row in manifest['cases']}
states = {row['file']: row for row in manifest['screenshot_states']}
assert len(cases) == 8 and len(states) == 23
cluster = cases['staff-cluster-pause']
assert cluster['shots'] == 1 and cluster['hits'] == 2 and cluster['damage'] == 108
assert {name: target['damage_taken'] for name, target in cluster['targets'].items()} == {
    'primary': 72, 'near': 36, 'far': 0, 'covered': 0}
assert len(cluster['area_events']) == 1
assert cluster['area_events'][0]['radius'] == 1.2 and cluster['area_events'][0]['visible_blast_count'] == 1
assert cluster['resolved'][0]['splash_radius'] == 1.2
assert cluster['resolved'][0]['splash_hitids'] == [cluster['targets']['near']['id']]
assert cluster['remaining_blasts'] == cluster['remaining_projectiles'] == 0
assert cluster['fixture_blocker']['test_only'] and cluster['fixture_blocker']['visible_mesh_matches_collision']
assert cluster['fixture_blocker']['removed_before_next_case']
assert cluster['fixture_blocker']['position'] == [3.6, .65, -.8]
assert cluster['fixture_blocker']['size'] == [1, 1.3, .12]
assert all(abs(actual - expected) < 1e-5 for actual, expected in zip(cluster['targets']['primary']['position'], [4, .03, 0]))
pause = manifest['pause']
assert pause['mode'] == 'paused' and pause['end_tick'] - pause['start_tick'] == 48
assert pause['age_before'] == pause['age_after']
assert pause['simulation_before'] == pause['simulation_after']
assert 0 < pause['age_before'] < .4 and pause['radius'] == 1.2
restart = manifest['restart']
assert restart['old_nodes_removed_from_owner'] and restart['old_blast_removed']
assert restart['before']['blasts'] and not restart['after']['blasts'] and not restart['after']['flights']
assert restart['after']['shots'] == restart['after']['hits'] == restart['after']['damage'] == 0
for family, cycle, rounds in [('staff', 1.2, 10), ('pistol', .42, 7), ('rifle', .9, 2)]:
    row = cases[f'{family}-three-shot-cadence']
    assert row['shots'] == 3 and row['mouse_presses'] == row['mouse_releases'] == 1
    assert row['hits'] == row['damage'] == 0 and not row['area_events']
    assert len(row['shot_intervals']) == 2
    assert all(abs(value - cycle) <= 2.1 / 120 for value in row['shot_intervals'])
    assert row['rounds'] == rounds and not row['reload_events']
    if family == 'staff':
        assert all(shot['speed'] == 5.5 and shot['range'] == 6 and shot['damage'] == 72 for shot in row['shot_events'])
    else:
        assert all(shot['element'] == 'physical' for shot in row['shot_events'])
reload = cases['rifle-six-shot-reload']
assert reload['shots'] == 6 and reload['rounds'] == 4 and not reload['reloading']
assert reload['casings_spawned'] == 6 and abs(reload['player_displacement'][0] + 1.32) < .003
assert len(reload['reload_events']) == 1 and reload['reload_events'][0]['duration'] == 1.2
assert all(abs(value - (.9 + (1.2 if index == 4 else 0))) <= 2.1 / 120
           for index, value in enumerate(reload['shot_intervals']))
for label, reason in [('staff-cover', 'cover'), ('staff-range', 'range')]:
    row = cases[label]
    assert row['shots'] == 1 and row['hits'] == row['damage'] == 0 and not row['area_events']
    assert len(row['resolved']) == 1 and row['resolved'][0]['reason'] == reason
    assert row['remaining_blasts'] == row['remaining_projectiles'] == 0
for name in states:
    with Image.open(capture / name) as source:
        assert source.size == (1280, 800), (name, source.size)

out.mkdir(parents=True, exist_ok=True)
font_path = 'C:/Windows/Fonts/tahoma.ttf'
font = ImageFont.truetype(font_path, 21)
small = ImageFont.truetype(font_path, 17)
tiny = ImageFont.truetype(font_path, 13)
background, paper, gold = '#0d1922', '#e7efe9', '#ffd06a'


def proof_points(rows):
    points = [row[key] for row in rows for key in ['screen_player_ground', 'screen_player_top']]
    for row in rows:
        for flight in row['flights']:
            x, y = flight['screen_position']
            points.extend([(x - 65, y - 35), (x + 35, y + 35)])
        for blast in row['blasts']:
            points.append(blast['screen_center'])
            points.extend(blast['screen_radius_points'])
        if row['case'].startswith('staff-cluster'):
            points.extend(target[key] for target in row['targets'].values() for key in ['screen_ground', 'screen_top'])
        elif row['case'].startswith('staff-native-restart'):
            points.extend(target[key] for target in row['targets'].values() for key in ['screen_ground', 'screen_top'])
    return points


def crop_box(rows):
    points = proof_points(rows)
    x = (min(point[0] for point in points) + max(point[0] for point in points)) / 2
    y = (min(point[1] for point in points) + max(point[1] for point in points)) / 2
    left, top = max(0, min(680, round(x - 300))), max(190, min(400, round(y - 200)))
    return left, top, left + 600, top + 400


cluster_rows = [row for row in states.values() if row['case'] == 'staff-cluster-pause']
cluster_box = crop_box(cluster_rows)
assert all(cluster_box[0] + 6 <= x <= cluster_box[2] - 6 and
           cluster_box[1] + 6 <= y <= cluster_box[3] - 6 for x, y in proof_points(cluster_rows)), 'Cluster crop omits an actor, flight, or real blast radius.'
blast_frame = states['staff-cluster-02-round-blast.png']
assert blast_frame['blasts'], 'Round-blast still must show a real active blast.'
assert all(190 <= point[1] <= 690 for point in blast_frame['blasts'][0]['screen_radius_points']), 'Blast proof is obscured by the native HUD or outside playfield.'


def sheet(filename, title, names, columns):
    width, height = 480, 390
    canvas = Image.new('RGB', (width * columns, 55 + height * ((len(names) + columns - 1) // columns)), background)
    draw = ImageDraw.Draw(canvas)
    draw.text((12, 8), title, font=font, fill=gold)
    draw.text((12, 34), 'Actual native viewport crops; all labels and values come from captured simulation state.', font=tiny, fill=paper)
    for index, name in enumerate(names):
        row = states[name]
        related = [state for state in states.values() if state['case'] == row['case']]
        with Image.open(capture / name) as source:
            tile = source.convert('RGB').crop(crop_box(related)).resize((480, 320), Image.Resampling.NEAREST)
        x, y = index % columns * width, 55 + index // columns * height
        canvas.paste(tile, (x, y))
        draw.text((x + 8, y + 324), name.removesuffix('.png').replace('-', ' ').upper(), font=tiny, fill=gold)
        draw.text((x + 8, y + 346), f"{row['mode'].upper()} / SHOTS {row['shots']} / HITS {row['hits']} / DAMAGE {row['damage']:.1f}", font=small, fill=paper)
        blast = row['blasts'][0] if row['blasts'] else None
        if blast:
            detail = f"GROUND RADIUS {blast['radius']:.2f} u / AGE {blast['age']:.3f}s"
        elif row['family'] == 'staff':
            detail = f"FLIGHTS {len(row['flights'])} / {row['phase'].upper()}"
        else:
            detail = f"FLIGHTS {len(row['flights'])} / AMMO {row['rounds']} / {row['phase'].upper()}"
        draw.text((x + 8, y + 370), detail, font=tiny, fill=paper)
    path = out / filename
    canvas.save(path)
    return path


outputs = [sheet('ranged-balance-staff-blast.png', 'EMBERWAKE v16 / SLOW FIREBALL / ROUND FIRE BLAST / REAL PAUSE',
                 ['staff-cluster-00-ready.png', 'staff-cluster-01-slow-fireball.png',
                  'staff-cluster-02-round-blast.png', 'staff-cluster-03-pause-frozen.png'], 2)]
outputs.append(sheet('ranged-balance-cadence.png', 'EMBERWAKE v16 / THREE ACTUAL SHOTS / SLOWER STAFF, PISTOL, RIFLE',
                     [f'{family}-three-shot-cadence-{phase}.png' for family in ['staff', 'pistol', 'rifle']
                      for phase in ['01-first-shot', '02-finished']], 2))
outputs.append(sheet('ranged-balance-lifecycle.png', 'EMBERWAKE v16 / RELOAD + COVER + RANGE + NATIVE RESTART',
                     ['rifle-six-shot-reload-02-finished.png', 'staff-cover-01-no-blast.png',
                      'staff-range-01-no-blast.png', 'staff-restart-00-active-blast.png',
                      'staff-restart-01-cleared.png'], 3))

if args.gif:
    timeline = manifest['raw_states']
    assert manifest['raw_frame_count'] == len(timeline) == len(manifest['raw_frames']) == 90
    assert all(timeline[index]['physics_tick'] - timeline[index - 1]['physics_tick'] == 4 for index in range(1, 90))
    assert all(abs(row['native_elapsed_seconds'] - (index + 1) / 30) < 1e-5 for index, row in enumerate(timeline))
    box, frames = crop_box(timeline), []
    for name, row in zip(manifest['raw_frames'], timeline):
        with Image.open(capture / 'fireball' / Path(name).name) as source:
            frame = Image.new('RGB', (900, 654), background)
            frame.paste(source.convert('RGB').crop(box).resize((900, 600), Image.Resampling.NEAREST), (0, 0))
        draw = ImageDraw.Draw(frame)
        draw.text((10, 604), f"ACTUAL LMB / {row['native_elapsed_seconds']:.2f}s / {row['mode'].upper()} / HITS {row['hits']} / DAMAGE {row['damage']:.0f}", font=small, fill=gold)
        draw.text((10, 630), 'DIRECT 72 / NEAR 36 / FAR 0 / COVERED 0 / GROUND BLAST RADIUS 1.20 u', font=tiny, fill=paper)
        frames.append(frame)
    path = out / 'ranged-balance-fireball-native.gif'
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=[30 if index % 3 != 2 else 40 for index in range(90)], loop=0, disposal=2, optimize=False)
    outputs.append(path)

summary = {'capture_manifest': str(capture / 'capture-manifest.json'), 'cases': manifest['cases'],
           'pause': manifest['pause'], 'restart': manifest['restart'],
           'outputs': [{'file': str(path), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()} for path in outputs]}
(out / 'ranged-balance-preview-summary.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding='utf-8')
for path in outputs:
    print(path)
