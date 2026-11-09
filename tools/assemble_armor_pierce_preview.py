"""Validate native Armor Pierce input evidence and assemble complete-viewport previews."""
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
cases = {row['case']: row for row in manifest['cases']}
states = {row['file']: row for row in manifest['screenshot_states']}
assert len(cases) == 11
assert all(row['fixture_restart_key'] == 'T' for row in cases.values())

def near(a, b):
    assert abs(a-b) < 1e-4, (a,b)

full = cases['e-full-then-first-physical']
assert full['keys'] == ['E'] and full['mouse_presses'] == full['mouse_releases'] == 1
near(full['damage'], 64.5)
assert full['hits'] == 3
slash, stab = states['e-01-slash-no-break.png'], states['e-02-stab-break.png']
near(slash['damage'], 18)
assert slash['hits'] == 1 and slash['armor_break_remaining'] == 0
near(stab['damage'], 42)
near(stab['effective_armor'], 80)
near(stab['armor_break_fraction'], .2)
assert stab['hits'] == 2 and 0 < stab['armor_break_remaining'] <= 4
for timing, hits, damage in [('first-windup',0,0),('after-slash',1,18),('stab-precontact',1,18),('post-contact',2,42)]:
    row = cases['e-cancel-' + timing]
    assert row['keys'] == ['E','Space'] and row['hits'] == hits
    near(row['damage'], damage)
    assert not row['skill_active'] and not row['motion_busy']
    assert row['before_dodge']['skill_active'] and row['before_dodge']['hits'] == hits
    near(row['armor_lunge_travelled'], row['cancel_lunge'])
    assert (row['armor_break_remaining'] > 0) == (hits == 2)
for family, damage in [('staff',72),('pistol',22.5)]:
    row = cases['e-then-' + family]
    assert row['keys'] == ['E'] and row['mouse_presses'] == row['mouse_releases'] == 1
    assert row['hits'] == 3 and row['armor_break_remaining'] > 0
    near(row['damage']-42, damage)
refresh = cases['e-refresh-not-stack']
assert refresh['keys'] == ['E','E'] and refresh['hits'] == 4
near(refresh['damage'], 94.5)
near(refresh['armor_break_fraction'], .2)
near(refresh['effective_armor'],80)
assert refresh['remaining_before_refresh'] < refresh['armor_break_remaining'] <= 4
expiry = cases['e-expiry-and-pause-freeze']
assert expiry['keys'] == ['E','Escape','Escape']
assert states['e-paused-break-timer.png']['mode'] == 'paused'
near(states['e-paused-break-timer.png']['armor_break_remaining'], expiry['paused_remaining'])
assert abs(expiry['expiry_sim_elapsed']-expiry['expiry_start_remaining']) <= 2/120
assert expiry['armor_break_remaining'] == expiry['armor_break_fraction'] == 0
near(expiry['effective_armor'],100)
cover = cases['e-world-cover-blocks-status']
assert cover['keys'] == ['E'] and cover['damage'] == cover['hits'] == cover['armor_break_remaining'] == 0
q = cases['q-retains-37-and-immediate-reuse']
assert q['keys'] == ['Q','Q'] and q['hits'] == 4 and q['damage'] == 74 and q['armor_break_remaining'] == 0
for row in states.values():
    with Image.open(capture / row['file']) as image:
        assert image.size == (1280,800)
    near(row['armor_rating'],100)
    assert all(abs(a-b)<1e-5 for a,b in zip(row['target_position'],[1.7,.03,0]))
    for key in ['screen_player_ground','screen_player_top','screen_target_ground','screen_target_top']:
        x,y=row[key]
        assert 0 <= x < 1280 and 190 <= y < 690, (row['file'],key,(x,y))

output.mkdir(parents=True,exist_ok=True)
font = ImageFont.truetype('C:/Windows/Fonts/tahoma.ttf',18)
small = ImageFont.truetype('C:/Windows/Fonts/tahoma.ttf',14)
bg, paper, gold = '#0d1922','#e7efe9','#ffd06a'

def sheet(filename,title,names):
    canvas=Image.new('RGB',(1280,62+((len(names)+1)//2)*458),bg)
    draw=ImageDraw.Draw(canvas)
    draw.text((12,8),title,font=font,fill=gold)
    draw.text((12,35),'Complete native viewport / actual input / fixed original dummy / real armor100 -> 80',font=small,fill=paper)
    for index,name in enumerate(names):
        row=states[name]
        x,y=(index%2)*640,62+(index//2)*458
        with Image.open(capture/name) as source:
            canvas.paste(source.convert('RGB').resize((640,400),Image.Resampling.NEAREST),(x,y))
        draw.text((x+8,y+402),name.removesuffix('.png').replace('-',' ').upper(),font=small,fill=gold)
        draw.text((x+8,y+423),f"HITS {row['hits']} / DAMAGE {row['damage']:.1f} / ARMOR {row['effective_armor']:.0f} / BREAK {row['armor_break_remaining']:.3f}s",font=small,fill=paper)
        draw.text((x+8,y+443),f"{row['phase'].upper()} / LUNGE {row['armor_lunge_travelled']:.3f}m / {row['mode'].upper()}",font=small,fill=paper)
    path=output/filename
    canvas.save(path)
    return path

outputs=[sheet('armor-pierce-native.png','EMBERWAKE v22 / SLASH18 + STAB24 / PHYSICAL FOLLOWUP22.5 / REAL ARMOR BREAK',
    ['e-01-slash-no-break.png','e-02-stab-break.png','e-03-physical-followup.png','e-then-staff.png','e-then-pistol.png','e-refresh-not-stack.png'])]
outputs.append(sheet('armor-pierce-cancel-native.png','EMBERWAKE v22 / SPACE CANCELS PENDING DAMAGE AND LUNGE / APPLIED STATUS SURVIVES',
    ['e-cancel-first-windup.png','e-cancel-after-slash.png','e-cancel-stab-precontact.png','e-cancel-post-contact.png']))
outputs.append(sheet('armor-pierce-lifetime-native.png','EMBERWAKE v22 / SIMULATION TIMER / PAUSE / COVER / Q REGRESSION',
    ['e-paused-break-timer.png','e-expired-real-armor-restored.png','e-world-cover-blocks-status.png','q-retains-37-and-immediate-reuse.png']))
if args.gif:
    timeline=manifest['raw_states']
    assert manifest['raw_frame_count']==len(timeline)==len(manifest['raw_frames'])==90
    assert all(timeline[i]['physics_tick']-timeline[i-1]['physics_tick']==4 for i in range(1,90))
    assert all(abs(row['native_elapsed_seconds']-(i+1)/30)<1e-5 for i,row in enumerate(timeline))
    frames=[]
    for path,row in zip(manifest['raw_frames'],timeline):
        with Image.open(capture/'armor-pierce'/Path(path).name) as source:
            frame=Image.new('RGB',(960,648),bg)
            frame.paste(source.convert('RGB').resize((960,600),Image.Resampling.NEAREST),(0,0))
        draw=ImageDraw.Draw(frame)
        draw.text((10,604),f"ACTUAL E + LMB / {row['native_elapsed_seconds']:.2f}s / DAMAGE {row['damage']:.1f} / ARMOR {row['effective_armor']:.0f}",font=font,fill=gold)
        draw.text((10,631),f"BREAK {row['armor_break_remaining']:.3f}s / {row['phase'].upper()} / 120Hz native simulation",font=small,fill=paper)
        frames.append(frame)
    path=output/'armor-pierce-native.gif'
    frames[0].save(path,save_all=True,append_images=frames[1:],duration=[30 if i%3!=2 else 40 for i in range(90)],loop=0,disposal=2,optimize=False)
    outputs.append(path)
summary={'capture_manifest':str(capture/'capture-manifest.json'),'cases':manifest['cases'],
         'outputs':[{'file':str(path),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()} for path in outputs]}
(output/'armor-pierce-preview-summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
for path in outputs: print(path)
