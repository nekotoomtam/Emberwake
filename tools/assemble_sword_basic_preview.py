"""Assemble the uninterrupted native ordinary-sword cycle and recorded evidence."""
import argparse
import hashlib
import json
import os
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--capture', type=Path, default=ROOT / 'docs/review/sword-basic')
parser.add_argument('--output-dir', type=Path, default=ROOT / 'docs')
parser.add_argument('--copy-evidence', action='store_true')
args = parser.parse_args()
capture = args.capture.resolve()
output = args.output_dir.resolve()
manifest = json.loads((capture / 'capture-manifest.json').read_text(encoding='utf-8'))
assert manifest['failures'] == [], manifest['failures']
native = manifest['native_window']
assert native['unfocusable'] and native['native_no_focus_flag']
assert native['actual_position'] == [20000, 20000] and native['checked_every_frame_and_tick']
physics = manifest['physics_context']
assert physics['outside_physics_ticks'] == 0
assert abs(physics['min_physics_delta'] - 1 / 120) < .000001
assert abs(physics['max_physics_delta'] - 1 / 120) < .000001
assert abs(physics['min_physical_weapon_length'] - 1.9) < .0001
assert abs(physics['max_physical_weapon_length'] - 1.9) < .0001
assert physics['max_rendered_tip_error'] < .0001
assert physics['max_active_ground_reach_error'] < .0001
assert manifest['stage_reaches'] == [2.1, 2.2, 2.55]
assert manifest['stage_arcs'] == [1.35, 1.45, 1.55]
assert len(manifest['directions']) == 4
assert [row['aim'] for row in manifest['directions']] == ['right', 'left', 'away', 'toward']
for row in manifest['directions']:
    assert row['stage_sequence'] == [0, 1, 2]
    assert row['damage_steps'] == [18, 19, 34]
    assert row['hits'] == 3 and row['damage'] == 71
    assert row['mouse_presses'] == row['mouse_releases'] == 1
    assert row['outside_arc_min_health'] == 1000 and row['mace_dash_travelled'] == 0
    assert row['final_phase'] == 'idle'
walking = manifest['walking_continuation']
assert walking['stage_sequence'] == [0, 1] and walking['hits'] == 2 and walking['damage'] == 37
assert walking['mouse_presses'] == walking['mouse_releases'] == 2
assert walking['normal_key'] == 'W' and walking['return_key'] == 'S'
assert walking['key_held_physics_ticks'] == walking['return_key_held_physics_ticks'] == 108
assert walking['outbound_simulation_seconds'] > .85 and walking['actual_movement_units'] > .1
assert walking['return_position_error'] < .15
assert walking['outside_arc_min_health'] == 1000 and walking['final_phase'] == 'idle'
dodge = manifest['dodge_reset']
assert dodge['stage_sequence'] == [0, 0] and dodge['hits'] == 2 and dodge['damage'] == 36
assert dodge['mouse_presses'] == dodge['mouse_releases'] == 2
assert dodge['normal_key'] == 'Space' and dodge['input_route'] == 'Viewport.push_input'
assert dodge['space_presses'] == dodge['space_releases'] == 1
assert dodge['stamina_after_press'] < dodge['stamina_before']
assert dodge['dodge_left_after_press'] > 0 and dodge['next_combo_after_press'] == 0
assert dodge['actual_movement_units'] > .1
assert dodge['outside_arc_min_health'] == 1000 and dodge['final_phase'] == 'idle'
assert manifest['contacts'] and all(row['in_physics_frame'] for row in manifest['contacts'])
geometry = manifest['geometry_samples']
assert geometry and all(abs(row['weapon_length'] - 1.9) < .0001
                        and abs(row['ground_tip_reach'] - row['stage_reach']) < .0001
                        and row['rendered_tip_error'] < .0001 for row in geometry)
for aim in ['right', 'left', 'away', 'toward']:
    rows = [row for row in geometry if row['case'] == aim and row['stage'] == 2]
    assert rows and min(row['pitch'] for row in rows) < -.15 and max(row['pitch'] for row in rows) > .25

files = sorted((capture / 'combo').glob('combo_*.png'))
stills = sorted(capture.glob('[0-9][0-9]-*.png'))
states = manifest['raw_states']
snapshots = {row['file']: row for row in manifest['screenshot_states']}
count = manifest['raw_frame_count']
assert len(files) == len(states) == count == 120 and len(stills) == 24
assert snapshots['20-normal-walking-keeps-second.png']['next_combo'] == 1
assert snapshots['21-after-walking-second-cut-active.png']['stage'] == 1
assert snapshots['21-after-walking-second-cut-active.png']['phase'] == 'active'
assert snapshots['23-space-dodge-resets-first.png']['next_combo'] == 0
assert snapshots['23-space-dodge-resets-first.png']['dodge_left'] > 0
assert snapshots['23-space-dodge-resets-first.png']['stamina'] < dodge['stamina_before']
assert snapshots['24-after-dodge-first-cut-active.png']['stage'] == 0
assert snapshots['24-after-dodge-first-cut-active.png']['phase'] == 'active'
assert [row['frame_index'] for row in states] == list(range(count))
assert all(states[i]['physics_tick'] - states[i - 1]['physics_tick'] == 4 for i in range(1, count))
assert all(abs(row['timeline_seconds'] - (i + 1) / 30) < .00001 for i, row in enumerate(states))
assert states[-1]['hits'] == 3 and states[-1]['damage'] == 71 and states[-1]['phase'] == 'idle'
for stage in range(3):
    for phase in ['windup', 'active', 'recovery']:
        assert any(row.get('case') == 'right' and row.get('stage') == stage
                   and row.get('phase') == phase for row in snapshots.values())
for path in files + stills:
    with Image.open(path) as image:
        assert image.size == (1280, 800), (path, image.size)

output.mkdir(parents=True, exist_ok=True)
font_path = 'C:/Windows/Fonts/tahoma.ttf'
font = ImageFont.truetype(font_path, 22)
small = ImageFont.truetype(font_path, 18)
tiny = ImageFont.truetype(font_path, 15)
background = (14, 24, 33)
cream = (235, 239, 231)
gold = (246, 194, 120)


def crop_for(rows):
    points = [point for row in rows for point in row['screen_points']]
    min_x, max_x = min(p[0] for p in points), max(p[0] for p in points)
    min_y, max_y = min(p[1] for p in points), max(p[1] for p in points)
    center_x = (min_x + max_x) / 2
    center_y = (min_y + max_y) / 2 - 25
    left = min(max(round(center_x - 260), 0), 1280 - 520)
    top = min(max(round(center_y - 150), 110), 800 - 300)
    return (left, top, left + 520, top + 300)


crop = crop_for(states)
size = (1040, 718)
rgb_frames = []
for path, state in zip(files, states):
    canvas = Image.new('RGB', size, background)
    with Image.open(path) as source:
        canvas.paste(source.convert('RGB').crop(crop).resize((1040, 600), Image.Resampling.NEAREST), (0, 42))
    draw = ImageDraw.Draw(canvas)
    draw.text((14, 6), 'EMBERWAKE v22 / SWORD / RIGHT-LEFT-DIAGONAL / ACTUAL INPUT', font=font, fill=gold)
    stage = str(state['stage'] + 1) if state['stage'] >= 0 else '-'
    draw.text((14, 650), f"{state['timeline_seconds']:.2f} s    CUT {stage} / 3    {state['phase'].upper()}"
              f"    HITS {state['hits']}    DAMAGE {state['damage']:.0f}", font=small, fill=cream)
    draw.text((14, 681), f"RIGID BLADE {state['weapon_length']:.2f}    TIP GROUND REACH {state['ground_tip_reach']:.2f}"
              f"    PITCH {state['pitch']:+.2f}    TRACES {state['trails_active']}", font=small, fill=cream)
    rgb_frames.append(canvas)

# Include each captured frame exactly once. GIF centiseconds represent 30 fps
# with a repeating 30/30/40 ms cadence, without any synthetic end pause.
palette_indices = list(range(0, count, 10)) + [count - 1]
atlas = Image.new('RGB', (size[0], size[1] * len(palette_indices)))
for index, frame_index in enumerate(palette_indices):
    atlas.paste(rgb_frames[frame_index], (0, index * size[1]))
palette = atlas.quantize(colors=240)
frames = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in rgb_frames]
durations = [30 if index % 3 != 2 else 40 for index in range(count)]
gif_path = output / 'sword-basic-preview.gif'
frames[0].save(gif_path, save_all=True, append_images=frames[1:], duration=durations,
               loop=0, disposal=2, optimize=False)

pose_names = [f'{3 + stage * 3 + phase_index:02d}-stage{stage + 1}-{phase}.png'
              for stage in range(3) for phase_index, phase in enumerate(['windup', 'active', 'recovery'])]
late_active_index = max(i for i, row in enumerate(states) if row['stage'] == 2 and row['phase'] == 'active')
late_active_name = f'combo/{files[late_active_index].name}'
snapshots[late_active_name] = states[late_active_index]
pose_names.insert(8, late_active_name)
pose_names += ['12-combo-complete.png', '14-left-diagonal-active.png',
               '16-away-diagonal-active.png', '18-toward-diagonal-active.png',
               '19-before-movement-next-is-second.png', '20-normal-walking-keeps-second.png',
               '21-after-walking-second-cut-active.png', '22-before-dodge-next-is-second.png',
               '23-space-dodge-resets-first.png', '24-after-dodge-first-cut-active.png']
tile_width, tile_height = 540, 372
sheet = Image.new('RGB', (1080, 48 + ((len(pose_names) + 1) // 2) * tile_height), background)
draw = ImageDraw.Draw(sheet)
draw.text((14, 9), 'EMBERWAKE v22 / WALKING COMBO + DODGE / NATIVE EVIDENCE', font=font, fill=gold)
for index, name in enumerate(pose_names):
    state = snapshots[name]
    x, y = (index % 2) * tile_width + 10, 48 + (index // 2) * tile_height
    with Image.open(capture / name) as source:
        pic = source.convert('RGB').crop(crop_for([state]))
    sheet.paste(pic, (x, y))
    if name == late_active_name:
        label = f"Third cut / late diagonal / recorded frame {late_active_index}"
    elif name.startswith('19-'):
        label = 'Single click complete / next cut 2 before movement'
    elif name.startswith('20-'):
        label = 'Normal W walk > 0.85 s / next cut stays 2'
    elif name.startswith('21-'):
        label = 'After W + S walk / second cut active'
    elif name.startswith('22-'):
        label = 'Single click complete / next cut 2 before dodge'
    elif name.startswith('23-'):
        label = 'Viewport Space dodge / next cut reset to 1'
    elif name.startswith('24-'):
        label = 'After accepted dodge / first cut active again'
    elif name.startswith('12-'):
        label = 'Cycle complete / 3 hits / 18 + 19 + 34 = 71'
    else:
        label = f"{state['case'].title()} / cut {state['stage'] + 1} / {state['phase']}"
    draw.text((x, y + 306), label, font=small, fill=gold)
    draw.text((x, y + 333), f"Length {state['weapon_length']:.2f}   ground tip {state['ground_tip_reach']:.2f}"
              f"   pitch {state['pitch']:+.2f}   hits {state['hits']} / {state['damage']:.0f}", font=tiny, fill=cream)
sheet_path = output / 'sword-basic-poses.png'
sheet.save(sheet_path)

# Inspect a decoded delivered GIF, including the actual active frame of each cut.
decoded_indices = sorted(set([0, 7, 8, count - 1, late_active_index] + [
    next(i for i, state in enumerate(states) if state['stage'] == stage
         and state['phase'] == phase and state['progress'] >= (.5 if phase == 'active' else .4))
    for stage in range(3) for phase in ['windup', 'active', 'recovery']]))
decoded_sheet = Image.new('RGB', (size[0], size[1] * len(decoded_indices)), background)
with Image.open(gif_path) as image:
    gif_count, gif_size = image.n_frames, image.size
    gif_duration = 0
    for index in range(gif_count):
        image.seek(index)
        gif_duration += image.info.get('duration', 0)
        if index in decoded_indices:
            decoded_sheet.paste(image.convert('RGB'), (0, decoded_indices.index(index) * size[1]))
assert gif_count == count and gif_size == size and gif_duration == 4000
decoded_path = capture / 'sword-basic-gif-decoded-review.png'
decoded_sheet.save(decoded_path)
manifest['evidence_files'] = [path.name for path in stills] + [f'combo/{path.name}' for path in files]
manifest['screenshots'] = [path.name for path in stills]
manifest['raw_frames'] = [f'combo/{path.name}' for path in files]
manifest['preview_files'] = [os.path.relpath(path, capture).replace('\\', '/')
                             for path in [gif_path, sheet_path, decoded_path]]
manifest['preview_frame_count'] = count
manifest['preview_fps'] = 30
manifest['preview_raw_indices'] = list(range(count))
manifest['preview_end_pause_ms'] = 0
manifest['preview_crop'] = list(crop)
manifest['preview_recorded_state_overlay'] = True
manifest['preview_duration_ms'] = gif_duration
manifest['preview_sha256'] = hashlib.sha256(gif_path.read_bytes()).hexdigest()
manifest['decoded_review_raw_indices'] = decoded_indices
(capture / 'capture-manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
if args.copy_evidence:
    destination = ROOT / 'docs/review/sword-basic'
    destination.mkdir(parents=True, exist_ok=True)
    (destination / 'combo').mkdir(exist_ok=True)
    if capture != destination.resolve():
        for path in stills:
            shutil.copy2(path, destination / path.name)
        for path in files:
            shutil.copy2(path, destination / 'combo' / path.name)
        shutil.copy2(decoded_path, destination / decoded_path.name)
    manifest['preview_files'] = [os.path.relpath(path, destination).replace('\\', '/')
                                 for path in [gif_path, sheet_path]] + [decoded_path.name]
    (destination / 'capture-manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
print(json.dumps({'native_stills': len(stills), 'raw_frames': count, 'gif_frames': gif_count,
                  'gif_size': gif_size, 'gif_duration_ms': gif_duration, 'output': str(output),
                  'copied_evidence': args.copy_evidence, 'max_rendered_tip_error': physics['max_rendered_tip_error'],
                  'max_active_ground_reach_error': physics['max_active_ground_reach_error']}))
