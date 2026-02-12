@tool
class_name CallMethod
extends TweenAction
## Tween action that invokes a target method via callback.
## In editor preview, this action's side effects are not auto-restored when preview stops.

const WarningUtils = preload("res://addons/tween_node/scripts/internal/tween_node_warning_utils.gd")

## Target id resolved from `TweenNode.target_map`.
@export var target_id: StringName = &"default":
	set(v):
		target_id = v
		_update_action_resource_name()
## Method name invoked when this action executes.
@export var method_name: StringName:
	set(v):
		method_name = v
		_update_action_resource_name()
## Arguments passed to `method_name`.
@export var args: Array[Variant] = []:
	set(v):
		args = v
		_update_action_resource_name()


## Validates target and method, then schedules a callback tweener.
func _apply_to_tween(tween: Tween, target_map: Dictionary[StringName, Node]) -> void:
	var target := _resolve_target(target_map, target_id, "CallMethod")
	if target == null:
		return
	if method_name == &"":
		push_warning("CallMethod: method_name is empty.")
		return
	if not WarningUtils.is_method_callable(target, method_name):
		push_warning(
			"CallMethod: method '%s' is not callable on '%s' in the current context."
			% [method_name, target.name],
		)
		return

	tween.tween_callback(_invoke_target_method.bind(target, method_name, args, tween))


## Builds an inspector-friendly action label.
func _get_action_resource_name() -> String:
	return "📢%s::%s(%s)" % [target_id, method_name, ", ".join(args.map(func(x): return str(x)))]


## Invokes the target method at execution time with safety rechecks.
## Missing targets or methods are reported as warnings and skipped.
func _invoke_target_method(
		target: Node,
		target_method_name: StringName,
		call_args: Array[Variant],
		owner_tween: Tween,
) -> void:
	if owner_tween != null and owner_tween.has_meta(SEEK_SUPPRESS_SIDE_EFFECTS_META_KEY):
		return
	if not is_instance_valid(target):
		push_warning(
			"CallMethod: target '%s' became invalid before callback execution."
			% target_id,
		)
		return
	if not WarningUtils.is_method_callable(target, target_method_name):
		push_warning(
			"CallMethod: method '%s' is not callable on '%s'; callback skipped."
			% [target_method_name, target.name],
		)
		return
	Callable(target, target_method_name).callv(call_args)
