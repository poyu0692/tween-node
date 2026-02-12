@tool
@abstract
class_name TweenAction
extends Resource
## Abstract base resource for tween actions scheduled by `TweenNode`.

## Runtime meta key used to suppress side effects while `TweenNode.seek()` pre-rolls.
const SEEK_SUPPRESS_SIDE_EFFECTS_META_KEY := &"_tween_node_seek_suppress_side_effects"


@abstract
## Schedules this action on the provided tween.
## Implementations must validate their own inputs and report issues.
func _apply_to_tween(tween: Tween, target_map: Dictionary[StringName, Node]) -> void


## Resolves a mapped target and reports invalid entries through warnings.
func _resolve_target(
		target_map: Dictionary[StringName, Node],
		target_id: StringName,
		action_name: String,
) -> Node:
	if not target_map.has(target_id):
		push_warning("%s: target_id '%s' is not present in target_map." % [action_name, target_id])
		return null
	var target := target_map.get(target_id) as Node
	if not is_instance_valid(target):
		push_warning("%s: target_id '%s' is invalid." % [action_name, target_id])
		return null
	return target


## Returns a short label used in the inspector resource name.
func _get_action_resource_name() -> String:
	return "Action"


## Updates `resource_name` from `_get_action_resource_name()`.
func _update_action_resource_name() -> void:
	resource_name = _get_action_resource_name()
