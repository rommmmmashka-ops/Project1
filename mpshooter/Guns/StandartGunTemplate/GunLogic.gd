class_name GunLogic
extends ItemLogic

var maxAmmo: int
var curAmmo: int
var ammo: int
var damage: int

var fireDelay = 0.2
var reloadDelay = 2
var nextTime = 0.0

func _init(data):
	maxAmmo = data.maxAmmo
	curAmmo = data.curAmmo
	ammo = data.ammo
	damage = data.damage

func _can_use() -> bool:
	return Time.get_ticks_msec() / 1000.0 >= nextTime

func use(player, params):
	if not _can_use():
		return [] 
	
	if curAmmo <= 0:
		if ammo:
			return reload()
		return []
	
	curAmmo -= 1
	nextTime = Time.get_ticks_msec() / 1000.0 + fireDelay
	
	var space = player.get_world_3d().direct_space_state
	var origin = params.origin
	var dir = params.direction
	
	var ray = PhysicsRayQueryParameters3D.create(
		origin,
		origin + dir * 1000
	)
	ray.exclude = [player.find_child("HeadHitbox")]
	ray.collide_with_areas = true
	ray.hit_from_inside = false
	ray.collision_mask = 0b00000000_00000000_00000000_00001000

	var hit = space.intersect_ray(ray)
	if hit:
		pass
		#print("ok   ", hit.collider)
	if hit and hit.collider.has_method("receive_dmg"):
		hit.collider.receive_dmg(damage, hit)
	
	var props = {
		"curAmmo": curAmmo,
		"ammo": ammo
	}
	return [props, 1]


func reload():
	if not _can_use():
		return []
	if !ammo:
		return []
	
	#print("reloading")
	nextTime = Time.get_ticks_msec() / 1000.0 + reloadDelay
	var take = min(maxAmmo, ammo)
	curAmmo = take
	ammo -= take
	
	var props = {
		"curAmmo": curAmmo,
		"ammo": ammo
	}
	return [props, 2]
