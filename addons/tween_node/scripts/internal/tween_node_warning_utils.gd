@tool
extends RefCounted
## Static helper utilities for `TweenNode` configuration warning evaluation.


## Builds warning groups for standard issues and debounced null-step issues.
static func build_warning_bundle(
		target_map: Dictionary[StringName, Node],
		sequence: TweenSequence,
) -> Dictionary:
	var warnings := PackedStringArray()
	var null_step_warnings := PackedStringArray()

	if target_map.is_empty():
		warnings.append("target_map is empty. Add at least one target entry.")

	for target_id in target_map.keys():
		var mapped_target := target_map.get(target_id)
		if mapped_target == null:
			warnings.append("target_map['%s'] is null." % target_id)
		elif not is_instance_valid(mapped_target):
			warnings.append("target_map['%s'] is invalid." % target_id)

	if sequence == null:
		warnings.append("sequence is not assigned.")
		return _build_warning_bundle(warnings, null_step_warnings)

	if sequence.steps.is_empty():
		warnings.append("sequence.steps is empty.")
		return _build_warning_bundle(warnings, null_step_warnings)

	if _actions_use_target_id(sequence.steps, &"default") and not target_map.has(&"default"):
		warnings.append("target_map does not contain the required key 'default'.")

	collect_warnings(sequence.steps, target_map, warnings, null_step_warnings, "steps")
	return _build_warning_bundle(warnings, null_step_warnings)


## Merges warning groups with optional inclusion of debounced null-step warnings.
static func compose_warnings(
		warnings: PackedStringArray,
		null_step_warnings: PackedStringArray,
		include_null_step_warnings: bool,
) -> PackedStringArray:
	var combined := PackedStringArray()
	for message in warnings:
		combined.append(message)
	if include_null_step_warnings:
		for message in null_step_warnings:
			combined.append(message)
	return combined


## Packs warning groups into a consistent dictionary payload.
static func _build_warning_bundle(
		warnings: PackedStringArray,
		null_step_warnings: PackedStringArray,
) -> Dictionary:
	return {
		"warnings": warnings,
		"null_step_warnings": null_step_warnings,
	}


## Recursively validates action configuration and appends inspector warnings.
static func collect_warnings(
		actions: Array[TweenAction],
		target_map: Dictionary[StringName, Node],
		warnings: PackedStringArray,
		null_step_warnings: PackedStringArray,
		context: String,
) -> void:
	for index in actions.size():
		var action := actions[index]
		var action_path := "%s[%d]" % [context, index]
		if action == null:
			null_step_warnings.append("%s is null." % action_path)
			continue

		if action is TweenLoop:
			if action.count <= 0:
				warnings.append("%s loop count must be > 0 (got %d)." % [action_path, action.count])
			if action.actions.is_empty():
				warnings.append("%s loop actions is empty." % action_path)
			collect_warnings(
				action.actions,
				target_map,
				warnings,
				null_step_warnings,
				action_path + ".actions",
			)
			continue

		if action is TweenStep and action.delay < 0.0:
			warnings.append("%s delay must be >= 0.0 (got %s)." % [action_path, action.delay])

		if action is TweenProperty:
			var property_target := resolve_target_for_warning(
				target_map,
				action.target_id,
				action_path,
				warnings,
			)
			if action.property.is_empty():
				warnings.append("%s property is empty." % action_path)
			elif (
				property_target != null
				and not is_property_path_valid(property_target, action.property)
			):
				warnings.append(
					"%s property '%s' does not exist on '%s'."
					% [action_path, action.property, property_target.name],
				)
			if action.duration < 0.0:
				warnings.append(
					"%s duration must be >= 0.0 (got %s)."
					% [action_path, action.duration],
				)
			continue

		if action is SetValue:
			var set_target := resolve_target_for_warning(
				target_map,
				action.target_id,
				action_path,
				warnings,
			)
			if action.property == &"":
				warnings.append("%s property is empty." % action_path)
			elif (
				set_target != null
				and not is_property_path_valid(set_target, String(action.property))
			):
				warnings.append(
					"%s property '%s' does not exist on '%s'."
					% [action_path, String(action.property), set_target.name],
				)
			continue

		if action is CallMethod:
			var call_target := resolve_target_for_warning(
				target_map,
				action.target_id,
				action_path,
				warnings,
			)
			if action.method_name == &"":
				warnings.append("%s method_name is empty." % action_path)
			elif call_target != null and not is_method_callable(call_target, action.method_name):
				if call_target.has_method(action.method_name):
					warnings.append(
						"%s method '%s' is not callable on '%s' in the current context."
						% [action_path, action.method_name, call_target.name],
					)
				else:
					warnings.append(
						"%s method '%s' does not exist on '%s'."
						% [action_path, action.method_name, call_target.name],
					)
			continue

		if action is TweenMethod:
			var method_target := resolve_target_for_warning(
				target_map,
				action.target_id,
				action_path,
				warnings,
			)
			if action.method_name == &"":
				warnings.append("%s method_name is empty." % action_path)
			elif (
				method_target != null
				and not is_method_callable(method_target, action.method_name)
			):
				if method_target.has_method(action.method_name):
					warnings.append(
						"%s method '%s' is not callable on '%s' in the current context."
						% [action_path, action.method_name, method_target.name],
					)
				else:
					warnings.append(
						"%s method '%s' does not exist on '%s'."
						% [action_path, action.method_name, method_target.name],
					)
			if action.duration < 0.0:
				warnings.append(
					"%s duration must be >= 0.0 (got %s)."
					% [action_path, action.duration],
				)
			if (
				not action.preview_restore_property.is_empty()
				and method_target != null
				and not is_property_path_valid(method_target, action.preview_restore_property)
			):
				warnings.append(
					"%s preview_restore_property '%s' does not exist on '%s'."
					% [action_path, action.preview_restore_property, method_target.name],
				)
			continue

		if action is SignalEmit:
			if action.signal_name == &"":
				warnings.append("%s signal_name is empty." % action_path)
			continue

		if action is TweenWait and action.duration < 0.0:
			warnings.append("%s duration must be >= 0.0 (got %s)." % [action_path, action.duration])


## Returns true when any action (including nested loop actions) references the given target_id.
static func _actions_use_target_id(actions: Array[TweenAction], target_id: StringName) -> bool:
	for action in actions:
		if action == null:
			continue
		if action is TweenLoop:
			if _actions_use_target_id(action.actions, target_id):
				return true
			continue
		if action is TweenProperty and action.target_id == target_id:
			return true
		if action is SetValue and action.target_id == target_id:
			return true
		if action is CallMethod and action.target_id == target_id:
			return true
		if action is TweenMethod and action.target_id == target_id:
			return true
	return false


## Validates `target_id` mapping and returns a usable target for warning checks.
static func resolve_target_for_warning(
		target_map: Dictionary[StringName, Node],
		target_id: StringName,
		action_path: String,
		warnings: PackedStringArray,
) -> Node:
	if not target_map.has(target_id):
		warnings.append(
			"%s target_id '%s' is not present in target_map." % [action_path, target_id],
		)
		return null
	var target := target_map.get(target_id) as Node
	if target == null:
		warnings.append("%s target_id '%s' maps to null." % [action_path, target_id])
		return null
	if not is_instance_valid(target):
		warnings.append("%s target_id '%s' maps to an invalid node." % [action_path, target_id])
		return null
	return target


## Returns true when an exact property name exists on the target object.
static func is_property_name_valid(target: Object, property_name: StringName) -> bool:
	for property_info in target.get_property_list():
		if StringName(property_info.get("name", &"")) == property_name:
			return true
	return false


## Returns true when the base property segment exists on the target object.
static func is_property_path_valid(target: Object, property_path: String) -> bool:
	if property_path.is_empty():
		return false
	var base_property := property_path.get_slice(":", 0)
	if base_property.is_empty():
		return false
	for property_info in target.get_property_list():
		if String(property_info.get("name", "")) == base_property:
			return true
	return false


## Returns true when a target method can be invoked in the current runtime context.
## In editor mode, non-tool scripts are treated as not callable.
static func is_method_callable(target: Object, method_name: StringName) -> bool:
	if method_name == &"":
		return false
	if not target.has_method(method_name):
		return false
	if not Engine.is_editor_hint():
		return true

	var target_script := target.get_script()
	if target_script == null:
		return true
	if target_script is Script:
		return target_script.is_tool()
	return false
