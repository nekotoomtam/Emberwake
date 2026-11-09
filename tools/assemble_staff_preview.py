"""Compose a preview from contiguous actual native frames; never supply game poses."""
import argparse
import json
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--capture', type=Path, default=ROOT / 'docs/review/staff')
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
assert manifest['physics_context']['outside_physics_ticks'] == 0
assert len(manifest['directions']) == 4
assert all(row['shots'] == row['hits'] == row['mouse_presses'] == row['mouse_releases'] == 1
           and row['damage'] == 24 and row['rear_min_health'] == 1000
           for row in manifest['directions'])
assert all(row['error_world_units'] <= .001 and row['element'] == 'fire'
           for row in manifest['muzzles'])
files = sorted((capture / 'shot').glob('shot_*.png'))
assert len(files) == 90
stills = sorted(capture.glob('[0-9][0-9]-*.png'))
assert len(stills) == 17
for path in files + stills:
    with Image.open(path) as source:
        assert source.size == (1280, 800), (path, source.size)
output.mkdir(parents=True, exist_ok=True)
font = ImageFont.truetype('C:/Windows/Fonts/tahoma.ttf', 17)
small_font = ImageFont.truetype('C:/Windows/Fonts/tahoma.ttf', 15)
crop = (390, 140, 1120, 605)

# Use the first 1.4 seconds once, preserving native 30-fps chronology. The GIF's
# natural loop replays the one-click capture; no repeated shots are fabricated.
selected = files[:42]
rgb_frames = []
for index, path in enumerate(selected):
    canvas = Image.new('RGB', (730, 501), (14, 24, 33))
    canvas.paste(Image.open(path).convert('RGB').crop(crop), (0, 36))
    draw = ImageDraw.Draw(canvas)
    draw.text((12, 7), 'FIRE STAFF / ONE CLICK > FIREBALL > FIRST HIT / 24 FIRE',
              font=font, fill=(246, 194, 120))
    rgb_frames.append(canvas)
atlas = Image.new('RGB', (730, 501 * 6))
for index, frame_index in enumerate((0, 2, 4, 8, 14, 20)):
    atlas.paste(rgb_frames[frame_index], (0, index * 501))
palette = atlas.quantize(colors=240)
frames = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in rgb_frames]
durations = [30 if index % 3 != 2 else 40 for index in range(len(frames))]
durations[-1] += 500
gif_path = output / 'staff-preview.gif'
frames[0].save(gif_path, save_all=True, append_images=frames[1:], duration=durations,
               loop=0, disposal=2, optimize=False)

poses = [
    ('03-windup.png', 'Windup / one basic firing animation'),
    ('04-release.png', 'Release / fireball starts at staff tip'),
    ('05-midflight.png', 'Flight / one finite fire projectile'),
    ('06-impact.png', 'First hit / 24 fire, projectile removed'),
    ('07-rear-target-unharmed.png', 'Rear dummy / untouched by first-hit shot'),
    ('09-left-midflight.png', 'Left / actual native flight'),
    ('11-away-midflight.png', 'Away / actual native flight'),
    ('13-toward-midflight.png', 'Toward / actual native flight'),
    ('16-range-last-flight.png', 'Range / six units from muzzle'),
]
sheet = Image.new('RGB', (1350, 1042), (14, 24, 33))
draw = ImageDraw.Draw(sheet)
draw.text((16, 14), 'EMBERWAKE / FIRE STAFF v06 / ACTUAL NATIVE INPUT CAPTURE', font=font,
          fill=(246, 194, 120))
for index, (name, label) in enumerate(poses):
    # Full frame thumbnails retain directional and first-target context.
    image = Image.open(capture / name).convert('RGB').resize((432, 270))
    x, y = 14 + index % 3 * 446, 53 + index // 3 * 326
    sheet.paste(image, (x, y))
    draw.text((x, y + 279), label, font=small_font, fill=(228, 232, 222))
sheet.save(output / 'staff-poses.png')

if args.copy_evidence:
    destination = ROOT / 'docs/review/staff'
    if capture != destination.resolve():
        destination.mkdir(parents=True, exist_ok=True)
        (destination / 'shot').mkdir(exist_ok=True)
        for path in stills:
            shutil.copy2(path, destination / path.name)
        for path in files:
            shutil.copy2(path, destination / 'shot' / path.name)
    manifest['evidence_files'] = [path.name for path in stills] + [f'shot/{p.name}' for p in files]
    manifest['preview_files'] = ['../../staff-preview.gif', '../../staff-poses.png']
    manifest['preview_frame_count'] = 42
    manifest['preview_fps'] = 30
    manifest['preview_raw_indices'] = list(range(42))
    manifest['preview_end_pause_ms'] = 500
    (destination / 'capture-manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')

with Image.open(gif_path) as image:
    print(json.dumps({'raw_frames': len(files), 'native_stills': len(stills),
                      'gif_frames': image.n_frames, 'gif_size': image.size,
                      'gif_duration_ms': sum(image.seek(i) or image.info.get('duration', 0)
                                             for i in range(image.n_frames)),
                      'output': str(output), 'copied_evidence': args.copy_evidence}))
