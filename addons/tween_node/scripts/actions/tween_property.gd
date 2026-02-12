@tool
@warning_ignore_start("shadowed_global_identifier")
class_name TweenProperty
extends TweenStep
## Tween action that animates a target property to a destination value.

const WarningUtils = preload("res://addons/tween_node/scripts/internal/tween_node_warning_utils.gd")

## Target id resolved from `TweenNode.target_map`.
@export var target_id: StringName = &"default":
	set(v):
		target_id = v
		_update_action_resource_name()
## Property path animated by this action.
@export var property: String:
	set(v):
		property = v
		_update_action_resource_name()
## Destination value passed to `Tween.tween_property()`.
@export var to: Variant:
	set(v):
		to = v
		_update_action_resource_name()
## Animation duration in seconds.
@export var duration: float = 1.0:
	set(v):
		duration = v
		_update_action_resource_name()
## Applies destination value as relative offset when true.
## Easing type used by the generated property tweener.
@export var ease: Tween.EaseType = Tween.EASE_IN:
	set(v):
		ease = v
		_update_action_resource_name()
## Transition function used by the generated property tweener.
@export var trans: Tween.TransitionType = Tween.TRANS_LINEAR:
	set(v):
		trans = v
		_update_action_resource_name()
@export var as_relative: bool = false:
	set(v):
		as_relative = v
		_update_action_resource_name()


## Validates inputs and schedules a property tweener.
func _apply_to_tween(tween: Tween, target_map: Dictionary[StringName, Node]) -> void:
	if property.is_empty():
		push_warning("TweenProperty: property is empty.")
		return
	if delay < 0.0:
		push_warning("TweenProperty: delay must be >= 0.0 (got %s)." % delay)
		return
	if duration < 0.0:
		push_warning("TweenProperty: duration must be >= 0.0 (got %s)." % duration)
		return
	var target := _resolve_target(target_map, target_id, "TweenProperty")
	if target == null:
		return
	if not WarningUtils.is_property_path_valid(target, property):
		push_warning(
			"TweenProperty: property '%s' does not exist on '%s'."
			% [property, target.name],
		)
		return

	var t := tween.tween_property(target, property, to, duration)
	t.set_trans(trans).set_ease(ease)
	t.set_delay(delay)
	if as_relative:
		t.as_relative()


## Builds an inspector-friendly action label.
func _get_action_resource_name() -> String:
	return "%s::%s => %s (%ss)" % [target_id, property, str(to), str(duration)]
