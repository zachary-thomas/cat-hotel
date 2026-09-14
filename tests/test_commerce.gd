extends SceneTree
const Commerce = preload("res://scripts/commerce/commerce_service.gd")
const GoogleStore = preload("res://scripts/commerce/google_play_store.gd")
var failures: int = 0
var granted: Array = []
var catalog: Dictionary = {}

class StoreClient:
	extends RefCounted
	var launched: Array = []
	func is_ready() -> bool:
		return true
	func purchase(id, option, offer) -> Dictionary:
		launched = [id,option,offer]
		return {"response_code":0}

func check(condition: bool,message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var service = Commerce.new()
	service.session_seconds = 179
	check(not service.can_show_ad("hotel_change"),"No ad interrupts the opening three minutes")
	service.session_seconds = 300
	check(service.can_show_ad("hotel_change"),"A later hotel transition is eligible for an ad")
	check(not service.can_show_ad("pet") and not service.can_show_ad("launch"),"Petting and app launch never trigger ads")
	service.last_ad = 280
	check(not service.can_show_ad("event_finished"),"Frequency cap prevents repeated ads")
	service.session_seconds = 600
	service.set_ads_removed(true)
	check(not service.can_show_ad("hotel_change"),"Any fulfilled purchase disables every ad placement")
	service.set_ads_removed(false)
	service.shown_ads = 3
	check(not service.can_show_ad("event_finished"),"Session cap limits total ad interruptions")
	var adapter = GoogleStore.new()
	adapter.catalog_ready.connect(func(value): catalog=value)
	adapter._products({"response_code":0,"product_details":[
		{"product_id":"purrington.cat_club","one_time_purchase_offer_details_list":[{"formatted_price":"$3.49","purchase_option_id":"permanent","offer_id":null,"rental_details":null}]},
		{"product_id":"purrington.forest_lodge","one_time_purchase_offer_details_list":null},
		{"product_id":"purrington.snowcap_spa","one_time_purchase_offer_details_list":[{"formatted_price":"$1.00","rental_details":{"end_time_millis":1000}}]}
	]})
	check(catalog.get("purrington.cat_club")=="$3.49" and catalog.size()==1,"The SDK offer-list schema supplies a real localized price and excludes missing/rental offers")
	var client = StoreClient.new()
	adapter.client = client
	adapter.purchase("purrington.cat_club")
	check(client.launched==["purrington.cat_club","permanent",""],"The displayed price's purchase option is passed to the billing flow")
	adapter.client = null
	adapter.completed.connect(func(id,token): granted.append([id,token]))
	adapter._purchases({"response_code":0,"purchases":[{"purchase_state":2,"purchase_token":"pending-token","product_ids":["purrington.cat_club"]}]})
	check(granted.is_empty(),"Pending payments never unlock content or remove ads")
	adapter._purchases({"response_code":1})
	check(granted.is_empty(),"Cancelled payments never unlock content")
	adapter._purchases({"response_code":0,"purchases":[{"purchase_state":1,"purchase_token":"confirmed-token","product_ids":["unrecognized","purrington.cat_club"]}]})
	check(granted.size()==1 and granted[0][0]=="purrington.cat_club","Only recognized completed store products reach fulfillment")
	service.free()
	adapter.free()
	print("COMMERCE TESTS: ","PASS" if failures==0 else "FAIL"," (",failures," failures)")
	quit(1 if failures else 0)
