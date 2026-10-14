# PGN Training Reader icon

Original artwork: `pgn-training-reader-icon.png`. Created with the built-in
imagegen tool for this project: an ivory chess knight over an open book on teal.

Android uses `ic_pgn_launcher`: five legacy PNG sizes (48, 72, 96, 144, 192 px)
and an API 26+ adaptive resource. The adaptive artwork is inset within its 108 dp
layer to keep the emblem visible under circular and rounded launcher masks.
The original Flutter placeholder resources are retained but no longer referenced
by the application manifest.

To regenerate the PNG exports with Python and Pillow available:

```sh
python3 tool/generate_launcher_icons.py
```

## Generation prompt

Use case: logo-brand
Asset type: final production Android app launcher icon for PGN Training Reader, a chess book reading and puzzle practice app.
Primary request: a beautifully polished, distinctive app icon: one bold ivory chess knight silhouette gracefully integrated with an open book underneath, communicating chess study. The knight is the main focal point, the book is understated with just two elegantly curved pages. Keep the emblem simple, cohesive, expertly balanced, instantly recognizable at 48 pixels.
Style/medium: premium minimalist graphic logo, crisp vector-like contours with very restrained tonal depth, sophisticated and calm. No photorealism.
Scene/backdrop: full-bleed opaque deep teal square background with extremely subtle tonal gradient, no border, no rounded corners baked into the artwork.
Composition/framing: square 1:1 artwork, centered compact emblem, all ivory subject content fully inside the central 60 percent of width and height so it remains safe under Android circular/squircle masks. Generous teal negative space, no tiny details.
Color palette: deep teal background close to #075A57, warm ivory emblem close to #FFF4DE, slight lighter teal only if needed for depth.
Text: none.
Constraints: single final icon artwork only, edge-to-edge square image, no mockup, no sheet, no lettering, no watermark, no frame, no chessboard, no extra objects.
