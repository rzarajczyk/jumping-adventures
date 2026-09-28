class_name LanPairing
extends Node

signal scanned(payload: String)
signal scan_failed(message: String)
signal scan_canceled

const VERSION := 1
const PORT := 7777
const PREFIX := "jumpingadventure://join?data="
var android: Object

func _ready() -> void:
	if Engine.has_singleton("JumpingLan"):
		android = Engine.get_singleton("JumpingLan")
		android.connect("scan_completed", func(value: String): scanned.emit(value))
		android.connect("scan_failed", func(value: String): scan_failed.emit(value))
		android.connect("scan_canceled", func(): scan_canceled.emit())

static func now_ms() -> int:
	if Engine.has_singleton("JumpingLan"):
		return Engine.get_singleton("JumpingLan").elapsedRealtime()
	return Time.get_ticks_msec()

static func token() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()

static func valid_token(value: Variant) -> bool:
	if not value is String or value.length() != 32: return false
	for c in value:
		if not c in "0123456789abcdef": return false
	return true

static func valid_ip(ip: String) -> bool:
	if not ip.is_valid_ip_address() or ip.contains(":"): return false
	var parts := ip.split(".")
	return int(parts[0]) > 0 and int(parts[0]) < 224 and ip != "255.255.255.255"

static func encode(address: String, session: String, invitation: String, port: int = PORT) -> String:
	var data := {"v": VERSION, "ip": address, "port": port, "session": session, "token": invitation}
	return PREFIX + JSON.stringify(data).uri_encode()

static func decode(payload: String) -> Dictionary:
	if payload.length() > 2048 or not payload.begins_with(PREFIX): return {}
	var data: Variant = JSON.parse_string(payload.trim_prefix(PREFIX).uri_decode())
	if not data is Dictionary: return {}
	if data.get("v") != VERSION or not (data.get("port") is float or data.get("port") is int): return {}
	if data.port != int(data.port) or data.port < 1024 or data.port > 65535: return {}
	if not data.get("ip") is String or not valid_ip(data.ip): return {}
	if not valid_token(data.get("session")) or not valid_token(data.get("token")): return {}
	return data

func addresses() -> Array[String]:
	var result: Array[String] = []
	if android:
		for ip in android.localAddresses():
			if valid_ip(ip) and not ip in result: result.append(ip)
	else:
		for interface in IP.get_local_interfaces():
			var interface_name: String = interface.name.to_lower()
			if interface_name.begins_with("lo") or interface_name.begins_with("utun") or interface_name.begins_with("tun") or interface_name.begins_with("ppp"): continue
			for ip in interface.addresses:
				if valid_ip(ip) and not ip.begins_with("127.") and not ip in result: result.append(ip)
	return result

func scan() -> void:
	if android: android.scanQr()
	else: scan_failed.emit("Skanowanie aparatem jest dostępne na Androidzie. Na komputerze wklej kod połączenia.")

func qr_texture(payload: String) -> Texture2D:
	if not android: return null
	var bytes: PackedByteArray = android.qrPng(payload)
	var picture := Image.new()
	if picture.load_png_from_buffer(bytes) != OK: return null
	return ImageTexture.create_from_image(picture)
