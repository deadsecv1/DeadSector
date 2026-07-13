extends Control

const GITHUB_USER := "deadsecv1"
const GITHUB_REPO := "DeadSector"
const VERSION_URL := "https://github.com/" + GITHUB_USER + "/" + GITHUB_REPO + "/releases/latest/download/version.txt"
const PCK_URL := "https://github.com/" + GITHUB_USER + "/" + GITHUB_REPO + "/releases/latest/download/DeadSector.pck"
const NEXT_SCENE := "res://scenes/StudioSplash.tscn"
const PCK_NAME := "DeadSector.pck"

@onready var http: HTTPRequest = $HTTPRequest
@onready var status_label: Label = $Center/VBox/StatusLabel
@onready var progress_bar: ProgressBar = $Center/VBox/ProgressBar

var _local_version: String = ""
var _exe_dir: String = ""

func _ready() -> void:
	if OS.has_feature("editor"):
		_proceed()
		return

	_exe_dir = OS.get_executable_path().get_base_dir()

	var f := FileAccess.open("res://version.txt", FileAccess.READ)
	if f:
		_local_version = f.get_line().strip_edges()
		f.close()

	status_label.text = "Checking for updates..."
	http.request_completed.connect(_on_version_checked)
	http.request(VERSION_URL)

func _on_version_checked(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_proceed()
		return

	var remote_version := body.get_string_from_utf8().strip_edges()
	if remote_version == _local_version:
		_proceed()
		return

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

	var bat := FileAccess.open(bat_path, FileAccess.WRITE)
	if bat == null:
		_proceed()
		return
	bat.store_string(
		"@echo off\r\n" +
		"timeout /t 2 /nobreak > nul\r\n" +
		"move /y \"" + new_pck + "\" \"" + old_pck + "\"\r\n" +
		"start \"\" \"" + exe + "\"\r\n" +
		"(goto) 2>nul & del \"%~f0\"\r\n"
	)
	bat.close()

	OS.create_process("cmd.exe", ["/c", bat_path.replace("/", "\\")])
	get_tree().quit()

func _proceed() -> void:
	get_tree().change_scene_to_file(NEXT_SCENE)
