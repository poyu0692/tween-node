@tool
class_name TweenLoop
extends TweenAction
## Tween action that loops only its nested actions.

## Number of loop iterations for this local action scope.
@export var count: int = 2:
	set(v):
		count = v
		_update_action_resource_name()
## Actions executed inside this loop scope.
@export var actions: Array[TweenAction]:
	set(v):
		actions = v
		_update_action_resource_name()


## Validates loop configuration and schedules nested actions.
func _apply_to_tween(tween: Tween, target_map: Dictionary[StringName, Node]) -> void:
	if count <= 0:
		push_warning("TweenLoop: count must be > 0 (got %d)." % count)
		return
	var scene_tree := Engine.get_main_loop() as SceneTree
	if scene_tree == null:
		push_error(
			"TweenLoop._apply_to_tween(): failed to resolve SceneTree "
			+ "for subtween creation.",
		)
		return
	var loop_tween := scene_tree.create_tween()
	if loop_tween == null:
		push_error("TweenLoop._apply_to_tween(): failed to create subtween.")
		return
	if tween.has_meta(SignalEmit.OWNER_ID_META_KEY):
		loop_tween.set_meta(
			SignalEmit.OWNER_ID_META_KEY,
			tween.get_meta(SignalEmit.OWNER_ID_META_KEY),
		)
	if tween.has_meta(SEEK_SUPPRESS_SIDE_EFFECTS_META_KEY):
		loop_tween.set_meta(
			SEEK_SUPPRESS_SIDE_EFFECTS_META_KEY,
			tween.get_meta(SEEK_SUPPRESS_SIDE_EFFECTS_META_KEY),
		)
	loop_tween.set_loops(count)

	var subtween := tween.tween_subtween(loop_tween)
	if subtween == null:
		loop_tween.kill()
		push_error("TweenLoop._apply_to_tween(): failed to attach subtween to parent tween.")
		return

	for index in actions.size():
		var action := actions[index]
		if action == null:
			push_warning(
				"TweenLoop._apply_to_tween(): actions[%d] is null and will be skipped."
				% index,
			)
			continue
		_resolve_callback(action, loop_tween, target_map)


## Builds an inspector-friendly action label.
func _get_action_resource_name() -> String:
	if count == 1:
		return "🔁Loop: %d time" % [count]
	return "🔁Loop: %d times" % [count]


## Applies the same chain/parallel resolution used by `TweenNode`.
func _resolve_callback(
		action: TweenAction,
		tween: Tween,
		target_map: Dictionary[StringName, Node],
) -> void:
	if action is TweenStep and action.parallel:
		tween.parallel()
	else:
		tween.chain()

	# gdlint-ignore-next-line
	action._apply_to_tween(tween, target_map)
