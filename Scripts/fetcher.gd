extends HTTPRequest

const HOME_PROTO = "https://"
const HOME_SITE = "thinkier.com/"
const HOME_DIR = "games/Match3MVP/testing/"
onready var home_url = HOME_PROTO + HOME_SITE + HOME_DIR

var current_download = ""	# store only name, no path! (look in downloaded_images[name + ".location"] for url)
var pending_textures = {}
	# image_name = full_url_path

# has the manifest data been processed?
var manifest_processed = false

# heartbeat timing
#var heartbeat_timer = 0.0
#var heartbeat_limit = 1.0

# signals
signal manifest_processed(received_manifest_data) # sent when manifest data is processed
signal texture_processed(image_name, image_texture)	# sent when an image file is downloaded and converted to texture

# Called when the node enters the scene tree for the first time.
func _ready():
# warning-ignore:return_value_discarded
	connect("request_completed", self, "_on_request_completed")
	current_download = "MANIFEST"
# warning-ignore:return_value_discarded
	request(home_url + "manifest.dat")
#	print("fetcher.gd:_ready() complete")
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass

# called every physics step (now slice?) - 'delta' is the elapsed time since the previous "now slice"
# warning-ignore:unused_argument
func _physics_process(delta):
	if manifest_processed:
		process_pending_downloads()
	pass


func _cry_and_break(message):
	print(message)
	print_stack()
	assert(false)


func is_downloaded(image_name):
	# returns true if the specified image is available
	# returns false if it isn't
	# returns null if it's not even queued for download
	var data = null
	if pending_textures.has(image_name + ".location"):
		if pending_textures.has(image_name + ".data"):
			data = true
		else:
			data = false
	return data


# read downloaded manifest and queue up downloads
func process_manifest(manifest_data):
	assert(manifest_processed == false)
	manifest_data = parse_json(manifest_data.get_string_from_utf8())
	for item in manifest_data.keys():
		print(manifest_data[item])
#		manifest_data[item] = manifest_data[item].replace(" ","%20")	# fix spaces causing breakage
		#TODO: check to see if the resource exists locally first
		queue_resource_acquisition(item, manifest_data[item])
	emit_signal("manifest_processed", manifest_data)
	manifest_processed = true
	pass


func process_pending_downloads():
	if current_download.length() > 0:
		#print("process_pending_downloads(): already downloading " + current_download)
		return null
	else:
		if pending_textures.size() > 0:
			for item in pending_textures.keys():
				current_download = item
				#TODO: check to see if resource exists locally first
# warning-ignore:return_value_discarded
				request(home_url + pending_textures[current_download])
#				print("fetcher.gd:process_pending_downloads(): downloading " + pending_textures[current_download])
				return true
	# if we get here, there's nothing left in the list to download
	return false


func queue_resource_acquisition(resource_name, resource_location):
	#TODO: check to see if the resource exists locally first
	pending_textures[resource_name] = resource_location
	pass


# warning-ignore:unused_argument
func _on_request_completed(result, response_code, headers, body):
#	print("fetcher.gd:_on_request_completed: receiving " + current_download)
	if !result:
		match response_code:
			200:
				# OK
				if current_download == "MANIFEST":
					process_manifest(body)
				else:
					# process the texture data into an actual texture
					var image = Image.new()
					var image_error = image.load_png_from_buffer(body)
					if image_error != OK:
						_cry_and_break("fetcher.gd:_on_request_completed: " + current_download + " failed when creating image")
					var texture = ImageTexture.new()
					texture.create_from_image(image)
					emit_signal("texture_processed", current_download, texture)
					pending_textures.erase(current_download)
#					print("fetcher.gd:_on_request_completed: remaining textures to download: " + str(pending_textures.size()))
				current_download = ""
			404:
				# file not found
				_cry_and_break("fetcher.gd:_on_request_completed: FILE NOT FOUND (" + home_url + pending_textures[current_download] + ")")
			_:
				# unknown reason for breakage
				_cry_and_break("fetcher.gd:_on_request_completed: " + current_download + " failed, status " + str(response_code))
	else: # why did it break?
		_cry_and_break("fetcher.gd:_on_request_completed: download failed! Error = " + result + ", response code = " + response_code + "\n" + "Failed download: " + HOME_SITE + HOME_DIR + pending_textures[current_download])
	pass
