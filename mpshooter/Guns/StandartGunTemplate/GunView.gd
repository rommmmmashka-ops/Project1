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
@export var maxAmmo := 12
@export var damage: int 

@onready var anim = $AnimationPlayer
@onready var sound = $AudioStreamPlayer
@onready var ammo_label = $Label
@onready var ray_origin = $RayCast3D
@onready var laser = $Laser

#var curAmmo := 12
#var ammo := 60

@onready var properties = {
	"maxAmmo": maxAmmo,
	"curAmmo": 12,
	"ammo": 60,
	"damage": damage
}



func _ready():
	continuous_cd = true
	changed()


func changed():
	#print(canBeTaken)
	ammo_label.visible = get_parent().get_parent().is_multiplayer_authority() and !canBeTaken
	ammo_label.text = str(properties.curAmmo) +"/"+str(properties.ammo)
	laser.visible = !canBeTaken

@rpc("any_peer", "reliable")
func change_props(props):
	properties.merge(props, true)
	#print(properties, props)


@rpc("any_peer", "call_local")
func used_client(type):
	#print(type)
	match type:
		1:
			anim.play("Shoot")
			sound.play()
			changed()
		2:
			anim.play("Reload")
			changed()
		
	
