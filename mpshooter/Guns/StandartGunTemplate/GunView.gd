extends RigidBody3D


# For inventory
@export var itemName = ""
@export var path = ""
@export var icon = ""
@export var weight = 1
@export var canBeTaken = true
@export var isForBuilding = false
@export var isOneUsage = true

var netID: int


# Gun propeties
#var active = false
@export var maxAmmo := 12
@export var damage: int 

@onready var anim = $AnimationPlayer
@onready var sound = $AudioStreamPlayer
@onready var ammo_label = $Label
@onready var ray_origin = $RayCast3D
@onready var collision_shape_3d = $CollisionShape3D
@onready var laser = $Laser
@onready var shot = $ShotMesh

#var curAmmo := 12
#var ammo := 60

@onready var properties = {
	"maxAmmo": maxAmmo,
	"curAmmo": 12,
	"ammo": 60,
	"damage": damage
}


var tracer
func _ready():
	continuous_cd = true
	if multiplayer.is_server():
		if !netID:
			netID = $/root/Main.generate_id()
			$/root/Main.register_existing_item(self)
	changed()

func can_use_item():
	return visible and !canBeTaken



func changed():
	#print(canBeTaken)
	ammo_label.visible = get_parent().get_parent().is_multiplayer_authority() and !canBeTaken
	ammo_label.text = str(properties.curAmmo) +"/"+str(properties.ammo)
	laser.visible = !canBeTaken
	shot.hide()

@rpc("any_peer", "reliable")
func change_props(props):
	properties.merge(props, true)
	#print(properties, props)


@rpc("any_peer", "call_local")
func used_client(type):
	if type != 3 and !can_use_item():
		return
	#print(type)
	match type:
		1:
			anim.play("Shoot")
			sound.play()
			changed()
			shot.show()
			tracer = load("res://Decals & Shaders/Tracers/Tracer.tscn").instantiate()
			tracer.length = laser.mesh.height
			tracer.position = laser.global_position
			tracer.rotation = laser.global_rotation
			#print(tracer.length, tracer.position)
			$ShotMesh/Timer.start()
		2:
			anim.play("Reload")
			changed()


@rpc("authority", "unreliable")
func sync_transform(transf, lVel, aVel):
	if multiplayer.is_server():
		return

	global_transform = transf
	linear_velocity = lVel
	angular_velocity = aVel

func _physics_process(_delta: float):
	
	if multiplayer.is_server() and canBeTaken:
		rpc("sync_transform", global_transform, linear_velocity, angular_velocity)
	
	if !canBeTaken and ray_origin.is_colliding():
		var col = ray_origin.get_collision_point()
		var distance = ray_origin.global_position.distance_to(col)
		laser.mesh.height = distance
		#print(laser.mesh.height)
		laser.position.z = -distance / 2

func _on_timer_timeout():
	shot.hide()

