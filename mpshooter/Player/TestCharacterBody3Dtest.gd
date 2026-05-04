extends CharacterBody3D

var platform = null

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
const SENSIVITY = 0.01

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var Health = $ProgressBar
@onready var Head = $Head
@onready var Hand = $Head/Hand
@onready var Cam = $Head/Camera3D
@onready var Ray = $Head/RayCast3D2

@onready var Body = $Body
@onready var Inv = $Control

var health = 49
var shift = 1

var defaultFOV = 75.0
var scopeFOV = 50.0
var scopeSpeed = 10.0

var sensivity = 1

var aiming = false
var locked = false

var maxInventory = 4
var maxWeight = 20
var curWeight = 0
var Inventory = [0, 0, 0, 0]
var actCell = 0
var curItem = null

var itemLogic: ItemLogic


func _enter_tree():
	set_multiplayer_authority(name.to_int())


func _ready():
	Cam.current = is_multiplayer_authority()
	if !is_multiplayer_authority():
		Inv.hide()
		Health.hide()

	if is_multiplayer_authority():
		Body.hide()

	platform = OS.get_name()
	match platform:
		"Windows", "macOS", "Linux":
			print("РџСЂР°С†СЋС” РЅР° РїРє: ", platform)
		"Android", "iOS":
			print("РџСЂР°С†СЋС” РЅР° РјРѕР±С–Р»СЊРЅРѕРјСѓ РїСЂРёСЃС‚СЂРѕС—: ", platform)
			platform = "mobile"
			$Joystick.show()
		"Web":
			print("РџСЂР°С†СЋС” РІ Р±СЂР°СѓР·РµСЂС–")
		_:
			print("Р†РЅС€Р° РїР»Р°С‚С„РѕСЂРјР°: ", platform)


func add_to_inv(item):
	if multiplayer.is_server():
		server_add_to_inv(
			item.name,
			item.itemName,
			item.path,
			item.icon,
			item.weight,
			item.isForBuilding,
			item.isOneUsage,
			item.properties
		)
	else:
		rpc_id(
			1,
			"server_add_to_inv",
			item.name,
			item.itemName,
			item.path,
			item.icon,
			item.weight,
			item.isForBuilding,
			item.isOneUsage,
			item.properties
		)


@rpc("any_peer", "reliable")
func server_add_to_inv(item_name, item_title, path, icon, weight, is_for_building, is_one_usage, props):
	if !multiplayer.is_server():
		return

	if !item_name:
		return

	var world_item = find_world_item(item_name)
	if !world_item:
		return

	var slot = add_to_inv_def(
		item_title,
		path,
		icon,
		weight,
		is_for_building,
		is_one_usage,
		props,
		item_name
	)
	if slot == -1:
		return

	set_world_item_in_inventory(world_item, true)
	rpc("sync_pickup_item", item_name, Inventory)


func add_to_inv_def(item_name, path, icon, weight, is_for_building, is_one_usage, properties, world_name):
	curWeight += weight
	var index = has_item(item_name)
	if index != -1:
		Inventory[index].Count += 1
		Inventory[index].WorldNames.append(world_name)
		return index

	var key = {
		"Name": item_name,
		"Count": 1,
		"Path": path,
		"Icon": icon,
		"Weight": weight,
		"ForBuild": is_for_building,
		"OneUse": is_one_usage,
		"Props": properties,
		"WorldNames": [world_name],
		"ViewNode": ""
	}
	for i in range(maxInventory):
		if !Inventory[i]:
			Inventory[i] = key
			return i
	curWeight -= weight
	return -1


@rpc("any_peer", "call_local", "reliable")
func sync_pickup_item(item_name, new_inventory):
	Inventory = new_inventory
	recalc_inventory_weight()
	var world_item = find_world_item(item_name)
	set_world_item_in_inventory(world_item, true)
	sync_view_models()
	curItem = Inventory[actCell]
	update_active_view()
	Inv.change(Inventory)


func find_world_item(item_name):
	return $/root/Main.find_child(item_name, true, false)


func set_world_item_in_inventory(item, in_inventory):
	if !item:
		return

	if in_inventory:
		if item is CollisionObject3D:
			if !item.has_meta("saved_collision_layer"):
				item.set_meta("saved_collision_layer", item.collision_layer)
			if !item.has_meta("saved_collision_mask"):
				item.set_meta("saved_collision_mask", item.collision_mask)
			item.collision_layer = 0
			item.collision_mask = 0
		if item is RigidBody3D:
			if !item.has_meta("saved_freeze"):
				item.set_meta("saved_freeze", item.freeze)
			item.freeze = true
			item.linear_velocity = Vector3.ZERO
			item.angular_velocity = Vector3.ZERO
		for shape in item.find_children("*", "CollisionShape3D", true, false):
			if !shape.has_meta("saved_disabled"):
				shape.set_meta("saved_disabled", shape.disabled)
			shape.disabled = true
		item.canBeTaken = false
		item.hide()
		return

	if item is CollisionObject3D:
		item.collision_layer = int(item.get_meta("saved_collision_layer", item.collision_layer))
		item.collision_mask = int(item.get_meta("saved_collision_mask", item.collision_mask))
	if item is RigidBody3D:
		item.freeze = bool(item.get_meta("saved_freeze", false))
	for shape in item.find_children("*", "CollisionShape3D", true, false):
		shape.disabled = bool(shape.get_meta("saved_disabled", false))
	item.canBeTaken = true
	item.show()
	if item.has_method("changed"):
		item.changed()


func sync_view_models():
	var valid_view_names = {}

	for i in range(maxInventory):
		var entry = Inventory[i]
		if !entry:
			continue
		var view = ensure_view_model(entry)
		if view:
			valid_view_names[view.name] = true

	for child in Head.get_children():
		if !child.has_meta("is_view_model"):
			continue
		if !valid_view_names.has(child.name):
			child.queue_free()


func ensure_view_model(entry):
	if !entry:
		return null

	var existing = get_view_model(entry)
	if existing:
		if existing.has_method("change_props"):
			existing.change_props(entry.Props)
		if existing.has_method("changed"):
			existing.changed()
		return existing

	var scene = load(entry.Path)
	if !scene:
		return null

	var view = scene.instantiate()
	view.name = "%s_View_%s" % [entry.Name, str(abs(hash(entry.WorldNames[0])))]
	view.set_meta("is_view_model", true)

	var synchronizer = view.get_node_or_null("MultiplayerSynchronizer")
	if synchronizer:
		synchronizer.free()

	if view is CollisionObject3D:
		view.collision_layer = 0
		view.collision_mask = 0
	if view is RigidBody3D:
		view.freeze = true
		view.linear_velocity = Vector3.ZERO
		view.angular_velocity = Vector3.ZERO
	view.canBeTaken = false

	for shape in view.find_children("*", "CollisionShape3D", true, false):
		shape.disabled = true

	Head.add_child(view)
	entry.ViewNode = view.name

	if view.has_method("change_props"):
		view.change_props(entry.Props)
	if view.has_method("changed"):
		view.changed()
	view.hide()
	return view


func get_view_model(entry):
	if !entry or !entry.has("ViewNode") or entry.ViewNode == "":
		return null
	print(entry.ViewNode)
	return Head.get_node_or_null(entry.ViewNode)


func get_curItem():
	return get_view_model(curItem)


func update_active_view():
	itemLogic = null
	for child in Head.get_children():
		if !child.has_meta("is_view_model"):
			continue
		child.hide()

	if !curItem:
		return

	var view = ensure_view_model(curItem)
	if !view:
		return

	view.show()
	update_active_view_transform()
	equip_item(curItem)


func update_active_view_transform():
	var item = get_curItem()
	if !item:
		return
	item.transform = Hand.transform


func equip_item(item):
	if !multiplayer.is_server():
		return

	match item.Name:
		"Gun":
			itemLogic = GunLogic.new(item.Props)
		"Bomb":
			itemLogic = BombLogic.new(item.Props)
		"Bazooka":
			itemLogic = BazookaLogic.new(item.Props)
		_:
			itemLogic = null


@rpc("any_peer", "reliable")
func server_use_item(item, params: Dictionary, mbtn):
	if !multiplayer.is_server() or !itemLogic:
		return

	var held_item = get_curItem()
	if !held_item or !held_item.visible:
		return

	if held_item.has_method("can_use_item") and !held_item.can_use_item():
		return

	var used = itemLogic.use(self, params, mbtn)
	if used.is_empty():
		return

	var props = used[0]
	var type = used[1]
	Inventory[has_item(item.Name)].Props.merge(props, true)
	rpc("item_used", item.Name, props, type)


@rpc("any_peer", "call_local")
func item_used(item_name, props, type):
	change_props(item_name, props)
	var entry = get_item(item_name)
	if !entry:
		return
	var view = get_view_model(entry)
	if view:
		if view.has_method("change_props"):
			view.change_props(props)
		if view.has_method("used_client"):
			view.used_client(type)


func change_props(item_name, props):
	var index = has_item(item_name)
	if index != -1:
		Inventory[index].Props.merge(props, true)


func is_empty():
	for i in range(maxInventory):
		if Inventory[i]:
			return false
	return true


func is_full(itemWeight = 0):
	if curWeight + itemWeight > maxWeight:
		return true
	for i in range(maxInventory):
		if !Inventory[i]:
			return false
	return true


func has_item(item_name):
	for i in range(maxInventory):
		if Inventory[i] and Inventory[i].Name == item_name:
			return i
	return -1


func get_item(item_name):
	for i in range(maxInventory):
		if Inventory[i] and Inventory[i].Name == item_name:
			return Inventory[i]
	return null


func recalc_inventory_weight():
	curWeight = 0
	for i in range(maxInventory):
		if !Inventory[i]:
			continue
		curWeight += Inventory[i].Weight * Inventory[i].Count


func delete_from_inv(i):
	if i < 0 or i >= maxInventory or !Inventory[i]:
		return {}

	var entry = Inventory[i]
	curWeight -= entry.Weight
	var world_name = entry.WorldNames.pop_back()
	entry.Count -= 1
	var removed_view = ""

	if entry.Count <= 0:
		removed_view = entry.ViewNode
		Inventory[i] = 0
	else:
		Inventory[i] = entry

	Inv.change(Inventory)
	return {
		"world_name": world_name,
		"removed_view": removed_view
	}


func set_cur_item(i):
	if multiplayer.is_server():
		rpc("apply_cur_item", i)
	else:
		rpc_id(1, "request_set_cur_item", i)


@rpc("any_peer", "reliable")
func request_set_cur_item(i):
	if !multiplayer.is_server():
		return
	rpc("apply_cur_item", i)


@rpc("any_peer", "call_local", "reliable")
func apply_cur_item(i):
	actCell = i
	curItem = Inventory[i]
	update_active_view()


@rpc("authority", "reliable")
func throw(force = 10.0):
	if !curItem:
		return
	if !multiplayer.is_server():
		return

	var held_view = get_curItem()
	if !held_view:
		return

	var removed = delete_from_inv(actCell)
	if !removed.has("world_name"):
		return

	var world_item = find_world_item(removed.world_name)
	if !world_item:
		return

	var view_transform = held_view.global_transform
	if removed.removed_view != "":
		held_view.queue_free()
	else:
		held_view.hide()

	set_world_item_in_inventory(world_item, false)
	world_item.global_transform = view_transform
	if world_item is RigidBody3D:
		world_item.linear_velocity = Vector3.ZERO
		world_item.angular_velocity = Vector3.ZERO
		world_item.freeze = false
		world_item.apply_central_impulse(-Cam.global_transform.basis.z.normalized() * force)

	curItem = Inventory[actCell]
	update_active_view()
	rpc("client_throw", removed.world_name, removed.removed_view, Inventory, view_transform, -Cam.global_transform.basis.z.normalized(), force, actCell)


@rpc("any_peer", "call_local")
func client_throw(world_name, removed_view, new_inventory, item_transform, dir, force, new_act_cell):
	if multiplayer.is_server():
		return

	Inventory = new_inventory
	recalc_inventory_weight()
	if removed_view != "":
		var removed_node = Head.get_node_or_null(removed_view)
		if removed_node:
			removed_node.queue_free()

	var world_item = find_world_item(world_name)
	set_world_item_in_inventory(world_item, false)
	if world_item:
		world_item.global_transform = item_transform
		if world_item is RigidBody3D:
			world_item.linear_velocity = Vector3.ZERO
			world_item.angular_velocity = Vector3.ZERO
			world_item.freeze = false
			world_item.apply_central_impulse(dir * force)

	actCell = new_act_cell
	curItem = Inventory[actCell]
	sync_view_models()
	update_active_view()
	Inv.change(Inventory)


func _unhandled_input(e):
	if !is_multiplayer_authority():
		return

	if e is InputEventMouseButton:
		var cast = Ray.get_collider()
		var held_item = get_curItem()
		if e.button_index == MOUSE_BUTTON_LEFT and e.pressed:
			if curItem and held_item and (!held_item.has_method("can_use_item") or held_item.can_use_item()):
				if multiplayer.is_server():
					server_use_item(curItem, {"origin": Cam.global_transform.origin, "direction": -Cam.global_transform.basis.z}, "left")
				else:
					rpc_id(1, "server_use_item", curItem, {"origin": Cam.global_transform.origin, "direction": -Cam.global_transform.basis.z}, "left")
		elif e.button_index == MOUSE_BUTTON_RIGHT and e.pressed:
			if curItem and held_item and (!held_item.has_method("can_use_item") or held_item.can_use_item()):
				if multiplayer.is_server():
					server_use_item(curItem, {"origin": Cam.global_transform.origin, "direction": -Cam.global_transform.basis.z}, "right")
				else:
					rpc_id(1, "server_use_item", curItem, {"origin": Cam.global_transform.origin, "direction": -Cam.global_transform.basis.z}, "right")
			elif cast and cast.canBeTaken and !is_full(cast.weight):
				add_to_inv(cast)
	elif e is InputEventMouseMotion:
		rotate_y(-e.relative.x * SENSIVITY * sensivity)
		Head.rotate_x(-e.relative.y * SENSIVITY * sensivity)
		Head.rotation.x = clamp(Head.rotation.x, -PI / 2, PI / 2)


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
			if multiplayer.is_server():
				throw()
			else:
				rpc_id(1, "throw")

		if !is_empty():
			if Input.is_action_just_pressed("1_gun"):
				set_cur_item(0)
			elif Input.is_action_just_pressed("2_gun"):
				set_cur_item(1)
			elif Input.is_action_just_pressed("3_gun"):
				set_cur_item(2)
			elif Input.is_action_just_pressed("4_gun"):
				set_cur_item(3)

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
			update_active_view_transform()
			move_and_slide()
			return

		var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		if direction:
			velocity.x = direction.x * SPEED * shift
			velocity.z = direction.z * SPEED * shift
		else:
			velocity.x = 0
			velocity.z = 0

	update_active_view_transform()
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
