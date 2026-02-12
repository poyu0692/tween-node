extends GdUnitTestSuite

const WarningUtils = preload("res://addons/tween_node/scripts/internal/tween_node_warning_utils.gd")
const PreviewUtils = preload(
	"res://addons/tween_node/scripts/internal/tween_node_preview_state_utils.gd"
)
const TweenNodeScript = preload("res://addons/tween_node/scripts/tween_node.gd")

class TestMethodTarget:
	extends Node

	var last_value: float = -1.0

	func apply_value(value: float) -> void:
		last_value = value


class TestPreviewMethodTarget:
	extends Node2D

	func apply_rotation(value: float) -> void:
		rotation = value


class TestSeekSideEffectTarget:
	extends Node

	var call_count: int = 0
	var method_call_count: int = 0
	var last_method_value: float = -1.0

	func mark_call() -> void:
		call_count += 1

	func apply_value(value: float) -> void:
		method_call_count += 1
		last_method_value = value


func test_preview_utils_collect_states_includes_nested_loop_entries() -> void:
	var root := auto_free(Node2D.new())
	add_child(root)

	var target := auto_free(Node2D.new())
	root.add_child(target)
	target.position = Vector2(3, 4)
	target.scale = Vector2(1, 1)
	target.rotation = 0.5

	var first_property := TweenProperty.new()
	first_property.target_id = &"default"
	first_property.property = "position"
	first_property.to = Vector2(10, 20)
	first_property.duration = 0.0

	var nested_property := TweenProperty.new()
	nested_property.target_id = &"default"
	nested_property.property = "scale"
	nested_property.to = Vector2(2, 2)
	nested_property.duration = 0.0

	var nested_set := TweenSet.new()
	nested_set.target_id = &"default"
	nested_set.property = &"rotation"
	nested_set.value = 2.0

	var nested_method_restore := TweenMethod.new()
	nested_method_restore.target_id = &"default"
	nested_method_restore.preview_restore_property = "modulate"

	var inner_loop := TweenLoop.new()
	inner_loop.count = 1
	inner_loop.actions = [nested_property, nested_set, nested_method_restore]

	var outer_loop := TweenLoop.new()
	outer_loop.count = 1
	outer_loop.actions = [first_property, inner_loop]

	var sequence := TweenSequence.new()
	sequence.steps = [outer_loop]

	var target_map: Dictionary[StringName, Node] = { &"default": target as Node }
	var initial_states := PreviewUtils.collect_states(sequence, target_map)
	var position_key := PreviewUtils.build_state_key(target.get_instance_id(), "position")
	var scale_key := PreviewUtils.build_state_key(target.get_instance_id(), "scale")
	var rotation_key := PreviewUtils.build_state_key(target.get_instance_id(), "rotation")
	var modulate_key := PreviewUtils.build_state_key(target.get_instance_id(), "modulate")

	assert_int(initial_states.size()).is_equal(4)
	assert_bool(initial_states.has(position_key)).is_true()
	assert_bool(initial_states.has(scale_key)).is_true()
	assert_bool(initial_states.has(rotation_key)).is_true()
	assert_bool(initial_states.has(modulate_key)).is_true()
	assert_that(initial_states[rotation_key]).is_equal(0.5)
	assert_that(initial_states[modulate_key]).is_equal(Color.WHITE)


func test_restore_states_restores_property_changed_in_nested_loop() -> void:
	var root := auto_free(Node2D.new())
	add_child(root)

	var target := auto_free(Node2D.new())
	root.add_child(target)
	target.position = Vector2(3, 4)

	var move_action := TweenProperty.new()
	move_action.target_id = &"default"
	move_action.property = "position"
	move_action.to = Vector2(40, 50)
	move_action.duration = 0.0

	var inner_loop := TweenLoop.new()
	inner_loop.count = 1
	inner_loop.actions = [move_action]

	var sequence := TweenSequence.new()
	sequence.steps = [inner_loop]

	var tween_node := auto_free(TweenNode.new())
	root.add_child(tween_node)
	var target_map: Dictionary[StringName, Node] = { &"default": target as Node }
	tween_node.target_map = target_map
	tween_node.sequence = sequence

	_call_private(tween_node, &"_editor_play")
	await get_tree().process_frame

	assert_that(target.position).is_equal(Vector2(40, 50))

	_call_private(tween_node, &"_restore_states")
	assert_that(target.position).is_equal(Vector2(3, 4))


func test_preview_utils_collect_states_skips_invalid_entries() -> void:
	var root := auto_free(Node2D.new())
	add_child(root)

	var target := auto_free(Node2D.new())
	root.add_child(target)
	target.position = Vector2(3, 4)
	target.scale = Vector2(1, 1)
	target.rotation = 0.25

	var valid_move := TweenProperty.new()
	valid_move.target_id = &"default"
	valid_move.property = "position"
	valid_move.to = Vector2(10, 20)

	var duplicate_move := TweenProperty.new()
	duplicate_move.target_id = &"default"
	duplicate_move.property = "position"
	duplicate_move.to = Vector2(30, 40)

	var invalid_property := TweenProperty.new()
	invalid_property.target_id = &"default"
	invalid_property.property = "missing_property"

	var empty_property := TweenProperty.new()
	empty_property.target_id = &"default"
	empty_property.property = ""

	var nested_scale := TweenProperty.new()
	nested_scale.target_id = &"default"
	nested_scale.property = "scale"
	nested_scale.to = Vector2(2, 2)

	var valid_set := TweenSet.new()
	valid_set.target_id = &"default"
	valid_set.property = &"rotation"
	valid_set.value = 1.0

	var duplicate_set := TweenSet.new()
	duplicate_set.target_id = &"default"
	duplicate_set.property = &"rotation"
	duplicate_set.value = 3.0

	var missing_set_property := TweenSet.new()
	missing_set_property.target_id = &"default"
	missing_set_property.property = &"missing_property"
	missing_set_property.value = 1.0

	var empty_set_property := TweenSet.new()
	empty_set_property.target_id = &"default"
	empty_set_property.property = &""
	empty_set_property.value = 1.0

	var missing_target := TweenProperty.new()
	missing_target.target_id = &"missing"
	missing_target.property = "position"

	var missing_set_target := TweenSet.new()
	missing_set_target.target_id = &"missing"
	missing_set_target.property = &"rotation"
	missing_set_target.value = 1.0

	var disabled_method_restore := TweenMethod.new()
	disabled_method_restore.target_id = &"default"
	disabled_method_restore.preview_restore_property = ""

	var empty_method_restore_property := TweenMethod.new()
	empty_method_restore_property.target_id = &"default"
	empty_method_restore_property.preview_restore_property = ""

	var invalid_method_restore_property := TweenMethod.new()
	invalid_method_restore_property.target_id = &"default"
	invalid_method_restore_property.preview_restore_property = "missing_property"

	var missing_method_restore_target := TweenMethod.new()
	missing_method_restore_target.target_id = &"missing"
	missing_method_restore_target.preview_restore_property = "modulate"

	var loop := TweenLoop.new()
	loop.count = 1
	loop.actions = [nested_scale, missing_target, missing_set_target, missing_method_restore_target]

	var sequence := TweenSequence.new()
	sequence.steps = [
		valid_move,
		duplicate_move,
		valid_set,
		duplicate_set,
		invalid_property,
		empty_property,
		missing_set_property,
		empty_set_property,
		disabled_method_restore,
		empty_method_restore_property,
		invalid_method_restore_property,
		loop,
	]

	var target_map: Dictionary[StringName, Node] = { &"default": target as Node }
	var initial_states := PreviewUtils.collect_states(sequence, target_map)
	var position_key := PreviewUtils.build_state_key(target.get_instance_id(), "position")
	var scale_key := PreviewUtils.build_state_key(target.get_instance_id(), "scale")
	var rotation_key := PreviewUtils.build_state_key(target.get_instance_id(), "rotation")
	var modulate_key := PreviewUtils.build_state_key(target.get_instance_id(), "modulate")

	assert_int(initial_states.size()).is_equal(3)
	assert_bool(initial_states.has(position_key)).is_true()
	assert_bool(initial_states.has(scale_key)).is_true()
	assert_bool(initial_states.has(rotation_key)).is_true()
	assert_that(initial_states[position_key]).is_equal(Vector2(3, 4))
	assert_that(initial_states[scale_key]).is_equal(Vector2(1, 1))
	assert_that(initial_states[rotation_key]).is_equal(0.25)
	assert_bool(initial_states.has(modulate_key)).is_false()


func test_preview_utils_restore_states_restores_valid_and_warns_invalid_keys() -> void:
	var root := auto_free(Node2D.new())
	add_child(root)

	var target := auto_free(Node2D.new())
	root.add_child(target)
	target.position = Vector2(20, 30)

	var target_id: int = int(target.get_instance_id())
	var initial_states: Dictionary[String, Variant] = {
		PreviewUtils.build_state_key(target_id, "position"): Vector2(3, 4),
		"invalid-key": Vector2.ZERO,
		"abc:position": Vector2.ZERO,
		"999999999:position": Vector2.ZERO,
		PreviewUtils.build_state_key(target_id, "missing_property"): Vector2.ZERO,
	}

	var warnings: Array[String] = []
	PreviewUtils.restore_states(
		initial_states,
		func(message: String) -> void:
			warnings.append(message)
	)

	assert_that(target.position).is_equal(Vector2(3, 4))
	assert_bool(_string_array_contains_text(warnings, "invalid state key")).is_true()
	assert_bool(_string_array_contains_text(warnings, "invalid instance id")).is_true()
	assert_bool(_string_array_contains_text(warnings, "is no longer valid")).is_true()
	assert_bool(_string_array_contains_text(warnings, "does not exist")).is_true()


func test_preview_utils_needs_restore_matrix() -> void:
	var empty_states: Dictionary[String, Variant] = { }
	var filled_states: Dictionary[String, Variant] = { "1:position": Vector2.ZERO }

	assert_bool(PreviewUtils.needs_restore(false, false, empty_states)).is_false()
	assert_bool(PreviewUtils.needs_restore(true, false, empty_states)).is_true()
	assert_bool(PreviewUtils.needs_restore(false, true, empty_states)).is_true()
	assert_bool(PreviewUtils.needs_restore(false, false, filled_states)).is_true()


func test_preview_utils_resolve_preview_command_matrix() -> void:
	assert_int(
		PreviewUtils.resolve_preview_command(false, false, true),
	).is_equal(PreviewUtils.PREVIEW_TOGGLE_COMMAND_NOOP)
	assert_int(
		PreviewUtils.resolve_preview_command(false, true, false),
	).is_equal(PreviewUtils.PREVIEW_TOGGLE_COMMAND_NOOP)
	assert_int(
		PreviewUtils.resolve_preview_command(false, true, true),
	).is_equal(PreviewUtils.PREVIEW_TOGGLE_COMMAND_PLAY)
	assert_int(
		PreviewUtils.resolve_preview_command(true, false, true),
	).is_equal(PreviewUtils.PREVIEW_TOGGLE_COMMAND_RESTORE)


func test_tween_node_restore_states_keeps_runtime_warning_dedup_with_preview_utils() -> void:
	var tween_node := auto_free(TweenNode.new())
	var invalid_states: Dictionary[String, Variant] = { "invalid-key": Vector2.ZERO }
	_set_private(tween_node, &"_initial_states", invalid_states)

	_call_private(tween_node, &"_restore_states")

	assert_bool(
		(_get_private(tween_node, &"_runtime_warning_once") as Dictionary).has(
			"TweenNode._restore_states(): invalid state key 'invalid-key'.",
		),
	).is_true()


func test_play_emits_finished_once_for_basic_sequence() -> void:
	var root := auto_free(Node.new())
	add_child(root)

	var tween_node := auto_free(TweenNode.new())
	root.add_child(tween_node)

	var wait_action := TweenWait.new()
	wait_action.duration = 0.01

	var sequence := TweenSequence.new()
	sequence.steps = [wait_action]
	tween_node.sequence = sequence

	var finished_count := [0]
	tween_node.finished.connect(
		func():
			finished_count[0] += 1
	)

	tween_node.play()
	await assert_signal(tween_node).wait_until(500).is_emitted("finished")
	await get_tree().process_frame

	assert_int(finished_count[0]).is_equal(1)


func test_stop_interrupts_active_tween_once() -> void:
	var root := auto_free(Node.new())
	add_child(root)

	var tween_node := auto_free(TweenNode.new())
	root.add_child(tween_node)

	var wait_action := TweenWait.new()
	wait_action.duration = 0.5

	var sequence := TweenSequence.new()
	sequence.steps = [wait_action]
	tween_node.sequence = sequence

	var interrupted_count := [0]
	tween_node.interrupted.connect(
		func():
			interrupted_count[0] += 1
	)

	tween_node.play()
	await get_tree().process_frame
	assert_bool(tween_node.is_playing()).is_true()

	tween_node.stop()
	await get_tree().process_frame

	assert_int(interrupted_count[0]).is_equal(1)
	assert_bool(tween_node.is_playing()).is_false()
	assert_bool(_get_private(tween_node, &"_active_tween") == null).is_true()


func test_stop_is_noop_when_idle() -> void:
	var tween_node := auto_free(TweenNode.new())
	var interrupted_count := [0]
	tween_node.interrupted.connect(
		func():
			interrupted_count[0] += 1
	)

	tween_node.stop()

	assert_int(interrupted_count[0]).is_equal(0)
	assert_bool(tween_node.is_playing()).is_false()


func test_pause_is_noop_when_idle() -> void:
	var tween_node := auto_free(TweenNode.new())

	tween_node.pause()

	assert_bool(tween_node.is_paused()).is_false()
	assert_bool(tween_node.is_playing()).is_false()


func test_pause_and_resume_continue_playback() -> void:
	var root := auto_free(Node.new())
	add_child(root)

	var tween_node := auto_free(TweenNode.new())
	root.add_child(tween_node)

	var wait_action := TweenWait.new()
	wait_action.duration = 0.06

	var sequence := TweenSequence.new()
	sequence.steps = [wait_action]
	tween_node.sequence = sequence

	var finished_count := [0]
	tween_node.finished.connect(
		func():
			finished_count[0] += 1
	)

	tween_node.play()
	await get_tree().process_frame

	tween_node.pause()
	assert_bool(tween_node.is_paused()).is_true()

	await get_tree().create_timer(0.03).timeout
	assert_int(finished_count[0]).is_equal(0)

	tween_node.resume()
	assert_bool(tween_node.is_paused()).is_false()
	await assert_signal(tween_node).wait_until(500).is_emitted("finished")

	assert_int(finished_count[0]).is_equal(1)
	assert_bool(tween_node.is_paused()).is_false()


func test_seek_moves_state_without_emitting_interrupted_or_finished() -> void:
	var root := auto_free(Node2D.new())
	add_child(root)

	var target := auto_free(Node2D.new())
	root.add_child(target)
	target.position = Vector2(0, 0)

	var tween_node := auto_free(TweenNode.new())
	root.add_child(tween_node)
	var target_map: Dictionary[StringName, Node] = { &"default": target as Node }
	tween_node.target_map = target_map

	var wait_action := TweenWait.new()
	wait_action.duration = 0.2

	var move_action := TweenProperty.new()
	move_action.target_id = &"default"
	move_action.property = "position:x"
	move_action.to = 100.0
	move_action.duration = 0.0

	var sequence := TweenSequence.new()
	sequence.steps = [wait_action, move_action]
	tween_node.sequence = sequence

	var interrupted_count := [0]
	var finished_count := [0]
	tween_node.interrupted.connect(
		func():
			interrupted_count[0] += 1
	)
	tween_node.finished.connect(
		func():
			finished_count[0] += 1
	)

	tween_node.play()
	await get_tree().process_frame
	tween_node.seek(0.25)
	await get_tree().process_frame

	assert_float(target.position.x).is_equal(100.0)
	assert_int(interrupted_count[0]).is_equal(0)
	assert_int(finished_count[0]).is_equal(0)


func test_seek_keeps_paused_state_when_called_while_paused() -> void:
	var root := auto_free(Node2D.new())
	add_child(root)

	var target := auto_free(Node2D.new())
	root.add_child(target)
	target.position = Vector2(0, 0)

	var tween_node := auto_free(TweenNode.new())
	root.add_child(tween_node)
	var target_map: Dictionary[StringName, Node] = { &"default": target as Node }
	tween_node.target_map = target_map

	var wait_action := TweenWait.new()
	wait_action.duration = 0.5

	var move_action := TweenProperty.new()
	move_action.target_id = &"default"
	move_action.property = "position:x"
	move_action.to = 100.0
	move_action.duration = 0.0

	var sequence := TweenSequence.new()
	sequence.steps = [wait_action, move_action]
	tween_node.sequence = sequence

	tween_node.play()
	await get_tree().process_frame
	tween_node.pause()
	assert_bool(tween_node.is_paused()).is_true()

	tween_node.seek(0.2)
	await get_tree().process_frame

	assert_bool(tween_node.is_paused()).is_true()
	assert_float(target.position.x).is_equal(0.0)


func test_seek_suppresses_side_effect_actions_during_preroll() -> void:
	var root := auto_free(Node.new())
	add_child(root)

	var target := auto_free(TestSeekSideEffectTarget.new())
	root.add_child(target)

	var tween_node := auto_free(TweenNode.new())
	root.add_child(tween_node)
	var target_map: Dictionary[StringName, Node] = { &"default": target as Node }
	tween_node.target_map = target_map

	var wait_action := TweenWait.new()
	wait_action.duration = 0.2

	var call_action := TweenCall.new()
	call_action.target_id = &"default"
	call_action.method_name = &"mark_call"

	var signal_action := SignalEmit.new()
	signal_action.signal_name = &"seek_checkpoint"

	var method_action := TweenMethod.new()
	method_action.target_id = &"default"
	method_action.method_name = &"apply_value"
	method_action.from = 0.0
	method_action.to = 1.0
	method_action.duration = 0.2

	var sequence := TweenSequence.new()
	sequence.steps = [wait_action, call_action, signal_action, method_action]
	tween_node.sequence = sequence

	var emitted_count := [0]
	tween_node.emitted.connect(
		func(_signal_name: StringName, _args: Array[Variant]) -> void:
			emitted_count[0] += 1
	)

	tween_node.play()
	await get_tree().process_frame
	tween_node.pause()
	tween_node.seek(0.35)
	await get_tree().process_frame

	assert_int(target.call_count).is_equal(0)
	assert_int(target.method_call_count).is_equal(0)
	assert_int(emitted_count[0]).is_equal(0)
	assert_bool(tween_node.is_paused()).is_true()


func test_is_playing_returns_false_after_sequence_finishes() -> void:
	var root := auto_free(Node.new())
	add_child(root)

	var tween_node := auto_free(TweenNode.new())
	root.add_child(tween_node)

	var wait_action := TweenWait.new()
	wait_action.duration = 0.2

	var sequence := TweenSequence.new()
	sequence.steps = [wait_action]
	tween_node.sequence = sequence

	tween_node.play()
	await get_tree().process_frame
	assert_bool(tween_node.is_playing()).is_true()

	await assert_signal(tween_node).wait_until(500).is_emitted("finished")
	await get_tree().process_frame

	assert_bool(tween_node.is_playing()).is_false()


func test_tween_wait_delay_keeps_tween_running_until_delay_elapses() -> void:
	var root := auto_free(Node.new())
	add_child(root)

	var tween_node := auto_free(TweenNodeScript.new())
	root.add_child(tween_node)

	var wait_action := TweenWait.new()
	wait_action.duration = 0.0
	wait_action.delay = 0.08

	var sequence := TweenSequence.new()
	sequence.steps = [wait_action]
	tween_node.sequence = sequence

	tween_node.play()
	await get_tree().create_timer(0.01).timeout

	assert_bool(tween_node.is_playing()).is_true()
	await assert_signal(tween_node).wait_until(500).is_emitted("finished")
	await get_tree().process_frame
	assert_bool(tween_node.is_playing()).is_false()


func test_tween_method_applies_final_value_to_target_method() -> void:
	var root := auto_free(Node.new())
	add_child(root)

	var target := auto_free(TestMethodTarget.new())
	root.add_child(target)

	var tween_node := auto_free(TweenNodeScript.new())
	root.add_child(tween_node)
	var target_map: Dictionary[StringName, Node] = { &"default": target as Node }
	tween_node.target_map = target_map

	var method_action := TweenMethod.new()
	method_action.target_id = &"default"
	method_action.method_name = &"apply_value"
	method_action.from = 0.0
	method_action.to = 1.0
	method_action.duration = 0.02

	var sequence := TweenSequence.new()
	sequence.steps = [method_action]
	tween_node.sequence = sequence

	tween_node.play()
	await assert_signal(tween_node).wait_until(500).is_emitted("finished")
	await get_tree().process_frame

	assert_that(target.last_value).is_equal(1.0)


func test_editor_preview_restore_reverts_tween_method_when_preview_restore_enabled() -> void:
	var root := auto_free(Node.new())
	add_child(root)

	var target := auto_free(TestPreviewMethodTarget.new())
	root.add_child(target)
	target.rotation = 0.25

	var method_action := TweenMethod.new()
	method_action.target_id = &"default"
	method_action.method_name = &"apply_rotation"
	method_action.from = 0.0
	method_action.to = 1.0
	method_action.duration = 0.0
	method_action.preview_restore_property = "rotation"

	var sequence := TweenSequence.new()
	sequence.steps = [method_action]

	var tween_node := auto_free(TweenNodeScript.new())
	root.add_child(tween_node)
	var target_map: Dictionary[StringName, Node] = { &"default": target as Node }
	tween_node.target_map = target_map
	tween_node.sequence = sequence

	_call_private(tween_node, &"_editor_play")
	await get_tree().process_frame
	assert_float(target.rotation).is_equal(1.0)

	_call_private(tween_node, &"_restore_states")
	assert_float(target.rotation).is_equal(0.25)


func test_editor_preview_restore_keeps_tween_method_when_preview_restore_disabled() -> void:
	var root := auto_free(Node.new())
	add_child(root)

	var target := auto_free(TestPreviewMethodTarget.new())
	root.add_child(target)
	target.rotation = 0.25

	var method_action := TweenMethod.new()
	method_action.target_id = &"default"
	method_action.method_name = &"apply_rotation"
	method_action.from = 0.0
	method_action.to = 1.0
	method_action.duration = 0.0
	method_action.preview_restore_property = ""

	var sequence := TweenSequence.new()
	sequence.steps = [method_action]

	var tween_node := auto_free(TweenNodeScript.new())
	root.add_child(tween_node)
	var target_map: Dictionary[StringName, Node] = { &"default": target as Node }
	tween_node.target_map = target_map
	tween_node.sequence = sequence

	_call_private(tween_node, &"_editor_play")
	await get_tree().process_frame
	assert_float(target.rotation).is_equal(1.0)

	_call_private(tween_node, &"_restore_states")
	assert_float(target.rotation).is_equal(1.0)


func test_signal_emit_forwards_payload_on_tween_node_signal() -> void:
	var root := auto_free(Node.new())
	add_child(root)

	var tween_node := auto_free(TweenNodeScript.new())
	root.add_child(tween_node)

	var emit_action := SignalEmit.new()
	emit_action.signal_name = &"phase_changed"
	emit_action.args = [1, "go"]

	var sequence := TweenSequence.new()
	sequence.steps = [emit_action]
	tween_node.sequence = sequence

	var emitted_events: Array[Dictionary] = []
	tween_node.emitted.connect(
		func(emitted_name: StringName, emitted_args: Array[Variant]) -> void:
			emitted_events.append(
				{
					"name": emitted_name,
					"args": emitted_args.duplicate(true),
				},
			)
	)

	tween_node.play()
	await assert_signal(tween_node).wait_until(500).is_emitted("finished")
	await get_tree().process_frame

	assert_int(emitted_events.size()).is_equal(1)
	assert_that(emitted_events[0].get("name", &"")).is_equal(&"phase_changed")
	assert_that(emitted_events[0].get("args", [])).is_equal([1, "go"])


func test_signal_emit_works_inside_loop_actions() -> void:
	var root := auto_free(Node.new())
	add_child(root)

	var tween_node := auto_free(TweenNodeScript.new())
	root.add_child(tween_node)

	var emit_action := SignalEmit.new()
	emit_action.signal_name = &"loop_tick"

	var loop := TweenLoop.new()
	loop.count = 2
	loop.actions = [emit_action]

	var sequence := TweenSequence.new()
	sequence.steps = [loop]
	tween_node.sequence = sequence

	var loop_emit_count := [0]
	tween_node.emitted.connect(
		func(emitted_name: StringName, _emitted_args: Array[Variant]) -> void:
			if emitted_name == &"loop_tick":
				loop_emit_count[0] += 1
	)

	tween_node.play()
	await assert_signal(tween_node).wait_until(500).is_emitted("finished")
	await get_tree().process_frame

	assert_int(loop_emit_count[0]).is_equal(2)


func test_play_replaces_active_tween_and_emits_interrupted_once() -> void:
	var root := auto_free(Node.new())
	add_child(root)

	var tween_node := auto_free(TweenNode.new())
	root.add_child(tween_node)

	var wait_action := TweenWait.new()
	wait_action.duration = 0.5

	var sequence := TweenSequence.new()
	sequence.steps = [wait_action]
	tween_node.sequence = sequence

	var interrupted_count := [0]
	tween_node.interrupted.connect(
		func():
			interrupted_count[0] += 1
	)

	tween_node.play()
	tween_node.play()

	await get_tree().process_frame

	assert_int(interrupted_count[0]).is_equal(1)


func test_play_without_sequence_interrupts_active_tween() -> void:
	var root := auto_free(Node.new())
	add_child(root)

	var tween_node := auto_free(TweenNode.new())
	root.add_child(tween_node)

	var wait_action := TweenWait.new()
	wait_action.duration = 0.5

	var sequence := TweenSequence.new()
	sequence.steps = [wait_action]
	tween_node.sequence = sequence

	var interrupted_count := [0]
	tween_node.interrupted.connect(
		func():
			interrupted_count[0] += 1
	)

	tween_node.play()
	tween_node.sequence = null
	tween_node.play()

	await get_tree().process_frame

	assert_int(interrupted_count[0]).is_equal(1)
	assert_bool(_get_private(tween_node, &"_active_tween") == null).is_true()


func test_editor_play_without_sequence_interrupts_active_tween() -> void:
	var root := auto_free(Node.new())
	add_child(root)

	var tween_node := auto_free(TweenNode.new())
	root.add_child(tween_node)

	var wait_action := TweenWait.new()
	wait_action.duration = 0.5

	var sequence := TweenSequence.new()
	sequence.steps = [wait_action]
	tween_node.sequence = sequence

	var interrupted_count := [0]
	tween_node.interrupted.connect(
		func():
			interrupted_count[0] += 1
	)

	_call_private(tween_node, &"_editor_play")
	_set_private(tween_node, &"_preview_toggle", true)
	tween_node.sequence = null
	_call_private(tween_node, &"_editor_play")

	await get_tree().process_frame

	assert_int(interrupted_count[0]).is_equal(1)
	assert_bool(_get_private(tween_node, &"_active_tween") == null).is_true()
	assert_bool(_get_private(tween_node, &"_preview_toggle") as bool).is_false()


func test_prepare_save_restores_preview_state_and_turns_toggle_off() -> void:
	var root := auto_free(Node2D.new())
	add_child(root)

	var target := auto_free(Node2D.new())
	root.add_child(target)
	target.position = Vector2(3, 4)

	var move_action := TweenProperty.new()
	move_action.target_id = &"default"
	move_action.property = "position"
	move_action.to = Vector2(40, 50)
	move_action.duration = 0.0

	var sequence := TweenSequence.new()
	sequence.steps = [move_action]

	var tween_node := auto_free(TweenNode.new())
	root.add_child(tween_node)
	var target_map: Dictionary[StringName, Node] = { &"default": target as Node }
	tween_node.target_map = target_map
	tween_node.sequence = sequence

	_call_private(tween_node, &"_editor_play")
	await get_tree().process_frame
	assert_that(target.position).is_equal(Vector2(40, 50))

	_call_private(tween_node, &"_prepare_save")

	assert_that(target.position).is_equal(Vector2(3, 4))
	assert_bool(_get_private(tween_node, &"_preview_toggle") as bool).is_false()


func test_editor_preview_restore_reverts_tween_set_side_effect() -> void:
	var root := auto_free(Node.new())
	add_child(root)

	var target := auto_free(Label.new())
	root.add_child(target)
	target.text = "before"

	var set_action := TweenSet.new()
	set_action.target_id = &"default"
	set_action.property = &"text"
	set_action.value = "after"

	var sequence := TweenSequence.new()
	sequence.steps = [set_action]

	var tween_node := auto_free(TweenNode.new())
	root.add_child(tween_node)
	var target_map: Dictionary[StringName, Node] = { &"default": target as Node }
	tween_node.target_map = target_map
	tween_node.sequence = sequence

	_call_private(tween_node, &"_editor_play")
	await get_tree().process_frame
	assert_that(target.text).is_equal("after")

	_call_private(tween_node, &"_restore_states")
	assert_that(target.text).is_equal("before")


func test_editor_preview_restore_does_not_revert_tween_call_side_effect() -> void:
	var root := auto_free(Node.new())
	add_child(root)

	var target := auto_free(Node.new())
	root.add_child(target)

	var call_action := TweenCall.new()
	call_action.target_id = &"default"
	call_action.method_name = &"set_meta"
	call_action.args = ["preview_state", "changed"]

	var sequence := TweenSequence.new()
	sequence.steps = [call_action]

	var tween_node := auto_free(TweenNode.new())
	root.add_child(tween_node)
	var target_map: Dictionary[StringName, Node] = { &"default": target as Node }
	tween_node.target_map = target_map
	tween_node.sequence = sequence

	_call_private(tween_node, &"_editor_play")
	await get_tree().process_frame
	assert_that(target.get_meta("preview_state", "")).is_equal("changed")

	_call_private(tween_node, &"_restore_states")
	assert_that(target.get_meta("preview_state", "")).is_equal("changed")


func test_preview_playing_property_is_editor_only_and_non_persistent() -> void:
	var tween_node := auto_free(TweenNode.new())
	var property_info := {
		"name": "_preview_playing",
		"usage": PROPERTY_USAGE_DEFAULT,
	}
	_call_private(tween_node, &"_validate_property", [property_info])

	var usage := int(property_info.get("usage", 0))
	assert_bool((usage & PROPERTY_USAGE_EDITOR) != 0).is_true()
	assert_bool((usage & PROPERTY_USAGE_STORAGE) == 0).is_true()


func test_configuration_warnings_reports_missing_sequence_and_target_map() -> void:
	var tween_node := auto_free(TweenNode.new())
	var target_map: Dictionary[StringName, Node] = { }
	tween_node.target_map = target_map

	var warnings: PackedStringArray = (
		_call_private(tween_node, &"_get_configuration_warnings") as PackedStringArray
	)

	assert_bool(_warnings_contains_text(warnings, "target_map is empty")).is_true()
	assert_bool(_warnings_contains_text(warnings, "sequence is not assigned")).is_true()


func test_configuration_warnings_reports_invalid_nested_action_settings() -> void:
	var tween_node := auto_free(TweenNode.new())
	var default_target := auto_free(Node2D.new())
	add_child(default_target)
	var target_map: Dictionary[StringName, Node] = { &"default": default_target as Node }
	tween_node.target_map = target_map

	var bad_property := TweenProperty.new()
	bad_property.target_id = &"missing"
	bad_property.property = ""
	bad_property.duration = -1.0

	var bad_loop := TweenLoop.new()
	bad_loop.count = 0
	bad_loop.actions = [bad_property]

	var sequence := TweenSequence.new()
	sequence.steps = [bad_loop]
	tween_node.sequence = sequence

	var warnings: PackedStringArray = (
		_call_private(tween_node, &"_get_configuration_warnings") as PackedStringArray
	)

	assert_bool(_warnings_contains_text(warnings, "loop count must be > 0")).is_true()
	assert_bool(_warnings_contains_text(warnings, "target_id 'missing' is not present")).is_true()
	assert_bool(_warnings_contains_text(warnings, "property is empty")).is_true()
	assert_bool(_warnings_contains_text(warnings, "duration must be >= 0.0")).is_true()


func test_configuration_warnings_reports_tween_method_and_signal_emit_settings() -> void:
	var tween_node := auto_free(TweenNode.new())
	var default_target := auto_free(Node.new())
	add_child(default_target)
	var target_map: Dictionary[StringName, Node] = { &"default": default_target as Node }
	tween_node.target_map = target_map

	var bad_method := TweenMethod.new()
	bad_method.target_id = &"default"
	bad_method.method_name = &""
	bad_method.delay = -0.5
	bad_method.duration = -1.0
	bad_method.preview_restore_property = ""

	var bad_method_preview_property := TweenMethod.new()
	bad_method_preview_property.target_id = &"default"
	bad_method_preview_property.method_name = &"set_name"
	bad_method_preview_property.preview_restore_property = "missing_property"

	var bad_signal := SignalEmit.new()
	bad_signal.signal_name = &""

	var sequence := TweenSequence.new()
	sequence.steps = [bad_method, bad_method_preview_property, bad_signal]
	tween_node.sequence = sequence

	var warnings: PackedStringArray = (
		_call_private(tween_node, &"_get_configuration_warnings") as PackedStringArray
	)

	assert_bool(_warnings_contains_text(warnings, "method_name is empty")).is_true()
	assert_bool(_warnings_contains_text(warnings, "delay must be >= 0.0")).is_true()
	assert_bool(_warnings_contains_text(warnings, "duration must be >= 0.0")).is_true()
	assert_bool(
		_warnings_contains_text(
			warnings,
			"preview_restore_property 'missing_property' does not exist",
		),
	).is_true()
	assert_bool(_warnings_contains_text(warnings, "signal_name is empty")).is_true()


func test_warning_utils_build_bundle_matches_expected_messages() -> void:
	var target_map: Dictionary[StringName, Node] = { }
	var warning_bundle := WarningUtils.build_warning_bundle(target_map, null)
	var warnings := warning_bundle.get("warnings", PackedStringArray()) as PackedStringArray
	var null_step_warnings := warning_bundle.get(
		"null_step_warnings",
		PackedStringArray(),
	) as PackedStringArray

	assert_bool(_warnings_contains_text(warnings, "target_map is empty")).is_true()
	assert_bool(_warnings_contains_text(warnings, "sequence is not assigned")).is_true()
	assert_int(null_step_warnings.size()).is_equal(0)


func test_warning_utils_does_not_require_default_when_unused() -> void:
	var target := auto_free(Node2D.new())
	add_child(target)

	var action := TweenSet.new()
	action.target_id = &"foo"
	action.property = &"position"
	action.value = Vector2.ZERO

	var sequence := TweenSequence.new()
	sequence.steps = [action]

	var target_map: Dictionary[StringName, Node] = { &"foo": target as Node }
	var warning_bundle := WarningUtils.build_warning_bundle(target_map, sequence)
	var warnings := warning_bundle.get("warnings", PackedStringArray()) as PackedStringArray

	assert_bool(_warnings_contains_text(warnings, "required key 'default'")).is_false()


func test_tween_set_applies_indexed_property_path() -> void:
	var root := auto_free(Node2D.new())
	add_child(root)

	var target := auto_free(Node2D.new())
	root.add_child(target)
	target.position = Vector2(1, 2)

	var action := TweenSet.new()
	action.target_id = &"default"
	action.property = &"position:x"
	action.value = 10.0

	var sequence := TweenSequence.new()
	sequence.steps = [action]

	var tween_node := auto_free(TweenNode.new())
	root.add_child(tween_node)
	tween_node.target_map = { &"default": target as Node }
	tween_node.sequence = sequence

	tween_node.play()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_float(target.position.x).is_equal(10.0)


func test_warning_utils_compose_includes_or_excludes_null_step_warnings() -> void:
	var warnings := PackedStringArray()
	warnings.append("base warning")
	var null_step_warnings := PackedStringArray()
	null_step_warnings.append("null-step warning")

	var without_null_steps := WarningUtils.compose_warnings(warnings, null_step_warnings, false)
	var with_null_steps := WarningUtils.compose_warnings(warnings, null_step_warnings, true)

	assert_int(without_null_steps.size()).is_equal(1)
	assert_bool(_warnings_contains_text(without_null_steps, "null-step warning")).is_false()
	assert_int(with_null_steps.size()).is_equal(2)
	assert_bool(_warnings_contains_text(with_null_steps, "null-step warning")).is_true()


func test_warning_utils_is_method_callable_handles_existing_and_missing_methods() -> void:
	var target := auto_free(Node.new())

	assert_bool(WarningUtils.is_method_callable(target, &"set_name")).is_true()
	assert_bool(WarningUtils.is_method_callable(target, &"missing_method")).is_false()


func test_tween_node_configuration_warning_output_matches_warning_utils() -> void:
	var tween_node := auto_free(TweenNode.new())
	var default_target := auto_free(Node2D.new())
	add_child(default_target)
	var target_map: Dictionary[StringName, Node] = { &"default": default_target as Node }
	tween_node.target_map = target_map

	var bad_property := TweenProperty.new()
	bad_property.target_id = &"missing"
	bad_property.property = ""
	bad_property.duration = -1.0

	var bad_loop := TweenLoop.new()
	bad_loop.count = 0
	bad_loop.actions = [bad_property]

	var sequence := TweenSequence.new()
	sequence.steps = [bad_loop]
	tween_node.sequence = sequence

	var node_warnings: PackedStringArray = (
		_call_private(tween_node, &"_get_configuration_warnings") as PackedStringArray
	)
	var warning_bundle := WarningUtils.build_warning_bundle(target_map, sequence)
	var util_warnings := warning_bundle.get("warnings", PackedStringArray()) as PackedStringArray
	var util_null_step_warnings := warning_bundle.get(
		"null_step_warnings",
		PackedStringArray(),
	) as PackedStringArray
	var composed_util_warnings := WarningUtils.compose_warnings(
		util_warnings,
		util_null_step_warnings,
		true,
	)

	assert_that("\n".join(node_warnings)).is_equal("\n".join(composed_util_warnings))


func test_inspector_warnings_debounce_null_steps_until_stable() -> void:
	var tween_node := auto_free(TweenNode.new())
	var default_target := auto_free(Node2D.new())
	add_child(default_target)
	var target_map: Dictionary[StringName, Node] = { &"default": default_target as Node }
	tween_node.target_map = target_map

	var sequence := TweenSequence.new()
	var steps: Array[TweenAction] = []
	steps.append(null)
	sequence.steps = steps
	tween_node.sequence = sequence

	_call_private(tween_node, &"_refresh_warnings")
	var first_warnings: PackedStringArray = (
		_call_private(tween_node, &"_get_inspector_warnings") as PackedStringArray
	)
	assert_bool(_warnings_contains_text(first_warnings, "steps[0] is null.")).is_false()

	_call_private(tween_node, &"_refresh_warnings")
	var second_warnings: PackedStringArray = (
		_call_private(tween_node, &"_get_inspector_warnings") as PackedStringArray
	)
	assert_bool(_warnings_contains_text(second_warnings, "steps[0] is null.")).is_true()


func test_inspector_warnings_clear_null_step_after_replacement() -> void:
	var tween_node := auto_free(TweenNode.new())
	var default_target := auto_free(Node2D.new())
	add_child(default_target)
	var target_map: Dictionary[StringName, Node] = { &"default": default_target as Node }
	tween_node.target_map = target_map

	var sequence := TweenSequence.new()
	var first_steps: Array[TweenAction] = []
	first_steps.append(null)
	sequence.steps = first_steps
	tween_node.sequence = sequence

	_call_private(tween_node, &"_refresh_warnings")
	_call_private(tween_node, &"_refresh_warnings")
	assert_bool(
		_warnings_contains_text(
			(_call_private(tween_node, &"_get_inspector_warnings") as PackedStringArray),
			"steps[0] is null.",
		),
	).is_true()

	var wait_action := TweenWait.new()
	var second_steps: Array[TweenAction] = []
	second_steps.append(wait_action)
	sequence.steps = second_steps
	_call_private(tween_node, &"_refresh_warnings")

	var warnings: PackedStringArray = (
		_call_private(tween_node, &"_get_inspector_warnings") as PackedStringArray
	)
	assert_bool(_warnings_contains_text(warnings, "steps[0] is null.")).is_false()


func test_warn_once_deduplicates_messages_within_session() -> void:
	var tween_node := auto_free(TweenNode.new())

	_call_private(tween_node, &"_begin_validation")
	_call_private(tween_node, &"_warn_once", ["duplicate warning"])
	_call_private(tween_node, &"_warn_once", ["duplicate warning"])

	assert_int(
		(_get_private(tween_node, &"_runtime_warning_once") as Dictionary).size(),
	).is_equal(1)
	assert_bool(
		(_get_private(tween_node, &"_runtime_warning_once") as Dictionary).has(
			"duplicate warning",
		),
	).is_true()


func test_begin_validation_clears_warning_cache() -> void:
	var tween_node := auto_free(TweenNode.new())

	_call_private(tween_node, &"_warn_once", ["warning to clear"])
	assert_int(
		(_get_private(tween_node, &"_runtime_warning_once") as Dictionary).size(),
	).is_equal(1)

	_call_private(tween_node, &"_begin_validation")
	assert_int(
		(_get_private(tween_node, &"_runtime_warning_once") as Dictionary).size(),
	).is_equal(0)


func _call_private(instance: Object, method: StringName, args: Array = []) -> Variant:
	return instance.callv(method, args)


func _get_private(instance: Object, member: StringName) -> Variant:
	return instance.get(member)


func _set_private(instance: Object, member: StringName, value: Variant) -> void:
	instance.set(member, value)


func _warnings_contains_text(warnings: PackedStringArray, expected_fragment: String) -> bool:
	for warning in warnings:
		if String(warning).contains(expected_fragment):
			return true
	return false


func _string_array_contains_text(values: Array[String], expected_fragment: String) -> bool:
	for value in values:
		if value.contains(expected_fragment):
			return true
	return false
