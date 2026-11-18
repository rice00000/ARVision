extends Module
## The piano under everything, from start to quit: "Vaporware" (The Cynic Project, CC0), cut to loop
## seamlessly from bar 46 back to bar 2. It plays on the Music bus, which dips under the voice by itself
## (default_bus_layout.tres). Delete the node to unplug it.

const LOOP := preload("res://modules/music/vaporware_loop.ogg")
const FADE_IN := 4.0

var _player := AudioStreamPlayer.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player.stream = LOOP
	_player.bus = &"Music"
	_player.volume_db = -40.0
	add_child(_player)
	_player.play()
	create_tween().tween_property(_player, ^"volume_db", 0.0, FADE_IN)


func playing() -> bool:
	return _player.playing
