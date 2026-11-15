extends SceneTree
## Línea de comandos:
##   godot --headless --path . --script res://tests/run_tests.gd
const Suite = preload("res://tests/suite.gd")


func _initialize() -> void:
	var n: Node = Suite.new()
	root.add_child(n)
	n.run()
