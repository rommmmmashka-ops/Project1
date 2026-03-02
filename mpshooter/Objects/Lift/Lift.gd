extends StaticBody3D


@onready var anim = $AnimationPlayer


func _on_area_3d_body_entered(_body):
	anim.play("Lifting")

func _on_area_3d_body_exited(_body):
	anim.play_backwards("Lifting")
