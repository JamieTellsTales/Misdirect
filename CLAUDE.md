# Misdirect - Project Guide

## Environment Setup

**Godot Executable Path (IMPORTANT - use this exact path):**
```
C:\Users\jamie\OneDrive - Blakeman Online\Desktop\Godot\Godot_v4.5.1-stable_win64.exe
```

To run the game:
```bash
"C:\Users\jamie\OneDrive - Blakeman Online\Desktop\Godot\Godot_v4.5.1-stable_win64.exe" --path "C:\Users\jamie\Documents\Repos\Misdirect"
```

## Project Overview

- **Game**: Misdirect - an arcade game of skill and misdirection
- **Repository**: https://github.com/JamieTellsTales/Misdirect
- **Engine Version**: Godot 4.5.1
- **Primary Language**: GDScript
- **Project Type**: 2D
- **Target Platforms**: Windows (initial), Steam + Android (post-prototype)

## Game Design (as implemented)

### Core Concept
The arena is a polygon (triangle up to octagon) with a coloured zone on some or all
edges. Balls spawn at the centre and bounce around. Each zone belongs to a colour —
you want to **let your own colour through** into your zone to score points, and
**deflect all other colours** away. Catching a wrong-colour ball costs score (or a
life, depending on game mode).

The player always controls the **GREEN** paddle on the bottom edge (side 0). All
other zones are AI-controlled paddles with per-colour personalities.

### Colours
Defined in `scripts/resources/department_data.gd` (`ColourData`, `ColourType` enum):
BLUE, GREEN, RED, YELLOW, PURPLE, ORANGE, CYAN, PINK. Up to 8 players/zones.

AI personalities live in `ai_paddle.gd::_apply_personality()` — each colour has its
own `reaction_delay`, `accuracy`, `move_speed`, `prediction_strength`, plus quirks
(RED deflects its own colour, YELLOW ignores purple, BLUE panics with many balls,
PURPLE is slow and inaccurate).

### Game Modes (`GameConfig.game_mode`)
- **normal** — timed round (`round_duration`, default 120s). Highest score wins;
  ties are draws. Wrong catch deducts score (floor 0).
- **endless** — no timer. Player has 3 lives; wrong catch costs a life (not score);
  +1 life per 100 points milestone. Game ends when lives hit 0 (`_end_round(true)`).
- **elimination** — no timer. Every zone has 3 lives. At 0 lives, the zone is
  collapsed (`_collapse_zone`): paddle/zone/score display removed and the edge is
  sealed with a wall. Player collapse ends the game; otherwise last zone standing wins.

Lives are drawn as dots near each score display (`_draw_lives` in arena.gd).

### Balls
- Random size 0.5–2.0; smaller = faster, bigger = more points (10–30).
- Wrong-catch penalty chain exists on the ball (`apply_wrong_catch_penalty`:
  speed-up, then blame stamp) **but is currently never called** — zones destroy
  every ball they catch. Known gap vs the original design.

### Maps & Player Counts
`GameConfig.MAP_VALID_PLAYERS` / `MAP_ZONE_SIDES` define which polygon sides are
active zones per (map, player count). Maps: triangle, square, pentagon, hexagon,
heptagon, octagon. Maps unlock via wins on the previous map
(`MAP_UNLOCK_REQUIREMENTS`, checked by `StatsManager.is_map_unlocked`).

### Power-Ups & Modifiers
- **Power-ups** (`GameConfig.POWER_UPS`) are bought with tokens in the shop and
  assigned to up to 3 slots pre-game (`power_up_slots`). Slots unlock by level +
  token fee (`POWER_UP_SLOT_DEFS`; keys SPACE/Q/E). Hold-key power-ups (gravity,
  anti_gravity, cyclone) are handled in `player_paddle.gd`; on-hit power-ups
  (railgun, splits, deflector) in `ticket.gd` / `paddle.gd`.
- **Modifiers** (`GameConfig.MODIFIERS`) are free toggles unlocked by level:
  rotated_colours, chaos_ball, load_balanced, random_directions, extra_time,
  final_countdown, speed_ball, black_hole, gravity_wells, pillars. Implemented
  in arena.gd (spawn logic, `_tick_black_hole`, `_tick_gravity_well`, pillars).

---

## Architecture

### Autoloads (registered in project.godot, in order)

| Autoload          | Purpose                                                             |
|-------------------|---------------------------------------------------------------------|
| `GameConfig`      | Per-run selections: mode, map, player count, power-up slots, modifiers. Canonical POWER_UPS / MODIFIERS lists. `reset()` on PLAY. |
| `ProfileManager`  | Player profiles under `user://profiles/`. Must load before StatsManager. |
| `AudioManager`    | Music crossfade + generated SFX. SFX players use `PROCESS_MODE_ALWAYS` so they play while the tree is paused. |
| `SettingsManager` | Audio/display settings, resolution list (landscape + portrait), persisted to `user://settings.cfg` (device-level, not per-profile). |
| `FontManager`     | Serves the accessibility font (`get_font()`); all UI uses this instead of ThemeDB. |
| `StatsManager`    | Per-profile lifetime stats (per-mode high scores/game counts, wins/draws/losses, tokens + total earned, XP/level, unlocks). Persists via ConfigFile per profile. |

Note: `scripts/autoload/score_manager.gd`, `scripts/ui/queue_display.gd`,
`scripts/resources/ticket_data.gd` are **legacy from the original ticket/SLA
design and are not registered or used**.

### Scene Flow
```
main_menu → mode_select → map_select → pre_game_config → arena
                                                            ├─ pause_menu (overlay, ESC)
                                                            │    └─ settings_screen (overlay; reloads arena on exit)
                                                            └─ game_over (overlay) → replay arena / main_menu
main_menu also → settings_screen, stats_screen, shop, profile_select/profile_setup
```
First run with no profiles jumps straight to profile_setup.

### Key Scripts
```
scripts/
├── autoload/            # See table above (+ legacy score_manager.gd)
├── arena/
│   ├── arena.gd         # THE core script: builds polygon, walls, zones, paddles,
│   │                    #   spawning, modifiers, lives/collapse, round lifecycle
│   └── department_zone.gd  # ColourZone Area2D: catch detection, score_up/score_down/wrong_catch signals
├── ticket/ticket.gd     # Ball (RigidBody2D): size/speed, splits, on-hit power-ups
├── paddle/
│   ├── paddle.gd        # Base CharacterBody2D: slide axis, collision shape, deflector triangle
│   ├── player_paddle.gd # Input + hold-key power-ups
│   └── ai_paddle.gd     # Threat targeting + per-colour personality
├── resources/department_data.gd  # ColourData: colours, names, enum
└── ui/                  # One script per screen; all custom-drawn (see UI conventions)
```

---

## Development Workflow

### Running & Testing
```bash
# Run the game
"C:\Users\jamie\OneDrive - Blakeman Online\Desktop\Godot\Godot_v4.5.1-stable_win64.exe" --path .

# Validate a script (NOTE: autoload references produce FALSE-POSITIVE
# "Identifier not found" errors under --check-only — ignore those; only
# genuine syntax/indentation errors matter)
"C:\Users\jamie\OneDrive - Blakeman Online\Desktop\Godot\Godot_v4.5.1-stable_win64.exe" --path . --check-only --script scripts/example.gd

# Debug collisions
"C:\Users\jamie\OneDrive - Blakeman Online\Desktop\Godot\Godot_v4.5.1-stable_win64.exe" --path . --debug-collisions
```

### Git Workflow
- Commit directly to `main`
- Use conventional commits: `feat:`, `fix:`, `refactor:`

---

## Coding Standards

### GDScript Style
```gdscript
# Use typed variables
var speed: float = 300.0

# Type function parameters and returns
func catch_ball(ball: Ball) -> void:
    ...

# Use @export for tunable properties
@export var paddle_speed: float = 400.0

# Use @onready for node references
@onready var collision: CollisionShape2D = $CollisionShape2D

# Signals use past tense
signal ticket_caught(ball: Ball)
```

### UI Conventions (important — all screens follow this pattern)
- Screens are `Node2D` (overlays are `Control`/`Node2D`) drawn **entirely in
  `_draw()`** — no Control-based layouts. Text via
  `draw_string(FontManager.get_font(), ...)`.
- Mouse hit-testing: build `Rect2`s during `_draw()`, test them in
  `_unhandled_input`. Buttons play `AudioManager.play_button_hover()/click()`.
- Every screen supports both mouse and keyboard (arrows + `ui_accept`/`ui_cancel`).
- `CornerHUD.draw_on(self)` at the end of menu screens draws the profile/level/token box.

---

## Known Patterns & Gotchas

### Coordinates & Scaling
- Stretch mode is `canvas_items` + `expand` (base 1280×720). At non-1× window
  scale, **`event.position` (window px) ≠ canvas coordinates**. For hit-testing
  against rects computed in `_draw()`, use `get_global_mouse_position()` —
  this bug has bitten pause_menu and settings_screen before.
- **Portrait mode**: arena.gd scales the polygon to fill the canvas width and
  stores `_arena_scale` (~2.1× on phone portrait). Every size/speed/force
  constant used in the arena must be multiplied by `_arena_scale` (balls take it
  via their `arena_scale` property). When adding arena features, scale them.
- Do **not** add a Camera2D to the arena — a previous one at (640,360) broke
  portrait layouts and was removed deliberately.

### Pause & Scene Lifecycle
- `SceneTree.paused` persists across `reload_current_scene()` / scene changes —
  always `get_tree().paused = false` before reloading or leaving.
- game_over_screen and pause overlays use `PROCESS_MODE_ALWAYS`; the arena pauses
  the tree when results show.
- Closing settings mid-game reloads the arena scene (physics nodes can't be
  repositioned safely after a resolution change) — this restarts the round.

### Physics
- Paddles: `CharacterBody2D`, moved along a slide axis (`move_direction`,
  `min_offset`/`max_offset` from `zone_centre`); rotation orients them to their edge.
  Arena sets all movement properties **before** `add_child()` so `_ready()` has them.
- Balls: `RigidBody2D` with bounce 1.0 / friction 0.0 material; speed clamped every
  physics frame between size-scaled min/max.
- Zones: `Area2D` outside the polygon edge (the wall is omitted on zone sides);
  `body_entered` = caught. Walls: `StaticBody2D` rectangles per polygon edge.
- Ball splits: arena's `_on_ball_split` frees the original and spawns children with
  divergent velocities; split children can't re-split (`can_split`).

### Persistence
- Everything saves through `ConfigFile` under `user://` — settings are
  device-level; stats are per-profile (`user://profiles/<id>/stats.cfg`).
- When adding a stat: add the var, default it in `load_stats()`, read it there,
  write it in `save_stats()`, and update it in `record_game_end()` if per-game.

### Performance
- Balls capped via `max_balls` (default 10) checked in `_try_spawn_ball()`.
