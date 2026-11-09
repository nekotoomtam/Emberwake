"""Assemble inspectable native attack-step stills without changing captured pixels."""
import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--capture', required=True, type=Path)
parser.add_argument('--output-dir', required=True, type=Path)
parser.add_argument('--gif', action='store_true', help='Use all 90 contiguous frames if captured.')
args = parser.parse_args()
capture = args.capture.resolve()
out = args.output_dir.resolve()
manifest = json.loads((capture / 'capture-manifest.json').read_text(encoding='utf-8'))
assert manifest['failures'] == [], manifest['failures']
assert manifest['physics_context']['outside_physics_ticks'] == 0
safe = manifest['native_window']
assert safe['unfocusable'] and safe['native_no_focus_flag'] and safe['checked_every_frame_and_tick']
assert safe['actual_position'] == [20000, 20000]
assert abs(manifest['physics_context']['min_physics_delta'] - 1 / 120) < 1e-6
assert abs(manifest['physics_context']['max_physics_delta'] - 1 / 120) < 1e-6
states = {row['file']: row for row in manifest['screenshot_states']}
cases = {row['case']: row for row in manifest['cases']}
assert len(cases) == 8 and len(manifest['strokes']) == 20
cursor = manifest['cursor_turn']
assert cursor['actual_input_received'] and cursor['cursor_intent_changed']
assert cursor['actual_game_aim_locked_midstroke']
assert cursor['maximum_game_aim_error_while_busy'] < .0001
assert cursor['maximum_motion_aim_error_while_busy'] < .0001
assert abs(cursor['actual_forward_displacement'] - .18) < .003
assert cursor['actual_perpendicular_displacement'] < .003
for family, caps in manifest['expected_distances'].items():
    for suffix in ['open-combo', 'target-stop']:
        row = cases[f'{family}-{suffix}']
        assert row['stage_sequence'] == [0, 1, 2]
        assert row['mouse_presses'] == row['mouse_releases'] == 1
        assert row['stamina'] == 100 and row['dodge_left'] == row['space_presses'] == 0
    actual = [s['actual_positive_projection'] for s in manifest['strokes']
              if s['case'] == f'{family}-open-combo']
    assert all(abs(a - b) < .003 for a, b in zip(actual, caps)), (family, actual)
for name in states:
    with Image.open(capture / name) as source:
        assert source.size == (1280, 800), (name, source.size)

out.mkdir(parents=True, exist_ok=True)
font_file = 'C:/Windows/Fonts/tahoma.ttf'
font = ImageFont.truetype(font_file, 21)
small = ImageFont.truetype(font_file, 17)
tiny = ImageFont.truetype(font_file, 14)
bg, paper, gold = '#0d1922', '#e7efe9', '#ffd06a'


def crop_box(rows):
    points = [row[key] for row in rows for key in ['screen_player_ground', 'screen_case_origin']]
    center_x = (min(p[0] for p in points) + max(p[0] for p in points)) / 2
    center_y = (min(p[1] for p in points) + max(p[1] for p in points)) / 2 - 52
    left = max(0, min(1280 - 500, round(center_x - 250)))
    top = max(210, min(800 - 355, round(center_y - 177)))
    return left, top, left + 500, top + 355


def sheet(filename, title, names, columns):
    width, height = 420, 378
    canvas = Image.new('RGB', (width * columns, 58 + height * ((len(names) + columns - 1) // columns)), bg)
    draw = ImageDraw.Draw(canvas)
    draw.text((14, 8), title, font=font, fill=gold)
    draw.text((14, 34), 'Actual native viewport crops; cyan origin and gold authored endpoint are visual fixture markers.', font=tiny, fill=paper)
    for index, name in enumerate(names):
        row = states[name]
        related = [s for s in states.values() if s['case'] == row['case']]
        with Image.open(capture / name) as source:
            tile = source.convert('RGB').crop(crop_box(related)).resize((420, 298), Image.Resampling.NEAREST)
        x, y = index % columns * width, 58 + index // columns * height
        canvas.paste(tile, (x, y))
        draw.text((x + 9, y + 303), row['case'].replace('-', ' ').upper(), font=tiny, fill=gold)
        stage = row['stage'] + 1
        travel = row['mace_dash_travelled'] if row['family'] == 'mace' and row['stage'] == 1 else row['attack_step_travelled']
        cap = manifest['expected_distances'][row['family']][row['stage']] if row['stage'] >= 0 else 0
        draw.text((x + 9, y + 325), f"STEP {stage} / {row['phase'].upper()}   {travel:.3f} / {cap:.3f} u", font=small, fill=paper)
        draw.text((x + 9, y + 349), f"TOTAL {row['case_forward_displacement']:.3f} u   HITS {row['hits']}   STAMINA {row['stamina']:.0f}", font=tiny, fill=paper)
    path = out / filename
    canvas.save(path)
    return path


open_names = [f'{family}-open-combo-{phase}.png'
              for family in ['sword', 'greatsword', 'mace']
              for phase in ['00-origin', '01-step-complete', '02-step-complete', '03-step-complete']]
outputs = [sheet('attack-step-open-combos.png', 'EMBERWAKE v13 / THREE NATIVE COMBOS / ACTUAL CAPPED TRAVEL', open_names, 4)]
collision_names = [f'{family}-target-stop-{phase}.png'
                   for family in ['sword', 'greatsword', 'mace']
                   for phase in ['00-origin', '03-step-complete']]
collision_names += ['greatsword-solid-pillar-00-origin.png', 'greatsword-solid-pillar-01-stopped.png']
outputs.append(sheet('attack-step-collision-stops.png', 'EMBERWAKE v13 / REAL TARGET HITS + ORIGINAL SOLID PILLAR', collision_names, 2))

if args.gif:
    assert manifest['raw_frame_count'] == len(manifest['raw_states']) == 90
    timeline = manifest['raw_states']
    assert all(timeline[i]['physics_tick'] - timeline[i - 1]['physics_tick'] == 4 for i in range(1, 90))
    assert all(abs(s['timeline_seconds'] - (i + 1) / 30) < 1e-5 for i, s in enumerate(timeline))
    box = crop_box(timeline)
    frames = []
    for name, row in zip(manifest['raw_frames'], timeline):
        source_path = capture / 'combo' / Path(name).name
        with Image.open(source_path) as source:
            frame = Image.new('RGB', (800, 624), bg)
            frame.paste(source.convert('RGB').crop(box).resize((800, 568), Image.Resampling.NEAREST), (0, 0))
        draw = ImageDraw.Draw(frame)
        draw.text((10, 574), f"NATIVE LMB / {row['timeline_seconds']:.2f}s / STEP {row['stage'] + 1} / {row['phase'].upper()}", font=small, fill=gold)
        draw.text((10, 599), f"ACTUAL TOTAL {row['case_forward_displacement']:.3f} u / STAMINA {row['stamina']:.0f} / DODGE {row['dodge_left']:.3f}", font=tiny, fill=paper)
        frames.append(frame)
    path = out / 'attack-step-sword-native.gif'
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=[30 if i % 3 != 2 else 40 for i in range(90)], loop=0, disposal=2, optimize=False)
    outputs.append(path)

summary = {'capture_manifest': str(capture / 'capture-manifest.json'),
           'outputs': [{'file': str(p), 'sha256': hashlib.sha256(p.read_bytes()).hexdigest()} for p in outputs],
           'cases': manifest['cases'], 'cursor_turn': manifest['cursor_turn']}
(out / 'attack-step-preview-summary.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding='utf-8')
for path in outputs:
    print(path)
