extends Node2D

# The Guild Hall - a simple no-damage hangout hub for the player's guild,
# mirroring SocialPlace.gd's shape (same Player/HUD wiring, no combat)
# but without Lilly/Arena's Current-Teams UI, and populated by the
# player's own named guildmates (GuildHallNpc.gd) instead of random
# simulated "real players".

const NPC_BASE_SCENE := preload("res://scenes/Enemy.tscn")
const NPC_SCRIPT := preload("res://scripts/GuildHallNpc.gd")
const PET_SCENE := preload("res://scenes/Pet.tscn")
const SPAWN_SPREAD := Vector2(380.0, 300.0)

@onready var player = $Player
@onready var hud = $HUD

func _ready() -> void:
	GameManager.set_crosshair_cursor()
	GameManager.in_social_hub = true
	player.stats_ready.connect(hud.update_stats)
	player.ammo_changed.connect(hud.update_ammo)
	player._update_ammo_display()
	player.stunned.connect(hud.flash_stun)
	player.health_changed.connect(hud._on_player_health_changed)
	_spawn_pet()
	_spawn_guildmates()

func _spawn_pet() -> void:
	if GameManager.equipped_pet == "":
		return
	var pet = PET_SCENE.instantiate()
	pet.pet_id = GameManager.equipped_pet
	add_child(pet)
	pet.global_position = player.global_position + Vector2(-40, 30)

func _spawn_guildmates() -> void:
	var names: Array = GameManager.get_guild_member_names(GameManager.player_guild_id, 7)
	for i in range(names.size()):
		var npc = NPC_BASE_SCENE.instantiate()
		npc.set_script(NPC_SCRIPT)
		npc.member_name = str(names[i])
		npc.role = GameManager.get_guild_member_role(i)
		# Position must be set BEFORE add_child() - see SocialPlace.gd's
		# _spawn_npc() for why (add_child() runs _ready() synchronously,
		# which captures "origin" from global_position immediately).
		npc.position = Vector2(
			randf_range(-SPAWN_SPREAD.x, SPAWN_SPREAD.x),
			randf_range(-SPAWN_SPREAD.y, SPAWN_SPREAD.y),
		)
		add_child(npc)
