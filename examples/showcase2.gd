extends Node2D

@onready var tween_node: TweenNode = $TweenNode


func _ready() -> void:
	tween_node.play()
