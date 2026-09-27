# Podniebny podróżnik — grafiki i dźwięk

Grafiki utworzono wbudowanym `image_gen`; oryginalne PNG z przezroczystością są w `assets/art`. AtlasTexture przycina marginesy w silniku, bez modyfikowania plików źródłowych. Ikony przycisków wykorzystują te same grafiki plecaka i kotwiczki. Efekty chmur, linki, fali i perełek rysuje Godot.

## wind_bottle.png

Use case: illustration-story. Asset type: isolated collectible sprite for a pastel kawaii children's 2D game, Jumping Adventure. Create ONE plump sky-blue glass bottle with a small warm cork and mint ribbon around the neck. Inside the bottle is one tiny fluffy spiral of white wind with a sweet simple smiling face. Soft lavender outlines, creamy highlights, gently painted storybook shading, polished readable silhouette at 56px. Front view slightly three-quarter right, entire object fills central 75% of square canvas. True transparent alpha background. No ground, no shadow outside silhouette, no scene, no lettering, no border, no other objects, no sparkles outside bottle. This is the magical Bottle of Mischievous Wind.

## anchor.png

Use case: illustration-story. Asset type: isolated collectible sprite for a pastel kawaii children's 2D game, Jumping Adventure. ONE magical amber anchor charm, round soft blunt flukes, chubby proportions, round ring at the top, translucent honey amber material with one tiny white light trapped inside. Soft lavender purple outlining around the entire silhouette, warm cream highlights, softly painted storybook shading. A small mint ribbon tied beneath the top ring. Front view, very clear simple recognizable anchor shape at 56px. Entire anchor central 75% of square canvas. True transparent alpha background. No ground, no scene, no rope, no lettering, no shadow outside silhouette, no loose sparkles, no other objects.

## cloud_pack.png

Use case: illustration-story. Asset type: isolated equipment overlay sprite for a pastel kawaii children's 2D jumping game. ONE small cloud-powered adventurer jetpack backpack, no wearer. Rounded mint fabric bag, small sky-blue cylindrical wind bottles on left and right with warm cork stoppers on top, two rounded lavender exhaust nozzles pointing down and slightly left. Cream cloud-shaped badge centered on bag, tiny simple straps tucked tightly against silhouette. View from side/three-quarter, suited to attach to the LEFT side of a cute character facing RIGHT. Plump soft pillow proportions, softly painted storybook shading, lavender contours, cream highlights, legible silhouette at 40px. Entire single pack fills central 75% of square canvas, actual alpha transparent background. No flame, no smoke, no cloud outside pack, no person or animal, no lettering, no scene, no external shadow.

## Dźwięk

`tools/generate_audio.py` generuje deterministycznie `artifact.wav`, `super_jump.wav` i `anchor.wav`, bez zewnętrznych próbek dźwięku.
