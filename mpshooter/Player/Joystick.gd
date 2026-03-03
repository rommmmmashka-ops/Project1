extends Control


@onready var knob = $Sprite2D2
@onready var bg = $Sprite2D

var max_radius = 80
var direction = Vector2.ZERO

func _gui_input(event):
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		if event.pressed or event is InputEventScreenDrag:
			var local_pos = knob.to_local(event.position)
			var offset = local_pos - bg.position
			
			if offset.length() > max_radius:
				offset = offset.normalized() * max_radius
			
			knob.position = bg.position + offset
			
			direction = offset.normalized()
			direction = snap_to_8(direction)
		else:
			reset()

func snap_to_8(dir: Vector2) -> Vector2:
	var angle = atan2(dir.y, dir.x)
	var step = PI / 4  # 45 градусів
	angle = round(angle / step) * step
	return Vector2(cos(angle), sin(angle))

func reset():
	knob.position = bg.position
	direction = Vector2.ZERO
