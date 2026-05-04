extends RigidBody3D


var netID: int

@onready var col_1 = $Area3D/CollisionShape3D
@onready var col_2 = $Area3D2/CollisionShape3D2

var health = 40

var initial_force = 40.0
var acceleration = 300.0
var deceleration = 100.0
var fuseTime = 0.2
var accel_time = 2.5
var timer = 0.0
var active = false
var fuseMode = 1

var mDir: Vector3



# Called when the node enters the scene tree for the first time.
func _ready():
	if multiplayer.is_server():
		if !netID:
			netID = $/root/Main.generate_id()
			$/root/Main.register_existing_item(self)

func changeMode():
	if fuseMode == 1:
		fuseMode = 2
	else:
		fuseMode = 1

func launch(misDir):
	if fuseMode == 1 or null:
		fuseTime = 0.2
		#col_1.disabled = false
		col_2.disabled = true
	else:
		fuseTime = 1.0
		#col_1.disabled = true
		col_2.disabled = false
	mDir = misDir
	freeze = false
	active = true
	timer = 0.0
	print(active, fuseMode)
	$CollisionShape3D.disabled = false
	apply_central_impulse(transform.basis.z * -initial_force) 

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
		
	if active:
		timer += delta
		if 0.4 < timer and timer < accel_time:
			$GPUParticles3D2.emitting = true
			apply_central_force(transform.basis.z * -(acceleration+1))
			#var dir = linear_velocity.normalized() + mDir.normalized()
			#var dir = mDir.normalized()
			#var calcDir = mDir * (mDir / linear_velocity).abs()
			#var dir = calcDir.normalized()
			var dir = (mDir + Vector3.UP * 0.2).normalized()
			if dir.cross(Vector3.UP).length() > 0.001:
				#var nose_dir = -global_transform.basis.z.normalized()
				#var ground_up = Vector3.UP
#
				## Вектор, який показує, наскільки ракета відхиляється від вертикалі
				#var correction_axis = nose_dir.cross(ground_up).normalized()
				#var correction_strength = nose_dir.angle_to(ground_up)
				#print(correction_axis, correction_strength)
#
				## Застосовуємо момент, щоб вирівняти ракету
				#apply_torque(correction_axis * correction_strength * 1.0)
				look_at(global_transform.origin + dir, Vector3.UP)
			#print(self.global_rotation_degrees)
			
			
		elif linear_velocity.length() > 0.01:
			$GPUParticles3D2.emitting = false
			var dir = linear_velocity.normalized()
			if dir.cross(Vector3.UP).length() > 0.001:
				look_at(global_transform.origin + dir, Vector3.UP)
			




func _on_area_3d_body_entered(body):
	if active and timer >= 0.2:
		#print("colidingbody: ",body)
		rpc("spawn_explosion")
		await get_tree().create_timer(0.1).timeout
		$/root/Main.server_remove_item(self.netID)


func _on_area_3d_2_body_entered(body):
	if active and timer >= fuseTime:
		#print("colidingbody: ",body)
		rpc("spawn_explosion")
		await get_tree().create_timer(0.1).timeout
		$/root/Main.server_remove_item(self.netID)

@rpc("any_peer", "call_local")
func spawn_explosion():
	#print("explosionSpawned")
	var explosion = load("res://Decals & Shaders/Explosion/explosion.tscn").instantiate()
	$/root/Main.add_child(explosion)
	explosion.position = self.global_position
	await get_tree().create_timer(0.1).timeout
	$/root/Main.add_item(explosion)





