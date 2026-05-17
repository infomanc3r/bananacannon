<h2 style="text-align: center;"> the fresh prince's bananacannon 2.0 </h2>

<p align="center">
  <img src="https://steamusercontent-a.akamaihd.net/ugc/12856631034461867284/1F8CD21A046FF16162C250F118E0510B01C15BA4/" alt="Kibo, Uktabi Prince" />
</p>

A Tabletop Simulator Lua accessory for [Kibo, Uktabi Prince](https://scryfall.com/card/bro/196/kibo-uktabi-prince) Commander decks. Kibo's ability creates Banana tokens - which Wizards never printed - meaning they don't exist in TTS either. This fixes that, and then keeps going.

<h2 style="text-align: center;"> Features </h2>

- **FIRE BANANAS!** — spawns 4 banana tokens at the table cannon's muzzle and fires them across the battlefield with nanner-related audio
- **SPAWN PILE / SPAWN ONE** — spawns bananas next to the panel for normal gameplay
- **CLEAN UP** — removes all spawned bananas from the table
- **BANANAPOCALYPSE** — 1500 bananas, 6 cannon volleys, a cheerleader screaming "AND IT'S A BANANA!!!", and a two-click confirmation because you will accidentally hit this
- **Mute toggle** — for when your opponents are less enthusiastic than you are

## Install (recommended)

Subscribe via Steam Workshop:
**[the fresh prince's bananacannon 2.0](https://steamcommunity.com/sharedfiles/filedetails/?id=YOUR_WORKSHOP_ID)** on the TTS Workshop page

1. Click Subscribe
2. Open Tabletop Simulator → Workshop → the fresh prince's bananacannon 2.0 → Load
3. Right-click the panel → **Save Object** to add it to your personal Saved Objects library
4. From now on: spawn it onto any Magic table from your Saved Objects menu

## Install (from source)

If you want to customize the script, the source is in this repo. See
[`kibo_banana_cannon.lua`](./kibo_banana_cannon.lua) for the main script.
You'll need to attach it to a Custom Tile in TTS yourself. See the
in-file comments for setup.

## Setup

- Auto-discovers the cannon by scanning for name/description keywords (`cannon`, `mortar`, `launcher`) and a `FireCannon` button — no manual GUID setup needed for most tables
- Hosts all banana mesh, texture, and audio via Steam Cloud — no local assets required at runtime
- Works out of the box on the ["MTG 4 player table - scripted"](https://steamcommunity.com/sharedfiles/filedetails/?id=2296042369) Commander table mod by Oops I Baked A Pie

To pin it to a specific cannon (useful once you've found yours), set `CANNON_GUID_OVERRIDE` at the top of the script.

## Files

| File | What it is |
|---|---|
| `bananacannon.7b64f3.lua` | the script — attach this to a Custom Tile in TTS |
| `banana.obj` | low-poly banana mesh |
| `banana_collider.obj` | simplified physics collider |
| `banana_texture.jpg` | banana diffuse texture |
| `banana_preview.png` | card art preview |

The mesh and texture are hosted on Steam Cloud; the files here are the source originals, lovingly hand-crafted by Claude.

## Technical notes

Cannon spawning bypasses the cannon mod's `AddObjects` function (which requires a player selection) and instead places bananas directly at the muzzle using local-space offsets read from the cannon's source. Physics are applied via `Wait.time` after a short delay since `setVelocity` silently fails during the spawning phase.

Audio runs through `MusicPlayer` — TTS has no proper SFX API. Each clip has a hardcoded duration field so we can pause at the right moment and prevent the table's default music from bleeding in. First playthrough is sequential; subsequent cycles are shuffled.

BANANAPOCALYPSE spawns in batches of 10 on a 60ms interval to stay under TTS's object-spawn rate limits. About 25% of bananas get randomized horizontal velocity for chaos texture.

## Go forth

the bananas are calling.
<p align="center">
  <img src="https://steamusercontent-a.akamaihd.net/ugc/16946525810598035048/C374DA862FD5E42B9A708E53DCB0A11AAF5E34EA/" alt="Kibo, Uktabi Prince" />
</p>


