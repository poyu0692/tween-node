@tool
@abstract
class_name TweenStep
extends TweenAction
## Abstract tween action that can run in chain or parallel mode.

## Delays start of this step by the given seconds.
@export var delay: float = 0.0:
	set(v):
		if is_equal_approx(delay, v):
			return
		delay = v
		_update_action_resource_name()
## Executes this step in parallel with the previous chain when true.
@export var parallel: bool = false:
	set(v):
		if parallel == v:
			return
		parallel = v
		_update_action_resource_name()


## Adds a visual prefix that indicates execution mode.
func _update_action_resource_name() -> void:
	var prefix = "🔀" if parallel else "➡️"
	var delay_suffix := ""
	if delay > 0.0:
		delay_suffix = " (+%ss)" % str(delay)
	resource_name = prefix + _get_action_resource_name() + delay_suffix
