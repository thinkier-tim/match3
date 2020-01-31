extends Node2D

# "export" makes the variable visible in the editor
# warning-ignore:unused_class_variable
export (String) var color	# used in grid.gd for matching piece colors to one another

var move_tween
const MOVE_SPEED = .3

# warning-ignore:unused_class_variable
var matched = false 	# used in grid.gd for marking matching pieces

# Declare member variables here. Examples:
# var a = 2
# var b = "text"

# Called when the node enters the scene tree for the first time.
func _ready():
#	print(get_path())
	#print(get_children())
#	move_tween = get_node("/root/game_window/grid/" + name + "/move_tween")
	move_tween = $move_tween
	assert(move_tween != null)
	pass # Replace with function body.

func move(target):
	move_tween.interpolate_property(self, "position", position, target, MOVE_SPEED, Tween.TRANS_ELASTIC, Tween.EASE_OUT)
	move_tween.start()

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

func dim():
	# sets alpha to 50% (0.5) for a "dimming" effect which is actually just an opacity shift
	var sprite = get_node("Sprite")
	sprite.modulate = Color(1,1,1,.5)


