extends RigidBody3D


# For inventory
@export var itemName = ""
@export var path = ""
@export var icon: Texture
@export var weight = 1
@export var canBeTaken = true
@export var isForBuilding = false
@export var isOneUsage = true

# Gun propeties
#var active = false
@export var maxAmmo = 12
@export var minDmg : int 
@export var maxDmg : int

var curAmmo = maxAmmo
var ammo = maxAmmo * 5

# Onready
@onready var ammoTxt = $Label
@onready var anim = $AnimationPlayer
@onready var ray = $RayCast3D
var cast = null
var properties = []


signal properties_changed(item, properties)

signal shoot_requested(gun)
signal reload_requested(gun)



func _ready():
	properties = [maxAmmo, curAmmo, ammo]
	if multiplayer.is_server():
		set_multiplayer_authority(1)
	continuous_cd = true
	if canBeTaken:
		ammoTxt.hide()


func onLMB():
	if canBeTaken or anim.is_playing():
		return
	
	if curAmmo > 0:
		emit_signal("shoot_requested", self)
	elif ammo > 0:
		emit_signal("reload_requested", self)
		
	change_properties_local()


func onRMB():
	pass


#@rpc("authority", "reliable")
func server_shoot():
	if !multiplayer.is_server():
		return
	if curAmmo <= 0:
		return
	
	cast = ray.get_collider()
	curAmmo -= 1
	#print(cast)
	if cast and cast.get_class() == "CharacterBody3D":
		cast.rpc_id(cast.get_multiplayer_authority(), "receive_dmg",  randf_range(minDmg, maxDmg))
	
	rpc("client_shoot", curAmmo)


@rpc("any_peer", "call_local")
func client_shoot(newCurAmmo):
	curAmmo = newCurAmmo
	ammoTxt.text = str(curAmmo) + "/" + str(ammo)
	anim.play("Shoot")


#@rpc("authority", "reliable")
func server_reload():
	if !multiplayer.is_server():
		return
	if ammo <= 0:
		return
	var take = min(maxAmmo, ammo)
	curAmmo = take
	ammo -= take

	rpc("client_reload", curAmmo, ammo)

@rpc("any_peer", "call_local")
func client_reload(newCurAmmo, newAmmo):
	anim.play("Reload")
	curAmmo = newCurAmmo
	ammo = newAmmo
	ammoTxt.text = str(curAmmo) + "/" + str(ammo)


func change_properties_local():
	properties = [maxAmmo, curAmmo, ammo]
	print(properties)
	emit_signal("properties_changed", self, properties)

func apply_properties(props):
	properties = props
	maxAmmo = props[0]
	curAmmo = props[1]
	ammo = props[2]


@rpc("any_peer", "call_local")
func action():
	if not is_instance_valid(self):
		return
	if canBeTaken:
		if multiplayer.is_server():
			$/root/Main.remove_item(self.get_path())
		else:
			$/root/Main.rpc_id(1, "remove_item", self.get_path())

