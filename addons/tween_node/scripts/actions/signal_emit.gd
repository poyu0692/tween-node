@tool
class_name SignalEmit
extends TweenAction
## Tween action that emits `TweenNode.emitted` with configured payload.

const OWNER_ID_META_KEY := &"_signal_emit_owner_id"

## Dynamic signal name forwarded through `TweenNode.emitted`.
@export var signal_name: StringName:
	set(v):
		signal_name = v
		_update_action_resource_name()
## Arguments payload forwarded through `TweenNode.emitted`.
@export var args: Array[Variant] = []:
	set(v):
		args = v
		_update_action_resource_name()


## Validates payload and schedules signal emission callback.
func _apply_to_tween(tween: Tween, _target_map: Dictionary[StringName, Node]) -> void:
	if signal_name == &"":
		push_warning("SignalEmit: signal_name is empty.")
		return
	if not tween.has_meta(OWNER_ID_META_KEY):
		push_warning("SignalEmit: tween runtime context is missing owner id.")
		return
	var owner_id_variant := tween.get_meta(OWNER_ID_META_KEY, -1)
	if typeof(owner_id_variant) != TYPE_INT:
		push_warning("SignalEmit: tween runtime owner id is invalid.")
		return
	tween.tween_callback(
		_emit_forwarded_signal.bind(int(owner_id_variant), signal_name, args, tween)
	)


## Builds an inspector-friendly action label.
func _get_action_resource_name() -> String:
	var args_str = "[%s]" % ", ".join(args.map(func(x): return str(x)))
	return "🚨(%s, %s)::emit()" % [signal_name, args_str]


## Emits payload via `TweenNode.emitted` if the owner still supports it.
func _emit_forwarded_signal(
		owner_id: int,
		forward_signal_name: StringName,
		forward_args: Array[Variant],
		owner_tween: Tween,
) -> void:
	if owner_tween != null and owner_tween.has_meta(SEEK_SUPPRESS_SIDE_EFFECTS_META_KEY):
		return
	var runtime_owner := instance_from_id(owner_id)
	if runtime_owner == null or not is_instance_valid(runtime_owner):
		push_warning("SignalEmit: runtime owner became invalid before callback execution.")
		return
	if not runtime_owner.has_signal(&"emitted"):
		push_warning("SignalEmit: runtime owner does not define signal 'emitted'.")
		return
	runtime_owner.emit_signal(&"emitted", forward_signal_name, forward_args)
