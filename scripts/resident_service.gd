extends Node

signal activated

const ENDPOINT := "user://resident.json"
var server := TCPServer.new()
var token := ""
var clients: Array[Dictionary] = []

func start() -> Error:
	var error := server.listen(0, "127.0.0.1")
	if error != OK: return error
	token = Crypto.new().generate_random_bytes(32).hex_encode()
	var file := FileAccess.open(ENDPOINT, FileAccess.WRITE)
	if file == null:
		server.stop()
		return ERR_CANT_CREATE
	file.store_string(JSON.stringify({"port": server.get_local_port(), "token": token}))
	file.close()
	return OK

func wake_existing() -> bool:
	# The owner may still be creating its endpoint after acquiring the native lock.
	var deadline := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < deadline:
		var endpoint = JSON.parse_string(FileAccess.get_file_as_string(ENDPOINT)) if FileAccess.file_exists(ENDPOINT) else null
		if endpoint is Dictionary and endpoint.get("port") is float and endpoint.get("token") is String:
			var client := StreamPeerTCP.new()
			if client.connect_to_host("127.0.0.1", int(endpoint.port)) == OK:
				while Time.get_ticks_msec() < deadline:
					client.poll()
					if client.get_status() == StreamPeerTCP.STATUS_CONNECTED:
						client.put_data((String(endpoint.token) + "\n").to_utf8_buffer())
						# An acknowledgement ensures the request reached the resident.
						while Time.get_ticks_msec() < deadline:
							client.poll()
							if client.get_available_bytes() > 0: return client.get_u8() == 1
							await get_tree().process_frame
						break
					if client.get_status() == StreamPeerTCP.STATUS_ERROR: break
					await get_tree().process_frame
		await get_tree().create_timer(0.05).timeout
	return false

func _process(_delta: float) -> void:
	while server.is_connection_available():
		var stream := server.take_connection()
		if clients.size() >= 16: stream.disconnect_from_host()
		else: clients.append({"stream": stream, "data": "", "since": Time.get_ticks_msec()})
	for index in range(clients.size() - 1, -1, -1):
		var entry: Dictionary = clients[index]
		var stream: StreamPeerTCP = entry.stream
		stream.poll()
		var available := stream.get_available_bytes()
		if available > 0:
			entry.data += stream.get_utf8_string(mini(available, 128))
			if entry.data == token + "\n":
				activated.emit()
				stream.put_u8(1)
				clients.remove_at(index)
				continue
		if entry.data.length() > 65 or Time.get_ticks_msec() - int(entry.since) > 2000 or stream.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			stream.disconnect_from_host()
			clients.remove_at(index)

func stop() -> void:
	server.stop()
	for entry: Dictionary in clients: entry.stream.disconnect_from_host()
	clients.clear()
	if not token.is_empty(): DirAccess.remove_absolute(ENDPOINT)
