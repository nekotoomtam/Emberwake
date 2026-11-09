"""Assemble inspected native melee-approach captures; never synthesize gameplay pixels."""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--capture', required=True, type=Path)
parser.add_argument('--output-dir', required=True, type=Path)
parser.add_argument('--gif', action='store_true', help='Use all 90 contiguous captured Sword frames.')
args = parser.parse_args()
capture = args.capture.resolve()
out = args.output_dir.resolve()
manifest = json.loads((capture / 'capture-manifest.json').read_text(encoding='utf-8'))
assert manifest['failures'] == [], manifest['failures']
physics = manifest['physics_context']
assert physics['outside_physics_ticks'] == 0
assert abs(physics['min_physics_delta'] - 1 / 120) < 1e-6
assert abs(physics['max_physics_delta'] - 1 / 120) < 1e-6
safe = manifest['native_window']
assert safe['unfocusable'] and safe['native_no_focus_flag'] and safe['checked_every_frame_and_tick']
assert safe['actual_position'] == [20000, 20000]
states = {row['file']: row for row in manifest['screenshot_states']}
cases = {row['case']: row for row in manifest['cases']}
assert len(cases) == 7 and len(manifest['strokes']) == 13
assert len(states) == 23
cursor = manifest['cursor_turn']
assert cursor['actual_input_received'] and cursor['cursor_intent_changed']
assert cursor['actual_game_aim_locked_midstroke']
assert cursor['maximum_game_aim_error_while_busy'] < .0001
assert cursor['maximum_motion_aim_error_while_busy'] < .0001
assert abs(cursor['actual_forward_displacement'] - .57) < .003
assert cursor['actual_perpendicular_displacement'] < .003
for family, total in [('sword', 71), ('greatsword', 177.5), ('mace', 92)]:
    row = cases[f'{family}-assisted-combo']
    assert row['stage_sequence'] == [0, 1, 2]
    assert row['mouse_presses'] == row['mouse_releases'] == 1
    assert row['stamina'] == 100 and row['dodge_left'] == row['space_presses'] == 0
    assert row['hits'] == 3 and row['damage'] == total
    assert row['initial_target_distance'] > row['initial_contact_range'] + row['previous_first_step']
    assert row['accepted_plans'][0]['assisted']
    assert row['accepted_plans'][0]['target_id'] == row['target_id']
    assert abs(row['accepted_plans'][0]['distance'] - .57) < .003
    assert all(not plan['assisted'] for plan in row['accepted_plans'][1:])
    assert row['target_final_displacement'] < .0001
    strokes = [s for s in manifest['strokes'] if s['case'] == row['case']]
    assert abs(strokes[0]['actual_positive_projection'] - .57) < .003
    assert all(abs(strokes[i]['actual_positive_projection'] - manifest['base_distances'][family][i]) < .003
               for i in [1, 2])
for label in ['sword-in-range', 'sword-far-empty', 'greatsword-blocked-target']:
    assert not cases[label]['accepted_plans'][0]['assisted']
assert cases['greatsword-blocked-target']['line_of_sight_blocked']
assert 0.01 < cases['greatsword-blocked-target']['actual_forward_displacement'] < .25
for name in states:
    with Image.open(capture / name) as source:
        assert source.size == (1280, 800), (name, source.size)

out.mkdir(parents=True, exist_ok=True)
font_file = 'C:/Windows/Fonts/tahoma.ttf'
font = ImageFont.truetype(font_file, 21)
small = ImageFont.truetype(font_file, 16)
tiny = ImageFont.truetype(font_file, 13)
bg, paper, gold = '#0d1922', '#e7efe9', '#ffd06a'


def crop_box(rows):
    points = [row[key] for row in rows for key in
              ['screen_player_ground', 'screen_case_origin', 'screen_target_ground']]
    center_x = (min(p[0] for p in points) + max(p[0] for p in points)) / 2
    center_y = (min(p[1] for p in points) + max(p[1] for p in points)) / 2 - 50
    left = max(0, min(1280 - 600, round(center_x - 300)))
    top = max(200, min(800 - 400, round(center_y - 200)))
    return left, top, left + 600, top + 400


def sheet(filename, title, names, columns):
    width, height = 400, 360
    canvas = Image.new('RGB', (width * columns, 58 + height * ((len(names) + columns - 1) // columns)), bg)
    draw = ImageDraw.Draw(canvas)
    draw.text((14, 8), title, font=font, fill=gold)
    draw.text((14, 34), 'Actual native viewport crops. Cyan: start / gold: first endpoint / coral: fixed target. Markers only.', font=tiny, fill=paper)
    for index, name in enumerate(names):
        row = states[name]
        related = [s for s in states.values() if s['case'] == row['case']]
        with Image.open(capture / name) as source:
            tile = source.convert('RGB').crop(crop_box(related)).resize((400, 267), Image.Resampling.NEAREST)
        x, y = index % columns * width, 58 + index // columns * height
        canvas.paste(tile, (x, y))
        draw.text((x + 8, y + 273), row['case'].replace('-', ' ').upper(), font=tiny, fill=gold)
        draw.text((x + 8, y + 294), f"STEP {row['stage'] + 1} / {row['phase'].upper()} / HITS {row['hits']} / DAMAGE {row['damage']:.1f}", font=small, fill=paper)
        draw.text((x + 8, y + 318), f"ACTUAL TOTAL {row['case_forward_displacement']:.3f} u / STAMINA {row['stamina']:.0f}", font=tiny, fill=paper)
        plan = row['plan']
        desc = f"ASSISTED {plan['distance']:.3f} u" if plan.get('assisted') else str(plan.get('reason', 'before input')).upper()
        draw.text((x + 8, y + 338), desc, font=tiny, fill=gold)
    path = out / filename
    canvas.save(path)
    return path


names = [f'{family}-assisted-combo-{phase}.png'
         for family in ['sword', 'greatsword', 'mace']
         for phase in ['00-before', '01-closing', '02-hit', '03-hit', '04-hit']]
outputs = [sheet('melee-approach-three-combos.png', 'EMBERWAKE v14 / FIXED TARGETS BEYOND OLD RANGE / THREE REAL HITS EACH', names, 5)]
names = ['sword-in-range-00-before.png', 'sword-in-range-01-after.png',
         'sword-far-empty-00-before.png', 'sword-far-empty-01-after.png',
         'greatsword-blocked-target-00-before.png', 'greatsword-blocked-target-01-stopped.png',
         'sword-cursor-lock-00-before.png', 'sword-cursor-lock-01-locked-hit.png']
outputs.append(sheet('melee-approach-fallback-and-lock.png', 'EMBERWAKE v14 / RANGE FALLBACK + SOLID PILLAR + CHANGED CURSOR', names, 4))

if args.gif:
    assert manifest['raw_frame_count'] == len(manifest['raw_states']) == 90
    timeline = manifest['raw_states']
    assert all(timeline[i]['physics_tick'] - timeline[i - 1]['physics_tick'] == 4 for i in range(1, 90))
    assert all(abs(row['timeline_seconds'] - (i + 1) / 30) < 1e-5 for i, row in enumerate(timeline))
    box = crop_box(timeline)
    frames = []
    for name, row in zip(manifest['raw_frames'], timeline):
        source_path = capture / 'combo' / Path(name).name
        with Image.open(source_path) as source:
            frame = Image.new('RGB', (900, 654), bg)
            frame.paste(source.convert('RGB').crop(box).resize((900, 600), Image.Resampling.NEAREST), (0, 0))
        draw = ImageDraw.Draw(frame)
        draw.text((10, 604), f"NATIVE HELD LMB / {row['timeline_seconds']:.2f}s / STEP {row['stage'] + 1} / {row['phase'].upper()}", font=small, fill=gold)
        draw.text((10, 630), f"ACTUAL TOTAL {row['case_forward_displacement']:.3f} u / HITS {row['hits']} / DAMAGE {row['damage']:.1f} / FIXED TARGET", font=tiny, fill=paper)
        frames.append(frame)
    path = out / 'melee-approach-sword-native.gif'
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=[30 if i % 3 != 2 else 40 for i in range(90)], loop=0, disposal=2, optimize=False)
    outputs.append(path)

summary = {'capture_manifest': str(capture / 'capture-manifest.json'),
           'outputs': [{'file': str(p), 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()} for p in outputs],
           'cases': manifest['cases'], 'cursor_turn': manifest['cursor_turn']}
(out / 'melee-approach-preview-summary.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding='utf-8')
for path in outputs:
    print(path)
