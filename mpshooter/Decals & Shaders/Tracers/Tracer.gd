extends MeshInstance3D

var length = 20.0

# Called when the node enters the scene tree for the first time.
func _ready():
	self.mesh.height = length
	#self.position.z -= length/2

func _on_timer_timeout():
	rpc("delete_self")

@rpc("any_peer", "call_local")
func delete_self():
	if is_instance_valid(self):
		self.queue_free()
