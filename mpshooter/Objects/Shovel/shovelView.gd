extends RigidBody3D




var netID: int
# Called when the node enters the scene tree for the first time.
func _ready():
	continuous_cd = true
	if multiplayer.is_server():
		if !netID:
			netID = $/root/Main.generate_id()
			$/root/Main.register_existing_item(self)

@rpc("authority", "unreliable")
func sync_transform(transf, lVel, aVel):
	if multiplayer.is_server():
		return

	global_transform = transf
	linear_velocity = lVel
	angular_velocity = aVel

func _physics_process(delta):
	
	if multiplayer.is_server():
		rpc("sync_transform", global_transform, linear_velocity, angular_velocity)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
	pass
