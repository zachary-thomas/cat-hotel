extends Node
## Adapter for the first-party GodotGooglePlayBilling BillingClient (Godot 4.2+).
signal catalog_ready(prices: Dictionary)
signal completed(product_id: String, token: String)
signal status(message: String, finished: bool)
const Content = preload("res://scripts/core/game_content.gd")
var client
var tokens: Dictionary = {}
var purchase_options: Dictionary = {}
var product_type: int = 0
var retry_seconds: float = 0.0

func _ready() -> void:
	if not Engine.has_singleton("GodotGooglePlayBilling"):
		status.emit("Google Play billing is unavailable in this build.",true)
		return
	for entry in ProjectSettings.get_global_class_list():
		if entry.class == "BillingClient":
			var script = load(entry.path)
			client = script.new()
			break
	if client == null:
		status.emit("Google Play billing is not installed in this build.",true)
		return
	add_child(client)
	client.connected.connect(_connected)
	client.disconnected.connect(func(): status.emit("Store disconnected. Reconnecting…",true); retry_seconds=3.0)
	client.connect_error.connect(func(_code,_debug): status.emit("Couldn't connect to Google Play. Try again later.",true); retry_seconds=10.0)
	client.query_product_details_response.connect(_products)
	client.query_purchases_response.connect(_purchases)
	client.on_purchase_updated.connect(_purchases)
	client.acknowledge_purchase_response.connect(_acknowledged)
	client.start_connection()

func _connected() -> void:
	var ids: Array = []
	for item in Content.PRODUCTS:
		ids.append(item.id)
	client.query_product_details(ids,product_type)
	client.query_purchases(product_type)

func _products(response: Dictionary) -> void:
	if response.get("response_code",-1) != 0:
		status.emit("Store prices aren't available. Please retry later.",true)
		return
	var result: Dictionary = {}
	purchase_options.clear()
	for item in response.get("product_details",[]):
		var id: String = str(item.get("product_id",""))
		if Content.product(id).is_empty():
			continue
		var offers = item.get("one_time_purchase_offer_details_list",[])
		if not offers is Array:
			continue
		for offer in offers:
			# These expansions promise permanent ownership; never sell a rental.
			if not offer is Dictionary or offer.get("rental_details") != null:
				continue
			var price: String = str(offer.get("formatted_price", ""))
			if price == "":
				continue
			result[id] = price
			purchase_options[id] = {"option":offer.get("purchase_option_id") if offer.get("purchase_option_id") != null else "", "offer":offer.get("offer_id") if offer.get("offer_id") != null else ""}
			# Prefer the standard permanent offer over temporary promotions.
			if purchase_options[id].offer == "":
				break
	catalog_ready.emit(result)

func purchase(id: String) -> void:
	if client == null or not client.is_ready():
		status.emit("Google Play is not ready. Please try again.",true)
		return
	if not purchase_options.has(id):
		status.emit("This expansion has no available purchase option.",true)
		return
	var option: Dictionary = purchase_options[id]
	var result: Dictionary = client.purchase(id,option.option,option.offer)
	if result.get("response_code",-1) != 0:
		status.emit("Purchase cancelled." if result.get("response_code")==1 else "The purchase could not start. No expansion was charged here.",true)

func restore_purchases() -> void:
	if client != null and client.is_ready():
		client.query_purchases(product_type)
	else:
		status.emit("Connect to Google Play to restore purchases.",true)

func _purchases(response: Dictionary) -> void:
	if response.get("response_code",-1) != 0:
		status.emit("Purchase cancelled." if response.get("response_code")==1 else "Couldn't check purchases. Please try restoring again.",true)
		return
	var purchases = response.get("purchases",[])
	if purchases.is_empty():
		status.emit("No purchases to restore on this store account.",true)
	for purchase_data in purchases:
		if purchase_data.get("purchase_state",0) == 2:
			status.emit("Payment is pending in Google Play. Content unlocks after payment completes.",true)
			continue
		if purchase_data.get("purchase_state",0) != 1:
			continue
		var token: String = str(purchase_data.get("purchase_token",""))
		if token == "":
			continue
		tokens[token] = purchase_data
		for id in purchase_data.get("product_ids",[]):
			if not Content.product(id).is_empty():
				completed.emit(id,token)

func acknowledge(token: String) -> void:
	if client != null and tokens.has(token):
		if not tokens[token].get("is_acknowledged",false):
			client.acknowledge_purchase(token)
		else:
			tokens.erase(token)

func _acknowledged(response: Dictionary) -> void:
	if response.get("response_code",-1) == 0:
		tokens.erase(str(response.get("token","")))
	else:
		status.emit("Your expansion is saved. Store confirmation will retry when connected.",true)
		retry_seconds = 10.0

func _process(delta: float) -> void:
	if retry_seconds > 0:
		retry_seconds -= delta
		if retry_seconds <= 0 and client != null:
			if client.is_ready():
				restore_purchases()
			else:
				client.start_connection()

func _exit_tree() -> void:
	if client != null:
		client.end_connection()
