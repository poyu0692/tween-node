# TweenNode

A declarative, composable tween sequence system for Godot 4, with editor preview support.

Build complex animation sequences as reusable resources, preview them directly in the editor, and organize them as scene nodes.

## ✨ Features

- **📦 Resource-based sequences** - Create reusable `TweenSequence` resources that can be shared across scenes
- **👁️ Editor preview** - Toggle preview playback in the editor with automatic state restoration
- **🔁 Nested loops** - Support for loop actions with their own nested action scopes
- **🔀 Parallel execution** - Chain or parallelize actions using a simple toggle
- **🎯 Flexible targeting** - Map symbolic target IDs to actual scene nodes via `target_map`
- **🧩 Composable actions** - Mix property animations, waits, method tweens, callbacks, signal emits, and instant property sets
- **⏯️ Runtime controls** - Pause, resume, and seek active runtime playback

## 📦 Installation

1. Copy the `addons/tween_node` folder into your Godot project's `addons/` directory
2. Enable the plugin in **Project → Project Settings → Plugins**
3. The `TweenNode` and action classes will be available in the editor

## 🚀 Quick Start

### 1. Add a TweenNode to your scene

Add a `TweenNode` node to your scene and configure the target map:

```gdscript
# In your scene tree
MyScene (Node2D)
├─ Sprite (Sprite2D)
└─ TweenNode
```

Select the `TweenNode` and set up the `target_map` in the inspector:
- Key: `"sprite"` → Value: `Sprite` (drag the Sprite node here)

### 2. Create a TweenSequence resource

In the `TweenNode` inspector, create a new `TweenSequence` resource for the `sequence` property.

Click on the sequence resource to edit it, then add actions to the `steps` array:

- **TweenProperty** - Animate `sprite` position from current to `(100, 100)` over `1.0s`
- **TweenWait** - Wait `0.5s`
- **TweenMethod** - Tween a value and pass it into a target method over time
- **TweenProperty** - Animate `sprite` position back to `(0, 0)` over `1.0s`

### 3. Preview in editor

Toggle the `_preview_playing` checkbox in the `TweenNode` inspector to preview your animation directly in the editor. When you disable it, the sprite automatically returns to its initial state.

Preview restore scope:
- `TweenProperty` and `TweenSet` changes are restored automatically.
- `TweenMethod` can be restored when preview options are enabled.
- `TweenCall` side effects are **not** restored automatically.

### 4. Play at runtime

```gdscript
func _ready():
    $TweenNode.play()

    # Connect to signals
    $TweenNode.finished.connect(_on_animation_finished)
    $TweenNode.interrupted.connect(_on_animation_interrupted)

func _on_cancel_pressed():
    if $TweenNode.is_playing():
        $TweenNode.stop()
```

### 5. Runtime playback control

```gdscript
func _on_pause_pressed():
    $TweenNode.pause()

func _on_resume_pressed():
    $TweenNode.resume()

func _on_seek_halfway_pressed():
    $TweenNode.seek(0.5)
```

- `pause()` and `resume()` only affect runtime playback (`play()` flow), not editor preview.
- `is_paused()` reports the current runtime paused state.
- `seek(seconds)` is **state-priority**:
  - It restores tracked tweened properties to runtime start state, then pre-rolls to `seconds`.
  - Side-effect actions (`TweenCall`, `SignalEmit`, `TweenMethod`) are suppressed during seek pre-roll.
  - Therefore, seek does **not** guarantee replay of callback/signal side effects between `0..seconds`.

## 🧪 Examples

- Open `res://examples/showcase1.tscn` for a compact end-to-end sample.
- Open `res://examples/showcase2.tscn` for an additional sample scene.
- It demonstrates `TweenProperty`, `TweenWait`, `TweenMethod`, `TweenSet`, `TweenCall`, `SignalEmit`, `TweenLoop`, parallel steps, and `finished`/`interrupted` signals.
- In the editor, select `TweenNode` and toggle `_preview_playing` to preview and restore pose.

## 📚 Available Actions

### TweenProperty

Animates a target property to a destination value.

- `target_id`: Target node ID from `target_map` (default: `"default"`)
- `property`: Property path (e.g., `"position"`, `"modulate:a"`)
- `to`: Destination value
- `duration`: Animation duration in seconds
- `as_relative`: Treat `to` as a relative offset
- `ease` / `trans`: Easing and transition types
- `delay`: Start delay in seconds
- `parallel`: Execute in parallel with the previous action

### TweenWait

Inserts a time delay.

- `duration`: Wait duration in seconds
- `delay`: Additional start delay before this wait step
- `parallel`: Execute in parallel with the previous action

### TweenMethod

Interpolates a value over time and calls a target method on each tween update.

- `target_id`: Target node ID from `target_map`
- `method_name`: Method to call with tweened value
- `from` / `to`: Interpolated value range
- `duration`: Tween duration in seconds
- `ease` / `trans`: Easing and transition types
- `delay`: Start delay in seconds
- `parallel`: Execute in parallel with the previous action
- `preview_restore_property`: Property path restored on preview stop (`""` disables restore)
- Note: Without preview restore options, `TweenMethod` side effects are not auto-restored.

### TweenCall

Invokes a method on a target node.

- `target_id`: Target node ID from `target_map`
- `method_name`: Method to call
- `args`: Array of arguments to pass
- Note: In editor preview, side effects from `TweenCall` are not auto-restored.

### SignalEmit

Emits `TweenNode.emitted(signal_name, args)` during sequence playback.

- `signal_name`: Forwarded event name
- `args`: Forwarded payload array

### TweenSet

Instantly sets a property value (via callback).

- `target_id`: Target node ID from `target_map`
- `property`: Property name to set
- `value`: Value to assign
- Note: In editor preview, property changes from `TweenSet` are auto-restored.

### TweenLoop

Repeats nested actions a specified number of times.

- `count`: Number of loop iterations
- `actions`: Array of actions to execute inside the loop

## 🎯 Example: Button Hover Effect

```gdscript
# Create this as a TweenSequence resource
# and assign it to a TweenNode in your button scene

Steps:
1. TweenProperty
   - target_id: "button"
   - property: "scale"
   - to: Vector2(1.1, 1.1)
   - duration: 0.15
   - ease: EASE_OUT
   - trans: TRANS_BACK

2. TweenProperty
   - target_id: "button"
   - property: "scale"
   - to: Vector2(1.0, 1.0)
   - duration: 0.15
   - ease: EASE_IN
   - trans: TRANS_BACK
```

Then in your button script:

```gdscript
func _on_mouse_entered():
    $TweenNode.play()
```

## 🏗️ Architecture

```
TweenNode (Node)
├─ Manages target_map and playback
├─ Handles editor preview state capture/restore
└─ Schedules actions from TweenSequence

TweenSequence (Resource)
└─ Contains ordered array of TweenAction steps

TweenAction (Resource, abstract)
├─ TweenStep (abstract, adds parallel support)
│   ├─ TweenProperty
│   ├─ TweenWait
│   └─ TweenMethod
├─ TweenCall
├─ SignalEmit
├─ TweenSet
└─ TweenLoop (supports nested actions)
```

## 🧪 Testing

This project uses [GdUnit4](https://github.com/MikeSchulze/gdUnit4) for testing.
The Asset Library release archive excludes `addons/gdUnit4` and `addons/tween_node/tests`.

Run tests:
```
./addons/gdUnit4/runtest.sh --godot_binary /path/to/godot \
  --ignoreHeadlessMode -a res://addons/tween_node/tests -c
```

## 📝 Version

Current version: **0.1.0** (pre-release)

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## 📄 License

MIT. See `LICENSE`.

## 🙏 Credits

Created by [@poyu0692](https://github.com/poyu0692)

---

**Note**: This plugin is in active development. API may change before version 1.0.
