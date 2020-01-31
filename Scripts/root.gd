extends Node

enum GameState { LOADING, MENU, GAME, NO_MATCHES, SETTINGS }
var game_state

#LOADING:
#	grab manifest
#	acquire "loading sprites"
#	display them
#	acquire game files
#	start game heartbeat
#	emit signal "loaded"

#MENU:
#	display main menu
#	wait for button press
#		emit signal "pressed button"

#GAME:
#	build game grid
#	generate pieces
#	poke holes in grid (make unplayable spaces)
#	generate obstacles
#	fill gameboard
#	play the game

#NO_MATCHES:
#	if moving:
#		if not already_matched_this_turn:
#			move did not result in a match, so unswap
#		else:
#			no more matches resulted from this turn, end turn
#	else:
#		if endless_mode:
#			no matches are possible, shuffle the board
#			next state: GAME
#		else:
#			no matches are possible, end the game
#			next state: MENU

#SETTINGS:
#	display and interact with options
#		sounds on or off
#		music on or off
#		endless mode on or off
#		next state: MENU

var moving = true

var endless_mode = true	# should default to false once we have the option (ie, have a shuffle method)
var make_sound = false	# should default to true once we have some noises to make
var make_music = false	# should default to true once we have some noises to make

var manifest_data = {}
var textures = {}
var textures_loaded = false

# Called when the node enters the scene tree for the first time.
func _ready():
	_state_change(GameState.LOADING)
	pass

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if false:
		# this should never actually fire, i'm just telling godot to stfu about unused variables
		print(delta)
	pass

func toggle_sound():
	make_sound = !make_sound

func toggle_music():
	make_music = !make_music

# toggles shuffling if no matches possible
func toggle_endless_mode():
	endless_mode = !endless_mode

func start_moving():
	moving = true

func stop_moving():
	moving = false

# signals targets

func _state_change(target_state):
#	print("root.gd:_state_change(", target_state, "): current state = ", game_state)
	game_state = target_state
	pass


func _on_fetcher_texture_processed(image_name, image_texture):
#	print("root.gd:_on_fetcher_texture_processed(): received texture " + image_name + " from fetcher")
	textures[image_name] = image_texture
#	print("root.gd:_on_fetcher_texture_processed(): textures size = " + str(textures.size()))
	if textures.size() == manifest_data.size():
		textures_loaded = true
		$game._on_resources_ready()
		_state_change(GameState.GAME)
	pass # Replace with function body.

func _on_fetcher_manifest_processed(received_manifest_data):
#	print("root.gd:_on_fetcher_manifest_processed(): received manifest data from fetcher")
	manifest_data = received_manifest_data
#	print("root.gd:_on_fetcher_manifest_processed(): items in manifest = " + str(manifest_data.size()))
	pass