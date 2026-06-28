# Combat portrait naming

Combat portraits are loaded from:

`res://assets/characters/portraits/<character_id>/<state>.png`

`<character_id>` must match `CharacterData.id`.

Supported state files:

- `normal.png`: default portrait.
- `low_hp.png`: HP is 25% or lower.
- `debuffed.png`: burn, bleed, weak, or vulnerable is active.
- `buffed.png`: block or strength is active.
- `ultimate.png`: ultimate buff is active.
- `down.png`: HP is 0.

Priority is:

`down` -> `ultimate` -> `low_hp` -> `debuffed` -> `buffed` -> `normal`

If a state file is missing, combat UI falls back to `normal.png`.
