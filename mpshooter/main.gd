extends Node3D

const PORT = 1777

var peer = ENetMultiplayerPeer.new()
var ip_adress = "127.0.0.1"
@export var playerPacked: PackedScene

var active_items = {}


func _ready():
	for i in self.get_children():
		if i.name == "MultiplayerSpawner" or i.name == "MainMenu":
			active_items[i.name] = null
		else:
			active_items[i.name] = i.get_path()
	print(active_items)

func get_item(itemName):
	if itemName in active_items:
		return get_node(active_items[itemName])

@rpc("authority", "reliable", "call_local")
func throw(object_name: String, dir: Vector3, force: float):
	if multiplayer.is_server(): 
		var obj = find_child(object_name, true, false)
		if obj:
			#obj.get_node("AnimationPlayer").play("RESET")
			obj.reparent(self)
			obj.freeze = false
			obj.canBeTaken = true
			obj.linear_velocity = dir * force
			add_item(obj)
			rpc("client_show_throw", object_name, obj.global_transform, dir, force)

@rpc("any_peer", "call_local")
func client_show_throw(object_name: String, transf: Transform3D, dir: Vector3, force: float):
	if multiplayer.is_server():
		return 

	var obj = find_child(object_name, true, false)
	if obj:
		obj.reparent(self)
		obj.global_transform = transf
		obj.freeze = false
		obj.canBeTaken = true
		obj.linear_velocity = dir * force


@rpc("authority", "reliable")
func server_remove_item(item):
	if !multiplayer.is_server():
		return
	print(item)
	if !item:
		print("Returned servert")
		return

	if active_items.has(item):
		get_item(item).queue_free()
		active_items.erase(item)

	rpc("client_remove_item", item)

@rpc("any_peer", "call_local")
func client_remove_item(item):
	if multiplayer.is_server():
		return
	if !item:
		print("Returned client")
		return
	get_item(item).queue_free()
	active_items.erase(item)


@rpc("authority", "reliable")
func add_item(item):
	if !multiplayer.is_server():
		return
	if !item:
		return
	
	var path = find_child(item,true,false).get_path()
	active_items[item] = path
	rpc("add_item_client", item, path)

@rpc("any_peer", "call_local")
func add_item_client(item, path):
	if !item:
		return
	active_items[item] = path

@rpc("any_peer", "call_local")
func sync_full_state(items_data: Dictionary):
	print(items_data)
	for child in get_children():
		if child.name in items_data:
			print(child.name)
			continue
		if not str(child.name).is_valid_int():
			child.queue_free()

func _on_line_edit_text_submitted(new_text):
	ip_adress = $MainMenu/LineEdit.new_text

func _on_host_pressed():
	peer.create_server(PORT)
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(add_player)
	
	add_player()
	#upnp_setup()
	$MainMenu.hide()
	


func _on_join_pressed():
	peer.create_client("127.0.0.1", PORT)
	multiplayer.multiplayer_peer = peer
	$MainMenu.hide()
	
func add_player(id = 1):
	var player = playerPacked.instantiate()
	player.name = str(id)
	player.set_multiplayer_authority(id)
	call_deferred("add_child", player)
	if multiplayer.is_server():
		rpc_id(id, "sync_full_state", active_items)


func exit_game(id):
	multiplayer.peer_disconnected.connect(del_player)
	del_player(id)

func del_player(id):
	rpc("_del_player", id)

@rpc("any_peer", "call_local")
func _del_player(id):
	get_node(str(id)).queue_free()


func upnp_setup():
	var upnp = UPNP.new()
	var discover = upnp.discover()
	
	assert(discover ==  UPNP.UPNP_RESULT_SUCCESS, \
	"UPNP Discover Failed! %s" % discover)
	
	assert(upnp.get_gateway() and upnp.get_gateway().is_valid_gateway(), \
	"UPNP Invalid Gateway!")
	
	var map = upnp.add_port_mapping(PORT)
	assert(map ==  UPNP.UPNP_RESULT_SUCCESS, \
	"UPNP PORT Mappnig Failed! %s" % map)
	
	print("Success! Join Adress: %s" % upnp.query_external_address()) 
