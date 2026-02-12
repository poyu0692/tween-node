@tool
class_name TweenWait
extends TweenStep
## Tween step that inserts a time interval.

## Delay duration in seconds.
@export var duration: float = 0.5:
	set(v):
		duration = v
		_update_action_resource_name()


## Schedules a tween interval when duration is valid.
func _apply_to_tween(tween: Tween, _target_map: Dictionary[StringName, Node]) -> void:
	if delay < 0.0:
		push_warning("TweenWait._apply_to_tween(): delay must be >= 0.0 (got %s)." % delay)
		return
	if duration < 0.0:
		push_warning("TweenWait._apply_to_tween(): duration must be >= 0.0 (got %s)." % duration)
		return
	tween.tween_interval(delay + duration)


## Builds an inspector-friendly action label.
func _get_action_resource_name() -> String:
	return "Wait: %ss" % str(duration)
