@tool
class_name TweenMethod
extends TweenStep
## Tween step that interpolates a value and calls a target method every tick.

const WarningUtils = preload("res://addons/tween_node/scripts/internal/tween_node_warning_utils.gd")

## Target id resolved from `TweenNode.target_map`.
@export var target_id: StringName = &"default":
	set(v):
		target_id = v
		_update_action_resource_name()
## Method name invoked with tweened value.
@export var method_name: StringName:
	set(v):
		method_name = v
		_update_action_resource_name()
## Start value passed to `Tween.tween_method()`.
@export var from: Variant:
	set(v):
		from = v
		_update_action_resource_name()
## End value passed to `Tween.tween_method()`.
@export var to: Variant:
	set(v):
		to = v
		_update_action_resource_name()
## Animation duration in seconds.
@export var duration: float = 1.0:
	set(v):
		duration = v
		_update_action_resource_name()
## Easing type used by the generated method tweener.
@export var ease: Tween.EaseType = Tween.EASE_IN:
	set(v):
		ease = v
		_update_action_resource_name()
## Transition function used by the generated method tweener.
@export var trans: Tween.TransitionType = Tween.TRANS_LINEAR:
	set(v):
		trans = v
		_update_action_resource_name()
@export_group("Preview")
## Property path restored on preview stop. Empty string disables preview rollback.
@export var preview_restore_property: String = "":
	set(v):
		preview_restore_property = v
		_update_action_resource_name()


## Validates target and method, then schedules a method tweener.
func _apply_to_tween(tween: Tween, target_map: Dictionary[StringName, Node]) -> void:
	if method_name == &"":
		push_warning("TweenMethod: method_name is empty.")
		return
	if delay < 0.0:
		push_warning("TweenMethod: delay must be >= 0.0 (got %s)." % delay)
		return
	if duration < 0.0:
		push_warning("TweenMethod: duration must be >= 0.0 (got %s)." % duration)
		return
	var target := _resolve_target(target_map, target_id, "TweenMethod")
	if target == null:
		return
	if not WarningUtils.is_method_callable(target, method_name):
		push_warning(
			"TweenMethod: method '%s' is not callable on '%s' in the current context."
			% [method_name, target.name],
		)
		return

	var method_callable := _invoke_target_method_value.bind(target, method_name, tween)
	var t := tween.tween_method(method_callable, from, to, duration)
	t.set_trans(trans)
	t.set_ease(ease)
	t.set_delay(delay)


## Builds an inspector-friendly action label.
func _get_action_resource_name() -> String:
	var preview_restore_label := ""
	if not preview_restore_property.is_empty():
		preview_restore_label = " [preview:%s]" % preview_restore_property
	return "%s::%s(%s => %s) (%ss)%s" % [
		target_id,
		method_name,
		str(from),
		str(to),
		str(duration),
		preview_restore_label,
	]


## Invokes target method during tween updates with runtime safety checks.
func _invoke_target_method_value(
		value: Variant,
		target: Node,
		target_method_name: StringName,
		owner_tween: Tween,
) -> void:
	if owner_tween != null and owner_tween.has_meta(SEEK_SUPPRESS_SIDE_EFFECTS_META_KEY):
		return
	if not is_instance_valid(target):
		push_warning("TweenMethod: target '%s' became invalid before method execution." % target_id)
		return
	if not WarningUtils.is_method_callable(target, target_method_name):
		push_warning(
			"TweenMethod: method '%s' is not callable on '%s'; tween update skipped."
			% [target_method_name, target.name],
		)
		return
	Callable(target, target_method_name).call(value)
