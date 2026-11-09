"""Compose actual native mace frames; no character/weapon pixels are synthesized."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
CAPTURE = ROOT / 'docs/review/mace'
font = ImageFont.truetype('C:/Windows/Fonts/tahoma.ttf', 17)
crop = (370, 140, 975, 565)
files = sorted((CAPTURE / 'combo').glob('combo_*.png'))
assert len(files) == 90
atlas = Image.new('RGB', (1210, 850))
for index, path in enumerate(files):
    image = Image.open(path).convert('RGB').crop(crop).resize((121, 85))
    atlas.paste(image, ((index % 10) * 121, (index // 10) * 85))
palette = atlas.quantize(colors=224)
frames = []
for path in files:
    canvas = Image.new('RGB', (605, 455), (14, 24, 33))
    canvas.paste(Image.open(path).convert('RGB').crop(crop), (0, 30))
    ImageDraw.Draw(canvas).text((10, 6), 'MACE / UPSWING > SHORT DASH > SLAM', font=font, fill=(239, 197, 129))
    frames.append(canvas.quantize(palette=palette, dither=Image.Dither.NONE))
durations = [30 if i % 3 != 2 else 40 for i in range(90)]
durations[-1] += 600
output = ROOT / 'docs/mace-preview.gif'
frames[0].save(output, save_all=True, append_images=frames[1:], duration=durations, loop=0, disposal=2, optimize=False)
poses = [('03-uppercut-preparation.png', '1 / เตรียมฟาดขึ้น'), ('04-uppercut-contact.png', '1 / ฟาดขึ้น 34'), ('06-short-dash-contact.png', '2 / พุ่งตี 12'), ('07-overhead-lift.png', '3 / ยกอาวุธ'), ('08-slam-impact.png', '3 / ฟาดลง 46'), ('09-overhead-recovery.png', '3 / คืนท่า')]
sheet = Image.new('RGB', (930, 740), (14, 24, 33))
draw = ImageDraw.Draw(sheet)
draw.text((14, 12), 'MACE / HEAVY > QUICK LIGHT DASH > HEAVY', font=font, fill=(239, 197, 129))
for index, (name, label) in enumerate(poses):
    image = Image.open(CAPTURE / name).convert('RGB').crop(crop)
    image.thumbnail((292, 290))
    x, y = 14 + index % 3 * 306, 58 + index // 3 * 334
    sheet.paste(image, (x, y))
    draw.text((x, y + 245), label, font=font, fill=(228, 232, 222))
sheet.save(ROOT / 'docs/mace-poses.png')
with Image.open(output) as image:
    print('90native input frames;', image.n_frames, 'GIF frames;', output)
