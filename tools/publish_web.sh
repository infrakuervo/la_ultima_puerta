#!/usr/bin/env bash
# Exporta la versión web (preset "Web": GL Compatibility, sin hilos) y la publica en la rama gh-pages.
# Requiere Godot 4.7.2 en el PATH y las plantillas web en ~/.local/share/godot/export_templates/4.7.2.stable/.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/build/web"
PUB="${PUB_DIR:-$ROOT/build/gh-pages}"
mkdir -p "$OUT"
"$ROOT/tools/anim_lossy.sh"
godot --headless --path "$ROOT" --export-release "Web" "$OUT/index.html"
rm -rf "$PUB"
git -C "$ROOT" fetch origin gh-pages 2>/dev/null || true
if git -C "$ROOT" rev-parse --verify -q origin/gh-pages >/dev/null; then
	git -C "$ROOT" worktree add -f "$PUB" origin/gh-pages --detach
else
	git -C "$ROOT" worktree add -f --detach "$PUB"
	git -C "$PUB" checkout --orphan gh-pages-tmp
	git -C "$PUB" rm -rfq . || true
fi
find "$PUB" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
cp -r "$OUT"/. "$PUB"/
touch "$PUB/.nojekyll"
git -C "$PUB" add -A
git -C "$PUB" commit -qm "Versión web $(git -C "$ROOT" rev-parse --short HEAD)" -m "${COMMIT_TRAILER:-}" || echo "sin cambios"
git -C "$PUB" push origin HEAD:gh-pages
git -C "$ROOT" worktree remove --force "$PUB"
