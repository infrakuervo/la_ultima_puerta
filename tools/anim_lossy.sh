#!/usr/bin/env bash
# Importa los fotogramas de art/anim como WebP con pérdida (calidad 0,8) para la versión web:
# el .pck pasa de ~39 MB a ~14 MB sin diferencia visible. Los *.import no se versionan,
# así que se reescriben aquí (primero se importa para que existan) y se vuelve a importar.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
godot --headless --editor --import --path "$ROOT" >/dev/null 2>&1 || true
find "$ROOT/art/anim" -name "*.png.import" -print0 | xargs -0 sed -i \
	-e 's/^compress\/mode=0/compress\/mode=1/' \
	-e 's/^compress\/lossy_quality=.*/compress\/lossy_quality=0.8/'
godot --headless --editor --import --path "$ROOT" >/dev/null 2>&1 || true
echo "fotogramas en WebP con pérdida"
