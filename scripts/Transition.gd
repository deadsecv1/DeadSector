extends CanvasLayer

# Global fade-to-black / fade-from-black transition. Autoloaded as
# "Transition" so it persists across scene changes and can be triggered
# from anywhere (e.g. GameManager right before switching scenes).

var rect: ColorRect

# Guards against two scene changes overlapping. change_scene_to_file()
# defers the actual swap to the end of the frame - if it gets called again
# before that swap finishes (e.g. the player clicks a menu button, then
# immediately clicks a "Back" button on the scene that's still loading),
# Godot can crash at the engine level with no script error. Every scene
# change in the game should go through this file so they all share one lock.
var _is_transitioning := false

# change_scene_to_file(path) re-reads and re-parses the .tscn from the
# .pck on every single call - nothing keeps the previous scene's
# PackedScene resource alive once you navigate away from it, so revisiting
# a screen (Stash, Traders, ...) pays that disk-load cost again every
# time, on top of the instantiate+_ready() cost that's unavoidable either
# way. This autoload never gets freed, so caching PackedScenes here by
# path keeps them warm for the whole session - a visit after the first
# skips straight to change_scene_to_packed(), no re-load.
var _scene_cache: Dictionary = {}

func get_cached_scene(path: String) -> PackedScene:
	if not _scene_cache.has(path):
		_scene_cache[path] = load(path)
	return _scene_cache[path]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	rect = ColorRect.new()
	rect.color = Color(0, 0, 0, 0)
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(rect)

func fade_out(duration: float = 0.6) -> void:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(rect, "color:a", 1.0, duration)
	await tween.finished

func fade_in(duration: float = 0.6) -> void:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(rect, "color:a", 0.0, duration)
	await tween.finished

# Fades out, switches scene, waits a frame, fades back in - all running on
# THIS node (an autoload that's never destroyed), so it's safe to call from
# a button handler even though that button's whole scene gets freed partway
# through. Calling get_tree() on the scene that triggered this would break
# once that scene is gone; get_tree() here never does.
func change_scene(path: String, fade_out_dur: float = 0.5, fade_in_dur: float = 0.5) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	# No sound played here anymore - every Button in the game plays its
	# own click sound the instant it's pressed (see Sfx._wire_global_
	# click_sfx), so a button-triggered transition already got its sound
	# at the moment of the click. Playing one here too, on a timer/auto-
	# triggered transition with no click at all (e.g. SearchingForPlayers
	# routing onward), used to fire a "click" sound out of nowhere.
	await fade_out(fade_out_dur)
	# Top off the music buffer to full right before the load - change_
	# scene_to_file() blocks the main thread while the new scene
	# instantiates, so MenuMusic's own _process()/_fill_buffer() doesn't
	# run at all for that whole stretch. Topping off here first gives it
	# the maximum possible headroom going in, on top of the buffer
	# itself already being sized with real margin.
	MenuMusic._fill_buffer()
	get_tree().change_scene_to_packed(get_cached_scene(path))
	await get_tree().process_frame
	await fade_in(fade_in_dur)
	_is_transitioning = false

# Same safety lock as change_scene(), but no fade - for menu-to-menu
# navigation (Traders, Settings, Back buttons, etc.) that swaps instantly.
# If a scene change is already in progress, extra clicks are simply
# ignored instead of being allowed to race each other.
func change_scene_instant(path: String) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	MenuMusic._fill_buffer()
	get_tree().change_scene_to_packed(get_cached_scene(path))
	await get_tree().process_frame
	_is_transitioning = false
