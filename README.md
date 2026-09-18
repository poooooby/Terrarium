# Terrarium - Wooble's English Fork

"A little world under glass: it has its own weather, its own hours, and things
living in it."

Before downloading, check out [BrenoBertucci's Terrarium](https://github.com/BrenoBertucci/Terrarium) first. This is Wooble's personal fork, and an attempt at an English translation plus other minor bug fixes, and is not a replacement for the original.

> ### Gen 2 (Pokémon Gold) is an early first pass — play Gen 1

> [!CAUTION]
> Terrarium is recommended on **Gen 1 only** (Red / Blue / Yellow).
> **Do not use it on Gold / Johto yet.**


> ### This is a fork of a fork, and neither original is mine
>
> **TerrariumVoxel is a fork of [BrenoBertucci's Terrarium](https://github.com/BrenoBertucci/Terrarium),
> itself a fork of the [Dramatic Shape Voxel Mod](https://github.com/DramaticShape/DramaticShapeVoxelMod)
> by [Dramatic Shape](https://github.com/DramaticShape).** Two layers of
> attribution, and neither is mine: the diorama, the depth-buffered
> occlusion, the shadow map, the tilt-shift pass and the over-the-shoulder
> battles are Dramatic Shape's original work; the low-end-hardware tuning,
> the weather, the ecology, the wild Pokemon you can see, and everything
> else under
> ["What Terrarium adds to the original"](#what-terrarium-adds-to-the-original)
> below is BrenoBertucci's. This tree's own additions sit on top of THAT,
> and are narrower: this mod's own menus default to English rather than the
> hardcoded Portuguese they shipped with (a Portuguese option is kept), plus
> a start-menu visibility/sizing fix, an engine-compat crash guard, and
> wiring in two options rows (SHOP / SHOP-FX) that existed in the code but
> were never reachable from the menu -- see
> **["What this fork adds on top of Terrarium"](#what-this-fork-adds-on-top-of-terrarium)**
> further down.
>
> **If you are choosing between them, go and look at the originals first:**
> <https://github.com/DramaticShape/DramaticShapeVoxelMod> and
> <https://github.com/BrenoBertucci/Terrarium>
>
> It ships under its own mod id `TERRARIUM` and its own folder, so it can
> sit **beside** either without overwriting it. This fork uses letter
> hotkeys (v/g/t/c/m/b/n/p) and its own pipeline ids, so it does not fight
> upstream's 3/5/6/7/8/9. Still only one world pipeline should own the frame
> at a time.

A mod for the [Pokemon Gen 1 Recompilation
Project](https://github.com/bryanthaboi/gen1recomp). The overworld becomes a
3D diorama: terrain extruded into real geometry, cast shadows that stretch
through the afternoon, a six-phase day/night cycle with a painted sky and
stars, weather that leaves puddles and snow on the ground, and wild Pokemon
standing in the grass where you can see them.

> **This is a fan-made modification. It is not a game, and it contains no part
> of any Nintendo product.** Please read [Legal](#legal) before anything else.

---

## Legal

**Pokemon Red, Pokemon Blue and Pokemon Yellow are © 1996–1999 Nintendo,
Creatures Inc. and GAME FREAK Inc. "Pokemon", "Nintendo" and "Game Boy" are
trademarks of their respective owners. All rights in the games, characters,
names, artwork, music and every other element of them belong to those
companies and to nobody else.**

This project is:

- **Unofficial and unaffiliated.** It is not made by, endorsed by, sponsored
  by, licensed by, or associated with Nintendo, Creatures Inc., GAME FREAK
  Inc., The Pokemon Company, or any of their subsidiaries or partners.
- **Not a game, and not a way to get one.** It is a modification: a set of
  Lua scripts and original art that changes how an already-installed program
  draws itself. On its own it does nothing at all.
- **Free of Nintendo's data.** This repository contains **no ROM, no ROM
  patch, no game code, no sprite, no map, no music and no sound** taken from
  any Pokemon title. It never has and it never will — the `.gitignore` here
  blocks ROMs, dumps, saves and patch files (`.bps`, `.ips`, `.ups`) so that
  one cannot be committed by accident.
- **Dependent on a copy you already own.** Gen1Recomp reads a ROM that the
  player dumps from their own cartridge. **Do not ask this project for a ROM,
  and do not link one in an issue or a pull request** — such a request will be
  closed and such a link removed.
- **Non-commercial.** It is given away. No part of it is sold, and no
  donations, ads or paid tiers are attached to it. It is a hobby project made
  out of affection for a thirty-year-old game.

The original art assets shipped here (ground textures, voxel models) were
drawn or generated for this mod. The ambient audio is CC0 public domain, with
every source and author named in
[`assets/audio/CREDITS.md`](assets/audio/CREDITS.md).

**If a rights holder objects to anything in this repository, open an issue or
contact me and it will be taken down promptly.** No argument, no delay.

---

## Made with AI assistance

**Large parts of this fork were written with the help of AI coding
assistants** (Anthropic's Claude, among others). This is stated plainly and up
front, not buried, because you have a right to know what you are installing
and reviewing.

What that means in practice:

- The code was **directed, tested and accepted by a human** — me. Features
  were specified, measured, and rejected when the measurement did not support
  them. It is not generated and dumped.
- Much of it is **verified by probes rather than by eye.** The `tests/`
  directory holds twenty self-contained probes that drive the real game
  headless and write numbers to a log — shadow lengths, palette ramps, pixel
  classifications, frame-time medians. Where this README claims a number, a
  probe produced it.
- It carries the usual caveat all the same: **read it before you trust it.**
  AI-assisted code can be confidently wrong, and some of this is in the render
  path of a program you are running on your own machine.

If AI-assisted contributions are something you would rather avoid, that is a
completely reasonable position and you should use the
[original mod](https://github.com/DramaticShape/DramaticShapeVoxelMod)
instead — it is excellent, and this fork exists because of it.

---

## What Terrarium adds to the original

The base is Dramatic Shape's **1.3.0**: the voxel diorama, the depth-buffered
occlusion, the leaning sprite slabs, the shadow map, the tilt-shift pass and
the over-the-shoulder battles. All of that is his work, and it is the reason
any of this exists.

Everything below was added in the `-mobile` line (versions 1.4.0 through
1.18.0 — see [`CHANGELOG.md`](CHANGELOG.md) for the full history, and
[`MOBILE.md`](MOBILE.md), written in Portuguese, for the reasoning).

### It runs on weak hardware

This was the whole point of the fork. The original targeted a desktop; this
one was made to run on an entry-level Android (a Samsung A14 5G — two-core
Mali, 2408×1080 panel) and on a low-end PC. Development and every measurement
in this repo happen on an **Intel i3-1115G4 with integrated UHD graphics**.

Two new rows on the OPTIONS menu, both visible under every preset:

| row | values | default | what it does |
| --- | --- | --- | --- |
| **RES** | 1/2 \| 1/3 \| 1/4 \| FULL | **1/2** | divides the resolution the 3D pass rasterises at before it is scaled back up. Every cost in the pass is quadratic in it: 1/2 is four times less of everything, 1/3 is nine. Upscaled *nearest*, so the result is chunkier, not blurrier — the right defect for this art. |
| **SHADOWS** | LOW \| OFF \| HIGH \| SOFT | **LOW** | LOW keeps real cast shadows on a 512–1024 texel map instead of 2048, one tap instead of four, no neighbouring maps casting, redrawn every second frame while walking. |
| **PFX** | ON \| LOW \| HIGH \| MAX | **ON** | how much air there is: dust and seeds on the wind, rain's falling shafts and splashes, snow, water still coming off the eaves. Its own row because it used to hang off RES, so asking for more weather also asked the grass, shadows and cloud raymarch to get heavier. LOW gives the frame back; HIGH doubles the counts, MAX quadruples them. |

Plus spatial culling, and a shadow-map size ladder chosen per frame from how
much world is actually in view.

### Wild Pokemon you can see

The **WILD** row. The map's own encounter table decides who is standing in the
grass right now; they wander their own patch in their own art, and the fight
starts when you walk into one — so a route can be picked through, hunted, or
crossed without a single battle.

This is the one feature that touches the game rather than the drawing of it,
which is exactly why it is a row with an OFF: **switch it off and the game
rolls its dice precisely as it always did.**

### And the rest of it

| row | what it is |
| --- | --- |
| **SCREEN FX** (was RTX) | not ray tracing: a screen-space row walked through the depth buffer the 3D pass already filled: ambient occlusion in corners the sky cannot reach, reflections marched across the water's own swell, light shafts toward the sun. OFF is byte-for-byte the old frame. |
| **TOWN** | Pokemon loose in the streets of every town: trainers' companions and strays, wandering in their own art. About one in three stares you down and wants to battle at your own lead's level. |
| **AMBIENT** | butterflies and ground birds by day, dragonflies over the water, fireflies through the night, a flock crossing the sky, leaves on the wind -- and civilian NPCs glance at you as you pass, then go back to what they were doing |
| **SOUNDS** | the sound of the place: crickets after dark, birdsong through the day, water moving near any water, rain and thunder after the flash -- crossfaded beds rather than one-shot beeps, and quieter indoors |
| **ROUTINES / SHELTER** | civilians look around, turn toward the sign they are standing beside, talk in pairs — and walk to the nearest doorway when a shower comes down hard. AGENDA (grouped with ROUTINES) decides whether that departure reaches DAY (a post to keep) or FULL (a doorway at night, street Pokemon included) |
| **WEATHER** | rain and snow, folded into the light rather than drawn over it |
| **WIND** | the tall grass is geometry, so wind is a bend and not a slid picture: the base stays planted, the tip gives and drops as it goes over, each tuft has its own stiffness, and the gust travels across a meadow. Rain weighs the blades down and damps them; settled snow bows them and piles white on the crowns; walkers lay them flat and they spring back, leaving a trail you can turn round and see. AUTO hands the row to the climate -- calm night, breeze by day, gale under a front, no menu trips. Plus the air itself: dust and spray streaks, and a gust front crossing the frame as a line |
| **GROUND** | what the weather leaves behind: puddles that gather through a shower and are still there ten minutes later wearing the sky's own colour, snow settling in drifts, footprints behind everyone walking on it |
| **ECOLOGY** | Gen 2's time-of-day encounters built out of Gen 1's single table — the nocturnal half of the dex comes up after dark, birds and caterpillars by day, by reweighting the map's own ten slot buckets rather than adding or removing anything |
| **WATER** | a cel-shaded swell: two crossing wave trains, analytic normals, depth-rung colour and binary foam (toon water ideas, hard steps only — not PBR). CALM / SWELL / FLAT. Rain and wind feed chop energy; freeze turns the surface into walkable ice when the party can Surf |
| **QOL** | type-effectiveness hints on the FIGHT menu, auto-repel, and HMs on an A press (CUT at a tree, SURF at water, STRENGTH at a boulder) |
| **BAG / STACK** | twenty item slots and ninety-nine per stack were Game Boy save-RAM limits, not design. Raise both. |
| **EXP** | TEAM pays every Pokemon still standing what the fighters earned; SPLIT divides that same total among them instead. OFF is the original's one-fighter-only rule. |
| **AUTO-FARM** | pick a party slot and a bot trains it, always picking the strongest move against what it faces |
| **GLINT** | a thin reflection sweeping across window panes as you walk |
| **IMPACT** | hand-drawn CC0 sprite-sheet hit effects composited into the world; press J in free roam to fire the next sheet at your feet |
| **ANIME** | cel animation: a cool rim light along every silhouette and an ink line closing every shape, on top of the SCREEN FX pass's own normals (needs SCREEN FX above OFF) |
| **TREES** | which trees stand on the round-tree sites: VOXEL is the blocky hand-modelled tree, 3D is a smoother canopy under photographed leaf cards |
| **LIGHT** | SKY lights the world with sun (warm, directional) and sky (cool, ambient) separately, so a shadow reads as somewhere the sky is lighting rather than just dimmer. FLAT is the single tint it used to be. |
| **DAYTIME** | pin the sky to DAY / NIGHT / DUSK / DAWN, let CYCLE run all six phases on its own clock, or SYNC it to the clock on the wall |
| **N-DARK** | how dark night is: DEEP drops the sky and the world's tint further so a town reads as lit windows and lamps in real darkness; SOFT is the older, more readable blue night |
| **CLOUDS** | volumetric clouds in the sky pass: ON keeps a few fair-weather puffs that thicken into a deck as a shower builds, THICK is a heavy sky even on a clear hour, OFF is bands only |
| **LAMPS** | street lamps in towns and cities -- three models of post, deterministic per map, burning in the hour's own lamp colour after dusk |
| **MAP** (corner radar) | player + facing + Center/Gym/Gate icons on free-roam; FULL adds a local walkability grid |
| **MAP** (Town Map item) | 3D builds Kanto as a diorama from the classic map's own data -- sea, clouds, the hour's light, your objective routed along the roads; CLASSIC is the original 160x144 screen |
| **3D-BTL** | fight on the map itself: the battle draws over the nearest clear ground instead of cutting to the classic flat screen |
| **BACK SPRITES** | with 3D-BTL on, puts your own Pokemon's back view into the shot too, big in the foreground the way Gen 1's own battle screen frames it. OFF by default. |
| **SM64CAM** | the Super Mario 64 camera: turns to look at you rather than staying fixed, takes its height from the ground, and changes how movement itself is read (D-pad walks you away from the camera, not due north) |
| **V-HAZE** | distance haze -- far ground fades into the hour's own sky colour instead of reading as a hard edge |
| **HORIZON** | the rest of Kanto on the skyline: every connected map out to a chosen distance, drawn as a bare silhouette |
| **Building kits** (TOWER / CRYPT / CRYPT-FX / SHOP / SHOP-FX / LEDGES / HAUNT / HEARTH / INDOOR) | NEW-vs-CLASSIC pairs for individual buildings and props -- the Pokemon Tower, its crypt interior and haunted lighting, the Poke Mart and its shader pass, hop-down ledges, Lavender's haunted glass, chimney smoke, and sleeping Pokemon/steaming mugs indoors. See [`FEATURES.md`](FEATURES.md) for each. |
| **COMBAT** | DYNAMIC (Modern JRPG), DYNAMIC MINIMAL (For Kanto Gear), CLASSIC (static rig, flat still panels), MINIMAL (CLASSIC without the menu/cards), OFF (none of this mod's own battle UI -- just the diorama, the mons and hit FX) |

### A interface deste mod fala inglês por padrão, e português à escolha

> This mod's UI speaks English by default, and Portuguese on request.

A nova linha **UI LANG** no menu de opções troca só o que este mod desenha
por conta própria — os botões de comando da batalha, as abas da bolsa, a
etiqueta da linha MAP no menu inicial. Nada que o próprio jogo imprime
muda com ela; veja o [`CHANGELOG.md`](CHANGELOG.md) para a história
completa de por que essa interface vivia em português por engano.

> The new **UI LANG** row on the options menu switches only what this mod
> draws on its own — the battle command buttons, the bag tabs, the MAP
> row's label in the start menu. Nothing the game itself prints changes
> with it; see [`CHANGELOG.md`](CHANGELOG.md) for the full story of why
> this UI lived in Portuguese by mistake.

### Cel water (measured)

The water is geometry, not a flat scrolling tile. Identity is the height test
alone (`y < -1` — recessed two world pixels so the shoreline shows a lip).
Displacement is Y = f(XZ) only, so an unindexed mesh never opens a seam.
The normal is two cosines of the same trains — analytic, free, exact.

Paint stays in the mod's four-colour dialect: hard `step`s, checker dither,
bands re-evaluated on a world-XZ cell (the sky's own `floor(sc/cell)` idiom).
Ideas from [Roy Stan's Toon Water Shader](https://roystan.net/articles/toon-water/)
are adapted here (depth-rung tint, binary surface-noise foam, shoreline foam)
without a second render target, without a normal map, and without soft
airbrush gradients. See [Credits](#credits).

**Shimmer is a number, not a screenshot.** `tests/water_shimmer_probe.lua`
freezes weather, wind, clock and NPCs, builds a water mask by FLAT-vs-SWELL
diff, then counts water pixels that change between consecutive frames under
ablations (tile roll / geometry / glint window / SSR). On VERMILION_CITY at
the default RES 1/2 rung, with climate off:

| | continuous background | of sampled water |
| --- | ---: | ---: |
| before anti-crawl pass | ~4125 px | **~5.9%** |
| after (`RATE` 0.9→0.55 + mid-pond foam gated on chop/rain) | ~1510–1890 px | **~2.2–2.7%** |

So about **half the continuous churn** on a calm clear pond. Ablation on the
pre-pass baseline: almost all of that churn was swell + cel paint; the
tileset roll, the glint rings and SSR each moved under 5% of the count.
`PAINT_PHASE_STEP` (temporal snap of paint phase) and a coarser paint cell
were tried and rejected — the first turned crawl into full-pond flashes, the
second made the palindrome unreadable. Knobs remain in `lib/Water.lua` at
safe defaults. Puddle SSR shares RayFX with the pond; `tests/puddle_rtx_probe.lua`
is the regression gate and still passes.

### Day, night, and the sky

The clock runs a six-phase dial — dawn, golden hour, day, dusk, violet
twilight, night — with a hand-quantised sky palette per phase on the Game Boy
Color's own 5-bit lattice, a dithered gradient, and a cell-art sun and moon.

The most recent work went here, and it is measured rather than eyeballed:

- **Every phase is now actually painted.** The dial used to hold `day` and
  `night` and pass *through* the other four: measured a second at a time,
  `dawn`, `golden` and `dusk` held for one second each and `violet` for none
  at all — four hand-authored palettes that were never shown. They now hold
  45–137 seconds each, and the sunrise runs dawn → golden → day the way the
  evening already ran day → golden → dusk.
- **Stars, and the occasional meteor.** A fixed 96-star field on the sky's own
  cell grid, posterised to four brightness rungs and twinkling on their own
  phases, fading in with the night and gone under an overcast. Star count is a
  rung on the quality ladder.
- **The night is darker, and the town is lit.** A lit window is exempt from
  the hour's tint in the shader, so taking a quarter of the light out of the
  night makes a town read as windows in the dark rather than as a blue-filtered
  afternoon. Each pane now burns at its own brightness, so a wall of windows
  is a wall of rooms.
- **Evening shadows stretch.** The shear clamp was cutting a full-strength
  shadow for 300 seconds of every 1200 — right through the golden hour. It is
  now derived from the fade angle instead, so it can only ever shorten a
  shadow already on its way out. Measured cost: `+0.015 ms` per frame.
- **The rain arrives instead of switching on.** A far curtain stands the
  shower on the horizon as vertical shafts, and it is full at a power where
  the drops near you are still almost nothing -- so weather is something you
  watch close in over most of a minute. Not a forecast: nothing here knows the
  future, it is the same shower drawn where a shower is visible *as* one.
- **The cloud deck sits over the map, not over the screen.** It reads the
  camera now, and shifts *less* than anything else in frame -- that difference
  is the distance cue. It also changes shape as it drifts, because the erosion
  noise moves at its own rate against the wind carrying the mass; a rigid
  pattern being towed past reads as a backdrop however fast you tow it.
- **God rays, where the deck is thin.** For the length of the post-rain spell,
  and drawn out of the cloud density the raymarch already computed -- so the
  whole effect is one `atan` and one `sin` on top of existing work. Hard rungs
  and the sky's own checker: a soft falloff here is bloom.
- **A storm register.** Heavy rain bruises the sky violet rather than only
  greying it, blended after the stratus on the same hour weight. It only
  leaves zero above the same threshold that arms the lightning, so a drizzle
  keeps the neutral grey it always had and a purple sky is one that can flash.
- **Stars go out one at a time.** Each has its own threshold, weighted by its
  own magnitude with a scatter off its twinkle phase, so the field empties in
  a scattered order instead of fading as one sheet. A clear deep night is
  unchanged.

  All five were isolated and measured (`tests/sky_weather_probe.lua`) because
  they landed in one shader, where a screenshot cannot say which of them
  moved: 59.7% of sky pixels move between two cameras at the same instant
  (0.0% with parallax zeroed); the curtain hits 38.9% in the lower sky and
  0.0% in the upper; the rays 30.3% near the disc against 8.2% away and 0.0%
  off a moon. Cost, as an off/on/on/off palindrome: `+4.6%` per sky paint with
  curtain and rays both forced on -- a state the game never reaches.

---

## What this fork adds on top of Terrarium

This is the second layer: everything above this section, back through "What
Terrarium adds to the original," is BrenoBertucci's work on Dramatic Shape's
base. What follows is this tree's own, on top of that.

- **This mod's own menus default to English.** The battle command buttons,
  the bag's pocket tabs, and the start menu's MAP row were hardcoded
  Portuguese literals -- not text from the game itself, which is English
  throughout (`src/core/Strings.lua` ships as an identity function with no
  translation loaded, and the extracted ROM text is the original cartridge
  script). A new **UI LANG** row (OPTIONS menu and the mod manager) switches
  between English and Portuguese for this mod's own overlays; nothing the
  game itself prints is affected either way.
- **The start menu could go invisible.** `StartMenuXY.available()` silenced
  the engine's own flat menu whenever assets were ready, regardless of
  whether the X/Y replacement would actually get painted -- which only
  happens while the VOXEL or T-SHIFT pipeline is active. With both off, the
  menu still opened (input still reached it) but nothing drew it. It also
  inserted its MAP row without resizing the menu's own box, so the top item
  could print above the frame's edge. Both are fixed.
- **A missing `pcall` crashed engine builds that don't ship GBCFX.** Two
  unguarded `require("src.render.GBCFX")` calls (a save-load hook and the
  VOXEL hotkey) are now guarded like the rest of the file already guards
  its own requires.
- **SHOP and SHOP-FX are reachable now.** Both existed in `lib/Shop.lua`,
  in the same shape as every other row, but neither was ever registered on
  the options menu -- so SHOP-FX (which asks the RTX row for a minimum
  ambient-occlusion rung inside a Poke Mart) had no OFF a player could
  reach, and RTX OFF quietly didn't hold inside a mart such as Viridian's.

Full detail on each, in this project's own bilingual (Portuguese-first)
style, lives in [`CHANGELOG.md`](CHANGELOG.md).

---

## Requirements

- **[Gen1Recomp](https://github.com/bryanthaboi/gen1recomp) v0.1.37 or newer**
  (developed against v0.1.60)
- A ROM you dumped yourself. **This project does not supply one.**

## Installing

Drop the folder into your Gen1Recomp `mods/` directory, or import the packaged
zip through the launcher's mods tab.

**Name the installed folder `TERRARIUM`.** That matches the mod id in
`manifest.json`. Probes under `tests/` launch as
`mods/TERRARIUM/tests/<probe>.lua`.

This fork is **independent** of upstream `DRAMATIC_SHAPE`: different id,
different folder, different pipeline registry keys (`terrarium_voxel` /
`terrarium_tiltshift`). You can install Terrarium alone, the original alone,
or both. The diorama design remains DramaticShape's work — see the fork note
at the top of this file.

**Letter hotkeys (TERRARIUM):** `v` VOXEL | `g` V-GRID | `t` T-SHIFT | `c` V-CURVE | `m` SM64CAM | `b` 3D-BTL | `n` WILD | `p` MAP. Upstream still uses digits.
`c` V-CURVE | `b` 3D-BTL | `n` WILD | `p` MAP. Upstream still uses digits.

### Porygonal — 3D overworld characters

[Porygonal](https://github.com/CurlyG004/porygonal-overworld-characters) puts
modelled characters in the world, but it draws none of them itself: it hooks
whichever 3D renderer mod it recognises and replaces the cast through that
renderer's own draw calls. It recognises renderers **by exact mod id**, so it
did not know this fork existed.

[`compat/porygonal/`](compat/porygonal/README.md) is the adapter that makes the
pair work, plus the probe that measures it. It is meant to go upstream; until
it does:

```bash
python compat/porygonal/make_adapter.py && python compat/porygonal/install.py
```

Nothing in `lib/` or `main.lua` changed for it.

## YouTube / videos

If you want to make YouTube videos with **builds newer than the public
releases**, get in touch on Discord: **carrara2803**.

Quem quiser gravar no YouTube com versões mais recentes do que as releases
públicas pode me chamar no Discord: **carrara2803**.

## Quiver / launcher packaging

- Install folder must be `mods/TERRARIUM` (matches `manifest.json` id).
- Catalog metadata for a future index entry lives in
  [`quiver-catalog-entry.json`](quiver-catalog-entry.json) (folder key
  `breno@TERRARIUM`) and a one-mod local index in
  [`quiver-local-index.json`](quiver-local-index.json).
- Pack manifest with hashes: [`.modkit/pack.json`](.modkit/pack.json).
- Reinstalling upstream `DRAMATIC_SHAPE` from Quiver only touches that
  folder; it cannot overwrite `TERRARIUM`.


Every feature is a row on the OPTIONS menu with an OFF. If something is too
slow, too bright or too much, turn that row off; nothing here is load-bearing
for anything else.

## Repository layout

| path | what it is |
| --- | --- |
| [`FEATURES.md`](FEATURES.md) | the full manual — every row, every control, every rule |
| [`MOBILE.md`](MOBILE.md) | why the fork exists and what was changed to make it run (Portuguese) |
| [`CHANGELOG.md`](CHANGELOG.md) | thirty-one releases, with the reasoning for each |
| `lib/` | the mod itself |
| `tests/` | twenty self-contained probes that drive the real game and write numbers |
| `assets/` | original art, CC0 audio, and the building/voxel documentation |
| `tools/` | authoring scripts — they run by hand, not at play time |
| [`compat/porygonal/`](compat/porygonal/README.md) | the renderer adapter that lets Porygonal put its 3D characters in this diorama |

---

## Licence — please read before forking

**Neither upstream mod currently carries a licence file**, and neither does
this fork. Under default copyright that means the code is *not* granted for
redistribution or modification, however freely it is shared in practice, and
[an open request for one](https://github.com/DramaticShape/DramaticShapeVoxelMod/issues/45)
is sitting on the original repository.

This fork is published in the spirit the originals were — freely, for other
people to read, run and learn from — but I cannot grant you rights over code
that is not mine to license, two layers removed from mine. If you plan to
build on this, **please talk to BrenoBertucci first** (this tree's direct
upstream), **and to Dramatic Shape** (the root of the chain). If a licence
lands anywhere upstream, this fork will adopt it.

## Roadmap & issues

- Backlog: [`ROADMAP.md`](ROADMAP.md)
- Open issues: <https://github.com/poooooby/Terrarium/issues>
- Drafts ready to file (UI + roamers + ambient):
  [`.github/issues-draft/`](.github/issues-draft/) —
  `powershell -File .github/issues-draft/create.ps1` after `gh auth login`

## Credits

- **[Dramatic Shape](https://github.com/DramaticShape/DramaticShapeVoxelMod)**
  — the voxel mod this is built on. The diorama, the battles and the shape of
  the whole thing are his.
- **[BrenoBertucci](https://github.com/BrenoBertucci/Terrarium)** — this
  tree's direct upstream. The low-end-hardware tuning, the weather, the
  ecology, the wild Pokemon you can see, and everything else under "What
  Terrarium adds to the original" above are his work on Dramatic Shape's
  base; this fork's own additions are the narrower list under "What this
  fork adds on top of Terrarium."
- **[bryanthaboi](https://github.com/bryanthaboi/gen1recomp)** and the
  Gen1Recomp contributors — the engine, and a mod platform generous enough
  that almost none of this needed a patch.
- **Water shading heavily inspired by Roy Stan’s Toon Water Shader tutorial**
  ([article](https://roystan.net/articles/toon-water/),
  [source](https://github.com/IronWarrior/ToonWaterShader)) — depth-rung
  colour, binary surface-noise foam, and shoreline foam ideas adapted to the
  mod’s voxel/cel system (hard steps, checker dither, analytic swell, no
  depth/normals buffer RT). Not a port of the Unity shader.
- **[Pokemon X/Y 5X GUI](https://gamebanana.com/mods/578206)** — the
  interface art the HUD, the overworld menu and the battle buttons are cut
  from. **The pack is not redistributed here**: crediting an author is not
  the same as holding a licence from them, and the underlying art is
  Nintendo's and Game Freak's whichever way it travels. Download it yourself
  and run [`tools/extract_xy_assets.py`](tools/extract_xy_assets.py), which
  cuts and names everything the mod expects. What this repository keeps is
  the *measurements* — glyph grids, HP trough boxes, button bounds — because
  the pack's files are named by content hash and none of that was written
  down anywhere.
- **Ambient audio** — CC0 recordings by Wolfgang_, isaiah658, Ylmir,
  rubberduck, Luke.RUSTLTD, TinyWorlds, JaggedStone, RandomMind, craigsmith,
  Littleboot, PagDev and Siobhan Leachman, from OpenGameArt, Freesound and
  Wikimedia Commons. Per-file sources, authors and licences are in
  [`assets/audio/CREDITS.md`](assets/audio/CREDITS.md). Everything is CC0 1.0;
  nothing here is CC-BY or CC-BY-SA, deliberately.
- **Overworld wild / town Pokémon sprites** — optional Gen 2-style walker
  sheets under `assets/roamers/`. **Not redistributed here** (same rule as
  the X/Y GUI pack). Install with
  [`tools/install_roamer_sprites.py`](tools/install_roamer_sprites.py)
  from [PokéPC Followers](https://github.com/gamecorner-033/PokePCFollowers)
  (ShockSlayer / Crystal Clear lineage). See
  [`assets/roamers/CREDITS.md`](assets/roamers/CREDITS.md). Without them the
  mod bakes greyscale sheets from each battle front pic.
- **Nintendo, Creatures Inc. and GAME FREAK Inc.** — for the game. It is
  theirs. This is only a coat of paint on a program that loads it.
