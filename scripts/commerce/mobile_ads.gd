extends Node
## Optional Poing Studios AdMob adapter. Missing SDK/config never blocks gameplay.
signal visibility_changed(visible: bool)
var enabled: bool = false
var ad
var loading: bool = false
var classes: Dictionary = {}
var unit_id: String = ""
var initialized: bool = false
var showing: bool = false
var consent_platform
var consent_started: bool = false
var consent_form
var initialization_listener
var ad_load_callback
var retry_after: float = 0.0

func _ready() -> void:
	for entry in ProjectSettings.get_global_class_list():
		if entry.class in ["MobileAds","InterstitialAdLoader","InterstitialAdLoadCallback","AdRequest","FullScreenContentCallback","ConsentInformation","ConsentRequestParameters","UserMessagingPlatform","OnInitializationCompleteListener"]:
			classes[entry.class] = entry.path
	if not OS.get_name() in ["Android","iOS"]:
		return
	var config = ConfigFile.new()
	if config.load("res://commerce.cfg") != OK:
		return
	unit_id = str(config.get_value("ads","android_interstitial" if OS.get_name()=="Android" else "ios_interstitial",""))
	# A blank ad-unit ID keeps development builds offline.

func make(id: String):
	return load(classes[id]).new() if classes.has(id) else null

func consent_ready(can_request_ads: bool) -> void:
	if not enabled or not can_request_ads or unit_id=="" or not classes.has("MobileAds"):
		return
	if initialized:
		load_ad()
		return
	var mobile = load(classes.MobileAds)
	initialization_listener = make("OnInitializationCompleteListener")
	if initialization_listener == null:
		return
	initialization_listener.on_initialization_complete = func(_status):
		initialized = true
		load_ad()
	mobile.initialize(initialization_listener)

func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled and ad != null and not showing:
		ad.destroy()
		ad = null
	elif enabled and initialized:
		load_ad()
	elif enabled and not consent_started:
		begin_consent()

func begin_consent() -> void:
	if not enabled or unit_id=="" or not classes.has("UserMessagingPlatform") or not Engine.has_singleton("PoingGodotAdMob"):
		return
	consent_started = true
	consent_platform = load(classes.UserMessagingPlatform)
	var parameters = make("ConsentRequestParameters")
	if parameters == null:
		return
	consent_platform.consent_information.update(parameters,_consent_updated,func(_error):
		# Previously obtained consent may still permit requests; unknown never does.
		_check_consent()
	)

func _consent_updated() -> void:
	var info = consent_platform.consent_information
	if info.get_consent_status()==2 and info.get_is_consent_form_available():
		consent_platform.load_consent_form(func(form):
			consent_form = form
			visibility_changed.emit(true)
			form.show(func(_error):
				visibility_changed.emit(false)
				consent_form = null
				_check_consent()
			)
		,func(_error): _check_consent())
	else:
		_check_consent()

func _check_consent() -> void:
	if consent_platform == null:
		return
	var consent: int = consent_platform.consent_information.get_consent_status()
	consent_ready(consent==1 or consent==3)

func privacy_options_available() -> bool:
	return consent_platform != null and consent_platform.consent_information.get_privacy_options_requirement_status()==2

func open_privacy_options() -> void:
	if not privacy_options_available():
		return
	if ad != null and not showing:
		ad.destroy()
		ad = null
	visibility_changed.emit(true)
	consent_platform.show_privacy_options_form(func(_error):
		visibility_changed.emit(false)
		_check_consent()
	)

func load_ad() -> void:
	if not enabled or not initialized or loading or ad != null:
		return
	var loader = make("InterstitialAdLoader")
	var callback = make("InterstitialAdLoadCallback")
	ad_load_callback = callback
	var request = make("AdRequest")
	if loader == null or callback == null or request == null:
		return
	loading = true
	callback.on_ad_failed_to_load = func(_error): loading=false; retry_after=60.0
	callback.on_ad_loaded = func(loaded):
		loading = false
		if not enabled:
			loaded.destroy()
			return
		ad = loaded
		var full = make("FullScreenContentCallback")
		if full != null:
			full.on_ad_dismissed_full_screen_content = _closed
			full.on_ad_failed_to_show_full_screen_content = func(_error): _closed()
			ad.full_screen_content_callback = full
	loader.load(unit_id,request,callback)

func show_if_ready() -> bool:
	if not enabled or ad == null or showing:
		return false
	showing = true
	visibility_changed.emit(true)
	ad.show()
	return true

func _closed() -> void:
	showing = false
	visibility_changed.emit(false)
	if ad != null:
		ad.destroy()
		ad = null
	load_ad()

func _exit_tree() -> void:
	if ad != null:
		ad.destroy()

func _process(delta: float) -> void:
	if retry_after>0:
		retry_after -= delta
		if retry_after<=0:
			load_ad()
