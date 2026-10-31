"""Generate native and web icon sizes from the approved Hymnals raster master."""
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
MASTER = Image.open(ROOT / 'assets/branding/hymnals-logo-v1.png').convert('RGB')
BLUE = '#2E3192'


def icon(size, inset=1.0):
    image = Image.new('RGB', (size, size), BLUE)
    side = round(size * inset)
    mark = MASTER.resize((side, side), Image.Resampling.LANCZOS)
    image.paste(mark, ((size - side) // 2, (size - side) // 2))
    return image


def save(relative, size, inset=1.0):
    path = ROOT / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    icon(size, inset).save(path, optimize=True)


for density, scale in [('mdpi', 1), ('hdpi', 1.5), ('xhdpi', 2), ('xxhdpi', 3), ('xxxhdpi', 4)]:
    save(f'android/app/src/main/res/mipmap-{density}/ic_hymnals.png', round(48 * scale))
    save(f'android/app/src/main/res/mipmap-{density}/ic_hymnals_foreground.png', round(108 * scale), .88)
    save(f'android/app/src/main/res/drawable-{density}/launch_image.png', round(96 * scale))

appicons = ROOT / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
for item in json.loads((appicons / 'Contents.json').read_text())['images']:
    size = round(float(item['size'].split('x')[0]) * float(item['scale'].rstrip('x')))
    save(appicons.relative_to(ROOT) / item['filename'], size)

for scale, suffix in [(1, ''), (2, '@2x'), (3, '@3x')]:
    save(f'ios/Runner/Assets.xcassets/LaunchImage.imageset/LaunchImage{suffix}.png', 168 * scale)

for size in [192, 512]:
    save(f'web/icons/Icon-{size}.png', size)
    save(f'web/icons/Icon-maskable-{size}.png', size, .88)
save('web/favicon.png', 32)
print('Generated Android, iOS and web Hymnals icons and launch images.')
