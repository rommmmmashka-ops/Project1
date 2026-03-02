extends CharacterBody3D


# Constants
const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const SENSIVITY = 0.01

# Gravity
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

# Onready
@onready var Health = $ProgressBar
@onready var Head = $Head
@onready var Hand = $Head/Hand
@onready var Cam = $Head/Camera3D
@onready var Ray = $Head/RayCast3D2

@onready var Body = $Body
@onready var Inv = $Control

# Main
var health = 49
var shift = 1

#Weapon
var defaultFOV = 75.0
var scopeFOV = 50.0
var scopeSpeed = 10.0

var sensivity = 1

var aiming = false

#Inventory
var maxInventory = 4
var maxWeight = 20
var curWeight = 0
var Inventory = [0,0,0,0]
var actCell = 0
var curItem = null

var itemLogic: ItemLogic

# Functions
#Inventory

func add_to_inv(item):
	#print("Adding")
	if multiplayer.is_server():
		server_add_to_inv(item.name,item.itemName,item.path,item.icon,item.weight,item.isForBuilding,item.isOneUsage,item.properties)
	else:
		rpc_id(1, "server_add_to_inv", item.name,item.itemName,item.path,item.icon,item.weight,item.isForBuilding,item.isOneUsage,item.properties)

@rpc("any_peer", "reliable")
func server_add_to_inv(itemName, itn,pth,icn,wth,ifb,iou,props):
	if !multiplayer.is_server():
		#print("Not server")
		return
	
	if !itemName:
		#print("Not item")
		return
	
	remove_item(itemName)
	
	add_to_inv_def(itn,pth,icn,wth,ifb,iou,props)
	
	rpc_id(multiplayer.get_remote_sender_id(), "client_add_to_inv", Inventory)

func add_to_inv_def(itemName,path,icon,weight,isForBuilding,isOneUsage,properties):
	if has_item(itemName)+1:
		get_item(itemName).Count += 1
		#print(Inventory)
	else:
		var key = {
			"Name": itemName,
			"Count": 1,
			"Path": path,
			"Icon": icon,
			"Weight": weight,  
			"ForBuild": isForBuilding,
			"OneUse": isOneUsage,
			"Props": properties
		}
		for i in maxInventory:
			if !Inventory[i]:
				Inventory.remove_at(i)
				Inventory.insert(i, key)
				curWeight += weight
				#print(Inventory)
				return

@rpc("any_peer", "call_local")
func client_add_to_inv(newInventory):
	Inventory = newInventory
	Inv.change(Inventory)



func remove_item(item):
	if not item:
		#print("Not Item")
		return
	if multiplayer.is_server():
		$/root/Main.server_remove_item(item)
	else:
		$/root/Main.rpc_id(1, "server_remove_item", item)


func equip_item(item):
	if !multiplayer.is_server():
		return
	
	if item.Name == "Gun":
		itemLogic = GunLogic.new(item.Props)

@rpc("any_peer", "reliable")
func server_use_item(item, params: Dictionary):
	if !multiplayer.is_server() or !itemLogic:
		return
	
	var used = itemLogic.use(self, params)
	if used.is_empty():
		return
	var props = used[0]
	var type = used[1]
	#print(type)
	
	Inventory[has_item(item.Name)].Props.merge(props, true)
	rpc("item_used", item, props, type)

@rpc("any_peer", "call_local")
func item_used(item, props, type):
	#print("item_used ", curItem.Name)
	change_props(item.Name, props)
	var Nitem = get_curItem()
	if Nitem:
		Nitem.change_props(props)
		Nitem.used_client(type)

func change_props(item, props):
	if has_item(item)+1:
		#print(item, props)
		Inventory[has_item(item)].Props.merge(props, true)
		#print(Inventory)




func is_empty():
	for i in maxInventory:
		if Inventory[i]:
			return false
	return true

func is_full(itemWeight = 0):
	if curWeight + itemWeight > maxWeight:
		return true
	for i in maxInventory:
		if !Inventory[i]:
			return false
	return true

func has_item(Name):
	for i in maxInventory:
		if Inventory[i] and Inventory[i].Name == Name:
			return i
	return -1

func get_item(Name):
	for i in maxInventory:
		if Inventory[i] and Inventory[i].Name == Name:
			return Inventory[i]

func delete_from_inv(i):
	#print("deleted")
	Inventory.remove_at(i)
	Inventory.insert(i, 0)
	Inv.change(Inventory)

func get_curItem():
	if Head.get_child_count() >= 5:
		return Head.get_child(4)



func set_cur_item(i):
	curItem = Inventory[i]
	if curItem:
		if multiplayer.is_server():
			show_item(curItem)
		else:
			rpc_id(1, "show_item", curItem)
	else:
		if multiplayer.is_server():
			hide_item()
		else:
			rpc_id(1, "hide_item")
	rpc("set_client_cur_item", i)

@rpc("any_peer", "call_local")
func set_client_cur_item(i):
	curItem = Inventory[i]


@rpc("authority", "reliable")
func hide_item():
	rpc("_remove_held_item")

@rpc("authority", "reliable")
func show_item(item):
	rpc("_spawn_held_item", item)

@rpc("any_peer", "reliable", "call_local")
func _spawn_held_item(Item):
	_remove_held_item()

	var scene = load(Item.Path)
	var item = scene.instantiate()
	
	item.canBeTaken = false
	Head.add_child(item)
	equip_item(Item)
	item.freeze = true
	item.change_props(Item.Props)
	item.set_position(Hand.get_position())
	item.changed()
	item.show()

@rpc("any_peer", "reliable", "call_local")
func _remove_held_item():
	if get_curItem():
		get_curItem().queue_free()



@rpc("authority", "reliable")
func throw(force = 10.0):
	#print("Throw")
	if !curItem:
		#print("isnt cur item")
		return
	if !multiplayer.is_server():
		return
	
	var dir = -Cam.global_transform.basis.z.normalized()
	delete_from_inv(actCell)
	curItem = null
	
	var item = get_curItem()
	item.reparent($/root/Main)
	item.freeze = false
	item.canBeTaken = true
	#item.rpc("changed")
	item.changed()
	item.linear_velocity = dir * force
	
	$/root/Main.add_item(item.name)
	rpc("client_throw", item.global_transform, dir, force)

@rpc("any_peer", "call_local")
func client_throw(transf, dir, force):
	#print("ClientThrow")
	if multiplayer.is_server():
		return
	
	var item = get_curItem()
	if !item:
		#print("isnt item")
		return
	
	delete_from_inv(actCell)
	curItem = null
	
	item.reparent($/root/Main)
	item.global_transform = transf
	item.freeze = false
	item.canBeTaken = true
	item.changed()
	item.linear_velocity = dir * force


#@rpc("any_peer", "reliable", "call_local")
#func throw_item(item_name: String, force: float = 10.0):
#	#print("ThrowMethodCalled")
#	if item_name:
#		#print("Throwed")
#		var dir = -Cam.global_transform.basis.z.normalized()
#		delete_from_inv(actCell)
#		curItem = null
#		
#		rpc_id(1, "server_throw_item", item_name, dir, force)
#
#@rpc("any_peer", "reliable", "call_local")
#func server_throw_item(item_name: String, dir: Vector3, force: float):
#	$/root/Main.rpc("throw", item_name, dir, force)

# Main
func _ready():
	Cam.current = is_multiplayer_authority()
	if !is_multiplayer_authority():
		Inv.hide()
		Health.hide()

	if is_multiplayer_authority():
		Body.hide()

	#Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _enter_tree():
	set_multiplayer_authority(name.to_int())

func _unhandled_input(e):
	if is_multiplayer_authority():
		if e is InputEventMouseButton:
			var cast = Ray.get_collider()
			#print(cast)
			if e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
				if curItem and Head.get_child(4):
					if multiplayer.is_server():
						server_use_item(curItem, {"origin":Cam.global_transform.origin, "direction":-Cam.global_transform.basis.z+Vector3(0,0,0)})
					else:
						rpc_id(1, "server_use_item",curItem, {"origin":Cam.global_transform.origin, "direction":-Cam.global_transform.basis.z+Vector3(0,0,0)})
			elif e.button_index == MOUSE_BUTTON_RIGHT and e.pressed:
				if curItem:
					pass
				elif cast and !is_full(cast.weight) and cast.canBeTaken:
					add_to_inv(cast)
					#print("In[uted]")
		elif e is InputEventMouseMotion:
			rotate_y(-e.relative.x * SENSIVITY * sensivity)
			Head.rotate_x(-e.relative.y * SENSIVITY * sensivity)
			Head.rotation.x = clamp(Head.rotation.x, -PI/2, PI/2)

func _physics_process(delta):
	if is_multiplayer_authority():
		
		if not is_on_floor():
			velocity.y -= gravity * delta
		
		if Input.is_action_just_pressed("ui_cancel"):
			$"../".exit_game(name.to_int())
			get_tree().quit()
		
		if Input.is_action_just_pressed("ui_scope"):
			if aiming:
				aiming = false
				sensivity = 1
			else:
				aiming = true
				sensivity = 0.5
		var targetFOV = scopeFOV if aiming else defaultFOV
		Cam.fov = lerp(Cam.fov, targetFOV, delta * scopeSpeed)
		
		
		if Input.is_action_just_pressed("ui_throw"):
			#print("ActionPressedThrow")
			if multiplayer.is_server():
				throw()
			else:
				rpc_id(1, "throw")
			#rpc("throw_item", get_curItem().name)
		
		if !is_empty():
			if Input.is_action_just_pressed("1_gun"):
				actCell = 0
				#rpc("set_cur_item", actCell)
				set_cur_item(actCell)
			elif Input.is_action_just_pressed("2_gun"):
				actCell = 1
				#rpc("set_cur_item", actCell)
				set_cur_item(actCell)
			elif Input.is_action_just_pressed("3_gun"):
				actCell = 2
				#rpc("set_cur_item", actCell)
				set_cur_item(actCell)
			
		
		if Input.is_action_just_pressed("ui_accept") and is_on_floor():
			velocity.y = JUMP_VELOCITY
			
		if Input.is_action_just_pressed("ui_shift"):
			if shift == 1.5:
				shift = 1
			else:
				shift = 1.5

		var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		if direction:
			velocity.x = direction.x * SPEED * shift
			velocity.z = direction.z * SPEED * shift
		else:
			#velocity.x = move_toward(velocity.x, 0, SPEED)
			#velocity.z = move_toward(velocity.z, 0, SPEED)
			velocity.x = 0
			velocity.z = 0

	move_and_slide()




func receive_dmg(dmg = 1, zone = "Body", hit = null):
	print("receiving dmg")
	rpc("receive_dmg_rpc", dmg, zone, hit)
	if hit:
		rpc("add_decal", hit)

@rpc("any_peer", "call_local")
func receive_dmg_rpc(dmg, _zone, _hit):
	health -= dmg
	if health <= 0:
		health = 100
		position = Vector3.ZERO

@rpc("any_peer", "call_local")
func add_decal(hit):
	var decal = load("res://Decals/blood.tscn").instantiate()
	add_child(decal)
	decal.global_position = hit.position
	decal.global_transform.origin = hit.position
	decal.global_transform.basis = Basis.looking_at(hit.normal, Vector3.UP)


func heal(h = 1):
	rpc("heal_rpc", h)

@rpc("any_peer", "call_local")
func heal_rpc(h):
	health += h
