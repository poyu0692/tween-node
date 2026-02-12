@tool
class_name SetValue
extends TweenAction
## Tween action that assigns a property value via callback.
## In editor preview, this action is restored when preview stops.

const WarningUtils = preload("res://addons/tween_node/scripts/internal/tween_node_warning_utils.gd")

## Target id resolved from `TweenNode.target_map`.
@export var target_id: StringName = &"default":
	set(v):
		target_id = v
		_update_action_resource_name()
## Property name assigned when this action executes.
@export var property: StringName:
	set(v):
		property = v
		_update_action_resource_name()
## Value assigned to `property`.
@export var value: Variant:
	set(v):
		value = v
		_update_action_resource_name()


## Validates target and property, then schedules a set callback.
func _apply_to_tween(tween: Tween, target_map: Dictionary[StringName, Node]) -> void:
	if property == &"":
		push_warning("SetValue: property is empty.")
		return
	var target := _resolve_target(target_map, target_id, "SetValue")
	if target == null:
		return
	var property_path := String(property)
	if not WarningUtils.is_property_path_valid(target, property_path):
		push_warning(
			"SetValue: property '%s' does not exist on '%s'." % [property_path, target.name]
		)
		return

	if property_path.contains(":"):
		tween.tween_callback(target.set_indexed.bind(NodePath(property_path), value))
	else:
		tween.tween_callback(target.set.bind(property, value))


## Builds an inspector-friendly action label.
func _get_action_resource_name() -> String:
	return "📥%s::%s = %s" % [target_id, String(property), str(value)]
