extends StaticBody3D



@onready var timer = $Timer
@onready var mesh = $MeshInstance3D
@onready var anim = $AnimationPlayer
var active = true

func _physics_process(_delta):
	anim.play("waiting")


func onRMB():
	if active:
		#print("OK")
		destroy_object()
	else:
		print("UNACTIVE")

func _on_area_3d_body_entered(body):
	if active and body.get_class() == "CharacterBody3D":
		body.heal(50)
		restart()

@rpc("any_peer", "call_local")
func restart():
	if not is_instance_valid(self):
		return
	active = false
	mesh.hide()
	timer.start()

func destroy_object():
	$/root/Main.remove_item(self.get_path())

func _on_timer_timeout():
	active = true
	mesh.show()
