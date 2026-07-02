# Too Fast to Die: Road to Oasis Documentation Index

This directory contains the current source-of-truth design documents.

## Current Documents

### `design/`

- `design/gdd-core.md`: game overview, world, factions, core combat, map, resources, shops, karma, enemies, cards, balance rules
- `design/gdd-characters.md`: playable characters, character-specific mechanics, character arcs, unique NPCs, character endings
- `design/gdd-pc-redesign.md`: current 5-PC roster and replacement mechanics for PC-specific combat systems
- `design/gdd-companions.md`: companion system, sidecar expansion, unique companion pool
- `design/gdd-events.md`: travel events, cruel events, pleasure/addiction systems, event text rules
- `design/gdd-narrative.md`: Oasis, ending structure, ambient road-movie fragments, pregnancy endings

### `lore/`

- `lore/lore-rules.md`: required rules for creating enemies, settlements, NPCs, faction sites, and other lore
- `lore/world-rules.md`: world-specific sexual depiction rules

### `writing/`

- `writing/pc-profiles.md`: PC sexual attitude profiles and NPC definitions
- `writing/context-types.md`: scene/context taxonomy and text templates
- `writing/ambient-fragments.md`: road-movie ambient fragments

### `art/`

- `art/character-visuals.md`: character visual design and image-generation prompts
- `art/image-generation-prompts.md`: prompts for enemies, backgrounds, title, logo, and UI assets

### `scenarios/`

- `scenarios/substories/devilf-pack.md`: Devilf pack substory design and implementation template
- `scenarios/substories/big-rick.md`: Big Rick substory design
- `scenarios/events/hornet-heat-event.md`: Hornet heat event draft
- `scenarios/events/hornet-poisoned.md`: Hornet poisoned event draft

### `planning/`

- `planning/remaining-tasks.md`: current remaining task list

## Archive

`archive/` contains completed design notes, superseded task lists, and historical amendment documents. Archive files are useful for provenance, but they are not authoritative when they conflict with current files.

## Root-Level Legacy Files

- `../Too_Fast_to Die_gdd_v2.md` is a pointer only. The split `design/gdd-*.md` files are authoritative.
- `../Too_Fast_to Die_implementation_spec.md` is a legacy implementation note; PC roster and unique mechanics defer to `design/gdd-pc-redesign.md` and current implementation.
- `../character_design.md` is a pointer only. `art/character-visuals.md` is authoritative.
- `../CLAUDE.md` is authoritative for agent/project instructions.
- `../AGENTS.md` is a mirror for tools that read AGENTS-style instructions.

## Conflict Rule

Prefer implemented behavior and `.tres` data over older design prose. When PC roster, character names, or unique combat mechanics conflict, `design/gdd-pc-redesign.md` overrides older `design/gdd-characters.md`, companion, narrative, and root-level implementation prose.

Current resolutions:

- Working title: `Too Fast to Die: Road to Oasis`
- Current timeline: 32 years after the collapse
- Playable roster: 5 PCs (`アータル`, `ホーネット`, `ウェズリー`, `ミーシャ`, `ホタル`)
- Old names are retired in current docs and UI text: `アタルパ` -> `アータル`, `ヴェスパ` -> `ホーネット`
- `覇者` is no longer a playable character; keep him as a future unique companion/NPC reference only.
- The hitchhiker is currently defined as a unique companion slot.
- Luto is tied to the Conqueror/NPC material, not the current playable roster.
- Nora as a Cultist dedicated companion is abolished; her useful elements are absorbed into a separate neon-addicted punk unique NPC concept.
