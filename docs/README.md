# Too Fast to Die: Road to Oasis Documentation Index

This directory contains the current source-of-truth design documents.

## Source of Truth

- `gdd-core.md`: game overview, world, factions, core combat, map, resources, shops, karma, enemies, cards, balance rules
- `gdd-characters.md`: playable characters, character-specific mechanics, character arcs, unique NPCs, character endings
- `gdd-pc-redesign.md`: current 5-PC roster and replacement mechanics for PC-specific combat systems
- `gdd-companions.md`: companion system, sidecar expansion, unique companion pool
- `gdd-events.md`: travel events, cruel events, pleasure/addiction systems, event text rules
- `gdd-narrative.md`: Oasis, ending structure, ambient road-movie fragments, pregnancy endings
- `character-visuals.md`: character visual design and image-generation prompts
- `pc-profiles.md`: PC sexual attitude profiles and NPC definitions
- `context-types.md`: scene/context taxonomy and text templates
- `world-rules.md`: world-specific sexual depiction rules
- `残りタスク.md`: current remaining task list

## Scenario and Event Drafts

- `substory-devilf-pack.md`: Devilf pack substory design and implementation template
- `vespa_heat_event.md`: Wasp heat event draft
- `vespa_poisoned.md`: Wasp poisoned event draft

## Tool Design

- `tools/debug_resource_editor_design.md`: debug resource editor design
- `tools/test_play_simulator_plan.md`: test-play simulator plan

## Archive

`archive/` contains old planning notes and historical amendment documents. Archive files are not authoritative when they conflict with current files.

## Root-Level Legacy Files

- `../Too_Fast_to Die_gdd_v2.md` is a pointer only. The split `gdd-*.md` files are authoritative.
- `../Too_Fast_to Die_implementation_spec.md` is a legacy implementation note; PC roster and unique mechanics defer to `gdd-pc-redesign.md` and current implementation.
- `../character_design.md` is a pointer only. `character-visuals.md` is authoritative.
- `../CLAUDE.md` is authoritative for agent/project instructions.
- `../AGENTS.md` is a mirror for tools that read AGENTS-style instructions.

## Conflict Rule

Prefer implemented behavior and `.tres` data over older design prose. When PC roster, character names, or unique combat mechanics conflict, `gdd-pc-redesign.md` overrides older `gdd-characters.md`, companion, narrative, and root-level implementation prose.

Current resolutions:

- Working title: `Too Fast to Die: Road to Oasis`
- Current timeline: 32 years after the collapse
- Playable roster: 5 PCs (`アータル`, `ワスプ`, `ウェズリー`, `ミーシャ`, `ホタル`)
- Old names are retired in current docs and UI text: `アタルパ` → `アータル`, `ヴェスパ` → `ワスプ`
- `覇者` is no longer a playable character; keep him as a future unique companion/NPC reference only.
- The hitchhiker is currently defined as a unique companion slot.
- Luto is tied to the Conqueror/NPC material, not the current playable roster.
- Nora as a Cultist dedicated companion is abolished; her useful elements are absorbed into a separate neon-addicted punk unique NPC concept.
