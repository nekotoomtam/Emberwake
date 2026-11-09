"""Compose the entire contiguous pistol magazine/reload capture with recorded ammo."""
import argparse
import hashlib
import json
import os
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--capture', type=Path, default=ROOT / 'docs/review/pistol')
parser.add_argument('--output-dir', type=Path, default=ROOT / 'docs/review/pistol')
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
assert manifest['physics_context']['outside_physics_ticks'] == 0
magazine = manifest['magazine']
assert magazine['shots'] == magazine['hits'] == 11 and magazine['damage'] == 198
assert magazine['mouse_presses'] == magazine['mouse_releases'] == magazine['reload_count'] == 1
assert magazine['rear_min_health'] == 1000 and magazine['final_rounds'] == 9
assert abs(magazine['measured_reload_turn_radians'] - 6.28318530718) < .001
assert len(manifest['directions']) == 4
assert all(row['shots'] == row['hits'] == row['mouse_presses'] == row['mouse_releases'] == 1
           and row['damage'] == 18 and row['rear_min_health'] == 1000
           for row in manifest['directions'])
assert all(row['error_world_units'] < .001 and row['core_error_world_units'] < .001
           and row['element'] == 'physical' and row['damage'] == 18
           for row in manifest['muzzles'])
assert len(manifest['reload_events']) == 2
assert abs(manifest['reload_events'][1]['duration_world_seconds'] - .5) <= 1 / 120 + .000001
assert all(row['rounds'] == 0 and row['shots'] == 10
           and row['hand_error_world_units'] < .001 and row['rotation_error_radians'] < .001
           for row in manifest['reload_samples'])
files = sorted((capture / 'shot').glob('shot_*.png'))
stills = sorted(capture.glob('[0-9][0-9]-*.png'))
states = manifest['raw_states']
assert len(files) == len(states) == 120 and len(stills) == 24
assert [row['frame_index'] for row in states] == list(range(120))
assert all(states[i]['physics_tick'] - states[i - 1]['physics_tick'] == 4
           for i in range(1, 120))
assert all(abs(row['timeline_seconds'] - (i + 1) / 30) < .00001
           for i, row in enumerate(states))
for path in files + stills:
    with Image.open(path) as source:
        assert source.size == (1280, 800), (path, source.size)
output.mkdir(parents=True, exist_ok=True)
font = ImageFont.truetype('C:/Windows/Fonts/tahoma.ttf', 23)
small_font = ImageFont.truetype('C:/Windows/Fonts/tahoma.ttf', 19)
sheet_font = ImageFont.truetype('C:/Windows/Fonts/tahoma.ttf', 16)
crop = (480, 240, 1040, 480)
size = (1120, 568)
rgb_frames = []
for path, state in zip(files, states):
    canvas = Image.new('RGB', size, (14, 24, 33))
    with Image.open(path) as source:
        canvas.paste(source.convert('RGB').crop(crop).resize((1120, 480), Image.Resampling.NEAREST), (0, 56))
    draw = ImageDraw.Draw(canvas)
    draw.text((14, 6), 'PISTOL / ACTUAL INPUT / 10 SHOTS > 0.5 s SPIN RELOAD > NEXT SHOT',
              font=font, fill=(246, 194, 120))
    ammo = f"{state['rounds']:02d} / {state['capacity']}"
    phase = f"RELOADING {state['reload_progress']:.0%}" if state['reloading'] else state['phase'].upper()
    draw.text((14, 534), f"{state['timeline_seconds']:.2f} s    AMMO {ammo}    {phase}",
              font=small_font, fill=(255, 215, 143) if state['reloading'] else (235, 239, 231))
    draw.text((703, 534), f"SHOTS {state['shots']:02d}   HITS {state['hits']:02d}   DAMAGE {state['damage']:.0f}",
              font=small_font, fill=(235, 239, 231))
    rgb_frames.append(canvas)

# Keep every raw frame once, including the complete 0.5-second reload. The
# natural GIF loop restarts the one held-input trial; no subsection is repeated.
atlas = Image.new('RGB', (size[0], size[1] * 12))
palette_indices = [0, 2, 4, 12, 36, 66, 76, 80, 84, 88, 96, 119]
for index, frame_index in enumerate(palette_indices):
    atlas.paste(rgb_frames[frame_index], (0, index * size[1]))
palette = atlas.quantize(colors=240)
frames = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in rgb_frames]
durations = [30 if index % 3 != 2 else 40 for index in range(120)]
gif_path = output / 'pistol-preview.gif'
frames[0].save(gif_path, save_all=True, append_images=frames[1:], duration=durations,
               loop=0, disposal=2, optimize=False)

poses = [
    ('02-ready.png', 'Ready / physical pistol, full 10-round magazine'),
    ('03-visible-bullet.png', 'Flight / ivory bullet leaves the real muzzle'),
    ('04-first-impact.png', 'First contact / 18 damage, rear untouched'),
    ('05-empty-magazine.png', 'Tenth shot / magazine reaches zero'),
    ('06-reload-start.png', 'Automatic reload / zero rounds, fixed hand'),
    ('07-reload-quarter-spin.png', 'Quarter turn / actual gun sprite'),
    ('08-reload-half-spin.png', 'Half turn / actual gun sprite'),
    ('09-reload-three-quarter-spin.png', 'Three-quarter turn / still zero rounds'),
    ('10-magazine-refill.png', '0.5 s complete / refill to ten rounds'),
    ('12-post-reload-bullet.png', 'Next bullet / magazine now nine rounds'),
    ('16-left-bullet.png', 'Left / one click, one 18-damage hit'),
    ('18-away-bullet.png', 'Away / one click, one 18-damage hit'),
    ('20-toward-bullet.png', 'Toward / one click, one 18-damage hit'),
    ('23-range-last-flight.png', 'Range / finite seven-unit muzzle distance'),
    ('24-range-expired.png', 'Expiry / no damage past the finite range'),
]
sheet = Image.new('RGB', (1350, 1700), (14, 24, 33))
draw = ImageDraw.Draw(sheet)
draw.text((16, 12), 'EMBERWAKE / PISTOL v07 / ACTUAL NATIVE INPUT CAPTURE', font=font,
          fill=(246, 194, 120))
for index, (name, label) in enumerate(poses):
    with Image.open(capture / name) as source:
        image = source.convert('RGB').resize((432, 270))
    x, y = 14 + index % 3 * 446, 52 + index // 3 * 326
    sheet.paste(image, (x, y))
    draw.text((x, y + 278), label, font=sheet_font, fill=(228, 232, 222))
sheet.save(output / 'pistol-poses.png')

# Decode the deliverable again, and retain samples of the encoded GIF itself.
decoded_indices = [0, 3, 16, 35, 70, 77, 81, 85, 89, 94, 99, 119]
decoded_sheet = Image.new('RGB', (1120, 568 * len(decoded_indices)), (14, 24, 33))
with Image.open(gif_path) as image:
    gif_count = image.n_frames
    gif_size = image.size
    gif_duration = 0
    for i in range(image.n_frames):
        image.seek(i)
        gif_duration += image.info.get('duration', 0)
        if i in decoded_indices:
            decoded_sheet.paste(image.convert('RGB'), (0, decoded_indices.index(i) * 568))
assert gif_count == 120 and gif_size == size and gif_duration == 4000
decoded_path = capture / 'pistol-gif-decoded-review.png'
decoded_sheet.save(decoded_path)

manifest['evidence_files'] = [path.name for path in stills] + [f'shot/{p.name}' for p in files]
preview_paths = [gif_path, output / 'pistol-poses.png', decoded_path]
manifest['preview_files'] = [os.path.relpath(path, capture).replace('\\', '/') for path in preview_paths]
manifest['preview_frame_count'] = 120
manifest['preview_fps'] = 30
manifest['preview_raw_indices'] = list(range(120))
manifest['preview_end_pause_ms'] = 0
manifest['preview_crop'] = list(crop)
manifest['preview_recorded_ammo_overlay'] = True
manifest['preview_duration_ms'] = gif_duration
manifest['preview_sha256'] = hashlib.sha256(gif_path.read_bytes()).hexdigest()
if args.copy_evidence:
    destination = ROOT / 'docs/review/pistol'
    destination.mkdir(parents=True, exist_ok=True)
    (destination / 'shot').mkdir(exist_ok=True)
    if capture != destination.resolve():
        for path in stills:
            shutil.copy2(path, destination / path.name)
        for path in files:
            shutil.copy2(path, destination / 'shot' / path.name)
    for path in preview_paths:
        if path.resolve() != (destination / path.name).resolve():
            shutil.copy2(path, destination / path.name)
    manifest['preview_files'] = [os.path.relpath(path, destination).replace('\\', '/') for path in preview_paths[:2]] + [decoded_path.name]
    (destination / 'capture-manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
print(json.dumps({'raw_frames': len(files), 'native_stills': len(stills),
                  'gif_frames': gif_count, 'gif_size': gif_size,
                  'gif_duration_ms': gif_duration, 'output': str(output),
                  'copied_evidence': args.copy_evidence,
                  'max_muzzle_error': max(row['error_world_units'] for row in manifest['muzzles']),
                  'max_core_error': max(row['core_error_world_units'] for row in manifest['muzzles'])}))
