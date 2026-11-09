"""Compose a complete native six-shot rifle trial and inspectable evidence sheet."""
import argparse
import hashlib
import json
import os
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--capture', type=Path, default=ROOT / 'docs/review/rifle')
parser.add_argument('--output-dir', type=Path, default=ROOT / 'docs')
parser.add_argument('--copy-evidence', action='store_true')
args = parser.parse_args()
capture = args.capture.resolve()
output = args.output_dir.resolve()
manifest = json.loads((capture / 'capture-manifest.json').read_text(encoding='utf-8'))
assert manifest['failures'] == [], manifest['failures']
assert manifest['native_window']['unfocusable']
assert manifest['native_window']['native_no_focus_flag']
assert manifest['native_window']['actual_position'] == [20000, 20000]
assert manifest['native_window']['checked_every_frame_and_tick']
physics = manifest['physics_context']
assert physics['outside_physics_ticks'] == 0
assert abs(physics['min_physics_delta'] - 1 / 120) < .000001
assert abs(physics['max_physics_delta'] - 1 / 120) < .000001
assert abs(physics['min_physical_weapon_length'] - 1.35) < .0001
assert abs(physics['max_physical_weapon_length'] - 1.35) < .0001
magazine = manifest['magazine']
assert magazine['shots'] == 6 and magazine['hits'] == 12 and magazine['damage'] == 594
assert magazine['mouse_presses'] == magazine['mouse_releases'] == magazine['reload_count'] == 1
assert magazine['far_min_health'] == 1000 and magazine['final_rounds'] == 4
assert magazine['casings_spawned'] == 6
assert abs(magazine['actual_backward_travel'] - 1.32) < .003
assert magazine['max_reload_screen_roll'] == 0
assert abs(magazine['reload_pitch_range'][1] - .30) < .001
assert len(manifest['directions']) == 4
assert all(row['shots'] == row['hits'] == row['mouse_presses'] == row['mouse_releases'] == row['casings_spawned'] == 1
           and row['damage'] == 49.5 and abs(row['actual_backward_travel'] - .22) < .003
           for row in manifest['directions'])
assert all(row['error_world_units'] < .001 and row['core_error_world_units'] < .001
           and row['element'] == 'physical' and row['damage'] == 49.5 and row['original_range'] == 9
           for row in manifest['muzzles'])
assert len(manifest['reload_events']) == 2
assert abs(manifest['reload_events'][1]['duration_world_seconds'] - 1.2) <= 1 / 120 + .000001
assert all(row['rounds'] == 0 and row['shots'] == 5 and row['screen_roll'] == 0
           and row['in_physics_frame'] for row in manifest['reload_samples'])
assert manifest['cutoff_samples'] and all(row['fixed_world_cutoff_error'] < .001
                                        and row['original_range'] == 9
                                        for row in manifest['cutoff_samples'])
assert any(row['hit_count'] == 2 for row in manifest['cutoff_samples'])
assert all(abs(row['cutoff_position'][0] - 5.01) < .001
           and abs(row['first_exit_position'][0] - 4.46) < .001
           and len(row['hitids']) == 2 for row in magazine['resolved'])
assert manifest['casing_samples'] and manifest['casing_max_active'] == 32 and manifest['casing_lifetime'] == 2
files = sorted((capture / 'shot').glob('shot_*.png'))
stills = sorted(capture.glob('[0-9][0-9]-*.png'))
states = manifest['raw_states']
count = manifest['raw_frame_count']
assert len(files) == len(states) == count == 180 and len(stills) == 24
assert [row['frame_index'] for row in states] == list(range(count))
assert all(states[i]['physics_tick'] - states[i - 1]['physics_tick'] == 4
           for i in range(1, count))
assert all(abs(row['timeline_seconds'] - (i + 1) / 30) < .00001
           for i, row in enumerate(states))
assert any(row['rounds'] == 0 and row['reloading'] for row in states)
assert states[-1]['rounds'] == 4 and states[-1]['shots'] == 6 and states[-1]['phase'] == 'idle'
for path in files + stills:
    with Image.open(path) as source:
        assert source.size == (1280, 800), (path, source.size)
output.mkdir(parents=True, exist_ok=True)
font = ImageFont.truetype('C:/Windows/Fonts/tahoma.ttf', 23)
small_font = ImageFont.truetype('C:/Windows/Fonts/tahoma.ttf', 19)
sheet_font = ImageFont.truetype('C:/Windows/Fonts/tahoma.ttf', 17)
tiny_font = ImageFont.truetype('C:/Windows/Fonts/tahoma.ttf', 15)
crop = (480, 250, 1150, 470)
size = (1340, 564)
rgb_frames = []
for path, state in zip(files, states):
    canvas = Image.new('RGB', size, (14, 24, 33))
    with Image.open(path) as source:
        canvas.paste(source.convert('RGB').crop(crop).resize((1340, 440), Image.Resampling.NEAREST), (0, 52))
    draw = ImageDraw.Draw(canvas)
    draw.text((14, 7), 'RIFLE / ACTUAL INPUT / FIVE ROUNDS > 1.2 s RELOAD > SIXTH SHOT',
              font=font, fill=(246, 194, 120))
    phase = f"RELOADING {state['reload_progress']:.0%}" if state['reloading'] else state['phase'].upper()
    draw.text((14, 497), f"{state['timeline_seconds']:.2f} s    AMMO {state['rounds']} / {state['capacity']}    {phase}"
              f"    SHOTS {state['shots']}    HITS {state['hits']}    DAMAGE {state['damage']:.0f}",
              font=small_font, fill=(255, 215, 143) if state['reloading'] else (235, 239, 231))
    draw.text((14, 530), f"ACTUAL BACKWARD TRAVEL {state['actual_backward_travel']:.2f}    "
              f"CASES {state['casings_spawned']} SPAWNED / {state['casings_active']} ACTIVE    "
              f"FAR DUMMY MIN HP {state['far_min_health']:.0f}",
              font=small_font, fill=(235, 239, 231))
    rgb_frames.append(canvas)

# Every raw frame appears once, in order. Only the complete six-second trial loops.
palette_indices = [0, 3, 7, 16, 35, 55, 75, 93, 108, 126, 132, 179]
atlas = Image.new('RGB', (size[0], size[1] * len(palette_indices)))
for index, frame_index in enumerate(palette_indices):
    atlas.paste(rgb_frames[frame_index], (0, index * size[1]))
palette = atlas.quantize(colors=240)
frames = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in rgb_frames]
durations = [30 if index % 3 != 2 else 40 for index in range(count)]
gif_path = output / 'rifle-preview.gif'
frames[0].save(gif_path, save_all=True, append_images=frames[1:], duration=durations,
               loop=0, disposal=2, optimize=False)

poses = [
    ('02-ready-five-rounds.png', 'Ready / rigid 1.35-unit physical rifle / five rounds', crop),
    ('03-first-fire.png', 'Release / actual muzzle, one brass casing spawned', crop),
    ('04-visible-native-bullet.png', 'Flight / separate short ivory streak, original range nine', crop),
    ('05-first-target-pierced.png', 'First hit / cutoff locks to first exit + 0.55', crop),
    ('06-near-target-hit-99-total.png', 'Near hit / 49.5 each, 99 total for this shot', crop),
    ('07-fixed-cutoff-far-unharmed.png', 'Short penetration ends / separated far target untouched', crop),
    ('08-visible-ejected-brass.png', 'Ejection / actual brass sprite, native crop enlarged', None),
    ('09-first-actual-backward-step.png', 'Recoil / actual player movement of 0.22 per shot', crop),
    ('10-empty-five-cases-spawned.png', 'Fifth shot / zero ammunition, five cases spawned', crop),
    ('11-long-reload-start.png', 'Automatic reload / zero ammunition', crop),
    ('12-long-reload-mid-tilt.png', 'Mid reload / lower and tilt, no spin', crop),
    ('14-magazine-refill-five-rounds.png', '1.2 s complete / five rounds refilled', crop),
    ('15-sixth-shot-four-rounds.png', 'Sixth shot / four rounds, sixth brass casing', crop),
    ('16-post-reload-idle.png', 'Idle / 12 hits, 594 damage, 1.32 backward travel', crop),
    ('19-left-bullet.png', 'Left / one click, one 49.5 hit, one case, 0.22 step', (300, 130, 970, 530)),
    ('21-away-bullet.png', 'Away / one click, one 49.5 hit, one case, 0.22 step', (300, 130, 970, 530)),
    ('23-toward-bullet.png', 'Toward / one click, one 49.5 hit, one case, 0.22 step', (300, 180, 970, 580)),
    ('17-right-bullet.png', 'Right / one click, one 49.5 hit, one case, 0.22 step', (480, 130, 1150, 530)),
]
sheet = Image.new('RGB', (1380, 56 + 7 * 266 + 2 * 446), (14, 24, 33))
draw = ImageDraw.Draw(sheet)
draw.text((16, 12), 'EMBERWAKE / RIFLE v09 / SHORT LINE BULLETS / ACTUAL INPUT', font=font,
          fill=(246, 194, 120))
for index, (name, label, pose_crop) in enumerate(poses):
    with Image.open(capture / name) as source:
        if pose_crop is None:
            # The close-up contains only actual viewport pixels around the real casing.
            x, y = manifest['casing_samples'][0]['screen_position']
            detail_crop = (round(x) - 84, round(y) - 28, round(x) + 84, round(y) + 27)
            pic = source.convert('RGB').crop(detail_crop).resize((670, 220), Image.Resampling.NEAREST)
        else:
            pic = source.convert('RGB').crop(pose_crop)
    row = index // 2
    x = 14 + index % 2 * 684
    y = 52 + min(row, 7) * 266 + max(row - 7, 0) * 446
    sheet.paste(pic, (x, y))
    draw.text((x, y + pic.height + 7), label, font=sheet_font, fill=(228, 232, 222))
sheet_path = output / 'rifle-poses.png'
sheet.save(sheet_path)

# Decode the delivered GIF, rather than reviewing pre-encoding source canvases only.
decoded_indices = [0, 3, 8, 18, 55, 75, 90, 105, 120, 126, 132, 179]
decoded_sheet = Image.new('RGB', (size[0], size[1] * len(decoded_indices)), (14, 24, 33))
with Image.open(gif_path) as image:
    gif_count = image.n_frames
    gif_size = image.size
    gif_duration = 0
    for i in range(image.n_frames):
        image.seek(i)
        gif_duration += image.info.get('duration', 0)
        if i in decoded_indices:
            decoded_sheet.paste(image.convert('RGB'), (0, decoded_indices.index(i) * size[1]))
assert gif_count == count and gif_size == size and gif_duration == 6000
decoded_path = capture / 'rifle-gif-decoded-review.png'
decoded_sheet.save(decoded_path)
manifest['evidence_files'] = [path.name for path in stills] + [f'shot/{p.name}' for p in files]
manifest['screenshots'] = [path.name for path in stills]
manifest['raw_frames'] = [f'shot/{p.name}' for p in files]
preview_paths = [gif_path, sheet_path, decoded_path]
manifest['preview_files'] = [os.path.relpath(path, capture).replace('\\', '/') for path in preview_paths]
manifest['preview_frame_count'] = count
manifest['preview_fps'] = 30
manifest['preview_raw_indices'] = list(range(count))
manifest['preview_end_pause_ms'] = 0
manifest['preview_crop'] = list(crop)
manifest['preview_recorded_state_overlay'] = True
manifest['preview_duration_ms'] = gif_duration
manifest['preview_sha256'] = hashlib.sha256(gif_path.read_bytes()).hexdigest()
(capture / 'capture-manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
if args.copy_evidence:
    destination = ROOT / 'docs/review/rifle'
    destination.mkdir(parents=True, exist_ok=True)
    (destination / 'shot').mkdir(exist_ok=True)
    if capture != destination.resolve():
        for path in stills:
            shutil.copy2(path, destination / path.name)
        for path in files:
            shutil.copy2(path, destination / 'shot' / path.name)
        shutil.copy2(decoded_path, destination / decoded_path.name)
    manifest['preview_files'] = [os.path.relpath(path, destination).replace('\\', '/') for path in preview_paths[:2]] + [decoded_path.name]
    (destination / 'capture-manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
print(json.dumps({'raw_frames': len(files), 'native_stills': len(stills),
                  'gif_frames': gif_count, 'gif_size': gif_size,
                  'gif_duration_ms': gif_duration, 'output': str(output),
                  'copied_evidence': args.copy_evidence,
                  'max_muzzle_error': max(row['error_world_units'] for row in manifest['muzzles']),
                  'max_core_error': max(row['core_error_world_units'] for row in manifest['muzzles'])}))
