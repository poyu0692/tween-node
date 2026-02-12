@tool
@icon("circle-arrow-out-up-right.svg")
class_name TweenNode
extends Node

## Emitted when playback reaches natural completion.
signal finished()
## Emitted when an active tween is killed before completion.
signal interrupted()
## Emitted by `SignalEmit` actions with dynamic event payload.
signal emitted(signal_name: StringName, args: Array[Variant])

const WarningUtils = preload("res://addons/tween_node/scripts/internal/tween_node_warning_utils.gd")
const PreviewUtils = preload(
	"res://addons/tween_node/scripts/internal/tween_node_preview_state_utils.gd"
)
const RuntimeSeekUtils = preload(
	"res://addons/tween_node/scripts/internal/tween_node_runtime_seek_utils.gd"
)
## Node that plays a `TweenSequence` against mapped scene targets.
## Editor preview values  are reset before scene save, similar to AnimationPlayer.
const _WARNINGS_POLL_INTERVAL_SEC := 0.2
const _NULL_STEP_WARNING_STABLE_POLLS := 2

## Maps symbolic target ids to scene nodes resolved by actions.
@export var target_map: Dictionary[StringName, Node] = { }:
	set(v):
		target_map = v
		_queue_warning_refresh()
## Sequence resource that defines actions to be scheduled.
@export var sequence: TweenSequence:
	set(v):
		sequence = v
		_queue_warning_refresh()
## Editor-only preview playback toggle shown in the inspector.
@export var _preview_playing: bool:
	get:
		return _preview_toggle
	set(value):
		var command := PreviewUtils.resolve_preview_command(
			_preview_toggle,
			value,
			Engine.is_editor_hint(),
		)
		_preview_toggle = value
		match command:
			PreviewUtils.PREVIEW_TOGGLE_COMMAND_PLAY:
				_editor_play()
			PreviewUtils.PREVIEW_TOGGLE_COMMAND_RESTORE:
				_restore_states()

## Backing value for the editor preview toggle.
var _preview_toggle: bool = false
## Currently active tween instance created by this node.
var _active_tween: Tween
## True while an editor preview tween is actively running.
var _is_preview_active: bool = false
## Captured target property values used by editor preview restore.
var _initial_states: Dictionary[String, Variant] = { }
## Captured runtime base states used by seek restoration.
var _runtime_initial_states: Dictionary[String, Variant] = { }
## True while runtime playback is manually paused.
var _is_paused_runtime: bool = false
## Accumulated time for editor warning polling cadence.
var _warnings_poll_accum: float = 0.0
## True when a warning refresh is requested before next poll.
var _warnings_refresh_requested: bool = true
## Last warning fingerprint used to skip redundant updates.
var _last_warning_fingerprint: int = 0
## Number of consecutive polls that observed null steps.
var _null_step_warning_streak: int = 0
## True when null step warnings should be shown in the inspector.
var _show_null_step_warnings: bool = false
## Tracks warnings already emitted in the current runtime validation session.
var _runtime_warning_once: Dictionary[String, bool] = { }
## True while seek pre-roll is suppressing finished signal emission.
var _suppress_finished_signal: bool = false


## Initializes editor configuration warning state when the node enters the tree.
func _enter_tree() -> void:
	_normalize_legacy_default_target_entry()
	set_process(Engine.is_editor_hint())
	_queue_warning_refresh()


## Polls editor configuration warnings to follow nested resource edits safely.
func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	_warnings_poll_accum += delta
	if not _warnings_refresh_requested and _warnings_poll_accum < _WARNINGS_POLL_INTERVAL_SEC:
		return
	_warnings_poll_accum = 0.0
	_refresh_warnings()


## Clears queued editor warning refresh state on tree exit.
func _exit_tree() -> void:
	set_process(false)
	_warnings_poll_accum = 0.0
	_warnings_refresh_requested = false
	_null_step_warning_streak = 0
	_show_null_step_warnings = false


## Handles editor save notifications and resets preview state before persistence.
func _notification(what: int) -> void:
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		_prepare_save()


## Returns editor configuration issues shown in the inspector.
func _get_configuration_warnings() -> PackedStringArray:
	if not Engine.is_editor_hint():
		return _compose_warnings(_build_warning_bundle(), true)
	return _get_inspector_warnings()


## Marks `_preview_playing` as editor-only so preview state is not persisted.
func _validate_property(property: Dictionary) -> void:
	if StringName(property.get("name", &"")) == &"_preview_playing":
		property["usage"] = PROPERTY_USAGE_EDITOR


## Starts runtime playback of the configured sequence.
## If another tween is active, it is stopped and `interrupted` is emitted.
func play() -> void:
	_begin_validation()
	_stop_active_tween()
	if not sequence:
		_warn_once("[TweenNode]: sequence is not assigned.")
		return
	_runtime_initial_states = RuntimeSeekUtils.collect_initial_states(sequence, target_map)
	_active_tween = create_tween()
	if _active_tween == null:
		push_error("[TweenNode]: failed to create tween.")
		return
	_is_paused_runtime = false
	_is_preview_active = false
	_bind_finished(_active_tween)
	_tag_tween_runtime_context(_active_tween)
	_apply_steps(_active_tween)


## Stops active playback if present.
## Emits `interrupted` when an active tween is stopped.
func stop() -> void:
	_stop_active_tween()


## Pauses active runtime playback while preserving current progress.
func pause() -> void:
	if _is_preview_active:
		_warn_once(
			"[TweenNode]: pause() is runtime-only and cannot control editor preview playback.",
		)
		return
	if _active_tween == null:
		return
	if not is_instance_valid(_active_tween):
		_active_tween = null
		_is_paused_runtime = false
		return
	_active_tween.pause()
	_is_paused_runtime = true


## Resumes runtime playback from the current paused position.
func resume() -> void:
	if _is_preview_active:
		_warn_once(
			"[TweenNode]: resume() is runtime-only and cannot control editor preview playback.",
		)
		return
	if _active_tween == null:
		return
	if not is_instance_valid(_active_tween):
		_active_tween = null
		_is_paused_runtime = false
		return
	_active_tween.play()
	_is_paused_runtime = false


## Jumps runtime playback to `seconds` from sequence start.
## Seek applies state restoration for tweened properties and suppresses side-effect actions.
func seek(seconds: float) -> void:
	_begin_validation()
	if _is_preview_active:
		_warn_once(
			"[TweenNode]: seek() is runtime-only and cannot control editor preview playback.",
		)
		return
	if _active_tween == null:
		_warn_once("[TweenNode]: seek() requires an active runtime tween. Call play() first.")
		return
	if not is_instance_valid(_active_tween):
		_active_tween = null
		_is_paused_runtime = false
		_warn_once("[TweenNode]: seek() cannot continue because the active tween is invalid.")
		return
	if not sequence:
		_warn_once("[TweenNode]: sequence is not assigned.")
		return

	if _runtime_initial_states.is_empty():
		_runtime_initial_states = RuntimeSeekUtils.collect_initial_states(sequence, target_map)
	var seek_seconds := maxf(0.0, seconds)
	var keep_paused := _is_paused_runtime

	_stop_active_tween(false)
	RuntimeSeekUtils.restore_initial_states(_runtime_initial_states, Callable(self, "_warn_once"))

	_active_tween = create_tween()
	if _active_tween == null:
		push_error("[TweenNode]: failed to create tween during seek().")
		_is_paused_runtime = false
		return
	_is_paused_runtime = false
	_bind_finished(_active_tween)
	_tag_tween_runtime_context(_active_tween)
	_active_tween.set_meta(TweenAction.SEEK_SUPPRESS_SIDE_EFFECTS_META_KEY, true)
	_apply_steps(_active_tween)
	_suppress_finished_signal = true
	_active_tween.pause()
	if seek_seconds > 0.0:
		_active_tween.custom_step(seek_seconds)
	if _active_tween != null and is_instance_valid(_active_tween):
		_active_tween.remove_meta(TweenAction.SEEK_SUPPRESS_SIDE_EFFECTS_META_KEY)
	_suppress_finished_signal = false
	if _active_tween == null:
		_is_paused_runtime = false
		return

	if keep_paused:
		_is_paused_runtime = true
		return
	_active_tween.play()


## Returns true when runtime playback is currently paused.
func is_paused() -> bool:
	if _active_tween == null:
		return false
	if not is_instance_valid(_active_tween):
		_active_tween = null
		_is_paused_runtime = false
		return false
	return _is_paused_runtime


## Returns true while this node currently owns an active running tween.
func is_playing() -> bool:
	if _active_tween == null:
		return false
	if not is_instance_valid(_active_tween):
		_active_tween = null
		_is_paused_runtime = false
		return false
	return _active_tween.is_running()


## Returns the warning set currently intended for inspector display.
func _get_inspector_warnings() -> PackedStringArray:
	return _compose_warnings(_build_warning_bundle(), _show_null_step_warnings)


## Refreshes inspector configuration warnings in editor contexts.
func _queue_warning_refresh() -> void:
	if not Engine.is_editor_hint():
		return
	_warnings_refresh_requested = true


## Removes legacy `default: null` placeholders from serialized maps.
func _normalize_legacy_default_target_entry() -> void:
	if not target_map.has(&"default"):
		return
	if target_map.get(&"default") != null:
		return
	var normalized_map := target_map.duplicate()
	normalized_map.erase(&"default")
	target_map = normalized_map


## Applies debounced warning refresh and updates inspector only on changes.
func _refresh_warnings() -> void:
	var warning_bundle := _build_warning_bundle()
	var null_step_warnings := warning_bundle.get(
		"null_step_warnings",
		PackedStringArray(),
	) as PackedStringArray
	if null_step_warnings.is_empty():
		_null_step_warning_streak = 0
		_show_null_step_warnings = false
	else:
		_null_step_warning_streak += 1
		_show_null_step_warnings = _null_step_warning_streak >= _NULL_STEP_WARNING_STABLE_POLLS

	var combined_warnings := _compose_warnings(warning_bundle, _show_null_step_warnings)
	var fingerprint := hash("\n".join(combined_warnings))
	if _warnings_refresh_requested or fingerprint != _last_warning_fingerprint:
		_last_warning_fingerprint = fingerprint
		update_configuration_warnings()
	_warnings_refresh_requested = false


## Builds configuration warning bundle from current `target_map` and `sequence`.
func _build_warning_bundle() -> Dictionary:
	return WarningUtils.build_warning_bundle(target_map, sequence)


## Composes user-visible warning lines from a warning bundle.
func _compose_warnings(
		warning_bundle: Dictionary,
		include_null_step_warnings: bool,
) -> PackedStringArray:
	var warnings := warning_bundle.get("warnings", PackedStringArray()) as PackedStringArray
	var null_step_warnings := warning_bundle.get(
		"null_step_warnings",
		PackedStringArray(),
	) as PackedStringArray
	return WarningUtils.compose_warnings(warnings, null_step_warnings, include_null_step_warnings)


## Starts editor preview playback and captures initial values first.
## If another tween is active, it is stopped and `interrupted` is emitted.
func _editor_play() -> void:
	_begin_validation()
	_stop_active_tween()
	if not sequence:
		_warn_once("[TweenNode]: sequence is not assigned.")
		_preview_toggle = false
		return
	_capture_states()
	_active_tween = create_tween()
	if _active_tween == null:
		push_error("[TweenNode]: failed to create tween.")
		_preview_toggle = false
		return
	_is_preview_active = true
	_bind_finished(_active_tween)
	_tag_tween_runtime_context(_active_tween)
	_apply_steps(_active_tween)


## Connects tween completion to signal emission.
## Editor preview state is kept until `_preview_playing` is turned off.
func _bind_finished(tween: Tween) -> void:
	if tween == null:
		push_error("[TweenNode]: tween is null.")
		return
	tween.finished.connect(
		func():
			var should_emit_finished := not _suppress_finished_signal
			if _active_tween == tween:
				_active_tween = null
			_is_preview_active = false
			_is_paused_runtime = false
			if should_emit_finished:
				finished.emit()
	)


## Schedules all sequence steps onto the given tween.
func _apply_steps(tween: Tween) -> void:
	for index in sequence.steps.size():
		var action := sequence.steps[index]
		if action == null:
			_warn_once("[TweenNode]: step[%d] is null and will be skipped." % index)
			continue

		if action is TweenStep and action.parallel:
			tween.parallel()
		else:
			tween.chain()

		# gdlint-ignore-next-line
		action._apply_to_tween(tween, target_map)


## Tags tween runtime context used by actions that need access to owner metadata.
func _tag_tween_runtime_context(tween: Tween) -> void:
	if tween == null:
		return
	tween.set_meta(SignalEmit.OWNER_ID_META_KEY, get_instance_id())


## Captures current property values used by preview-restorable actions.
## Values are stored once per target/property pair during editor preview.
func _capture_states() -> void:
	if not _initial_states.is_empty():
		return
	_initial_states = PreviewUtils.collect_states(sequence, target_map)


## Restores previously captured values and stops editor preview state.
## If preview playback is active, it is stopped via `_stop_active_tween()`.
func _restore_states() -> void:
	if not PreviewUtils.needs_restore(_preview_toggle, _is_preview_active, _initial_states):
		_preview_toggle = false
		return
	_stop_active_tween()
	PreviewUtils.restore_states(_initial_states, Callable(self, "_warn_once"))
	_initial_states.clear()
	_preview_toggle = false
	_is_preview_active = false


## Resets preview state before editor save to avoid persisting preview poses.
## Preview remains off after save, matching `AnimationPlayer.reset_on_save` style.
func _prepare_save() -> void:
	if not PreviewUtils.needs_restore(_preview_toggle, _is_preview_active, _initial_states):
		return
	_restore_states()


## Stops the current active tween by calling `Tween.kill()`.
## This path does not emit `finished`; `interrupted` is optional.
func _stop_active_tween(emit_interrupted: bool = true) -> void:
	if _active_tween == null:
		return
	_active_tween.kill()
	_active_tween = null
	_is_preview_active = false
	_is_paused_runtime = false
	_suppress_finished_signal = false
	if emit_interrupted:
		interrupted.emit()


## Clears warning dedup state for the current runtime operation.
func _begin_validation() -> void:
	_runtime_warning_once.clear()


## Emits a warning once per runtime validation session.
func _warn_once(message: String) -> void:
	if _runtime_warning_once.has(message):
		return
	_runtime_warning_once[message] = true
	push_warning(message)
