# GodotNodes+

A reusable component-based library of nodes for Godot 4, favouring composition over inheritance.

Add health, damage, shields, cooldowns, state machines, object pooling, save/load, projectiles, and more to any entity — without writing boilerplate.

## Features

- **Composition-first** — attach only what you need. A player = Sprite2D + Health + Hurtbox2D + StateMachine.
- **Cross-dimension** — 2D and 3D variants for most systems.
- **Synergistic** — nodes are designed to work together. StatusEffect ticks on Health, TimerLabel displays Cooldown, Follow2D tracks Target2D.
- **Editor dock** — browse and add nodes with one click via the NodesPlus sidebar.
- **Signal-driven** — every component emits typed signals for decoupled game logic.

## Installation

1. Copy `addons/nodes_plus/` into your project's `addons/` directory.
2. Enable it in **Project Settings → Plugins**.
3. The **NodesPlus** dock appears in the bottom-left editor panel.

## Quick Start

Add health to a player:

1. In the NodesPlus dock, click **Health**.
2. Set `max_health` to `100` in the inspector.
3. Connect the `health_depleted` signal to handle death.
4. Call `apply_damage(10)` from an enemy's Hitbox2D.

```gdscript
# Some enemy script
$Hitbox2D.damage_node.apply_damage($Player/Health)
```

Add a StateMachine:

1. Click **StateMachine** and **State** from the dock.
2. Add child State nodes (idle, run, jump).
3. Override `enter()`, `update()`, `exit()` in each state.
4. Call `$StateMachine.change_state($StateMachine/Idle)`.

## Node Reference

### Stats

| Node | Base | Description |
|------|------|-------------|
| Health | Node | HP management with `health_changed` and `health_depleted` signals. |
| Damage | Node | Damage value with crit chance and multiplier. |
| Shield | Node | Absorbs damage before Health. Supports recharge and break. |
| Regeneration | Node | Heals Health and Shield over time. |
| Cooldown | Node | Ready/not-ready timer for abilities. Supports pause and auto-restart. |
| Lifespan | Node | Auto-queue_free, hide, or signal after a duration. |
| StatusEffect | Node | Temporary property modifiers + DoT/HoT tick system with stacking. |

### Combat (2D & 3D)

| Node | Base | Description |
|------|------|-------------|
| Hitbox2D / Hitbox3D | Area2D / Area3D | Deals damage to Hurtbox nodes. One-shot and group filtering support. |
| Hurtbox2D / Hurtbox3D | Area2D / Area3D | Receives damage, delegates to Health/Shield. Invincibility frames. |

### Movement & Tracking (2D & 3D)

| Node | Base | Description |
|------|------|-------------|
| Follow2D / Follow3D | Node | Smooth lerp-based position following. |
| Target2D / Target3D | Area2D / Area3D | Lock-on detection with auto-acquire and nearest-target selection. |
| Projectile2D / Projectile3D | CharacterBody2D / CharacterBody3D | Physics-based projectiles with collision, max distance, and lifespan integration. |

### Interaction (2D & 3D)

| Node | Base | Description |
|------|------|-------------|
| InteractionArea2D / InteractionArea3D | Area2D / Area3D | Input-triggered interaction with nearest-body detection, cooldown, and one-shot. |

### Spawning

| Node | Base | Description |
|------|------|-------------|
| Spawner | Node | Timed or on-demand scene spawning with limits. |
| ObjectPool | Node | Reusable instance pool with prewarm, growth, and auto-return. |

### State Machine

| Node | Base | Description |
|------|------|-------------|
| StateMachine | Node | Manages state transitions with `change_state()`. |
| State | Node | Base class with `enter()`, `exit()`, `update()`, `physics_update()`, `handle_input()`. |

### Save / Load

| Node | Base | Description |
|------|------|-------------|
| Save | Node | JSON serialization with automatic data collection via `save_targets`. |
| Load | Node | Loads and applies saved data to target nodes. |

### Effects

| Node | Base | Description |
|------|------|-------------|
| Shaker | Node | Universal shake for Node2D, Node3D, and Control nodes. |

### UI

| Node | Base | Description |
|------|------|-------------|
| TimerLabel | RichTextLabel | Displays remaining time from Cooldown, Lifespan, or StatusEffect with color thresholds. |

## Compatibility

- **Godot 4.7+** (tested with GL Compatibility renderer).
- **2D and 3D** — every system has variants for both.
- **No external dependencies** — pure GDScript.

## License

MIT
