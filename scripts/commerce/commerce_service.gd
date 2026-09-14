extends Node
## UI never grants products. Only store purchase callbacks reach fulfillment.
signal changed(data: Dictionary)
signal purchased(product_id: String, token: String)
signal ad_visibility_changed(visible: bool)
signal preview_ad_requested
const Content = preload("res://scripts/core/game_content.gd")
const AndroidStore = preload("res://scripts/commerce/google_play_store.gd")
const Ads = preload("res://scripts/commerce/mobile_ads.gd")
var store_adapter
var ad_adapter
var preview: bool = false
var store_ready: bool = false
var busy: bool = false
var prices: Dictionary = {}
var message: String = "Purchases will be available in the mobile store release."
var ads_removed: bool = false
var session_seconds: float = 0.0
var last_ad: float = -1000.0
var shown_ads: int = 0
var busy_seconds: float = 0.0
var preview_owned: Array = []

func _ready() -> void:
	preview = OS.get_cmdline_user_args().has("--commerce-preview") and OS.has_feature("debug") and not OS.has_feature("mobile")
	if preview:
		store_ready = true
		message = "TEST STORE · No money is charged. This preview uses a separate save."
	elif OS.get_name() == "Android":
		store_adapter = AndroidStore.new()
		store_adapter.catalog_ready.connect(_catalog)
		store_adapter.completed.connect(func(id,token): purchased.emit(id,token))
		store_adapter.status.connect(_status)
		add_child(store_adapter)
	ad_adapter = Ads.new()
	ad_adapter.visibility_changed.connect(func(visible): ad_visibility_changed.emit(visible))
	add_child(ad_adapter)
	publish()

func publish() -> void:
	changed.emit({"ready":store_ready,"can_restore":preview or store_adapter != null,"busy":busy,"prices":prices.duplicate(),"message":message,"preview":preview})

func _catalog(value: Dictionary) -> void:
	prices = value
	store_ready = not prices.is_empty()
	message = "One-time expansions. Any purchase removes every ad." if store_ready else "No expansions are currently available from the store. Please try again later."
	publish()

func _status(text: String, finished: bool = true) -> void:
	message = text
	if finished:
		busy = false
	publish()

func purchase(id: String) -> void:
	if busy or not store_ready or Content.product(id).is_empty():
		return
	busy = true
	busy_seconds = 0
	message = "Waiting for the store…"
	publish()
	if preview:
		if not preview_owned.has(id):
			preview_owned.append(id)
		purchased.emit(id,"preview:"+id)
	elif store_adapter != null and prices.has(id):
		store_adapter.purchase(id)
	else:
		_status("This expansion is not available from the store yet.")

func restore_purchases() -> void:
	if busy or (not preview and store_adapter == null):
		return
	busy = true
	busy_seconds = 0
	if preview:
		for id in preview_owned:
			purchased.emit(id,"preview:"+id)
		_status("Test purchases restored." if not preview_owned.is_empty() else "No test purchases to restore.")
	elif store_adapter != null:
		store_adapter.restore_purchases()

func fulfilled(token: String, saved: bool) -> void:
	if saved:
		set_ads_removed(true)
		if not token.begins_with("preview:") and store_adapter != null:
			store_adapter.acknowledge(token)
		_status("Expansion unlocked. Your entire game is now ad-free.")
	else:
		_status("Your purchase is waiting for a successful save. Restore purchases to retry.")

func set_ads_removed(value: bool) -> void:
	ads_removed = value
	if ad_adapter != null:
		ad_adapter.set_enabled(not value)

func can_show_ad(placement: String) -> bool:
	return not ads_removed and not busy and placement in ["hotel_change","event_finished"] and session_seconds >= 180.0 and session_seconds-last_ad >= 240.0 and shown_ads < 3

func natural_break(placement: String) -> void:
	if not can_show_ad(placement):
		return
	if preview:
		last_ad = session_seconds
		shown_ads += 1
		preview_ad_requested.emit()
	elif ad_adapter != null and ad_adapter.show_if_ready():
		last_ad = session_seconds
		shown_ads += 1

func _process(delta: float) -> void:
	session_seconds += delta
	if busy:
		busy_seconds += delta
		if busy_seconds > 90:
			_status("The store is taking longer than expected. You can retry or restore purchases.")
