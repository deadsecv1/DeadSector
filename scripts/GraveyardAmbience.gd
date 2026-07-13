extends AudioStreamPlayer

# The Graveyard's own ambience pool - separate from the general raid
# ambience tracks so it doesn't repeat what Overgrowth/Boneclock use.
# Loops by restarting on a random pick rather than relying on each
# track's own loop point.

const TRACKS := [
	preload("res://assets/audio/music/graveyard_ambience.ogg"),
	preload("res://assets/audio/music/graveyard_ambience_2.ogg"),
	preload("res://assets/audio/music/graveyard_ambience_3.ogg"),
]

func _ready() -> void:
	bus = "Music"
	volume_db = -26.0
	stream = TRACKS[randi() % TRACKS.size()]
	finished.connect(_on_finished)
	play()

func _on_finished() -> void:
	stream = TRACKS[randi() % TRACKS.size()]
	play()
