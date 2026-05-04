extends CharacterBody3D

var platform = null

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

@onready var Name = $Label3D

var netID: int
var nickname: String

# Main
var health = 49
var shift = 1

#Weapon
var defaultFOV = 75.0
var scopeFOV = 50.0
var scopeSpeed = 10.0

var sensivity = 1

var aiming = false
var locked = false

#Inventory
var maxInventory = 4
var maxWeight = 20
var curWeight = 0
var Inventory = [null,null,null,null]
var actCell = 0
var curItem = null

var itemLogic: ItemLogic

# Functions
#Inventory

func add_to_inv(item):
	print("Adding", self.name)
	if multiplayer.is_server():
		server_add_to_inv(item.netID,item.itemName,item.path,item.icon,item.weight,item.isForBuilding,item.isOneUsage,item.properties)
	else:
		rpc_id(1, "server_add_to_inv", item.netID,item.itemName,item.path,item.icon,item.weight,item.isForBuilding,item.isOneUsage,item.properties)

@rpc("any_peer", "reliable")
func server_add_to_inv(itemID, itn,pth,icn,wth,ifb,iou,props):
	if !multiplayer.is_server():
		print("Not server")
		return
	
	print(itemID)
	if !itemID:
		print("Not item")
		return
	
	#$/root/Main.active_items.erase(itemName)
	
	remove_item(itemID)
	add_to_inv_def(itn,pth,icn,wth,ifb,iou,props)
	print(itn)
	
	#rpc_id(multiplayer.get_remote_sender_id(), "client_add_to_inv", Inventory)
	rpc("client_add_to_inv",Inventory)

func add_to_inv_def(itemName,path,icon,weight,isForBuilding,isOneUsage,properties):
	if has_item(itemName):
		get_item(itemName).Count += 1
		print("Inventory: ", self.name, Inventory)
	else:
		var key = {
			"Name": itemName,
			"Count": 1,
			"Path": path,
			"Icon": icon,
			"Weight": weight,  
			"ForBuild": isForBuilding,
			"OneUse": isOneUsage,
			"Props": properties.duplicate(true)
		}
		for i in maxInventory:
			if !Inventory[i]:
				Inventory[i] = key
				curWeight += weight
				#print(Inventory)
				return

@rpc("any_peer", "call_local")
func client_add_to_inv(newInventory):
	Inventory = newInventory.duplicate(true)
	print("Sync Inventory: ", self.name,  Inventory)
	Inv.change(Inventory)



func remove_item(itemID):
	if not itemID:
		#print("Not Item")
		return
	if multiplayer.is_server():
		$/root/Main.server_remove_item(itemID)
	else:
		$/root/Main.rpc_id(1, "server_remove_item", itemID)


func equip_item(item):
	if !multiplayer.is_server():
		return
	
	itemLogic = null
	match item.Name:
		"Gun":
			itemLogic = GunLogic.new(item.Props)
		"Bomb":
			itemLogic = BombLogic.new(item.Props)
		"Bazooka":
			itemLogic = BazookaLogic.new(item.Props)
		
	#if item.Name == "Gun":
	#	itemLogic = GunLogic.new(item.Props)

@rpc("any_peer", "reliable")
func server_use_item(item, params: Dictionary, mbtn):
	if !multiplayer.is_server() or !get_curItemN() or !get_curItemN().visible or !itemLogic:
		return
	
	var used = itemLogic.use(self, params, mbtn)
	print(used, itemLogic)
	if used.is_empty():
		print("empty")
		return
	var props = used[0]
	var type = used[1]
	#print(type)
	
	get_item(item.Name).Props.merge(props, true)
	rpc("item_used", item.Name, props, type)

@rpc("any_peer", "call_local")
func item_used(itemN, props, type):
	#print("item_used ", curItem.Name)
	change_props(itemN, props)
	var Nitem = get_curItemN()
	#print(Nitem)
	if Nitem:
		Nitem.change_props(props)
		Nitem.used_client(type)

func change_props(item, props):
	if has_item(item):
		#print(item, props)
		get_item(item).Props.merge(props, true)
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
			return true
	return false

func get_item(Name):
	for i in maxInventory:
		if Inventory[i] and Inventory[i].Name == Name:
			return Inventory[i]

#@rpc("any_peer", "call_local", "reliable")
func delete_from_inv(i):
	#print("deleted")
	if !multiplayer.is_server():
		return
	if !Inventory[i]:
		return 
	curWeight -= Inventory[i].Weight
	#Inventory.remove_at(i)
	#Inventory.insert(i, 0)
	Inventory[i] = null
	
	Inv.change(Inventory)
	print("Inventory after deleting: ", self.name, Inventory)
	rpc("client_add_to_inv", Inventory)

#func get_curItem():
	#if Head.get_child_count() >= 5:
		#return Head.get_child(4)

func get_curItem():
	return Inventory[actCell]

func get_curItemN():
	if curItem:
		return get_held_item(curItem.Name)

func get_held_item(itemName): 
	if Head.get_child_count()>= 5: 
		for chil in Head.get_children():
			if chil.has_method("changed") and chil.itemName == itemName:
				print(chil.name, itemName)
				return chil
	return null



func set_cur_item(i):
	if !Inventory[i]:
		print("No Inventory i")
		curItem = null
		if multiplayer.is_server():
			hide_item()
		else:
			rpc_id(1, "hide_item")
		#return
	else:
		curItem = Inventory[i]
		if multiplayer.is_server():
			show_item(curItem)
		else:
			rpc_id(1, "show_item", curItem)
	rpc("client_add_to_inv", Inventory)
	rpc("set_client_cur_item", i)

@rpc("any_peer", "call_local")
func set_client_cur_item(i):
	curItem = Inventory[i]
	print("Inventory afre cutItem", self.name, Inventory)


#@rpc("authority", "reliable")
#func hide_item():
	#rpc("_remove_held_item")

@rpc("any_peer", "reliable")
func hide_item():
	if !multiplayer.is_server():
		return
	rpc("_remove_held_item")

@rpc("authority", "reliable")
func show_item(item):
	rpc("_spawn_held_item", item)

@rpc("any_peer", "reliable", "call_local")
func _spawn_held_item(Item):
	_remove_held_item()
	var item = get_held_item(Item.Name)
	if !item:
		var scene = load(Item.Path)
		item = scene.instantiate()
		Head.add_child(item)
		item.set_position(Hand.get_position())
	

	#var scene = load(Item.Path)
	#var item = scene.instantiate()
	
	item.canBeTaken = false
	item.freeze = true
	item.change_props(Item.Props)
	item.changed()
	item.get_node("CollisionShape3D").disabled = true
	item.show()
	equip_item(Item)
	print("Inventory: ", self.name, Inventory)
	#print(Head.get_children())


@rpc("any_peer", "reliable", "call_local")
func _remove_held_item():
	#print("removeCalled")
	for i in Head.get_children():
		if i.has_method("changed"):
			#i.queue_free()
			i.hide()



@rpc("authority", "reliable")
func throw(force = 10.0):
	#print("Throw")
	if !multiplayer.is_server():
		return
	#if !curItem:
		#print("isnt cur item")
		#return
	
	var dir = -Cam.global_transform.basis.z.normalized()

	print("Throw cur item: ", curItem, actCell)
	var item = get_curItemN()
	if !item:
		#print("No item")
		return
	item.reparent($/root/Main)
	item.freeze = false
	item.canBeTaken = true
	#item.rpc("changed")
	item.changed()
	item.get_node("CollisionShape3D").disabled = false
	#print(item)
	#await get_tree().create_timer(0.1).timeout
	item.linear_velocity = dir * force
	curItem = null
	delete_from_inv(actCell)
	rpc("client_add_to_inv", Inventory)
	#rpc("delete_from_inv", actCell)
	print("Inventory after throw: ", self.name, Inventory)
	rpc("client_throw", item.global_transform, dir, force)
	$/root/Main.add_item(item)

@rpc("any_peer", "call_local")
func client_throw(transf, _dir, _force):
	print("ClientThrow")
	if multiplayer.is_server():
		return
	
	var item = get_curItemN()
	if !item:
		print("isnt item")
		return
	
	#delete_from_inv(actCell)
	curItem = null
	
	print("Inventory after throw: ", self.name, Inventory)
	print("Act cell", actCell, curItem)
	item.reparent($/root/Main)
	item.global_transform = transf
	item.freeze = false
	item.canBeTaken = true
	item.changed()
	item.get_node("CollisionShape3D").disabled = false
	#item.linear_velocity = dir * force



# Main
func _ready():
	Cam.current = is_multiplayer_authority()
	if !is_multiplayer_authority():
		Inv.hide()
		Health.hide()

	if is_multiplayer_authority():
		Body.hide()
	
	nickname = self.name
	Name.text = nickname
	
	set_cur_item(actCell)
	
	platform = OS.get_name()
	match platform:
		"Windows", "macOS", "Linux":
			print("Працює на десктопі: ", platform)
		"Android", "iOS":
			print("Працює на мобільному пристрої: ", platform)
			platform = "mobile"
			$Joystick.show()
		"Web":
			print("Працює в браузері")
		_:
			print("Інша платформа: ", platform)
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
						server_use_item(curItem, {"origin":Cam.global_transform.origin, "direction":-Cam.global_transform.basis.z+Vector3(0,0,0)}, "left")
					else:
						rpc_id(1, "server_use_item",curItem, {"origin":Cam.global_transform.origin, "direction":-Cam.global_transform.basis.z+Vector3(0,0,0)}, "left")
			elif e.button_index == MOUSE_BUTTON_RIGHT and e.pressed:
				if curItem:
					if multiplayer.is_server():
						server_use_item(curItem, {"origin":Cam.global_transform.origin, "direction":-Cam.global_transform.basis.z+Vector3(0,0,0)}, "right")
					else:
						rpc_id(1, "server_use_item",curItem, {"origin":Cam.global_transform.origin, "direction":-Cam.global_transform.basis.z+Vector3(0,0,0)}, "right")
				elif cast and !is_full(cast.weight) and cast.canBeTaken:
					add_to_inv(cast)
					#await get_tree().process_frame
					#set_cur_item(actCell)
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
		
		if Input.is_action_just_pressed("lock_screen"):
			locked = !locked
			sensivity = int(locked)
		
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
			elif Input.is_action_just_pressed("4_gun"):
				actCell = 3
				#rpc("set_cur_item", actCell)
				set_cur_item(actCell)
			
		
		if Input.is_action_just_pressed("ui_accept") and is_on_floor():
			velocity.y = JUMP_VELOCITY
			
		if Input.is_action_just_pressed("ui_shift"):
			if shift == 1.5:
				shift = 1
			else:
				shift = 1.5
		
		if platform == "mobile":
			velocity.x = $Joystick.direction.x * SPEED * shift
			velocity.z = $Joystick.direction.y * SPEED * shift
			return
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
	print("receiving dmg", dmg, zone, hit)
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
	var decal = load("res://Decals & Shaders/Blood/blood.tscn").instantiate()
	add_child(decal)
	decal.global_position = hit.position
	decal.global_transform.origin = hit.position
	decal.global_transform.basis = Basis.looking_at(hit.normal, Vector3.UP)


func heal(h = 1):
	rpc("heal_rpc", h)

@rpc("any_peer", "call_local")
func heal_rpc(h):
	health += h
