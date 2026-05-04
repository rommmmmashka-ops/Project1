class_name BazookaLogic
extends ItemLogic


var loaded = false
var missile_dir = null

var reloadDelay = 2
var nextTime = 0.0

func _init(data):
	loaded = data.loaded
	missile_dir = data.missile_dir

func _can_use() -> bool:
	return Time.get_ticks_msec() / 1000.0 >= nextTime

func use(_player, params, mbtn):
	#res://Guns/Bazooka/BazookaRocket.gd
	if mbtn == "left" and loaded and _can_use():
		loaded = false
		var props = {
		"loaded": loaded,
		"missile_dir": params.direction,
		}
		print(props)
		return [props, 1]
	elif !loaded:
		return reload(params)
	elif mbtn == "right" and loaded:
		var props = {
		"loaded": loaded,
		"missile_dir": params.direction,
		}
		return [props, 3]
	return []

func reload(params):
	nextTime = Time.get_ticks_msec() / 1000.0 + reloadDelay
	loaded = true
	var props = {
	"loaded": loaded,
	"missile_dir": params.direction,
	}
	print(props)
	return [props, 2]
