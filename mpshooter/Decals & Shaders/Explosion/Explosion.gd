extends Node3D


@onready var area = $Area3D
@onready var gpu_particles_3d = $GPUParticles3D
@onready var gpu_particles_3d_3 = $GPUParticles3D3
@onready var gpu_particles_3d_2 = $GPUParticles3D2
@onready var audio_stream_player_3d = $AudioStreamPlayer3D

@export var explosion_force = 100.0

var netID: int

func _ready():
	if multiplayer.is_server():
		if !netID:
			netID = $/root/Main.generate_id()
			$/root/Main.register_existing_item(self)
			
	if multiplayer.is_server():
		visual_explode()
		physics_explode()
		
	#else:
	#	rpc_id(1, "visual_explode")
	#	rpc_id(1, "physics_explode")
	await get_tree().create_timer(2.0).timeout
	$/root/Main.server_remove_item(self.netID)


@rpc("authority", "reliable")
func visual_explode():
	gpu_particles_3d.emitting=true
	gpu_particles_3d_2.emitting=true
	gpu_particles_3d_3.emitting=true
	audio_stream_player_3d.play()
	rpc("client_visual_explode")

@rpc("any_peer", "reliable")
func client_visual_explode():
	if multiplayer.is_server():
		#print("serverReturned")
		return
	gpu_particles_3d.emitting=true
	gpu_particles_3d_2.emitting=true
	gpu_particles_3d_3.emitting=true
	audio_stream_player_3d.play()

@rpc("authority", "reliable", "call_local")
func physics_explode():
	await get_tree().create_timer(0.1).timeout
	print(area.get_overlapping_bodies())
	for body in area.get_overlapping_bodies():
		if body is RigidBody3D:
			var dir = (body.global_transform.origin - self.global_transform.origin).normalized()
			body.apply_central_impulse(dir * explosion_force)
			#print(body, dir, body.linear_velocity)
		if body is CharacterBody3D:
			var dist = (body.global_position - self.global_position).length()
			#print(dist)
			if 400 - dist * 100 > 0:
				body.receive_dmg(400 - dist * 100)
