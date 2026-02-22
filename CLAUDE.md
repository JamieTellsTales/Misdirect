# Misdirect - Project Guide

## Environment Setup

**Godot Executable Path (IMPORTANT - use this exact path):**
```
C:\Users\jamie\OneDrive\Desktop\Godot\Godot_v4.5.1-stable_win64.exe
```

To run the game:
```bash
"C:\Users\jamie\OneDrive\Desktop\Godot\Godot_v4.5.1-stable_win64.exe" --path "C:\Users\jamie\Documents\Repos\Misdirect"
```

## Project Overview

- **Game**: Misdirect - a strategic arcade game where IT departments deflect wrong-colour tickets and catch their own
- **Engine Version**: Godot 4.5.1
- **Primary Language**: GDScript
- **Project Type**: 2D
- **Target Platforms**: Windows (initial), Steam + Android (post-prototype)

## Game Design Overview

### Core Concept
The play area is a rectangular arena with IT departments occupying each edge/zone. Tickets (balls) bounce around the arena. Each department has a colour — you want to **catch your own colour** tickets to score points and clear your queue, and **deflect all other colours** away from your zone. Catching the wrong ticket triggers a penalty chain.

### Departments & Ticket Colours

| Department     | Colour  | Ticket Traits                                                                 |
|----------------|---------|-------------------------------------------------------------------------------|
| Service Desk   | Blue    | Fast, frequent, low value. Swarm in large numbers.                            |
| Infrastructure | Green   | Slow, heavy, high value. Large hitbox, predictable movement.                  |
| Security       | Red     | Unpredictable, changes direction mid-flight. Escalates if wrongly caught.     |
| Development    | Yellow  | Start slow, randomly accelerate. Deceptively manageable at first.             |
| Management     | Purple  | Huge, slow, massive hitbox. Rare but clogs queues badly if caught wrongly.    |

### Paddle & Zone Mechanics
Each department has a paddle that **deflects** tickets back into play. Behind the paddle is the department's **zone** — if a ticket gets past the paddle and enters the zone, it is **automatically caught** by that department.

- **Paddle** — deflects tickets back into the arena
- **Zone** — any ticket entering the zone is caught (added to that department's queue)

The player controls one department. All other departments are AI-controlled with personalities (see AI section). The goal is to deflect wrong-colour tickets away while letting your own colour through to be caught.

### Ticket Queue & Scoring
- Each department has a visible queue with a counter
- Catching your own colour ticket adds it to your queue; tickets are cleared automatically over time (simulating resolution)
- Each resolved ticket scores points based on ticket type
- SLA timers count down on queued tickets — missing SLA loses points
- Wrong-colour tickets in your queue **cannot be resolved** — they drain your SLA timer and must be manually reassigned

### Wrong Ticket Penalty Chain
Catching the wrong colour triggers an escalating penalty:
1. **First offence** — ticket re-enters play at increased speed
2. **Second offence (or catching another wrong ticket quickly)** — ticket splits into two on re-entry
3. **Accumulated wrong catches** — point deduction and a "blame stamp" placed on the ticket (other departments get a bonus for catching a stamped ticket you misdirected)

### Ticket Types & Special Behaviours

| Type                     | Behaviour                                              |
|--------------------------|--------------------------------------------------------|
| Password Reset           | Fast, predictable, common                              |
| Network Outage           | Slow, large, high value                                |
| Phishing Alert           | Erratic movement, splits on wrong catch                |
| Feature Request          | Accelerates randomly after a few bounces               |
| "Can you just quickly…"  | Splits into three smaller tickets on first deflect     |
| Vague Strategic Request  | Enormous hitbox, very slow, almost impossible to dodge |

### Win / Lose Conditions
- **Win** — survive until end of the working day (time-limited round) with the highest score
- **Lose** — queue overflows past maximum capacity (department collapses and is out of the round)
- Optional: last department standing mode

### AI Department Personalities
AI departments should feel believable and satirical:
- **Service Desk AI** — reactive, occasionally panics and misses their own tickets
- **Infrastructure AI** — slow to respond, rarely misses but takes its time
- **Security AI** — paranoid, deflects almost everything including its own tickets sometimes
- **Development AI** — distracted, will ignore tickets that look like Management colour
- **Management AI** — almost never catches anything, somehow avoids blame

---

## Project Architecture

### Autoloads (Global Singletons)

| Autoload         | Purpose                                                        |
|------------------|----------------------------------------------------------------|
| `Global`         | Game state, scores, round settings, active departments         |
| `RoundManager`   | Round timer, win/lose detection, phase transitions             |
| `TicketManager`  | Spawns tickets, manages ticket pool, tracks ticket state       |
| `ScoreManager`   | Points, SLA tracking, penalty chain state per department       |
| `AudioManager`   | Sound effects and music                                        |
| `InputManager`   | Global keyboard shortcuts, pause handling                      |

### Key Signals

```gdscript
# TicketManager
signal ticket_spawned(ticket: Ticket)
signal ticket_caught(ticket: Ticket, department: Department)
signal ticket_wrong_catch(ticket: Ticket, department: Department)
signal ticket_split(original: Ticket, new_tickets: Array)

# ScoreManager
signal score_changed(department: Department, new_score: int)
signal sla_missed(ticket: Ticket, department: Department)
signal penalty_applied(department: Department, penalty_type: String)

# RoundManager
signal round_started
signal round_ended(winner: Department)
signal department_collapsed(department: Department)
```

### Project Structure
```
Misdirect/
├── scenes/
│   ├── main_menu.tscn          # Start screen, department select
│   ├── arena.tscn              # Main gameplay scene
│   ├── hud.tscn                # Score, queue, SLA timers overlay
│   ├── game_over.tscn          # End of round results screen
│   └── components/
│       ├── ticket.tscn         # Individual ticket ball
│       ├── paddle.tscn         # Department paddle (player or AI)
│       ├── queue_display.tscn  # Per-department queue UI
│       └── department_zone.tscn # Arena zone ownership area
├── scripts/
│   ├── autoload/
│   │   ├── global.gd
│   │   ├── round_manager.gd
│   │   ├── ticket_manager.gd
│   │   ├── score_manager.gd
│   │   ├── audio_manager.gd
│   │   └── input_manager.gd
│   ├── arena/
│   │   ├── arena.gd            # Arena setup, boundary logic
│   │   └── department_zone.gd  # Zone ownership and collision
│   ├── ticket/
│   │   ├── ticket.gd           # Base ticket physics and state
│   │   └── ticket_types.gd     # Ticket type definitions and behaviours
│   ├── paddle/
│   │   ├── paddle.gd           # Base paddle logic
│   │   ├── player_paddle.gd    # Player input handling
│   │   └── ai_paddle.gd        # AI behaviour per department personality
│   ├── ui/
│   │   ├── hud.gd
│   │   ├── queue_display.gd
│   │   └── sla_timer.gd
│   └── resources/
│       ├── department_data.gd  # Department colour, name, personality config
│       └── ticket_data.gd      # Ticket type definitions as resources
├── assets/
│   ├── sounds/
│   │   ├── catch.wav
│   │   ├── deflect.wav
│   │   ├── wrong_catch.wav
│   │   ├── split.wav
│   │   └── music/
│   └── fonts/
├── docs/
│   ├── game_design.md          # Full GDD (this file summarised)
│   ├── ticket_types.md         # Ticket behaviour reference
│   ├── ai_behaviour.md         # AI personality rules
│   └── steam_notes.md          # Steam integration notes for later
└── project.godot
```

---

## Development Workflow

### Running & Testing
```bash
# Run the game
"C:\Users\jamie\OneDrive\Desktop\Godot\Godot_v4.5.1-stable_win64.exe" --path .

# Validate a script
"C:\Users\jamie\OneDrive\Desktop\Godot\Godot_v4.5.1-stable_win64.exe" --path . --check-only --script scripts/example.gd

# Run headless
"C:\Users\jamie\OneDrive\Desktop\Godot\Godot_v4.5.1-stable_win64.exe" --path . --headless

# Debug collisions (useful for paddle/ticket hitbox tuning)
"C:\Users\jamie\OneDrive\Desktop\Godot\Godot_v4.5.1-stable_win64.exe" --path . --debug-collisions
```

### Git Workflow
- Create feature branches: `feature/feature-name`
- Use conventional commits: `feat:`, `fix:`, `refactor:`
- Create PRs, then merge when ready
- Always pull main after merging

### Build Priority Order
Build in this order to keep a playable state at all times:
1. Arena boundaries + single bouncing ticket
2. Department zones + paddle collision
3. Player-controlled paddle
4. Zone catching + queue display
5. Ticket colour matching + wrong catch penalty chain
6. AI department paddles with basic personalities
7. Multiple ticket types with behaviours
8. Scoring + SLA timers
9. Win/lose conditions + round flow
10. Sound, juice, polish

---

## Coding Standards

### GDScript Style
```gdscript
# Use typed variables
var speed: float = 300.0
var department_colour: Color = Color.BLUE

# Type function parameters and returns
func catch_ticket(ticket: Ticket) -> void:
    if ticket.department_type == self.department_type:
        score_manager.add_correct_catch(ticket)
    else:
        score_manager.apply_wrong_catch_penalty(ticket, self)

# Use @export for tunable properties (keeps things tweakable in editor)
@export var paddle_speed: float = 400.0
@export var queue_resolve_time: float = 3.0  # seconds per ticket

# Use @onready for node references
@onready var collision: CollisionShape2D = $CollisionShape2D

# Signals use past tense
signal ticket_caught(ticket: Ticket)
signal queue_overflowed
```

### Department Type Enum
Always use the shared enum for department identity:
```gdscript
enum DepartmentType {
    SERVICE_DESK,
    INFRASTRUCTURE,
    SECURITY,
    DEVELOPMENT,
    MANAGEMENT
}
```

### Ticket State Machine
Tickets should always be in one of these states:
```gdscript
enum TicketState {
    IN_PLAY,      # Bouncing around the arena
    CAUGHT,       # Held in a department queue
    REASSIGNED,   # Batted back out after wrong catch
    RESOLVED,     # Cleared from queue, award points
    ESCALATED     # Split state triggered
}
```

---

## Known Patterns & Gotchas

### Physics
- Use `CharacterBody2D` for paddles (direct movement control)
- Use `RigidBody2D` for tickets (physics-driven bouncing)
- Set `physics_material_override` on tickets for bounciness — bounce = 1.0, friction = 0.0
- Speed cap tickets via `linear_velocity = linear_velocity.normalized() * max_speed` in `_physics_process` to prevent runaway acceleration

### Arena Boundaries
- Use `StaticBody2D` with `CollisionShape2D` segments for walls
- Department zones are `Area2D` nodes — use `body_entered` signal to detect tickets entering the zone
- When a ticket enters a zone, it is automatically caught by that department (no manual catch action needed)

### AI Paddle Behaviour
- AI paddles use a simple target-following approach: lerp toward the ticket's predicted X/Y position
- Each personality has a `reaction_delay: float` and `accuracy: float` (0.0–1.0) to simulate mistakes
- Management AI has a very high `reaction_delay` and low `accuracy` by design

### Splittig Tickets
- When a ticket splits, free the original and spawn two new tickets from `TicketManager`
- Apply slightly divergent velocities (e.g. ±30 degrees from original direction)
- Preserve the original department colour and type on children

### Performance
- Pool tickets rather than instancing/freeing repeatedly — use a `TicketPool` in `TicketManager`
- Cap maximum simultaneous tickets at 12 to prevent chaos beyond playability
