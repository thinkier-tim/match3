extends Node2D

#TODO: fix obstacles - we're constantly spraying errors about not being able to emit signals, and other stuff

#TODO: create loading screen (essentially, placing and animating the sprites/textures)
#	use the loading_imagery_scaffolding to figure out all the things

#FIXME: i broke the matching code! argh.


enum GameState { WAIT, MOVE }
var state

# game grid variables
var grid_width = 8
var grid_height = 10
var x_start = 64
var y_start = 800
var offset = 64
var drop_offset = 2

# obstacle variables (PoolVector2Array, but that doesn't have a "has"?!?)
export (PoolVector2Array) var empty_spaces
export (PoolVector2Array) var ice_spaces
export (PoolVector2Array) var lock_spaces
export (PoolVector2Array) var concrete_spaces
export (PoolVector2Array) var slime_spaces

var damaged_slime_this_turn = false
var can_make_slime = false

#FIXME: these signals have no reason to exist, and should be function calls instead
enum ObstacleTypes { ICE, LOCK, CONCRETE, SLIME }
signal make_obstacle(obstacle_type)
signal damage_obstacle(obstacle_type)

# pool of pieces we're allowed to drop
var possible_pieces = []
# game grid
var pieces_in_grid = []

# piece-swapping (used in swap_back())
var piece_one = null				# the last piece to be moved
var piece_two = null				# the piece it was swapped with
var last_place = Vector2.ZERO		# the last "start move" position
var last_direction = Vector2.ZERO	# the last "finish move" direction
var move_checked = false			# shows whether the most recent move has been checked for matches

# input and piece control vars
var touch_first = Vector2.ZERO
var touch_last = Vector2.ZERO
var controlling = false

# timer variables (these should probably be handled in heartbeat, instead)
#var destroy_timer
#var collapse_timer
#var refill_timer

var heartbeat_timer = 0.0
var heartbeat_limit = 0.5
enum HeartBeatActions { NONE, SEEK, DESTROY, COLLAPSE, REFILL }
var heartbeat_action = HeartBeatActions.NONE

# script strings
var piece_script = """
extends Node2D

# warning-ignore:unused_variable
export (String) var color	# used in grid.gd for matching piece colors to one another

var move_tween
const MOVE_SPEED = .3

# warning-ignore:unused_variable
var matched = false 	# used in grid.gd for marking matching pieces

func _ready():
	move_tween = $move_tween
	assert(move_tween != null)

func move(target):
	move_tween.interpolate_property(self, "position", position, target, MOVE_SPEED, Tween.TRANS_ELASTIC, Tween.EASE_OUT)
	move_tween.start()

func dim():
	# sets alpha to 50% (0.5) for a "dimming" effect which is actually just an opacity shift
	var sprite = get_node("Sprite")
	sprite.modulate = Color(1,1,1,.5)
"""
# this is from ice.gd, but all obstacles use it
var obstacle_script = """
extends Node2D

var health = 1

func take_damage(damage):
	health -= damage
	# can add damage effects here (particle effects, etc)
"""
# can we generify the *_holder scripts?
var ice_holder_script = """
extends Node2D

var ice_pieces = []
var width = 8
var height = 10
#var ice = preload("res://Scenes/ice.tscn")
# this loads a node2d named 'ice', adds script 'ice.gd', generates a sprite, and sets sprite.texture to ice.png

func make_2d_array():
	# initialize the array with nulls
	var array = []
	for i in width:
		array.append([])
		for j in height:
			array[i].append(null)
	return array

# replace this with some shit in game.gd
func _on_grid_make_ice(board_position):
	if ice_pieces.size() == 0:
		ice_pieces = make_2d_array()
	var current = ice.instance()
	add_child(current)
	current.position = Vector2(board_position.x * 64 + 64, -board_position.y * 64 + 800)
	ice_pieces[board_position.x][board_position.y] = current

# replace this with some shit in game.gd
func _on_grid_damage_ice(board_position):
	if ice_pieces[board_position.x][board_position.y] != null:
		ice_pieces[board_position.x][board_position.y].take_damage(1)
		if ice_pieces[board_position.x][board_position.y].health <= 0:
			ice_pieces[board_position.x][board_position.y].queue_free()
			ice_pieces[board_position.x][board_position.y] = null
	pass # Replace with function body.
"""


func _ready():
	print("game.gd:_ready()")
	state = GameState.MOVE
	randomize()
	pieces_in_grid = make_2d_array()
#	check_copy()	# DEBUG - determining whether a copied array (the game grid) is a copy or another handle :P
	display_loading_screen()


func copy_array(array_to_copy):
#	var new_copy = str2var(var2str(array_to_copy))
#	# note: Array.duplicate(true) returns ref, not val. NO WORKIE.
#	return new_copy
	return str2var(var2str(array_to_copy))


#func check_copy():
#	var blah = copy_array(pieces_in_grid)
#	blah[1][1].color = "mauve"
#	if blah[1][1] == pieces_in_grid[1][1]:
#		print("Dammit! Still not a good copy!")
#		print(pieces_in_grid[1][1].color, " == ", blah[1][1].color)
#	else:
#		print("Holy shit, it actually made a real copy!")
#		print(pieces_in_grid[1][1].color, " != ", blah[1][1].color)


func restricted_fill(place):
# checks to see whether placing a piece is allowed in the given space
	# check the empty pieces
	if is_in_array(empty_spaces, place):
		return true
	# check the concrete pieces
	if is_in_array(concrete_spaces, place):
		return true
	# check the slime spaces
	if is_in_array(slime_spaces, place):
		return true
	return false


func is_immobile(place):
# checks to see whether a piece is allowed to move
	# check licorice/lock pieces
	if is_in_array(lock_spaces, place):
		return true
	# check the concrete pieces
	if is_in_array(concrete_spaces, place):
		return true
	return false


func is_in_array(array, item):
	# returns true if item is in array, else false
	# this is to deal with PoolVector2Array not having a .has()
	for i in array.size():
		if array[i] == item:
			return true
	return false

func remove_from_array(array, item):
	# returns array with item removed
	# this should just be the native "array.erase(item_to_look_for)", but PoolVector2Array doesn't have it
	for i in range(array.size() -1, -1, -1):
		if array[i] == item:
			array.remove(i)
	return array


func make_2d_array():
	# initialize the array with nulls
	# is this even necessary?
	var array = []
	for i in grid_width:
		array.append([])
		for j in grid_height:
			array[i].append(null)
	return array


# creates pieces from bottom to top, then proceeds to next column to the right
# used at the beginning of the game to generate the entire gamefield
func spawn_pieces():
#	print("spawn_pieces():")
	for i in grid_width:
		for j in grid_height:
			# check for movement restriction
			if !restricted_fill(Vector2(i, j)):
				# choose a random number and store it
				var rand = floor(rand_range(0,possible_pieces.size()))
				# instantiate that piece from the array so we can check the color
				var piece = possible_pieces[rand].instance()
				
				# check for match (we're avoiding matches in the initial board)
				var loops = 0	# ideally, we only loop 100 times trying to get a piece that doesn't match...
				while(match_at(i, j, piece.color) && loops < possible_pieces.size()):
					# generate a new random piece
					rand=floor(rand_range(0,possible_pieces.size()))
					# instantiate the new piece
					piece = possible_pieces[rand].instance()
					# increment the loop counter
					loops += 1
					# and then the while loop checks the color of the instantiated piece
				# assuming we have a non-matching piece, we can go ahead and add it to the scene
				add_child(piece)
				piece.get_node("Sprite").visible = true
				# move the non-matching piece into the proper position
				piece.position = grid_to_pixel(i,j)
				# to have them drop in from above the grid, comment the above line
				# and uncomment the two below
				#piece.position = grid_to_pixel(i, j - y_offset)
				#piece.move(grid_to_pixel(i,j))
	
				# update the logic grid
				pieces_in_grid[i][j] = piece


# generate all obstacles
func spawn_obstacles():
# calls each of the obstacle generation routines
# used to generate the initial state of the gamefield
# it should actually be "spawn_obstacle(obstacle_type)", a general obstacle factory
# or perhaps even a generic piece generation routine?
	spawn_ice()
	spawn_locks()
	spawn_concrete()
	spawn_slime()

# this collection of spawners is emitting signals because the obstacles are all self-scripted
# how can we streamline this process?


func spawn_ice():
	for i in ice_spaces.size():
		emit_signal("make_ice", ice_spaces[i])


func spawn_locks():
	for i in lock_spaces.size():
		emit_signal("make_lock", lock_spaces[i])


func spawn_concrete():
	for i in concrete_spaces.size():
		emit_signal("make_concrete", concrete_spaces[i])


func spawn_slime():
	for i in slime_spaces.size():
		emit_signal("make_slime", slime_spaces[i])


# helper function - checks for matching colors
# checks the two columns to the left of the given grid coords
# checks the two rows below the given grid coords
# returns true if all 3 are the same
# does NOT mark piece as matched
func match_at(column, row, color):
	if column > 1:	# verify we're looking at a valid column
		# and check to see if we have enough pieces to our left to check for a match
		if pieces_in_grid[column - 1][row] != null && pieces_in_grid[column - 2][row] != null:
			# finally, look for a horizontal match with the two pieces to the left
			if pieces_in_grid[column - 1][row].color == color && pieces_in_grid[column - 2][row].color == color:
				# print("grid:match_at: Found horizontal match at ", column, ",", row, " - color was ", color)
				return true
	if row > 1:	# verify we're looking at a valid row
		# and check to see if we have enough pieces below us to check for a match
		if pieces_in_grid[column][row - 1] != null && pieces_in_grid[column][row - 2] != null:
			# finally, look for a vertical match with the two pieces below
			if pieces_in_grid[column][row - 1].color == color && pieces_in_grid[column][row - 2].color == color:
				# print("grid:match_at: Found vertical match at ", column, ",", row, " - color was ", color)
				return true
	# print("grid:match_at: No match found at ", column, ",", row, " - color was ", color)
	# mister taft uses a "pass" statement here.
	# I would rather explicitly return false if the execution gets to this point
	return false


# helper function - translates grid coords to pixel coords
func grid_to_pixel(column, row):
	var new_x = x_start + offset * column
	var new_y = y_start + -offset * row
	return Vector2(new_x,new_y)
	# more efficient in terms of garbage collection?
	# return Vector2(x_start + offset * column,y_start + -offset * row)
	# garbage collection is automatic, this is a reference-counting language


# helper function - translates pixel (screen) coords to grid coords
func pixel_to_grid(pixel_x,pixel_y):
	var column = round((pixel_x - x_start) / offset)
	var row = round((pixel_y - y_start) / -offset)
	# print( "grid:pixel_to_grid: ", column , ", ", row)
	return Vector2(column,row)
	# more efficient in terms of garbage collection?
	# return Vector2((pixel_x - x_start)/offset,(pixel_y - y_start)/-offset)


func is_in_grid(grid_position):
	# return true if specified coord is inside the gamefield
	if grid_position.x >= 0 && grid_position.x < grid_width:
		if grid_position.y >= 0 && grid_position.y < grid_height:
			return true
	return false


func _unhandled_input(event):
	# handle touch input
	if event is InputEventScreenTouch:
		if event.is_pressed():
			tap_or_click(event.position)
		else:
			un_tap_or_click(event.position)
	# handle mouse clicks
	elif event is InputEventMouseButton:
		if event.get_button_index() == BUTTON_LEFT:
			if event.is_pressed():
				tap_or_click(event.position)
			else:
				un_tap_or_click(event.position)


func tap_or_click(screen_position):
#	print("grid:tap_or_click", screen_position)
# doesn't count if the first tap isn't on a piece
	if is_in_grid(pixel_to_grid(screen_position.x,screen_position.y)):
		touch_first = pixel_to_grid(screen_position.x, screen_position.y)
		controlling = true


func un_tap_or_click(screen_position):
#	print("grid:un_tap_or_click", screen_position)
#	if is_in_grid(touch_coords) && controlling:
# we don't actually care if the second touch is in the grid or not...
	if controlling:
		controlling = false
		touch_last = pixel_to_grid(screen_position.x, screen_position.y)
		touch_difference(touch_first, touch_last)


func swap_pieces(column, row, direction):
	var other_piece = null
	# this gets called when a move is made
#	print("grid:swap_pieces(column:", column, ", row:", row, ", direction:", direction)
	
	var first_piece = pieces_in_grid[column][row]
	if is_in_grid(Vector2(column + direction.x,row+direction.y)):
		other_piece = pieces_in_grid[column + direction.x][row + direction.y]
#		print("grid:swap_pieces(): valid swap")
#	else:
#		print("grid:swap_pieces(): NOT valid swap")

	# pulled this out of the below if statement in an attempt
	# to avoid swapping pieces when nothing actually needs to move
	# (ie, stop swapping pieces because we touched a locked piece)
	store_info(first_piece, other_piece, Vector2(column,row), direction)

	if first_piece != null and other_piece != null:
		if !is_immobile(Vector2(column, row)) && !is_immobile(Vector2(column, row) + direction):
			# change game state
			state = GameState.WAIT
			# pulled this above the if statement in an attempt
			# to avoid swapping pieces when nothing actually needs to move
			#store_info(first_piece, other_piece, Vector2(column,row), direction)
			pieces_in_grid[column][row] = other_piece
			pieces_in_grid[column + direction.x][row + direction.y] = first_piece
			#first_piece.position = grid_to_pixel(column + direction.x, row + direction.y)
			first_piece.move(grid_to_pixel(column + direction.x, row + direction.y))
			#other_piece.position = grid_to_pixel(column, row)
			other_piece.move(grid_to_pixel(column, row))
			if !move_checked:
				can_make_slime = true
				find_matches()


func store_info(first_piece, other_piece, place, direction):
	piece_one = first_piece
	piece_two = other_piece
	last_place = place
	last_direction = direction


func swap_back():
	# move the previously swapped pieces back to their previous places
	#print("grid:swap_back:No match occurred during this move, so undoing move")
	if piece_one != null && piece_two != null:
		if !is_immobile(last_place) && !is_immobile(last_place + last_direction):
			swap_pieces(last_place.x, last_place.y, last_direction)
	state = GameState.MOVE
	move_checked = false
	can_make_slime = false


func touch_difference(grid_1, grid_2):
	var difference = grid_2 - grid_1
#	print("grid:touch_difference: diff = ", difference.x, ", ", difference.y)
	if abs(difference.x) > abs(difference.y):
		if difference.x > 0:
			swap_pieces(grid_1.x,grid_1.y, Vector2(1,0))
		elif difference.x < 0:
			swap_pieces(grid_1.x,grid_1.y, Vector2(-1,0))
	elif abs(difference.y) > abs(difference.x):
		if difference.y > 0:
			swap_pieces(grid_1.x,grid_1.y, Vector2(0,1))
		elif difference.y < 0:
			swap_pieces(grid_1.x,grid_1.y, Vector2(0,-1))


func _physics_process(delta):
	heartbeat_timer += delta
	if heartbeat_timer >= heartbeat_limit:
		heartbeat_timer -= heartbeat_limit
		_do_heartbeat()
	pass


func _do_heartbeat():
	match heartbeat_action:
		HeartBeatActions.SEEK:
			find_matches()
		HeartBeatActions.COLLAPSE:
			collapse_columns()
		HeartBeatActions.DESTROY:
			destroy_matched()
		HeartBeatActions.REFILL:
			refill_columns()


func match_and_dim(item):
	item.matched = true
	item.dim()


func is_piece_null(column, row):
	if pieces_in_grid[column][row] == null:
		return true
	return false


func find_matches():
	var number_of_matches = 0
	for i in grid_width:
		for j in grid_height:
			if pieces_in_grid[i][j] != null:
				var current_color = pieces_in_grid[i][j].color
				if i > 0 && i < grid_width - 1:
					if !is_piece_null(i-1,j) && !is_piece_null(i+1,j):
						if pieces_in_grid[i-1][j].color == current_color && \
						pieces_in_grid[i+1][j].color == current_color:
							number_of_matches += 1
							match_and_dim(pieces_in_grid[i - 1][j])
							match_and_dim(pieces_in_grid[i][j])
							match_and_dim(pieces_in_grid[i + 1][j])
							# TODO: OPTIMIZE THIS LOOP
							# is there a way to set all three in less than 6 lines?
							# for that matter, why is it necessary to change the color of more than self?
				if j > 0 && j < grid_height -1:
					if !is_piece_null(i,j-1) && !is_piece_null(i,j+1):
						if pieces_in_grid[i][j-1].color == current_color && \
						pieces_in_grid[i][j+1].color == current_color:
							number_of_matches += 1
							match_and_dim(pieces_in_grid[i][j - 1])
							match_and_dim(pieces_in_grid[i][j])
							match_and_dim(pieces_in_grid[i][j + 1])
				# replaced because this is done in _ready() to avoid duplicate effort
				# get_parent().get_node("destroy_timer").start()
#				destroy_timer.start()
	print("game.gd:find_matches(): found ", number_of_matches, " matches!")
	if heartbeat_timer > 0.3:
		heartbeat_timer -= 0.3
	heartbeat_action = HeartBeatActions.DESTROY


func destroy_matched():
	var was_matched = false
	for i in grid_width:
		for j in grid_height:
			if pieces_in_grid[i][j] != null:
				if pieces_in_grid[i][j].matched:
					#damage_special(i,j)
					was_matched = true
					pieces_in_grid[i][j].queue_free()
					# still have to null the node after queue_free()
					# i assume this is because queue_free() essentially just marks it for GC?
					# look into call_deferred("free")
					pieces_in_grid[i][j] = null
					# why do we have to null the piece?
	move_checked = true

	if was_matched:
		print("grid:destroy_matched: matches found")
#		collapse_timer.start()
		heartbeat_action = HeartBeatActions.COLLAPSE
	else:
		print("grid:destroy_matched: no matches found, undoing move")
#		print_stack()
		swap_back()


func check_concrete(column, row):
	# check everything *around* the given position, to damage *adjacent* concrete
	# check right
	if column < grid_width - 1:
		emit_signal("damage_concrete", Vector2(column + 1, row))
	# check left
	if column > 0:
		emit_signal("damage_concrete", Vector2(column - 1, row))
	# check up
	if row < grid_height - 1:
		emit_signal("damage_concrete", Vector2(column, row + 1))
	# check down
	if row > 0:
		emit_signal("damage_concrete", Vector2(column, row - 1))


func check_slime(column, row):
	# check everything *around* the given position, to damage *adjacent* concrete ... err, slime
	# check right
	if column < grid_width - 1:
		emit_signal("damage_slime", Vector2(column + 1, row))
	# check left
	if column > 0: #FIXME: should this instead be 1?
		emit_signal("damage_slime", Vector2(column - 1, row))
	# check up
	if row < grid_height - 1:
		emit_signal("damage_slime", Vector2(column, row + 1))
	# check down
	if row > 0:
		emit_signal("damage_slime", Vector2(column, row - 1))


func damage_special(column, row):
	emit_signal("damage_ice", Vector2(column, row))
	emit_signal("damage_lock", Vector2(column, row))
	check_concrete(column, row)
	check_slime(column, row)


func _on_destroy_timer_timeout():
	#print("grid:_on_destroy_timer_timeout: fired")
	destroy_matched()


func collapse_columns():
	for i in grid_width:
		for j in grid_height:
			if pieces_in_grid[i][j] == null && !restricted_fill(Vector2(i, j)):
				for k in range(j+1, grid_height):
					if pieces_in_grid[i][k] != null:
						pieces_in_grid[i][k].move(grid_to_pixel(i,j))
						pieces_in_grid[i][j] = pieces_in_grid[i][k]
						pieces_in_grid[i][k] = null
						break
	# replaced because this is done in _ready() to avoid duplicate effort
	# get_parent().get_node("refill_timer").start()
#	refill_timer.start()
	heartbeat_action = HeartBeatActions.REFILL


func _on_collapse_timer_timeout():
	#print("grid:_on_collapse_timer_timeout: fired")
	collapse_columns()


func refill_columns():
	#print("grid:refill_columns: fired")
	for i in grid_width:
		for j in grid_height:
			if pieces_in_grid[i][j] == null && !restricted_fill(Vector2(i, j)):
				# choose a random number and store it
				var rand = floor(rand_range(0,possible_pieces.size()))
				# instantiate that piece from the array so we can check the color
				var piece = possible_pieces[rand].instance()
				# this is likely to be ridiculously memory-intensive, and generate a ton of garbage
	
				# check for match (we're avoiding matches in the initial board)
				var loops = 0	# ideally, we only loop 100 times trying to get a piece that doesn't match...
				while(match_at(i, j, piece.color) && loops < 100):
					# generate a new random piece
					rand=floor(rand_range(0,possible_pieces.size()))
					# instantiate the new piece
					piece = possible_pieces[rand].instance()
					# increment the loop counter
					loops += 1
					# and then the while loop checks the color of the instantiated piece
				#print("refill:loop count: ", loops) # empirical data suggests that this loop runs only once, sometimes twice
				# assuming we have a non-matching piece, we can go ahead and add it to the scene
				add_child(piece)

				# move the non-matching piece into the proper position
				# piece.position = grid_to_pixel(i, j)
				# to have the pieces drop in from above the grid, comment the line above
				# and uncomment the two lines below
				piece.position = grid_to_pixel(i, j - drop_offset)
				piece.move(grid_to_pixel(i,j))
				piece.get_node("Sprite").visible = true
				# update the logic grid
				pieces_in_grid[i][j] = piece

				# do post-processing (break more matched blocks)
				after_refill()	# not sure why there's an additional function call here
								# consider pulling after_refill() into refill_columns()?

func after_refill():
	for i in grid_width:
		for j in grid_height:
			if pieces_in_grid[i][j] != null:
				if match_at(i, j, pieces_in_grid[i][j].color):
					find_matches()
					return; # break out of the method, we only need a reason to start the "a move has been made" sequence

	# this is broken and fires more than once per "move"
	# possible fix: use a global boolean to indicate whether to generate a slime or not
	# (set it to true at the beginning of swap_pieces, and false once slime has been generated)
	# if slime was not damaged this turn,
	if can_make_slime:
#		print("grid:after_refill: slime has not been generated this move, but can be")
		if !damaged_slime_this_turn:
#			print("grid:after_refill: slime has not been damaged this move, making *one* slime")
			generate_slime()		# make a new slime
			can_make_slime = false	# generate slime only once per move!
		else:
#			print("grid:after_refill: slime has been damaged this move, should not make slime")
			can_make_slime = false
#	else:
#		print("grid:after_refill: slime can not be made, doing nothing")
	#print_stack()

	# if no matches have been found, allow moves again
	state = GameState.MOVE
	move_checked = false	# current move has been resolved, so set up for the next move
	damaged_slime_this_turn = false # reset the slime damage marker


func generate_slime():
	# make sure there are slime pieces on the board
	if slime_spaces.size() > 0:
		var slime_made = false
		var tracker = 0
		while !slime_made && tracker < 100:
			# check a random slime
			var random_num = floor(rand_range(0, slime_spaces.size()))
			var neighbor = find_normal_neighbor(slime_spaces[random_num].x, slime_spaces[random_num].y)
			if neighbor != null:
				# print_debug(neighbor)
				# turn the found neighbor into slime
				# start by removing the space from the playable spaces
				pieces_in_grid[neighbor.x][neighbor.y].queue_free()
				pieces_in_grid[neighbor.x][neighbor.y] = null
				# add the space to slime array
				slime_spaces.append(Vector2(neighbor.x,neighbor.y))
				#print(slime_spaces)
				# signal slime_holder to make a new slime at the space
				emit_signal("make_slime", Vector2(neighbor.x,neighbor.y))
				slime_made = true
			tracker += 1
#		print("grid:generate_slime:tracker = ", tracker)
#	else:
#		print("no slime to make more slime from, aborting slime generation")


func find_normal_neighbor(column, row):
	# finds all "normal" (non-slime, non-concrete) tiles,
	# returns a random found "normal" neighbor
	# returns null if no "normal" neighbors found
	
	# TODO: (later) maybe allow concrete (etc) to get slimed, too?
	
	# array to hold found "normal" neighbors
	var normal_neighbors = []
	# check right
	if is_in_grid(Vector2(column + 1, row)):
		if pieces_in_grid[column + 1][row] != null:
			normal_neighbors.append(Vector2(column + 1, row))
	# check left
	if is_in_grid(Vector2(column - 1, row)):
		if pieces_in_grid[column - 1][row] != null:
			normal_neighbors.append(Vector2(column - 1, row))
	# check up
	if is_in_grid(Vector2(column, row + 1)):
		if pieces_in_grid[column][row + 1] != null:
			normal_neighbors.append(Vector2(column, row + 1))
	# check down
	if is_in_grid(Vector2(column, row - 1)):
		if pieces_in_grid[column][row - 1] != null:
			normal_neighbors.append(Vector2(column, row - 1))

	# return a found neighbor at random, if any exist
	if normal_neighbors.size() > 0:
		return normal_neighbors[floor(rand_range(0,normal_neighbors.size()))]
	else:
		# no normal neighbors found
		return null


func _on_refill_timer_timeout():
	refill_columns()


func _on_lock_holder_remove_lock(place):
	lock_spaces.erase(place)


func _on_concrete_holder_remove_concrete(place):
	concrete_spaces.erase(place)


func _on_slime_holder_remove_slime(place):
	damaged_slime_this_turn = true
	slime_spaces.erase(place)


func get_pieces():
	#TODO: see if we can acquire the loading imagery FIRST
	#	... might need to do something even earlier, before pulling anything down
	#	see root:_on_fetcher_texture_processed()
	
	# this is a neat fucking trick: generating packed_scenes to load, without an actual file system
	var textures = get_parent().textures
	var LCV = 0
	for item in textures.keys():
		match item.left(5):
			"backg":
				var background = Sprite.new()
				add_child(background)
				background.texture = textures[item]
				background.position = Vector2(288,512)
			"piece":
				# create a scene
				var gamepiece_scene = PackedScene.new()
				# create the base gamepiece node
				var gamepiece_node = Node2D.new()
				add_child(gamepiece_node)
				gamepiece_node.name = item
				# add a sprite, so we can display images
				var gamepiece_sprite = Sprite.new()
				gamepiece_node.add_child(gamepiece_sprite)
				gamepiece_sprite.owner = gamepiece_node
				# add the tween node to move the sprite
				var gamepiece_tween = Tween.new()
				gamepiece_node.add_child(gamepiece_tween)
				gamepiece_tween.owner = gamepiece_node
				gamepiece_tween.name = "move_tween"
				# script implementation
				var script = GDScript.new()
				script.source_code = piece_script
				script.reload()
				gamepiece_node.set_script(script)
				# end script implementation

				# set the script's variables
				gamepiece_node.color = item
				# set the sprite's texture
				gamepiece_sprite.texture = textures[item]
				gamepiece_sprite.set_scale(Vector2(64,64) / textures[item].get_size())
				gamepiece_sprite.name = "Sprite"
				# set it invisible so it's hidden (don't forget to unhide it when you spawn a new one!)
				gamepiece_sprite.visible = false
		
				# pack the scene into res:// so we can use it later
				var result = gamepiece_scene.pack(gamepiece_node)
				if result == OK:
					#print("get_pieces(): " + str(gamepiece_scene) + " scene created successfully!")
					#TODO: save resources locally if we're not in a browser
						# generate the scene file
						#ResourceSaver.save("res://gamepiece_" + str(LCV) + ".tscn", gamepiece_scene)
					# add the scene to possible_pieces
					possible_pieces.append(gamepiece_scene)
				LCV += 1
				#print("get_pieces(): created node ", gamepiece_node.name, ": ", gamepiece_node.get_path())
			"loadi":
#				# loading imagery (need to sprite.modulate and color shift)
#				print("Found loading imagery (word): ", item)
#				match item:
#					"loading_inner":
#						pass
#					"loading_outer":
#						pass
				pass
			"dot_i", "dot_o":
#				# loading imagery (need to sprite.modulate and color shift)
#				print("Found loading imagery (dots): ", item)
#				match item:
#					"dot_inner":
#						pass
#					"dot_outer":
#						pass
				pass
			_:
				print("matching failed, unknown item name: ", item)
		pass


func _on_resources_ready():
	print("root says the resources are ready!")
	
	print("hiding loading screen")
	hide_loading_screen()
	print("getting pieces")
	get_pieces() # download images and generate pieces
	print("spawning pieces")
	spawn_pieces()					# instantiate pieces
	print("spawning obstacles")
	spawn_obstacles()				# instantiate obstacle pieces
	# these others are included in spawn_obstacles()
#	spawn_ice()						# instantiate ice
#	spawn_locks()					# instantiate licorice (locks)
#	spawn_concrete()				# instantiate concrete
#	spawn_slime()					# instantiate slime
	pass


func display_loading_screen():
	get_node("../loading_animation").visible = true

func hide_loading_screen():
	get_node("../loading_animation").visible = false

