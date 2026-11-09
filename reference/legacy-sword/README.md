# Preserved ordinary-sword reference

Exact v09 source snapshots preserve the original sword motion, rendering and broad effects for a future skill. No active skill has been added in v10. weapon_motion.gd can be instantiated as the old motion reference with its default sword family; hero_visual.gd and effects.gd show the matching presentation. game.gd records original timing, forward movement and feedback integration and is a source reference, not a replacement main scene.

Current normal attacks use scripts/sword_motion.gd. This source-only reference is excluded from the playable Windows pack. Byte hashes are recorded in docs/preservation-results.json.
