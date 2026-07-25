# Hero Turrets Redux (Langmans Fork)

Your turrets carry salvaged, self-learning AI from your ship. The more they fight, the deadlier they get — kill enough enemies (or optionally deal enough damage) and a turret automatically promotes itself, in place, into a stronger version of itself, no rebuilding required.

This is a fork of [HeroTurrets_Redux](https://mods.factorio.com/mod/HeroTurretRedux) by fortheking55 (itself a port of the original [HeroTurrets](https://mods.factorio.com/mod/heroturrets) by btarrant for Factorio 2.0/Space Age), continued and extended as a separate mod (`HeroTurretsReduxFork`) for Factorio 2.1.

## How ranking works

Every turret starts at rank 1 and can be promoted through six ranks by default:

1. Private 1st Class
2. Corporal
3. Sergeant
4. General
5. Field Marshal
6. Supreme Commander

By default, promotion is based on **kills**: 150 / 1,000 / 2,500 / 5,000 / 10,000 / 20,000 kills for ranks 1–6. You can optionally also enable **"Rank by Damage"**, so turrets that deal a lot of damage without necessarily landing the finishing blow (e.g. against tough enemies) can still promote once one of their kills pushes their total damage dealt over a rank's threshold.

Everything about ranking is configurable in the mod settings:
- Custom rank names (up to 12), replacing the default six.
- Custom kill and/or damage thresholds per rank.
- A global "Rank Modifier" to scale all thresholds up or down.
- Separate kill/damage multipliers for ammo, fluid, electric, and artillery turrets.

## What a higher rank gives you

Each rank adds a percentage bonus, building up from about 12% at the first rank to 60% at the top rank by default. Unless you set custom values, the same percentage applies across the board to:

- Damage dealt
- Max health
- Range
- Fire rate / cooldown
- Attack (turret rotation / aiming) speed

Each of these can be given its own independent custom bonus curve in the settings, and there's a separate "Rank Buff Modifier" to scale all bonuses up or down globally.

## What happens when a turret ranks up

The promotion happens instantly, in place — no downtime, no manual rebuilding. The mod swaps the turret for its higher-rank version (using the game's native fast-replace where possible) and carries over:

- Loaded ammo, fluid, and stored energy
- Current health (unless "Set Health to Max on Rank Up" is enabled)
- Kill/damage counters
- Priority target list and "ignore unlisted targets" setting
- Circuit and logistic network connections and their conditions

If you have rank-up notifications enabled (on by default, per player), you'll see a floating rank name and a brief light flash above the turret, plus either a local sound at the turret or a clickable alert (your choice), when it promotes.

## Picking up ranked turrets

The **Kill Counter** setting controls what happens when you mine/pick up a ranked turret:

- **Fuzzy** (default): the turret keeps its rank, but its kill count resets to just enough to justify that rank rather than the exact number.
- **Exact**: the turret keeps its precise kill count (and damage dealt, if "Retain Damage Counter" is also on), stored as a tag on the item. Because each item can carry a different exact count, this can result in several separate item stacks in your inventory.
- **Disable**: the turret loses its rank entirely and reverts to a plain base turret when picked up.

Two more settings affect ghosts and blueprints, both **disabled by default** (meaning ranked turrets are downgraded to plain base turrets in these cases unless you turn them on):
- **Allow ranked ghosts** — lets construction robots rebuild a destroyed turret at its original rank instead of from scratch.
- **Allow ranked turrets in blueprints/copy-paste** — keeps a turret's rank when it's blueprinted or copy-pasted.

## Turret & mod compatibility

Supported turret types: ammo, fluid (e.g. flamethrower), electric (e.g. laser), and artillery turrets — both vanilla and most modded turrets, including Space Age. Artillery turrets have their own on/off toggle since ranking them up can't use fast-replace; if you disable artillery ranking after already ranking some up, those turrets need to be picked up and placed again to revert.

Not ranked, by design (matched by entity name, not a hard mod-name check, so this list is best-effort):
- Turrets from the [Water Turret](https://mods.factorio.com/mod/WaterTurret) mod (water/steam turrets)
- Turrets from the [Vehicle turrets](https://mods.factorio.com/mod/Vehicle-turrets) mod (vehicle-mounted gun/rocket turrets)
- Meteor-defense turrets, most likely from Space Exploration (unconfirmed which exact mod)
- A "big artillery turret" from an unidentified mod (couldn't be confirmed via the Mod Portal)
- Shield domes and creative-mode turrets

Yuoki Turrets is listed as an optional mod, with a compatibility fix dating back to before this mod's Factorio 2.1/Space Age port — it has not been re-verified against current Yuoki versions on 2.1, so treat it as untested rather than guaranteed. The Concentrated Solar and a Zeus Turret mod are intentionally skipped until their known issues are fixed.

## In-game wiki (Informatron)

If you have the [Informatron](https://mods.factorio.com/mod/informatron) mod installed, this mod adds its own set of help pages to it — covering ranks & promotion, rank bonuses, what happens on rank-up, how picking up ranked turrets works, and turret/mod compatibility. Informatron is entirely optional; without it, nothing changes.

## Credits

- Original mod: [HeroTurrets](https://mods.factorio.com/mod/heroturrets) by btarrant
- Factorio 2.0/Space Age port: [HeroTurrets_Redux](https://mods.factorio.com/mod/HeroTurretRedux) by fortheking55
- This fork (Factorio 2.1): Langmans
