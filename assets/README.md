# Crownfield — original visual assets

All SVG artwork in this folder is newly hand-authored vector artwork for this project. It does not reproduce or extract Falcom sprites, maps, music, logos, or title art. The Crownfield mark is an original shield-and-crown composition. The landscape is a decorative original composition, not an original-game map.

- `terrain/`: 64×64 repeatable grass, water, rough ground, cave.
- `entities/`: 128×128 transparent castle, village, spear knight, mounted sovereign, timber bridge, palisade. Drawn with layered original geometry, gradients, masonry, roof tiling, harness, armour, vegetation and restrained shadows.
- `icon.svg` / `icon.png`: 192×192 application icon.
- `android_foreground.png` / `android_background.png`: 432×432 adaptive layers; foreground composition is constrained to the middle 264×264 safe area.
- `title_landscape.svg`: 1600×800 layered painted-vector landscape.
- `source/generate_assets.py`: editable deterministic source; run with Python 3 and Inkscape to recreate vector artwork and raster icons.

Copyright in original new artwork follows the project owner’s rights. No third-party art license is required for these SVGs. Font/audio resources, if present, have separate provenance and licenses.

SVG gradients and paths are supported by Godot’s SVG import; no filters, linked images, or external fonts are used. `art_preview.png` is a rendered visual QA contact sheet, not a game screenshot.
