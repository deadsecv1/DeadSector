extends AudioStreamPlayer

# Picks one of the real ambient horror tracks at random and loops it
# for the raid's atmosphere. Quiet by default so it sits under gunfire
# and footsteps rather than over them.

const TRACKS := [
	preload("res://assets/audio/music/raid_ambience_1.ogg"),
	preload("res://assets/audio/music/raid_ambience_2.ogg"),
	preload("res://assets/audio/music/raid_ambience_3.ogg"),
]

func _ready() -> void:
	bus = "Music"
	volume_db = -24.0
	stream = TRACKS[randi() % TRACKS.size()]
	finished.connect(_on_finished)
	play()

func _on_finished() -> void:
	# Loop by restarting rather than relying on the file's own loop flag,
	# since not every source track is authored to loop seamlessly.
	stream = TRACKS[randi() % TRACKS.size()]
	play()
