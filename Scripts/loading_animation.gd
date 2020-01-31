extends Node2D

# place "loading" and the ellipsis in appropriate positions
# color them with modulate (cycle/shift colors for the heck of it?)
# visible 1 dot, then 2, then all three, then back to one.
# cycle visibility on loading-related events (signals?)
# should this be integrated with the fetcher?

# color cycling
var inner_start_color:= Color(1,0,0,1)
var inner_end_color:= Color(0,0,1,1)
var inner_color_steps:= 20
var inner_current_step:= 0
var inner_step_direction:="up"

var outer_start_color:= Color(0,0,1,1)
var outer_end_color:= Color(1,0,0,1)
var outer_color_steps:= 20
var outer_current_step:= 0
var outer_step_direction:="down"


var animation_timer:= 0.0
var animation_tick:= 0.1

var dot_state = 0
var dot_LCV = 0
var dot_LCV_max = 4
#onready var dot1i = $dot_inner
#onready var dot1o = $dot_outer
onready var dot2i = $dot2_inner
onready var dot2o = $dot2_outer
onready var dot3i = $dot3_inner
onready var dot3o = $dot3_outer

func _ready():
	print("displaying loading screen")



func _physics_process(delta):
	animation_timer += delta
	if animation_timer >= animation_tick:
		animation_timer -= animation_tick
		shift_colors()
		dot_LCV += 1
		if dot_LCV > dot_LCV_max:
			make_dots()
			dot_LCV = 0


func inner_next_color_in_cycle():
	# step application
	if inner_step_direction == "up":
		inner_current_step += 1
	else:
		inner_current_step -= 1
	# bounds checking and direction shifting
	if inner_current_step < 0:
		inner_current_step = 0
		inner_step_direction = "up"
	elif inner_current_step > inner_color_steps:
		inner_current_step = inner_color_steps
		inner_step_direction = "down"

	var the_color = (((inner_end_color - inner_start_color) / inner_color_steps) * inner_current_step) + inner_start_color

	var color_as_array = []
	color_as_array.append(the_color.r)
	color_as_array.append(the_color.g)
	color_as_array.append(the_color.b)
	color_as_array.append(the_color.a)

	for channel in color_as_array:
		while channel < 0.0:
			channel += 1.0
		while channel > 1.0:
			channel -= 1.0
	the_color = Color(color_as_array[0],color_as_array[1],color_as_array[2],color_as_array[3])

	return the_color

func outer_next_color_in_cycle():
	# step application
	if outer_step_direction == "up":
		outer_current_step += 1
	else:
		outer_current_step -= 1
	# bounds checking and direction shifting
	if outer_current_step < 0:
		outer_current_step = 0
		outer_step_direction = "up"
	elif outer_current_step > outer_color_steps:
		outer_current_step = outer_color_steps
		outer_step_direction = "down"

	var the_color = (((outer_end_color - outer_start_color) / outer_color_steps) * outer_current_step) + outer_start_color

#	var color_as_array = []
#	color_as_array.append(the_color.r)
#	color_as_array.append(the_color.g)
#	color_as_array.append(the_color.b)
#	color_as_array.append(the_color.a)

	for channel in [the_color.r,the_color.g,the_color.b,the_color.a]:
		while channel < 0.0:
			channel += 1.0
		while channel > 1.0:
			channel -= 1.0
#	the_color = Color(color_as_array[0],color_as_array[1],color_as_array[2],color_as_array[3])

	return the_color

func shift_colors():
	if visible:
		var inner_color = inner_next_color_in_cycle()
		var outer_color = outer_next_color_in_cycle()
		for child in get_children():
			if child.name.ends_with("inner"):
				child.modulate = inner_color
			else:
				child.modulate = outer_color


func make_dots():
	dot_state += 1
	if dot_state >= 4:
		dot_state = 1
#	print("loading_animation:make_dots(): num_dots = ", dot_state)
	match dot_state:
		1:
			dot2i.visible = false
			dot2o.visible = false
			dot3i.visible = false
			dot3o.visible = false
		2:
			dot2i.visible = true
			dot2o.visible = true
			dot3i.visible = false
			dot3o.visible = false
		3:
			dot2i.visible = true
			dot2o.visible = true
			dot3i.visible = true
			dot3o.visible = true


