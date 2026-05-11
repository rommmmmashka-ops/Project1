extends Node3D

const PORT = 1777

var peer = ENetMultiplayerPeer.new()
var ip_adress = "127.0.0.1"
@export var playerPacked: PackedScene

var active_items = {}


var nextID: int = 1
func generate_id():
	var netID = nextID
	nextID += 1
	return netID


func register_existing_item(node):
	if !multiplayer.is_server():
		print("Not  server")
		return
	
	active_items[node.netID] = node
	print("registered: ", node, " ", node.netID)
	
	rpc("register_existing_item_client", node.netID, node.get_path())

@rpc("any_peer", "reliable")
func register_existing_item_client(netID, path):
	if multiplayer.is_server():
		return
	
	var node = get_node_or_null(path)
	print("The node is: ", node, "   ", netID)
	if node:
		node.netID = netID
		active_items[netID] = node
	print("Client register:  ",active_items)



func _ready():
	for child in self.get_children():
		if child is RigidBody3D or child is CharacterBody3D:
			active_items[child.netID] = child
	print("Items:", active_items)

func get_item(netID):
	if netID in active_items:
		return active_items[netID]
		

@rpc("authority", "reliable")
func add_item(node):
	#print("Adding ", node)
	if !multiplayer.is_server() or !node:
		print(multiplayer.is_server(), "  ", node)
		return
	
	#print("Node is: ", node)
	active_items[node.netID] = node
	#print("Added ", active_items)
	#print("Server add Items:", active_items)
	rpc("add_item_client", node.get_path(), node.netID)

@rpc("any_peer", "reliable")
func add_item_client(nodePath, netID):
	if !netID or !nodePath:
		return
	#print("Client add NodePath and id ", nodePath, " ", netID)
	var node = get_node_or_null(nodePath)
	if node:
		active_items[netID] = node
	#print("Clietn add active items list: ", active_items)

@rpc("authority", "reliable")
func server_remove_item(netID):
	if !multiplayer.is_server() or !active_items.has(netID):
		return 
	
	var node = active_items[netID]
	#print("Server remove node: ", node)
	node.queue_free()
	active_items.erase(netID)
	
	rpc("client_remove_item", netID)

@rpc("any_peer", "reliable")
func client_remove_item(netID):
	if multiplayer.is_server() or !active_items.has(netID):
		return
	
	var node = active_items[netID]
	#print("Client remove active items list: ", active_items)
	#print("Client remove node: ", node)
	node.queue_free()
	active_items.erase(netID)

@rpc("any_peer", "call_local")
func sync_full_state(items_data: Dictionary):
	print("Items data: ", items_data)
	for child in get_children():
		if not child is RigidBody3D:
			print(child)
			continue
		if not child.netID in items_data:
			child.queue_free()

@rpc("any_peer", "reliable")
func reparent_item(itemID, parentID, additionalNode = null):
	print(itemID, " ", parentID, " ", additionalNode)
	if !multiplayer.is_server() or !active_items.has(itemID) or !active_items.has(parentID):
		print("Returned")
		return
	print("Active items: ", active_items)
	var item = active_items[itemID]
	var parent = active_items[parentID]
	print(item," ", parent)
	if additionalNode:
		var node = parent.get_node_or_null(additionalNode)
		item.reparent(node)
		print("Reparented", node)
	else:
		item.reparent(parent)
	
	rpc("reparent_item_client", itemID, parentID, additionalNode)

@rpc("authority", "reliable")
func reparent_item_client(itemID, parentID, additionalNode):
	print("Client act items: ", active_items)
	var item = active_items[itemID]
	var parent = active_items[parentID]
	print(item, "     ", parent)
	item.reparent(parent)
	if additionalNode:
		var node = parent.get_node_or_null(additionalNode)
		item.reparent(node)
		print("Clietn reparented", node)
	else:
		item.reparent(parent)


func _on_line_edit_text_submitted(new_text):
	ip_adress = new_text

func _on_host_pressed():
	peer.create_server(PORT)
	multiplayer.multiplayer_peer = peer
	multiplayer.peer_connected.connect(add_player)
	
	add_player()
	#upnp_setup()
	$MainMenu.hide()

func _on_join_pressed():
	peer.create_client(ip_adress, PORT)
	multiplayer.multiplayer_peer = peer
	$MainMenu.hide()
	
func add_player(id = 1):
	var player = playerPacked.instantiate()
	player.name = str(id)
	player.set_multiplayer_authority(id)
	#call_deferred("add_child", player)
	add_child(player)
	print("Act items aftert player: ", active_items)
	if multiplayer.is_server():
		#print("Registering")
		await player._ready
		print("Player ready")
		register_existing_item(player)
		var items_data = {}
		for itemID in active_items.keys():
			#print(itemID)
			items_data[itemID] = active_items[itemID].get_path()
		rpc_id(id, "sync_full_state", items_data)

#func _add_player(id = 1):
	#var player = playerPacked.instantiate()
#
	#player.name = str(id)
	#player.set_multiplayer_authority(id)
#
	#add_child(player)
#
	#if multiplayer.is_server():
#
		#await player.ready
#
		#if player.netID == 0:
			#player.netID = generate_id()
#
		#register_existing_item(player)
#
		#var items_data = {}
#
		#for itemID in active_items.keys():
			#items_data[itemID] = str(active_items[itemID].get_path())
#
		#rpc_id(id, "sync_full_state", items_data)


func exit_game(id):
	multiplayer.peer_disconnected.connect(del_player)
	del_player(id)

func del_player(id):
	rpc("_del_player", id)

@rpc("any_peer", "call_local")
func _del_player(id):
	get_node_or_null(str(id)).queue_free()


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



