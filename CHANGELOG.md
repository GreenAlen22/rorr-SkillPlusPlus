# Changelog

All notable Skills++ changes.

## [0.3.0]

### Added

- **Player drone:** when you die and become a drone, every point you spent levels up its attack: +20% damage per point, and its hits heal the nearest living ally for 10% of the damage dealt. Your skill levels are back as they were after the revival.

### Changed

- **Commando:** Double Tap - +8% skill attack speed and +10% chance to fire a second bullet per level; Combat Knife - +2 Rusty Knife bleeds on hit per level instead of damage.
- **Huntress:** Pierce - +20% damage and +20% arrow size per level; Laser Glaive - +1 bounce and +20% damage per bounce per level; Blink - +1 charge per level, no invulnerability; Warp Dart - +25% landing blast radius and +0.5s invulnerability after the teleport per level.
- **Bandit:** Whip - +10% chance to fire a chain lightning and +20% reach per level; Dynamite Toss - +20% blast radius and +1 stick per throw per level; Lights Out - +25% damage to targets below half health per level, no plain damage bonus; Standoff - +10% Standoff duration and +10% damage per Standoff stack per level.
- **Engineer:** Mortar Barrage - +10% blast radius per level and +1 shell every 2 levels; Bounding Mine - +1 mine per drop per level; Thermal Harpoons - +10% damage and +1 harpoon per volley per level.
- A charge every level now reads "+1 (+1 per level) charge".

## [0.2.1]

### Fixed

- **Compatibility with Primary Skill Evolution:**
  - the primary skill's level moves one row up, off that mod's ammo counter;
  - Double Tap's and Clusterfire's extra bullets turn toward the cursor once, like the shot, instead of twice as far;
  - upgrades of the primary keep working during that mod's reload: on the last round of a magazine and on grenades and shells that land while reloading.
- **For modders:** `rank` reads the slot's own skill while another mod's temporary skill, such as a reload, holds the slot.

## [0.2.0]

### Added

- **API for survivor mods:** own upgrades for modded skills - numbers, effects of their own that read the skill level, or "cannot be leveled", with their own description line. See the wiki page For modders.
- `spp_status` shows how many skills other mods registered.

## [0.1.0]

### Added

- **Skill points:** one every 5 team levels (adjustable from 1 to 10 in the mod options; online, the host's setting counts).
- **Skill levels:** spend a point to level up one of your skills. Hold Alt (L3 on a gamepad) and the skill key, or hold Tab and click the skill icon. A right-click with Tab held undoes the last purchase within 3 seconds.
- **Own upgrades for every skill of all 16 survivors:** Commando, Huntress, Enforcer, Bandit, HAN-D, Engineer, Miner, Sniper, Acrid, Mercenary, Loader, CHEF, Pilot, Artificer, Drifter, and ROBOMANDO, alternatives and Ancient Scepter versions included.
- A generic bonus for skills of modded survivors.
- Skill levels and free points shown on the HUD.
- The upgrade line at the bottom of every skill description.
- Mod options: point interval and the upgrade key.
- Multiplayer support.
- English and Russian localization.
