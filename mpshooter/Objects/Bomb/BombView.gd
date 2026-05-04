extends RigidBody3D


@onready var timer = $Timer
@onready var label = $Label
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
var time_fuse = 60.0
#var start = false
var properties = {
	"time_fuse": time_fuse,
	"time_left": time_fuse,
	"started": false,
}

# Called when the node enters the scene tree for the first time.
func _ready():
	continuous_cd = true
	if multiplayer.is_server():
		if !netID:
			netID = $/root/Main.generate_id()
			$/root/Main.register_existing_item(self)
	if properties.started:
		used_client(2)
		canBeTaken = false
	changed()

func can_use_item():
	return visible and !canBeTaken

func _process(_delta):
	if properties.started:
		#print(timer.time_left)
		pass

func changed():
	#print(canBeTaken)
	label.visible = get_parent().get_parent().is_multiplayer_authority() and !canBeTaken
	label.text = "Timer: " + str(properties.time_fuse)
	timer.wait_time = properties.time_fuse

@rpc("any_peer", "reliable")
func change_props(props):
	properties.merge(props, true)
	changed()
	#print(properties, props)

@rpc("any_peer", "call_local")
func used_client(type):
	if type != 3 and !can_use_item():
		return
	#print(type)
	match type:
		1:
			print(properties)
			changed()
		2:
			timer.start()
			$AudioStreamPlayer.play()
			properties.started = true
			canBeTaken = false
			changed()

@rpc("authority", "unreliable")
func sync_transform(transf, lVel, aVel):
	if multiplayer.is_server():
		return

	global_transform = transf
	linear_velocity = lVel
	angular_velocity = aVel

func _physics_process(_delta):
	
	if multiplayer.is_server() and canBeTaken:
		rpc("sync_transform", global_transform, linear_velocity, angular_velocity)


func _on_timer_timeout():
	if !multiplayer.is_server():
		return
	rpc("spawn_explosion")
	await get_tree().create_timer(0.2).timeout
	$/root/Main.server_remove_item(self.name)

@rpc("any_peer", "call_local")
func spawn_explosion():
	#print("explosionSpawned")
	var explosion = load("res://Decals & Shaders/Explosion/explosion.tscn").instantiate()
	$/root/Main.add_child(explosion)
	$/root/Main.add_item(explosion.name)
	explosion.position = self.global_position
