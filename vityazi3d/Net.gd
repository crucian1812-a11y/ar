extends Node

# LAN co-op transport + UDP host discovery for "same Wi-Fi" play.
const PORT := 24567
const BCAST_PORT := 24568
const MAGIC := "VITYAZI_HOST_V1"
const MAX_PLAYERS := 6

var active := false
var is_host := false
var connected := false      # ready to start (host always; client after handshake)
var status := ""            # human-readable lobby status
var found_ip := ""

var _peer: ENetMultiplayerPeer
var _beacon: PacketPeerUDP    # host: broadcasts presence
var _listener: PacketPeerUDP  # client: listens for a host
var _beacon_t := 0.0

signal lobby_changed()

func _ready() -> void:
	set_process(true)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func host() -> bool:
	_reset()
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_server(PORT, MAX_PLAYERS)
	if err != OK:
		status = "Не удалось создать игру"
		lobby_changed.emit()
		return false
	multiplayer.multiplayer_peer = _peer
	active = true
	is_host = true
	connected = true
	status = "Хост создан. Игроки в сети могут подключиться."
	_beacon = PacketPeerUDP.new()
	_beacon.set_broadcast_enabled(true)
	_beacon.set_dest_address("255.255.255.255", BCAST_PORT)
	_beacon_t = 0.0
	lobby_changed.emit()
	return true

func discover() -> void:
	_reset()
	_listener = PacketPeerUDP.new()
	_listener.bind(BCAST_PORT)
	status = "Поиск игры в сети…"
	lobby_changed.emit()

func join(ip: String) -> bool:
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_client(ip, PORT)
	if err != OK:
		status = "Не удалось подключиться"
		lobby_changed.emit()
		return false
	multiplayer.multiplayer_peer = _peer
	active = true
	is_host = false
	status = "Подключение к %s…" % ip
	lobby_changed.emit()
	return true

func leave() -> void:
	_reset()

func my_id() -> int:
	if multiplayer.multiplayer_peer == null:
		return 1
	return multiplayer.get_unique_id()

func peers() -> Array:
	return multiplayer.get_peers()

func _reset() -> void:
	if _beacon: _beacon.close(); _beacon = null
	if _listener: _listener.close(); _listener = null
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer = null
	_peer = null
	active = false
	is_host = false
	connected = false
	found_ip = ""

func _process(delta: float) -> void:
	if is_host and _beacon:
		_beacon_t -= delta
		if _beacon_t <= 0.0:
			_beacon_t = 1.0
			_beacon.put_packet(MAGIC.to_utf8_buffer())
	if _listener and found_ip == "" and _listener.get_available_packet_count() > 0:
		var pkt := _listener.get_packet()
		if pkt.get_string_from_utf8() == MAGIC:
			found_ip = _listener.get_packet_ip()
			_listener.close(); _listener = null
			status = "Игра найдена: %s" % found_ip
			join(found_ip)

func _on_peer_connected(id: int) -> void:
	status = "Игрок подключился (%d). Всего: %d" % [id, peers().size() + 1]
	lobby_changed.emit()

func _on_peer_disconnected(id: int) -> void:
	status = "Игрок отключился (%d)" % id
	lobby_changed.emit()

func _on_connected() -> void:
	connected = true
	status = "Подключено! Выберите витязя."
	lobby_changed.emit()

func _on_failed() -> void:
	status = "Подключение не удалось"
	_reset()
	lobby_changed.emit()

func _on_server_disconnected() -> void:
	status = "Хост закрыл игру"
	_reset()
	lobby_changed.emit()
