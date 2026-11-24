# Crownfield — original visual assets

All SVG artwork in this folder is newly hand-authored vector artwork for this project. It does not reproduce or extract Falcom sprites, maps, music, logos, or title art. The Crownfield mark is an original shield-and-crown composition. The landscape is a decorative original composition, not an original-game map.

- `terrain/`: 256×256 tile artwork. Meadow and river backgrounds meet the next tile at the same value; rough heath and caves have distinct silhouettes.
- `entities/`: 384×384 transparent castle, cottage group, foot soldier, mounted sovereign, timber bridge and stockade. Hand-drawn with warm local light, compact shadows and a dark ink silhouette. The horizontal bridge can be rotated for a vertical crossing. Terrain and entity SVGs use a 128-unit viewBox, with mipmaps for distant map views.
- `icon.svg` / `icon.png`: 192×192 application icon.
- `android_foreground.png` / `android_background.png`: 432×432 adaptive layers; foreground composition is constrained to the middle 264×264 safe area.
- `title_chart.svg`: 960×1080 original illustrated castle valley; used by the game title and Web loader.
- `foods/atlas.svg`: 46 illustrations at 192px each, in 256px padded slots, built from `tools/build_food_art.py`.
- `interface/`: shared vector button symbols and wordmark.
- `title_landscape.svg`: 1600×800 layered painted-vector landscape.
- `source/generate_assets.py`: legacy title / application icon generator, run with Python 3 and Inkscape. The current map SVGs are directly editable masters; regeneration does not overwrite them.

Copyright in original new artwork follows the project owner’s rights. The CROWNFIELD wordmark uses outlines from DejaVu Serif (see interface/wordmark-license.txt). Font/audio resources, if present, have separate provenance and licenses.

SVG gradients and paths are supported by Godot’s SVG import; no filters, linked images, or external fonts are used. `art_preview.png` is a historical visual QA contact sheet, not a game screenshot.
