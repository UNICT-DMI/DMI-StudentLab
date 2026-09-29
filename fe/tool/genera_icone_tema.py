#!/usr/bin/env python3
"""Rigenera le icone Android per tema partendo dalle icone attuali.

Da usare se cambi l'icona dell'app (per esempio con flutter_launcher_icons):
ricrea launcher_icon_<tema>.png, ic_launcher_foreground_<tema>.png e i colori
di sfondo, con la stessa ricolorazione di mascotte e logo.

Uso, dalla cartella fe/:
    pip install pillow numpy
    python3 tool/genera_icone_tema.py
"""
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).parent))
from studentlab_recolor import THEMES, recolor  # noqa: E402

RES = Path('android/app/src/main/res')
DENSITIES = ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']


def main():
    if not RES.exists():
        sys.exit('✗ Esegui dalla cartella fe/ (non trovo android/app/src/main/res).')
    count = 0
    for theme in THEMES:
        for density in DENSITIES:
            for folder, name in (('mipmap', 'launcher_icon'), ('drawable', 'ic_launcher_foreground')):
                src = RES / f'{folder}-{density}' / f'{name}.png'
                if not src.exists():
                    continue
                out = RES / f'{folder}-{density}' / f'{name}_{theme}.png'
                image = recolor(Image.open(src).convert('RGBA'), theme).convert('RGB')
                image.quantize(colors=256).save(out, optimize=True)
                count += 1
    print(f'✓ {count} icone rigenerate per {len(THEMES)} temi')


if __name__ == '__main__':
    main()
