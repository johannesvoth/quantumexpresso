extends Control

@onready var multiplayer_ui: Control = $"."
@onready var lobby_list: VBoxContainer = $SteamStuff/ScrollContainer/LobbyList

@onready var text_edit_ip_adress_lan: TextEdit = $LANStuff/TextEditIPAdressLAN
@onready var text_edit_port_lan: TextEdit = $LANStuff/TextEditPortLAN

const PLAYER = preload("res://player/player.tscn")

@onready var player_spawner: MultiplayerSpawner = $"../PlayerSpawner"


var lobby_id: int = 0
var steam_peer = SteamMultiplayerPeer.new()
var lan_peer = ENetMultiplayerPeer.new()


const DEFAULT_PORT_FALLBACK = 10567
const MAX_PEERS = 12
var player_name = "The Warrior"


func _ready():
	Steam.steamInit(480)
	#multiplayer.peer_connected.connect(self._player_connected)
	#multiplayer.peer_disconnected.connect(self._player_disconnected)
	#multiplayer.connected_to_server.connect(self._connected_ok)
	#multiplayer.connection_failed.connect(self._connected_fail)
	#multiplayer.server_disconnected.connect(self._server_disconnected)
	Steam.lobby_joined.connect(_on_lobby_joined.bind())
	Steam.lobby_created.connect(_on_lobby_created.bind())

func _process(delta):
	Steam.run_callbacks()
@onready var world_spawner: MultiplayerSpawner = $"../WorldSpawner"
func _on_host_steam_pressed() -> void:
	Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC, MAX_PEERS)
	multiplayer_ui.hide()
	
	#multiplayer.peer_connected.connect(
		#func(p_id):
			#print(str(p_id) + "has joined the LAN game")
			#add_player(p_id)
	#) THIS IS NOT FIRING WITH EXPRESSO
	
	world_spawner.spawn_world()
	add_player(multiplayer.get_unique_id()) # always host but whatever

func _on_lobby_created(_connect: int, _lobby_id: int):
	print("created lobby callback")
	if _connect == 1:
		lobby_id = _lobby_id
		Steam.setLobbyData(_lobby_id, "name", "test_server")
		steam_peer.create_host(1)
		multiplayer.set_multiplayer_peer(steam_peer)
		print("Create lobby id:",str(lobby_id))
	else:
		print("Error on create lobby!")



@onready var steam_id_field: TextEdit = $SteamStuff/SteamIdField
func _on_join_steam_pressed() -> void:
	print("on join button pressed")
	Steam.joinLobby(int(steam_id_field.text))



func _on_lobby_joined(lobby: int, permissions: int, locked: bool, response: int):
	print("LOOBY JOINED CALLBACK")
	if response == 1:
		var id = Steam.getLobbyOwner(lobby)
		if id != Steam.getSteamID():
			print("Creating client because not looby owner.")
			steam_peer.create_client(id, 0)
			multiplayer.set_multiplayer_peer(steam_peer)
			multiplayer_ui.hide()
			
			add_player(multiplayer.get_unique_id()).rpc()
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





func _on_host_lan_pressed() -> void:
	var port = text_edit_port_lan.text
	lan_peer.create_server(int(port))
	multiplayer.multiplayer_peer = lan_peer
	
	multiplayer.peer_connected.connect(
		func(p_id):
			print(str(p_id) + "has joined the LAN game")
			add_player(p_id)
	)
	
	add_player(multiplayer.get_unique_id()) # host player
	
	world_spawner.spawn_world() # only spawn the world if you are a host
	
	multiplayer_ui.hide()

func _on_join_lan_pressed() -> void:
	var port = text_edit_port_lan.text
	var hostname = text_edit_ip_adress_lan.text
	lan_peer.create_client(hostname,int(port))
	multiplayer.multiplayer_peer = lan_peer
	
	multiplayer_ui.hide()

@rpc("call_local")
func add_player(p_id): # just done it here instead of giving the player spawner a dedicated script. Might move this in the future.
	var player = PLAYER.instantiate()
	player.name = str(p_id)
	player_spawner.add_child(player, true)


#func _on_refresh_lobbies_button_pressed() -> void:
	#Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)
	#print("305 Mr. Worldwide Requesting a lobby list")
	#Steam.requestLobbyList()

#func _on_steam_join(lobby_id:int): # no adding of player here, but when? = when the host is created, he setupts the signal for when other peers join.
	#steam_peer.connect_lobby(lobby_id)
	#multiplayer.multiplayer_peer = steam_peer
	#
	#multiplayer_ui.hide()


#func _on_lobby_match_list(these_lobbies: Array) -> void:
	#
	#if lobby_list.get_child_count() > 0:
		#for n in lobby_list.get_children():
			#n.queue_free()
	#
	#for this_lobby in these_lobbies:
		#
		#var lobby_name: String = Steam.getLobbyData(this_lobby, "name")
		#var lobby_mode: String = Steam.getLobbyData(this_lobby, "mode")
		#var lobby_num_members: int = Steam.getNumLobbyMembers(this_lobby)
		#
		#var lobby_button: Button = Button.new()
		#lobby_button.set_text("Lobby %s: %s [%s] - %s Player(s)" % [this_lobby, lobby_name, lobby_mode, lobby_num_members])
		#lobby_button.set_size(Vector2(400/4, 25/4))
		#lobby_button.set_name("lobby_%s" % this_lobby)
		#lobby_button.connect("pressed", Callable(self, "_on_steam_join").bind(this_lobby))
#
		#lobby_list.add_child(lobby_button)
