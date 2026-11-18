extends Node2D
## A canvas layer that hands its _draw() to a callable, so all drawing code can
## live in game.gd / hud.gd while keeping separate draw orders.

var fn: Callable


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if fn.is_valid():
		fn.call(self)
