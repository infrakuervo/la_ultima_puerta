extends Node
## Desde el editor: ejecutar la escena tests/run_scene.tscn (la salida va al registro del juego).
const Suite = preload("res://tests/suite.gd")


func _ready() -> void:
	var n: Node = Suite.new()
	add_child(n)
	n.run()
