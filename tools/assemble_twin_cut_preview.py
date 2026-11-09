"""Validate actual-input Twin Cut evidence and assemble native viewport previews."""
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
capture, output = args.capture.resolve(), args.output_dir.resolve()
manifest = json.loads((capture / 'capture-manifest.json').read_text(encoding='utf-8-sig'))
assert not manifest['failures'], manifest['failures']
assert manifest['renderer'] != 'headless'
window, physics = manifest['native_window'], manifest['physics_context']
assert window['unfocusable'] and window['native_no_focus_flag'] and window['checked_every_frame_and_tick']
assert window['actual_position'] == [20000, 20000]
assert physics['outside_physics_ticks'] == 0 and physics['physics_ticks_per_second'] == 120
assert abs(physics['min_physics_delta'] - 1 / 120) < 1e-6
assert abs(physics['max_physics_delta'] - 1 / 120) < 1e-6
assert manifest['authored_cut_seconds'] == [.15, .20]
assert manifest['authored_total_seconds'] == .35
cases = {row['case']: row for row in manifest['cases']}
states = {row['file']: row for row in manifest['screenshot_states']}
assert len(cases) == 12 and len(states) == 14
sequence = cases['q-automatic-two-cuts-and-reuse']
assert sequence['keys'] == ['Q', 'Q'] and sequence['mouse_presses'] == 0
assert sequence['hits'] == 4 and sequence['damage'] == sequence['target_damage'] == 74
assert not sequence['skill_active'] and sequence['reuse_press_tick'] == sequence['first_completion_tick']
assert states['q-01-first-hit.png']['hits'] == 1 and states['q-01-first-hit.png']['damage'] == 18
assert states['q-02-second-hit.png']['hits'] == 2 and states['q-02-second-hit.png']['damage'] == 37
for name, hits, damage in [('q-dodge-first-windup', 0, 0), ('q-dodge-after-first-hit', 1, 18)]:
    row = cases[name]
    assert row['keys'] == ['Q', 'Space']
    assert row['hits'] == hits and row['damage'] == row['target_damage'] == damage
    assert not row['skill_active'] and not row['motion_busy']
    assert row['before_dodge']['skill_active'] and row['before_dodge']['hits'] == hits
    still = states[f'{name}.png']
    assert still['dodge_left'] > 0 and not still['skill_active'] and not still['motion_busy']
for family in ['sword', 'greatsword', 'mace', 'staff', 'pistol', 'rifle']:
    name = f'{family}-basic-windup-dodge'
    row = cases[name]
    assert row['keys'] == ['Space'] and row['mouse_presses'] == row['mouse_releases'] == 1
    assert row['before_dodge']['phase'] == 'windup' and row['before_dodge']['motion_busy']
    assert row['hits'] == row['damage'] == row['shots'] == 0 and not row['motion_busy']
    assert states[f'{name}.png']['dodge_left'] > 0 and not states[f'{name}.png']['motion_busy']
    if family in ['pistol', 'rifle']:
        assert row['rounds'] == row['capacity']
for family in ['pistol', 'rifle']:
    name = f'{family}-reload-dodge'
    row = cases[name]
    assert row['keys'] == ['R', 'Space'] and row['mouse_presses'] == row['mouse_releases'] == 1
    assert row['before_dodge']['reloading']
    assert row['shots'] == 1 and row['rounds'] == row['capacity'] - 1 and not row['reloading']
    assert row['rounds'] == row['before_dodge']['rounds']
    assert states[f'{name}.png']['dodge_left'] > 0 and not states[f'{name}.png']['reloading']
fireball = cases['released-fireball-survives-dodge']
assert fireball['keys'] == ['Space'] and fireball['mouse_presses'] == fireball['mouse_releases'] == 1
assert len(fireball['before_dodge']['flights']) == 1 and fireball['before_dodge']['hits'] == 0
assert fireball['hits'] == 1 and fireball['damage'] == fireball['target_damage'] == 72 and fireball['shots'] == 1
assert len(states['released-fireball-survives-dodge.png']['flights']) == 1
assert states['released-fireball-survives-dodge.png']['dodge_left'] > 0
for row in states.values():
    with Image.open(capture / row['file']) as image:
        assert image.size == (1280, 800)
    target_distance = 4 if row['case'] == 'released-fireball-survives-dodge' else 1.7
    assert all(abs(actual - expected) < 1e-5 for actual, expected in zip(row['target_position'], [target_distance, .03, 0]))
    for key in ['screen_player_ground', 'screen_player_top', 'screen_target_ground', 'screen_target_top']:
        x, y = row[key]
        assert 0 <= x < 1280 and 190 <= y < 690, (row['file'], key, (x, y))

output.mkdir(parents=True, exist_ok=True)
font_file = 'C:/Windows/Fonts/tahoma.ttf'
font = ImageFont.truetype(font_file, 20)
small = ImageFont.truetype(font_file, 15)
tiny = ImageFont.truetype(font_file, 12)
bg, paper, gold = '#0d1922', '#e7efe9', '#ffd06a'


def sheet(filename, title, names, columns=2):
    width, height = 640, 458
    canvas = Image.new('RGB', (columns * width, 62 + ((len(names) + columns - 1) // columns) * height), bg)
    draw = ImageDraw.Draw(canvas)
    draw.text((12, 8), title, font=font, fill=gold)
    draw.text((12, 35), 'Complete native viewport / actual Q, Space, LMB and R / fixed original practice dummy', font=small, fill=paper)
    for index, name in enumerate(names):
        row = states[name]
        x, y = (index % columns) * width, 62 + (index // columns) * height
        with Image.open(capture / name) as source:
            canvas.paste(source.convert('RGB').resize((640, 400), Image.Resampling.NEAREST), (x, y))
        draw.text((x + 8, y + 403), name.removesuffix('.png').replace('-', ' ').upper(), font=small, fill=gold)
        draw.text((x + 8, y + 424), f"HITS {row['hits']} / DAMAGE {row['damage']:.0f} / {row['phase'].upper()} / DODGE {row['dodge_left']:.3f}s", font=small, fill=paper)
        draw.text((x + 8, y + 445), f"AMMO {row['rounds']}/{row['capacity']} / RELOAD {row['reloading']} / LIVE PROJECTILES {len(row['flights'])}", font=tiny, fill=paper)
    path = output / filename
    canvas.save(path)
    return path


outputs = [sheet('twin-cut-native.png', 'EMBERWAKE v23 / ONE Q, TWO ARCHIVED CUTS / IMMEDIATE REUSE / DODGE INTERRUPTS',
    ['q-01-first-hit.png', 'q-02-second-hit.png', 'q-03-immediate-reuse-finished.png',
     'q-dodge-first-windup.png', 'q-dodge-after-first-hit.png'])]
outputs.append(sheet('priority-dodge-six-weapons.png', 'EMBERWAKE v23 / SPACE CANCELS THE WINDUP OF ALL SIX WEAPONS',
    [f'{family}-basic-windup-dodge.png' for family in ['sword', 'greatsword', 'mace', 'staff', 'pistol', 'rifle']]))
outputs.append(sheet('priority-dodge-reload-fireball.png', 'EMBERWAKE v23 / RELOAD CANCELLATION / RELEASED FIREBALL SURVIVES',
    ['pistol-reload-dodge.png', 'rifle-reload-dodge.png', 'released-fireball-survives-dodge.png']))
if args.gif:
    timeline = manifest['raw_states']
    assert manifest['raw_frame_count'] == len(timeline) == len(manifest['raw_frames']) == 90
    assert all(timeline[index]['physics_tick'] - timeline[index - 1]['physics_tick'] == 4 for index in range(1, 90))
    assert all(abs(row['native_elapsed_seconds'] - (index + 1) / 30) < 1e-5 for index, row in enumerate(timeline))
    frames = []
    for path, row in zip(manifest['raw_frames'], timeline):
        with Image.open(capture / 'twin-cut' / Path(path).name) as source:
            frame = Image.new('RGB', (960, 648), bg)
            frame.paste(source.convert('RGB').resize((960, 600), Image.Resampling.NEAREST), (0, 0))
        draw = ImageDraw.Draw(frame)
        draw.text((10, 604), f"ACTUAL Q / {row['native_elapsed_seconds']:.2f}s / HITS {row['hits']} / DAMAGE {row['damage']:.0f} / CUT {row['skill_cut_index'] + 1}", font=font, fill=gold)
        draw.text((10, 631), 'Two real Q presses / no cooldown / 18 + 19 each / consecutive native 120-Hz model ticks', font=tiny, fill=paper)
        frames.append(frame)
    path = output / 'twin-cut-native.gif'
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=[30 if index % 3 != 2 else 40 for index in range(90)], loop=0, disposal=2, optimize=False)
    outputs.append(path)
summary = {'capture_manifest': str(capture / 'capture-manifest.json'), 'cases': manifest['cases'],
           'outputs': [{'file': str(path), 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()} for path in outputs]}
(output / 'twin-cut-preview-summary.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2), encoding='utf-8')
for path in outputs:
    print(path)
