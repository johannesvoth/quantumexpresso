extends Node2D

# Default game server port. Can be any number between 1024 and 49151.
# Not on the list of registered or common ports as of November 2020:
# https://en.wikipedia.org/wiki/List_of_TCP_and_UDP_port_numbers
const DEFAULT_PORT = 10567

# Max number of players.
const MAX_PEERS = 12

var peer = null

# Name for my player.
var player_name = "The Warrior"

# Names for remote players in id:name format.
var players = {}
var players_ready = []

var lobby_id := -1

# Signals to let lobby GUI know what's going on.
signal player_list_changed()
signal connection_failed()
signal connection_succeeded()
signal game_ended()
signal game_error(what)


func _process(delta):
	Steam.run_callbacks()


# Callback from SceneTree.
func _player_connected(id):
	# Registration of a client beings here, tell the connected player that we are here.
	#register_player.rpc_id(id, player_name)
	
	print("player connected callback, adding player..")
	add_player(id)


# Callback from SceneTree.
func _player_disconnected(id):
	if has_node("/root/World"): # Game is in progress.
		if multiplayer.is_server():
			game_error.emit("Player " + players[id] + " disconnected")
			end_game()
	else: # Game is not in progress.
		# Unregister this player.
		unregister_player(id)


# Callback from SceneTree, only for clients (not server).
func _connected_ok():
	# We just connected to a server
	connection_succeeded.emit()


# Callback from SceneTree, only for clients (not server).
func _server_disconnected():
	game_error.emit("Server disconnected")
	end_game()


# Callback from SceneTree, only for clients (not server).
func _connected_fail():
	multiplayer.set_network_peer(null) # Remove peer
	connection_failed.emit()


func unregister_player(id):
	players.erase(id)
	player_list_changed.emit()


@rpc("call_local")
func load_world():
	# Change scene.
	var world = load("res://world.tscn").instantiate()
	get_tree().get_root().add_child(world)
	get_tree().get_root().get_node("Lobby").hide()

	# Set up score.
	world.get_node("Score").add_player(multiplayer.get_unique_id(), player_name)
	for pn in players:
		world.get_node("Score").add_player(pn, players[pn])
	get_tree().set_pause(false) # Unpause and unleash the game!

func get_player_list():
	return players.values()


func get_player_name():
	return player_name

func end_game():
	if has_node("/root/World"): # Game is in progress.
		# End it
		get_node("/root/World").queue_free()

	game_ended.emit()
	players.clear()


func _ready():
	Steam.steamInit(480)
	multiplayer.peer_connected.connect(self._player_connected)
	multiplayer.peer_disconnected.connect(self._player_disconnected)
	multiplayer.connected_to_server.connect(self._connected_ok)
	multiplayer.connection_failed.connect(self._connected_fail)
	multiplayer.server_disconnected.connect(self._server_disconnected)
	Steam.lobby_joined.connect(_on_lobby_joined.bind())
	Steam.lobby_created.connect(_on_lobby_created.bind())


func _on_lobby_created(_connect: int, _lobby_id: int):
	if _connect == 1:
		lobby_id = _lobby_id
		Steam.setLobbyData(_lobby_id, "name", "test_server")
		create_socket()
		print("Create lobby id:",str(lobby_id))
	else:
		print("Error on create lobby!")


func _on_lobby_joined(lobby: int, permissions: int, locked: bool, response: int):
	if response == 1:
		var id = Steam.getLobbyOwner(lobby)
		if id != Steam.getSteamID():
			connect_socket(id)
	else:
		var FAIL_REASON: String # Get the failure reason
		match response:
			2:  FAIL_REASON = "This lobby no longer exists."
			3:  FAIL_REASON = "You don't have permission to join this lobby."
			4:  FAIL_REASON = "The lobby is now full."
			5:  FAIL_REASON = "Uh... something unexpected happened!"
			6:  FAIL_REASON = "You are banned from this lobby."
			7:  FAIL_REASON = "You cannot join due to having a limited account."
			8:  FAIL_REASON = "This lobby is locked or disabled."
			9:  FAIL_REASON = "This lobby is community locked."
			10: FAIL_REASON = "A user in the lobby has blocked you from joining."
			11: FAIL_REASON = "A user you have blocked is in the lobby."
		print(FAIL_REASON)


func create_socket():
	peer = SteamMultiplayerPeer.new()
	# Example of peer config
	#peer.set_config(SteamPeerConfig.NETWORKING_CONFIG_SEND_BUFFER_SIZE, 524288)
	peer.create_host(1)
	multiplayer.set_multiplayer_peer(peer)
	
	
	add_player(1)


func connect_socket(steam_id : int):
	peer = SteamMultiplayerPeer.new()
	# Example of peer config
	# peer.set_config(SteamPeerConfig.NETWORKING_CONFIG_SEND_BUFFER_SIZE, 524288)
	peer.create_client(steam_id, 0)
	multiplayer.set_multiplayer_peer(peer)
	
	add_player(peer.get_unique_id())
	print("connect_socket.")


func _on_host_steam_game_pressed() -> void:
	player_name = "TEMP PLAYER NAME"
	Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC, MAX_PEERS)

@onready var steam_id_field: TextEdit = $ExpressoUI/SteamIdField

func _on_join_steam_game_pressed() -> void:
	player_name = "SOME JOINING DUDE"
	Steam.joinLobby(int(steam_id_field.text))


@onready var player_spawner: MultiplayerSpawner = $PlayerSpawner
const PLAYER = preload("res://player/player.tscn")
func add_player(p_id): # just done it here instead of giving the player spawner a dedicated script. Might move this in the future.
	var player = PLAYER.instantiate()
	player.name = str(p_id)
	player_spawner.add_child(player, true)
