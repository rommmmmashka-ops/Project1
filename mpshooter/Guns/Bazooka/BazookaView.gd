extends RigidBody3D


@onready var rocket = $Rocket
@onready var collision_shape_3d = $CollisionShape3D


#Inventory
@export var itemName = ""
@export var path = ""
@export var icon = ""
@export var weight = 1
@export var canBeTaken = true
@export var isForBuilding = false
@export var isOneUsage = true

var netID: int
#Properties
var properties = {
	"loaded": true,
	"missile_dir": null,
}


# Called when the node enters the scene tree for the first time.
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
	pass

@rpc("any_peer", "reliable")
func change_props(props):
	properties.merge(props, true)
	changed()
	print(properties, props)

#@rpc("any_peer", "call_local")
func used_client(type):
	if type != 3 and !can_use_item():
		return
	#print(type)
	match type:
		1:
			if multiplayer.is_server():
				spawn_rocket()
			#else:
			#	rpc_id(1, "spawn_rocket")
			changed()
			rocket.hide()
		2:
			#print(properties, "OK")
			$AnimationPlayer.play("Reload")
			await get_tree().create_timer(2.0).timeout
			rocket.show()
			changed()
		3:
			rocket.changeMode()
			#print(properties, "OK", rocket.fuseMode)
			changed()


@rpc("authority", "unreliable")
func sync_transform(transf, lVel, aVel):
	if multiplayer.is_server():
		return

	global_transform = transf
	linear_velocity = lVel
	angular_velocity = aVel

func _physics_process(delta):
	
	if multiplayer.is_server() and canBeTaken:
		rpc("sync_transform", global_transform, linear_velocity, angular_velocity)



@rpc("any_peer", "reliable")
func spawn_rocket():
	if !multiplayer.is_server():
		#print("isntServer")
		return
	var rocketChild = rocket.duplicate()
	rocketChild.fuseMode = rocket.fuseMode
	add_child(rocketChild)
	rocketChild.reparent($/root/Main)
	rocketChild.launch(properties.missile_dir)
	rpc("client_spawn_rocket")
	$/root/Main.add_item(rocketChild)

@rpc("authority", "reliable")
func client_spawn_rocket():
	print("clientSpawnedRocket")
	var rocketChild = rocket.duplicate()
	rocketChild.show()
	rocketChild.fuseMode = rocket.fuseMode
	add_child(rocketChild)
	rocketChild.reparent($/root/Main)
	rocketChild.launch(properties.missile_dir)
	#$/root/Main.add_item(rocketChild.name)
