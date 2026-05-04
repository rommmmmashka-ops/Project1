class_name BombLogic
extends ItemLogic


var time_fuse: int
var started = false

func _init(data):
	time_fuse = data.time_fuse



func use(_player, _params, mbtn):
	if !started and mbtn=="left":
		if time_fuse < 120:
			time_fuse += 5
		else: 
			time_fuse = 15
		print(time_fuse)
		
		var props = {
			"time_fuse": time_fuse,
		}
		return [props, 1]
	elif !started and mbtn:
		return start()

func start():
	var props = {
			"time_fuse": time_fuse,
		}
	return [props, 2]


