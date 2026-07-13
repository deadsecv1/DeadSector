extends Control

const GITHUB_USER := "deadsecv1"
const GITHUB_REPO := "DeadSector"
const VERSION_URL := "https://github.com/" + GITHUB_USER + "/" + GITHUB_REPO + "/releases/latest/download/version.txt"
const PCK_URL := "https://github.com/" + GITHUB_USER + "/" + GITHUB_REPO + "/releases/latest/download/DeadSector.pck"
const NEXT_SCENE := "res://scenes/StudioSplash.tscn"
const PCK_NAME := "DeadSector.pck"
const MARKER_NAME := "_update_attempt.txt"

# The in-game version players see (VersionLabel.gd, the What's New popup)
# comes from ChangelogPanel's own CHANGELOG list - reading the same source
# here means the updater's local version can never drift out of sync with
# what's actually displayed in the game, the way a separately-maintained
# version.txt could (and did).
const ChangelogScript := preload("res://scripts/ChangelogPanel.gd")

@onready var http: HTTPRequest = $HTTPRequest
@onready var status_label: Label = $Center/VBox/StatusLabel
@onready var progress_bar: ProgressBar = $Center/VBox/ProgressBar

var _local_version: String = ""
var _exe_dir: String = ""
var _pending_version: String = ""

func _ready() -> void:
	if OS.has_feature("editor"):
		_proceed()
		return

	_exe_dir = OS.get_executable_path().get_base_dir()

	var changelog: Array = ChangelogScript.get_all_entries()
	if not changelog.is_empty():
		_local_version = str(changelog[changelog.size() - 1].get("version", ""))

	# If a previous boot tried to swap in a new .pck and we're STILL on the
	# version it was attempting to reach, the swap silently failed (e.g.
	# antivirus holding a lock on the freshly downloaded file for a moment
	# too long). Don't redownload and relaunch again - that's what caused
	# an infinite open/close loop before this guard existed. Just play on
	# the current version instead.
	var attempted_version := _consume_update_marker()
	if attempted_version != "" and attempted_version != _local_version:
		_proceed()
		return

	status_label.text = "Checking for updates..."
	http.request_completed.connect(_on_version_checked)
	http.request(VERSION_URL)

# Only ever updates FORWARD. A local build that's temporarily ahead of
# what's published (e.g. a fresh dev export before its matching release
# goes out) must never get silently downgraded just because the version
# strings don't match. Compares numeric dot-segments (so "0.1.10" >
# "0.1.9"), not a plain string/lexical comparison.
func _is_remote_newer(remote: String, local: String) -> bool:
	var remote_parts := remote.split(".")
	var local_parts := local.split(".")
	var count: int = max(remote_parts.size(), local_parts.size())
	for i in range(count):
		var r: int = int(remote_parts[i]) if i < remote_parts.size() else 0
		var l: int = int(local_parts[i]) if i < local_parts.size() else 0
		if r != l:
			return r > l
	return false

func _consume_update_marker() -> String:
	var marker_path := _exe_dir + "/" + MARKER_NAME
	if not FileAccess.file_exists(marker_path):
		return ""
	var mf := FileAccess.open(marker_path, FileAccess.READ)
	var attempted_version := ""
	if mf:
		attempted_version = mf.get_line().strip_edges()
		mf.close()
	DirAccess.remove_absolute(marker_path)
	return attempted_version

func _on_version_checked(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_proceed()
		return

	var remote_version := body.get_string_from_utf8().strip_edges()
	if not _is_remote_newer(remote_version, _local_version):
		_proceed()
		return

	_pending_version = remote_version
	status_label.text = "Downloading update " + remote_version + "..."
	progress_bar.visible = true
	http.request_completed.disconnect(_on_version_checked)
	http.request_completed.connect(_on_pck_downloaded)
	http.download_file = _exe_dir + "/" + PCK_NAME + ".new"
	http.request(PCK_URL)

func _process(_delta: float) -> void:
	if progress_bar.visible and http.get_body_size() > 0:
		progress_bar.value = float(http.get_downloaded_bytes()) / float(http.get_body_size()) * 100.0

func _on_pck_downloaded(result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_proceed()
		return

	var dir := _exe_dir.replace("/", "\\")
	var new_pck := dir + "\\" + PCK_NAME + ".new"
	var old_pck := dir + "\\" + PCK_NAME
	var exe := OS.get_executable_path().replace("/", "\\")
	var bat_path := _exe_dir + "/_update.bat"

	# Record which version we're attempting before handing off to the .bat -
	# read back on the next boot to detect a failed swap (see
	# _consume_update_marker) instead of looping forever.
	var marker := FileAccess.open(_exe_dir + "/" + MARKER_NAME, FileAccess.WRITE)
	if marker:
		marker.store_string(_pending_version)
		marker.close()

	var bat := FileAccess.open(bat_path, FileAccess.WRITE)
	if bat == null:
		_proceed()
		return
	# Windows (often Defender scanning the freshly downloaded file) can hold
	# a brief lock on the .pck.new right after download, so a single
	# immediate `move` can fail silently. Retry with short waits before
	# giving up and relaunching anyway - the marker above is the backstop
	# if every retry fails.
	bat.store_string(
		"@echo off\r\n" +
		"setlocal enabledelayedexpansion\r\n" +
		"set ATTEMPTS=0\r\n" +
		":retry\r\n" +
		"timeout /t 1 /nobreak > nul\r\n" +
		"move /y \"" + new_pck + "\" \"" + old_pck + "\" > nul 2>&1\r\n" +
		"if exist \"" + new_pck + "\" (\r\n" +
		"  set /a ATTEMPTS+=1\r\n" +
		"  if !ATTEMPTS! LSS 8 goto retry\r\n" +
		")\r\n" +
		"start \"\" \"" + exe + "\"\r\n" +
		"(goto) 2>nul & del \"%~f0\"\r\n"
	)
	bat.close()

	OS.create_process("cmd.exe", ["/c", bat_path.replace("/", "\\")])
	get_tree().quit()

func _proceed() -> void:
	get_tree().change_scene_to_file(NEXT_SCENE)
