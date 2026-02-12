@tool
extends RefCounted
## Static helper utilities for `TweenNode` editor preview state handling.

const WarningUtils = preload("res://addons/tween_node/scripts/internal/tween_node_warning_utils.gd")
const PREVIEW_TOGGLE_COMMAND_NOOP := 0
const PREVIEW_TOGGLE_COMMAND_PLAY := 1
const PREVIEW_TOGGLE_COMMAND_RESTORE := 2


## Returns true when preview state restore work is required.
static func needs_restore(
		preview_toggle: bool,
		is_preview_active: bool,
		initial_states: Dictionary[String, Variant],
) -> bool:
	return preview_toggle or is_preview_active or not initial_states.is_empty()


## Returns the preview flow command for the requested toggle change.
static func resolve_preview_command(
		current_toggle: bool,
		requested_toggle: bool,
		is_editor_hint: bool,
) -> int:
	if current_toggle == requested_toggle:
		return PREVIEW_TOGGLE_COMMAND_NOOP
	if not is_editor_hint:
		return PREVIEW_TOGGLE_COMMAND_NOOP
	if requested_toggle:
		return PREVIEW_TOGGLE_COMMAND_PLAY
	return PREVIEW_TOGGLE_COMMAND_RESTORE


## Builds a stable state key from target instance id and property path.
static func build_state_key(instance_id: int, property_path: String) -> String:
	return str(instance_id) + ":" + property_path


## Captures unique target/property values for preview-restorable actions in the sequence.
## `TweenCall` side effects are intentionally out of scope.
static func collect_states(
		sequence: TweenSequence,
		target_map: Dictionary[StringName, Node],
) -> Dictionary[String, Variant]:
	var initial_states: Dictionary[String, Variant] = { }
	if sequence == null:
		return initial_states

	_collect_states(sequence.steps, target_map, initial_states)
	return initial_states


## Restores captured property values.
## Emits warnings through the callback when entries are invalid.
static func restore_states(
		initial_states: Dictionary[String, Variant],
		warn_callback: Callable,
) -> void:
	for key_variant in initial_states.keys():
		var key := String(key_variant)
		var parts := key.split(":", false, 1)
		if parts.size() != 2:
			_warn_restore(
				warn_callback,
				"TweenNode._restore_states(): invalid state key '%s'." % key,
			)
			continue
		if not parts[0].is_valid_int():
			_warn_restore(
				warn_callback,
				"TweenNode._restore_states(): invalid instance id '%s' in key '%s'."
				% [parts[0], key],
			)
			continue

		var target := instance_from_id(int(parts[0]))
		if not is_instance_valid(target):
			_warn_restore(
				warn_callback,
				"TweenNode._restore_states(): target instance '%s' is no longer valid."
				% parts[0],
			)
			continue

		var property_path := parts[1]
		if property_path.is_empty():
			_warn_restore(
				warn_callback,
				"TweenNode._restore_states(): property path is empty in key '%s'." % key,
			)
			continue
		if not WarningUtils.is_property_path_valid(target, property_path):
			_warn_restore(
				warn_callback,
				"TweenNode._restore_states(): property '%s' does not exist on '%s'."
				% [property_path, _target_name(target)],
			)
			continue

		target.set_indexed(property_path, initial_states[key])


## Recursively collects state snapshots for preview-restorable actions.
static func _collect_states(
		actions: Array[TweenAction],
		target_map: Dictionary[StringName, Node],
		out: Dictionary[String, Variant],
) -> void:
	for action in actions:
		if action == null:
			continue
		if action is TweenProperty:
			_capture_property_path_state(
				action.target_id,
				action.property,
				target_map,
				out,
			)
			continue
		if action is SetValue:
			_capture_property_path_state(
				action.target_id,
				String(action.property),
				target_map,
				out,
			)
			continue
		if action is TweenMethod:
			if action.preview_restore_property.is_empty():
				continue
			_capture_property_path_state(
				action.target_id,
				action.preview_restore_property,
				target_map,
				out,
			)
			continue
		if action is TweenLoop:
			_collect_states(action.actions, target_map, out)


## Captures a snapshot for a property-path style action if valid.
static func _capture_property_path_state(
		target_id: StringName,
		property_path: String,
		target_map: Dictionary[StringName, Node],
		out: Dictionary[String, Variant],
) -> void:
	if property_path.is_empty():
		return
	var target := _resolve_state_target(target_map, target_id)
	if target == null:
		return
	if not WarningUtils.is_property_path_valid(target, property_path):
		return
	var state_key := build_state_key(target.get_instance_id(), property_path)
	if out.has(state_key):
		return
	out[state_key] = target.get_indexed(property_path)


## Resolves a valid snapshot target from `target_map`.
static func _resolve_state_target(
		target_map: Dictionary[StringName, Node],
		target_id: StringName,
) -> Node:
	if not target_map.has(target_id):
		return null
	var target := target_map.get(target_id) as Node
	if not is_instance_valid(target):
		return null
	return target


## Emits a restore warning through the provided callback when available.
static func _warn_restore(warn_callback: Callable, message: String) -> void:
	if warn_callback.is_valid():
		warn_callback.call(message)


## Returns a readable target name for warning messages.
static func _target_name(target: Object) -> String:
	if target is Node:
		return target.name
	return target.get_class()
