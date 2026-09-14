extends Control
## Continuous, saved building across rooms and shared spaces.
const Layout=preload("res://scripts/core/room_layout.gd")
const Interior=preload("res://scripts/core/furniture_layout.gd")
const Catalog=preload("res://scripts/core/furniture_catalog.gd")
const Quality=preload("res://scripts/core/room_quality.gd")
const Session=preload("res://scripts/core/build_session.gd")
const Shared=preload("res://scripts/core/shared_layout.gd")
const Blueprint=preload("res://scripts/core/room_blueprint.gd")
const Metrics=preload("res://scripts/ui/build_metrics.gd")
const Thumbnail=preload("res://scripts/ui/furniture_thumbnail.gd")
const PlayfulTheme=preload("res://scripts/ui/playful_theme.gd")
static var _placement_icons: Dictionary={}
var app
var ui
var panel: PanelContainer
var content: VBoxContainer
var actions: HBoxContainer
var wallet: Label
var status: Label
var confirm_button: Button
var catalogue_view
var placement_tools: HBoxContainer
var session
var selected_room: int=-1
var selected_item: String=""
var selected_uid: String=""
var category: String="sleep"
var browse: bool=false
var affordable: bool=false
var sort_by: String="price"
var placing: bool=false
var moving: int=-1
var candidate: Dictionary={}
var ghost: Dictionary={}
var ghost_intent: String=""
var validity: Dictionary={}
var transaction_error: String=""
var review: String=""
var reviewed_cost: int=0
var source_room: int=-1
var clipboard: Dictionary={}
var blueprint_placing: bool=false
var blueprint_cost: int=0
var tools_open: bool=false
var filter_panel_visible: bool=false
var adjust_open: bool=false
var metrics: Dictionary={}
var chooser: Array=[]
var _last_balance: int=-1
var _target: float=48
var _font_scale: float=1

func _ready() -> void:
 theme=ui.theme
 set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 mouse_filter=Control.MOUSE_FILTER_IGNORE
 hide()
 get_viewport().size_changed.connect(_resize)

func open(room: int=-1) -> void:
 if not app.model.started: return
 ui.close_sheet(); ui.tab="Build"
 app.world.build_mode=true; app.world.follow_cat=-1; app.world.set_exterior_view(false)
 show(); ui.header.hide(); ui.toast_label.hide(); app.build_input.reset()
 review=""; ghost={}; placing=false; tools_open=false; transaction_error=""; adjust_open=false
 selected_room=-1; session=null; browse=room<0
 if room>=0: _select_room(room)
 _refresh(); restore_preview(); focus_room()

func _select_room(room: int) -> void:
 if room!=-2 and (room<0 or room>=app.model.room_count(app.model.current_hotel)): return
 _clear_ghost()
 selected_room=room
 _reset_session()
 review=""; browse=false; ghost={}; selected_item=""; selected_uid=""; chooser=[]; tools_open=false; adjust_open=false
 app.world.edited_room=room
 _refresh(); restore_preview()

func _reset_session() -> void:
 session=null
 if selected_room==-1: return
 if selected_room>=app.model.room_count(app.model.current_hotel): selected_room=-1; return
 session=Session.new()
 session.begin(app.model,app.model.current_hotel,selected_room,"%x-%x" % [Time.get_ticks_usec(),randi()])

func close() -> void:
 # Each Place is already saved. An unfinished ghost has never been bought.
 _finish_close()

func _finish_close() -> void:
 app.world.room_builder.clear_preview(); app.world.room_builder.clear_draft(); app.world.room_builder.select_room(-1)
 app.world.edited_room=-1; app.world.build_mode=false
 app.world.set_exterior_view(app.model.settings.exterior); app.build_input.reset()
 placing=false; blueprint_placing=false; ghost={}; selected_item=""; review=""; session=null; selected_room=-1; adjust_open=false
 hide(); ui.tab="Hotel"; app.world.apply_life(app.model); app._update_ui(); app.world.focus_hotel()

func dismiss_for_menu() -> void:
 if not visible: return
 var destination: String=ui.tab
 _finish_close()
 ui.tab=destination

func _process(_delta: float) -> void:
 if not visible: return
 ui.header.hide(); ui.footer.hide(); ui.toast_label.hide()
 if is_instance_valid(wallet): wallet.text=_wallet_copy()
 if _last_balance!=int(app.model.coins):
  _last_balance=int(app.model.coins)
  if is_instance_valid(catalogue_view): catalogue_view.update_availability(app.model.coins)
  _update_action()

func _resize() -> void:
 app.build_input.reset()
 if visible: _refresh()

func _refresh() -> void:
 if not visible: return
 metrics=Metrics.measure(get_viewport_rect().size,Metrics.safe_area(self),Metrics.phone_scale(self),app.model.settings.build_text_scale)
 _target=metrics.min_target; _font_scale=app.model.settings.build_text_scale*metrics.unit
 for child in get_children(): remove_child(child); child.queue_free()
 confirm_button=null; status=null; catalogue_view=null; placement_tools=null
 var header_surface=Panel.new(); header_surface.name="BuildHeaderSurface"; add_child(header_surface)
 header_surface.position=metrics.header_rect.position; header_surface.size=metrics.header_rect.size; header_surface.mouse_filter=Control.MOUSE_FILTER_IGNORE
 var header_style=PlayfulTheme.panel(PlayfulTheme.CREAM,metrics.unit,20)
 header_style.content_margin_top=4*metrics.unit; header_style.content_margin_bottom=4*metrics.unit
 header_style.content_margin_left=12*metrics.unit; header_style.content_margin_right=6*metrics.unit
 header_surface.add_theme_stylebox_override("panel",header_style)
 var header=HBoxContainer.new(); header.name="BuildHeader"; header.add_theme_constant_override("separation",roundi(6*metrics.unit)); add_child(header)
 header.position=metrics.header_rect.position+Vector2(12,4)*metrics.unit; header.size=metrics.header_rect.size-Vector2(18,8)*metrics.unit
 var title=ui.canvas_label("BUILD",ceili(17*_font_scale),PlayfulTheme.INK)
 title.size_flags_horizontal=Control.SIZE_EXPAND_FILL; header.add_child(title)
 wallet=ui.canvas_label(_wallet_copy(),ceili(14*_font_scale),PlayfulTheme.INK); header.add_child(wallet)
 var close_button: Button=_button("▶  Play",close,true,"CloseBuilder",header)
 close_button.size_flags_horizontal=Control.SIZE_SHRINK_END
 close_button.autowrap_mode=TextServer.AUTOWRAP_OFF
 close_button.custom_minimum_size.x=104*metrics.unit
 close_button.custom_minimum_size.y=56*metrics.unit
 close_button.add_theme_font_size_override("font_size",ceili(14*_font_scale))
 var history_panel=PanelContainer.new(); history_panel.name="BuildHistory"; add_child(history_panel)
 history_panel.position=metrics.history_rect.position; history_panel.size=metrics.history_rect.size
 var history_style=PlayfulTheme.panel(PlayfulTheme.CREAM,metrics.unit,16)
 history_style.content_margin_top=0; history_style.content_margin_bottom=0
 history_style.content_margin_left=6*metrics.unit; history_style.content_margin_right=6*metrics.unit
 history_panel.add_theme_stylebox_override("panel",history_style)
 var history_row=HBoxContainer.new(); history_row.add_theme_constant_override("separation",roundi(8*metrics.unit)); history_panel.add_child(history_row)
 _history_actions(history_row)
 panel=PanelContainer.new(); panel.name="BuildPanel"; add_child(panel)
 panel.add_theme_stylebox_override("panel",PlayfulTheme.panel(PlayfulTheme.CREAM,metrics.unit,20))
 var bounds: Rect2=metrics.browse_rect if browse or tools_open else metrics.panel_rect
 panel.position=bounds.position; panel.size=bounds.size
 var scroll=ScrollContainer.new(); scroll.name="BuildScroll"; scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; panel.add_child(scroll)
 content=VBoxContainer.new(); content.size_flags_horizontal=Control.SIZE_EXPAND_FILL; content.add_theme_constant_override("separation",roundi(8*metrics.unit)); scroll.add_child(content)
 actions=HBoxContainer.new(); actions.name="BuildActions"; add_child(actions)
 actions.position=metrics.actions_rect.position; actions.size=metrics.actions_rect.size
 actions.add_theme_constant_override("separation",roundi(6*metrics.unit))
 if placing: _room_placement()
 elif tools_open: _rooms_content()
 elif not chooser.is_empty():
  _copy("Choose an object")
  for uid in chooser: _button(Catalog.item(_instance(uid).item).name,func(): chooser=[]; _select_object(uid))
  _button("Back",func(): chooser=[]; _refresh())
 elif browse: _catalogue_content()
 elif not ghost.is_empty() or session!=null: _makeover_content()
 else: _rooms_content()
 if transaction_error!="" and not is_instance_valid(status): status=_alert_copy(transaction_error)
 _update_action()
 queue_redraw()

func _button(text: String, callback: Callable, primary: bool=false, id: String="", parent: Node=null) -> Button:
 var button: Button=ui.button(text,callback,primary)
 button.custom_minimum_size=Vector2(_target,_target)
 button.add_theme_font_size_override("font_size",ceili(16*_font_scale))
 button.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 if id!="": button.name=id
 (parent if parent!=null else content).add_child(button)
 return button

func _wallet_copy() -> String:
 var coins: float=app.model.coins
 if coins>=1000000000: return "%.1fB coins" % (coins/1000000000.0)
 if coins>=1000000: return "%.1fM coins" % (coins/1000000.0)
 if coins>=10000: return "%.1fK coins" % (coins/1000.0)
 return "%s coins" % ui.number(coins)

func _placement_button(accept: bool) -> Button:
 var button: Button=_button("Place" if accept else "Cancel",confirm if accept else cancel,accept,"PlaceFurniture" if accept else "CancelFurniture",actions)
 if not _placement_icons.has(accept):
  var path: String="M5 17 L13 25 L29 7" if accept else "M8 8 L24 24 M24 8 L8 24"
  var picture=Image.new()
  picture.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32"><path d="'+path+'" fill="none" stroke="white" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/></svg>',3.0)
  _placement_icons[accept]=ImageTexture.create_from_image(picture)
 button.icon=_placement_icons[accept]
 button.icon_alignment=HORIZONTAL_ALIGNMENT_LEFT
 button.add_theme_constant_override("icon_max_width",roundi(24*metrics.unit))
 button.add_theme_constant_override("h_separation",roundi(8*metrics.unit))
 button.autowrap_mode=TextServer.AUTOWRAP_OFF
 var color: Color=PlayfulTheme.INK
 for key in ["icon_normal_color","icon_hover_color","icon_pressed_color","icon_focus_color"]: button.add_theme_color_override(key,color)
 button.add_theme_color_override("icon_disabled_color",Color(color,0.35))
 button.accessibility_name="Place furniture" if accept else "Cancel placement"
 button.tooltip_text=button.accessibility_name
 return button

func _copy(text: String, color: Color=PlayfulTheme.SECONDARY_INK, parent: Node=null, size: int=16) -> Label:
 var label: Label=ui.canvas_paragraph(text,ceili(size*_font_scale),color); (parent if parent!=null else content).add_child(label); return label

func _alert_copy(text: String, parent: Node=null) -> Label:
 var alert=PanelContainer.new(); alert.name="BuildAlert"
 var alert_style=PlayfulTheme.panel(PlayfulTheme.ERROR_FILL,metrics.unit,14)
 alert_style.shadow_size=0; alert_style.content_margin_left=8*metrics.unit; alert_style.content_margin_right=8*metrics.unit
 alert_style.content_margin_top=6*metrics.unit; alert_style.content_margin_bottom=6*metrics.unit
 alert.add_theme_stylebox_override("panel",alert_style)
 (parent if parent!=null else content).add_child(alert)
 var row=HBoxContainer.new(); row.add_theme_constant_override("separation",roundi(8*metrics.unit)); alert.add_child(row)
 var badge=PanelContainer.new(); badge.custom_minimum_size=Vector2.ONE*24*metrics.unit; row.add_child(badge)
 var badge_style=PlayfulTheme.panel(PlayfulTheme.ERROR_INK,metrics.unit,12); badge_style.shadow_size=0
 badge_style.content_margin_left=0; badge_style.content_margin_right=0; badge_style.content_margin_top=0; badge_style.content_margin_bottom=0
 badge.add_theme_stylebox_override("panel",badge_style)
 var icon=ui.canvas_label("!",ceili(16*_font_scale),Color.WHITE); icon.name="BuildAlertIcon"; icon.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
 icon.vertical_alignment=VERTICAL_ALIGNMENT_CENTER; icon.accessibility_name="Error"; badge.add_child(icon)
 var label=ui.canvas_paragraph(text,ceili(14*_font_scale),PlayfulTheme.ERROR_INK); label.size_flags_horizontal=Control.SIZE_EXPAND_FILL; row.add_child(label)
 return label

func _rooms_content() -> void:
 _copy("Build anywhere. Tap furniture to move it, or browse for something new.")
 var row=HBoxContainer.new(); content.add_child(row)
 _button("Furniture",func(): tools_open=false; browse=true; _refresh(),true,"OpenCatalogue",row)
 _button("Hotel view",func(): selected_room=-1; session=null; focus_room(),false,"HotelView",row)
 for kind in ["regular","suite"]: _button("New %s · %s coins" % [kind,ui.number(Layout.cost(kind))],func(): begin_place(kind),false,"Build_"+kind)
 if not clipboard.is_empty(): _button("Paste "+str(clipboard.name),paste_room,true,"PasteRoom")
 _copy("Tap any room to copy its layout or move the whole room.")
 _button("Expand building",func(): _finish_close(); ui.open_expansions(app.model.wing_count(app.model.current_hotel)))
 if app.recovered_draft.get("ok",false):
  var old_quote: Dictionary=app.recovered_draft.session.quote(app.model)
  _button("Restore previous makeover · %d" % int(old_quote.cost_coins),_resume,false,"ResumeDraft")
 var sizes=HBoxContainer.new(); content.add_child(sizes)
 for scale in [1.0,1.25,1.5]: _button("%d%%" % int(scale*100),func(): app.change_setting("build_text_scale",scale); _resize(),false,"BuildText%d" % int(scale*100),sizes)

func _makeover_content() -> void:
 if session==null: return
 var before: Dictionary=Quality.summarize(app.model.furniture.room_items(session.hotel,session.room))
 var after: Dictionary=before
 if not ghost.is_empty():
  var definition: Dictionary=Catalog.item(ghost.item)
  var status_copy: String=transaction_error if transaction_error!="" else validity.get("message","Tap any floor to position.")
  status=_alert_copy(status_copy) if transaction_error!="" or not validity.get("ok",false) else _copy(status_copy,PlayfulTheme.INK)
  var tray=HBoxContainer.new(); tray.name="SelectedFurnitureTray"; tray.add_theme_constant_override("separation",roundi(10*metrics.unit)); content.add_child(tray)
  var thumbnail=Thumbnail.new(); thumbnail.name="SelectedFurnitureArt"; thumbnail.item_id=definition.id; thumbnail.custom_minimum_size=Vector2.ONE*72*metrics.unit; tray.add_child(thumbnail)
  var details=VBoxContainer.new(); details.size_flags_horizontal=Control.SIZE_EXPAND_FILL; details.add_theme_constant_override("separation",roundi(2*metrics.unit)); tray.add_child(details)
  _copy(definition.name,PlayfulTheme.INK,details,18)
  _copy(_preference_hint(definition),PlayfulTheme.SECONDARY_INK,details,14)
  _copy("%d × %d footprint" % [definition.footprint.x,definition.footprint.y],PlayfulTheme.SECONDARY_INK,details,14)
  placement_tools=HBoxContainer.new(); placement_tools.name="BuildPlacementTools"; placement_tools.add_theme_constant_override("separation",roundi(6*metrics.unit)); add_child(placement_tools)
  placement_tools.position=Vector2(panel.position.x,panel.position.y+panel.size.y-_target); placement_tools.size=Vector2(panel.size.x,_target)
  _button("↻  Rotate",rotate,false,"RotateFurniture",placement_tools)
  _button("✥  Adjust",func(): adjust_open=not adjust_open; _refresh(),false,"AdjustFurniture",placement_tools)
  if adjust_open:
   var nudges=GridContainer.new(); nudges.columns=4; nudges.name="FurnitureNudges"; content.add_child(nudges)
   for direction in [["←",Vector2i.LEFT],["↑",Vector2i.UP],["↓",Vector2i.DOWN],["→",Vector2i.RIGHT]]:
    _button(direction[0],func(): nudge(direction[1]),false,"Nudge"+str(direction[1]),nudges)
  if ghost_intent=="move": _button("Store object · Free",store_selected,false,"StoreFurniture")
  if validity.get("ok",false): after=Quality.summarize(_ghost_instances())
  _placement_button(false)
  confirm_button=_placement_button(true)
 else:
  _copy(_space_name(selected_room)+" · Saved")
  var row=HBoxContainer.new(); content.add_child(row)
  _button("Furniture",func(): browse=true; _refresh(),true,"OpenCatalogue",row)
  _button("Rooms",func(): tools_open=true; _refresh(),false,"RoomTools",row)
 var stats=preload("res://scripts/ui/build_room_stats.gd").new(); content.add_child(stats); stats.populate(ui,before,after,_font_scale,true)
 _copy("%s quality %d/100 · +%d coins/min" % ["Shared space" if selected_room==-2 else "Room",after.quality,after.income])
 if ghost.is_empty():
  if selected_room>=0:
   var row=HBoxContainer.new(); content.add_child(row)
   _button("Copy room",copy_room,false,"CopyRoom",row)
   _button("Move room",func(): begin_place(_room().kind,selected_room),false,"MoveRoom",row)
  if not clipboard.is_empty(): _button("Paste "+str(clipboard.name),paste_room,false,"PasteRoom")
  if selected_room>=0: _room_effects(session.instances)
  _copy("Objects here")
  for instance in session.instances: _button(Catalog.item(instance.item).name,func(): _select_object(instance.uid),false,"Select_"+str(instance.uid))
 else: _copy("Mix sleep, play and decoration. Repeated furniture adds less.")
 if not ghost.is_empty():
  var tool_space=Control.new(); tool_space.custom_minimum_size.y=_target+metrics.gap; content.add_child(tool_space)

func _space_name(room: int) -> String:
 return "Lobby & shared floor" if room==-2 else ("Room %02d" % (room+1) if room>=0 else "Hotel")

func _preference_hint(definition: Dictionary) -> String:
 for cat in range(app.Content.CAT_NAMES.size()):
  var preference: String=app.Content.PREFERENCES[cat]
  if app.model.life.known(cat) and definition.tags.has(preference):
   return "%s loves %s." % [app.Content.CAT_NAMES[cat],app.Content.PREFERENCE_COPY[preference]]
 return "Learn cat favorites to find the perfect guest match."

func _history_actions(parent: Node) -> void:
 _button("↶  Undo",func(): _history(false),false,"UndoBuild",parent).disabled=app.build_history.undo_steps==0
 _button("↷  Redo",func(): _history(true),false,"RedoBuild",parent).disabled=app.build_history.redo_steps==0

func _history(redo: bool) -> void:
 var result: Dictionary=app.undo_build(redo)
 if not result.ok: show_error(result.message); return
 _reset_session(); transaction_error=""; _refresh(); restore_preview()

func _other_rooms() -> void:
 cancel(); selected_room=-1; session=null; tools_open=true; _refresh(); focus_room()

func _catalogue_content() -> void:
 _copy("Pick a cozy piece, then tap any room or shared floor.",PlayfulTheme.INK)
 var tabs=GridContainer.new(); tabs.name="BuildCategoryGrid"; tabs.columns=2; tabs.add_theme_constant_override("h_separation",roundi(6*metrics.unit)); tabs.add_theme_constant_override("v_separation",roundi(6*metrics.unit)); content.add_child(tabs)
 for key in ["sleep","play","decor","storage"]: _button(key.capitalize(),func(): category=key; _refresh(),category==key,"Category_"+key,tabs)
 _button("Filters"+(" · On" if affordable or sort_by!="price" else ""),func(): set_filter_panel_visible(not filter_panel_visible),false,"ToggleBuildFilters")
 if filter_panel_visible:
  var filters=HBoxContainer.new(); filters.name="BuildFilters"; content.add_child(filters)
  _button("Affordable ✓" if affordable else "All prices",func(): affordable=not affordable; _refresh(),false,"AffordableFilter",filters)
  var sort_control=OptionButton.new(); sort_control.name="BuildSort"; sort_control.custom_minimum_size.y=_target; sort_control.add_theme_font_size_override("font_size",ceili(16*_font_scale))
  var sorts=["price","comfort","entertainment","atmosphere"]
  for key in sorts: sort_control.add_item(key.capitalize())
  sort_control.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  sort_control.select(sorts.find(sort_by)); sort_control.item_selected.connect(func(index): sort_by=sorts[index]; _refresh()); filters.add_child(sort_control)
 catalogue_view=preload("res://scripts/ui/build_catalogue.gd").new(); content.add_child(catalogue_view)
 catalogue_view.item_selected.connect(func(item,uid): preview_item(item,uid))
 catalogue_view.populate(ui,app.model,app.model.current_hotel,category,_target,_font_scale,affordable,sort_by,app.model.coins)
 _button("Rooms",func(): browse=false; tools_open=true; _refresh(),false,"RoomTools",actions)
 _button("Back",func(): browse=false; _refresh(),true,"CloseCatalogue",actions)

func set_filter_panel_visible(visible_value: bool) -> void:
 filter_panel_visible=visible_value
 if visible: _refresh()

func _review_content() -> void:
 pass # Kept only for compatibility with older saved draft callers.

func _resume() -> void:
 if not app.recovered_draft.get("ok",false): return
 var previous=app.recovered_draft.session
 var result: Dictionary=app.apply_build(previous)
 if not result.ok: show_error(result.message); return
 if previous.hotel==app.model.current_hotel: _select_room(previous.room)
 else: _refresh()

func _discard() -> void:
 app.discard_draft()

func _room() -> Dictionary:
 return _room_data(selected_room)

func _room_data(room: int) -> Dictionary:
 if room==-2: return Shared.data(app.model.hotels,app.model.current_hotel)
 var rooms: Array=Layout.entries(app.model,app.model.current_hotel)
 return rooms[room] if room>=0 and room<rooms.size() else {}

func _room_effects(instances: Array) -> void:
 var ids: Array=instances.map(func(value): return value.item)
 var combinations: Array=[]; var tags: Array=[]
 for combo in app.Content.COMBOS:
  if ids.has(combo.items[0]) and ids.has(combo.items[1]): combinations.append(combo.name+" +%d/min" % combo.bonus)
 if not combinations.is_empty(): _copy("Combinations: "+", ".join(combinations))
 for value in instances:
  for tag in Catalog.item(value.item).tags:
   if not tags.has(tag): tags.append(tag)
 var fit: Array=[]; var report: Dictionary=Quality.summarize(instances)
 for cat in range(app.Content.CAT_NAMES.size()):
  if app.model.life.known(cat): fit.append({"cat":cat,"score":Quality.guest_fit(report,tags,app.Content.PREFERENCES[cat])})
 fit.sort_custom(func(a,b): return a.score>b.score)
 var favorites: Array=[]
 for index in range(mini(2,fit.size())): favorites.append("%s %d/100" % [app.Content.CAT_NAMES[fit[index].cat],fit[index].score])
 _copy("Best guest fit: "+", ".join(favorites))
func _instance(uid: String) -> Dictionary:
 if session!=null:
  for value in session.instances:
   if value.uid==uid: return value.duplicate(true)
 return {}

func preview_item(id: String, uid: String="") -> void:
 if Catalog.item(id).is_empty(): return
 if session==null:
  selected_room=_space_at(app.world.camera_target)
  _reset_session()
 selected_item=id; selected_uid=uid; browse=false; tools_open=false; review=""; transaction_error=""; adjust_open=false
 ghost_intent="add" if uid.is_empty() else "place_stored"; source_room=-1
 ghost={"item":id,"uid":"draft:preview:0" if uid.is_empty() else uid,"hotel":session.hotel,"room":session.room,"x":0,"y":0,"rotation":0}
 var center: Vector2=Interior.world_to_local(_room(),app.world.camera_target)
 ghost.x=int(floor(center.x)); ghost.y=int(floor(center.y))
 if not Interior.validate(_room(),_ghost_instances(),false).ok:
  var found: bool=false; var dims: Vector2i=Interior.dimensions(_room().kind)
  for y in range(dims.y):
   for x in range(dims.x):
    ghost.x=x; ghost.y=y
    if Interior.validate(_room(),_ghost_instances(),false).ok: found=true; break
   if found: break
 _check_ghost(); _refresh()

func _space_at(point: Vector3) -> int:
 var rooms: Array=Layout.entries(app.model,app.model.current_hotel)
 for room in range(rooms.size()):
  var cell: Vector2=Interior.world_to_local(rooms[room],point)
  if Rect2(Vector2.ZERO,Vector2(Interior.dimensions(rooms[room].kind))).has_point(cell): return room
 return -2

func _select_object(uid: String) -> void:
 ghost=_instance(uid)
 if ghost.is_empty(): return
 selected_item=ghost.item; selected_uid=uid; ghost_intent="move"; source_room=selected_room; browse=false; tools_open=false; adjust_open=false
 _check_ghost(); _refresh()

func _ghost_instances() -> Array:
 var result: Array=[]
 for value in session.instances:
  if ghost_intent!="move" or value.uid!=ghost.uid: result.append(value.duplicate(true))
 result.append(ghost.duplicate(true)); return result

func _check_ghost() -> void:
 if ghost.is_empty() or session==null: return
 validity=Interior.validate(_room(),_ghost_instances(),false)
 var definition: Dictionary=Catalog.item(ghost.item)
 if validity.ok and ghost_intent=="move" and source_room!=selected_room:
  var source: Array=app.model.furniture.room_items(session.hotel,source_room).filter(func(value): return value.uid!=ghost.uid)
  validity=Interior.validate(_room_data(source_room),source,source_room>=0)
 if validity.ok and ghost_intent=="add":
  if app.model.hotel_level(session.hotel)<definition.level or (definition.bond>0 and not app.model.furniture.state.legacy_reuse.has(ghost.item)):
   validity={"ok":false,"message":"Friendship 20 gift" if definition.bond>0 else "Available at hotel level %d." % definition.level,"blocked":[]}
  elif app.model.coins_units<_ghost_cost()*app.model.UNIT:
   validity={"ok":false,"message":"Need %d more coins." % ceili(_ghost_cost()-app.model.coins),"blocked":[]}
 if validity.ok: validity.message="Ready to place · "+_space_name(selected_room)
 var renderer=app.world.room_builder.renderer(selected_room)
 if renderer!=null: renderer.show_ghost(_room(),ghost,validity)

func _ghost_cost() -> int:
 if ghost.is_empty() or ghost_intent!="add" or app.model.furniture.state.legacy_reuse.has(ghost.item): return 0
 return int(Catalog.item(ghost.item).cost)

func nudge(step: Vector2i) -> void:
 if ghost.is_empty(): return
 ghost.x+=step.x; ghost.y+=step.y; _check_ghost(); _refresh()
func rotate() -> void:
 if placing: candidate.rotation=(int(candidate.rotation)+1)%4; _update_validity(); _refresh()
 elif not ghost.is_empty(): ghost.rotation=(int(ghost.rotation)+1)%4; _check_ghost(); _refresh()
func store_selected() -> void:
 if ghost_intent!="move": return
 var target: int=source_room
 var edit=Session.new(); edit.begin(app.model,app.model.current_hotel,target,"%x-%x" % [Time.get_ticks_usec(),randi()])
 var result: Dictionary=edit.edit("store",{"uid":selected_uid})
 if result.ok: result=app.apply_build(edit)
 if result.ok: _edited()
 else: show_error(result.message)

func _edited() -> void:
 _clear_ghost()
 ghost={}; selected_item=""; selected_uid=""; transaction_error=""; chooser=[]; adjust_open=false
 _reset_session(); _refresh(); restore_preview()

func cancel() -> void:
 transaction_error=""
 if placing: placing=false; blueprint_placing=false; app.world.room_builder.clear_preview()
 _clear_ghost(); ghost={}; selected_item=""; selected_uid=""; review=""; adjust_open=false
 _refresh(); restore_preview()

func _clear_ghost() -> void:
 if selected_room!=-1:
  var renderer=app.world.room_builder.renderer(selected_room)
  if renderer!=null: renderer.clear_ghost(); renderer.clear_marker()

func confirm() -> void:
 transaction_error=""
 if placing:
  var payload: Dictionary=candidate.duplicate(true); payload.room=moving
  var result: Dictionary=app.paste_build(clipboard,candidate) if blueprint_placing else app.perform_layout("move_room" if moving>=0 else "place_room",payload)
  if not result.ok: show_error(result.message); return
  placing=false; blueprint_placing=false; app.world.room_builder.clear_preview(); _select_room(result.room); return
 if ghost.is_empty() or session==null: return
 _check_ghost()
 if not validity.get("ok",false): show_error(validity.get("message","Choose an open space.")); return
 var result: Dictionary
 if ghost_intent=="move" and source_room!=selected_room:
  result=app.transfer_build(source_room,selected_room,ghost)
 else:
  # One tap performs one saved edit; preview state never becomes a checkout.
  _reset_session()
  result=session.edit("transform" if ghost_intent=="move" else ghost_intent,ghost.duplicate(true))
  if result.ok: result=app.apply_build(session,_ghost_cost())
 if not result.ok:
  _reset_session(); show_error(result.message); return
 _edited()

func _apply() -> void:
 confirm()

func _update_action() -> void:
 if not is_instance_valid(confirm_button): return
 if placing:
  var price: int=blueprint_cost if blueprint_placing else (0 if moving>=0 else Layout.cost(candidate.kind))
  var room_caption: String="Paste · %s" % ui.number(price) if blueprint_placing else ("Move · Free" if moving>=0 else "Place · %s" % ui.number(price))
  confirm_button.text=room_caption
  confirm_button.accessibility_name=room_caption+" Cat Coins" if price>0 else room_caption
  confirm_button.disabled=not validity.get("ok",false) or app.model.coins<price
 elif not ghost.is_empty():
  _check_ghost()
  var cost: int=_ghost_cost()
  var caption: String="Move · Free" if ghost_intent=="move" else ("Place · Free" if cost==0 else "Place · %s" % ui.number(cost))
  confirm_button.text=caption
  confirm_button.accessibility_name=caption+" Cat Coins" if cost>0 else caption
  confirm_button.disabled=not validity.get("ok",false)
  confirm_button.accessibility_description="Saves this placement immediately." if validity.get("ok",false) else validity.get("message","Choose a valid position.")
  confirm_button.tooltip_text=confirm_button.accessibility_name if validity.get("ok",false) else confirm_button.accessibility_description

func show_error(message: String) -> void:
 transaction_error=message
 if visible: _refresh()

func begin_place(kind: String, room: int=-1) -> void:
 _clear_ghost(); app.world.room_builder.clear_draft(); app.world.edited_room=-1
 ghost={}; selected_item=""; moving=room; placing=true; browse=false; tools_open=false; blueprint_placing=false; adjust_open=false
 candidate=Layout.entries(app.model,app.model.current_hotel)[room].duplicate(true) if room>=0 else {"kind":kind,"x":0,"y":9,"rotation":0}
 if room<0:
  var found: bool=false
  for y in range(11,-1,-1):
   for x in range(10):
    candidate.x=x; candidate.y=y
    if Layout.validate(app.model,app.model.current_hotel,candidate).ok: found=true; break
   if found: break
 _update_validity(); _refresh(); focus_room()

func copy_room() -> void:
 if selected_room<0: return
 clipboard=Blueprint.capture(app.model,app.model.current_hotel,selected_room)
 if clipboard.is_empty(): return
 paste_room()

func paste_room() -> void:
 if clipboard.is_empty(): return
 begin_place(str(clipboard.kind))
 blueprint_placing=true; _update_validity(); _refresh()

func _room_placement() -> void:
 _copy("Paste "+str(clipboard.name) if blueprint_placing else ("Move room" if moving>=0 else "New "+str(candidate.kind)))
 _copy("Tap the floor to position. Keep the entrance connected to the lobby.")
 if blueprint_placing:
  var quote: Dictionary=Blueprint.quote(app.model,app.model.current_hotel,clipboard,candidate)
  _copy("Room %d + furniture %d = %d coins" % [quote.get("room_cost",0),quote.get("furniture_cost",0),quote.get("cost_coins",0)])
 var placement_message: String=transaction_error if transaction_error!="" else validity.get("message","")
 status=_alert_copy(placement_message) if transaction_error!="" or not validity.get("ok",false) else _copy(placement_message)
 _button("Rotate entrance ↻",rotate,false,"RotateRoom")
 var label: String="Paste · %d" % blueprint_cost if blueprint_placing else ("Move · Free" if moving>=0 else "Build · %d" % Layout.cost(candidate.kind))
 confirm_button=_button(label,confirm,true,"ConfirmRoom",actions)
 _button("Cancel",cancel,false,"CancelPlacement",actions)

func _update_validity() -> void:
 if blueprint_placing:
  validity=Blueprint.quote(app.model,app.model.current_hotel,clipboard,candidate)
  blueprint_cost=int(validity.get("cost_coins",0))
 else: validity=Layout.validate(app.model,app.model.current_hotel,candidate,moving)
 if blueprint_placing: app.world.room_builder.preview_blueprint(candidate,clipboard.items,validity.ok)
 else: app.world.room_builder.preview_room(candidate,validity.ok)

func input_context() -> Dictionary:
 var rect: Rect2=metrics.get("world_rect",Rect2())
 if is_instance_valid(panel) and not metrics.get("wide",false): rect.size.y=maxf(0,panel.position.y-rect.position.y-metrics.gap)
 var handle: Rect2=Rect2()
 if not ghost.is_empty() and ghost_intent=="move":
  var screen: Vector2=app.world.camera.unproject_position(Interior.local_to_world(_room(),Vector2(ghost.x,ghost.y)+Vector2(0.5,0.5)))
  handle=Rect2(screen-Vector2.ONE*_target*0.5,Vector2.ONE*_target)
 return {"world_rect":rect,"move_rect":handle,"ui_scale":Metrics.phone_scale(self),"mobile":OS.has_feature("mobile")}
func contains_world(point: Vector2) -> bool: return visible and input_context().world_rect.has_point(point)
func handle_command(command: Dictionary) -> void:
 match command.kind:
  "tap_world", "move_ghost": world_tapped(command.position)
  "pan": app.world._pan(command.relative)
  "zoom": app.world.camera.size=clampf(app.world.camera.size/maxf(0.01,command.factor),5,40); app.world._update_camera()
 queue_redraw()

func _draw() -> void:
 if not visible or ghost.is_empty() or ghost_intent!="move": return
 var context: Dictionary=input_context()
 var handle: Rect2=context.move_rect
 if not context.world_rect.has_point(handle.get_center()): return
 var center: Vector2=handle.get_center()
 var radius: float=_target*0.38
 var valid: bool=validity.get("ok",false)
 draw_circle(center,radius,Color("faf3e2") if valid else Color("f5c3b9"))
 draw_arc(center,radius,0,TAU,32,Color("537d67") if valid else Color("d95748"),2.0)
 var length: float=radius*0.58
 var ink: Color=Color("34594a") if valid else Color("9d322b")
 draw_line(center-Vector2(length,0),center+Vector2(length,0),ink,3)
 draw_line(center-Vector2(0,length),center+Vector2(0,length),ink,3)
func world_tapped(screen: Vector2) -> void:
 var camera: Camera3D=app.world.camera
 var point=Plane(Vector3.UP,0.24).intersects_ray(camera.project_ray_origin(screen),camera.project_ray_normal(screen))
 if point==null: return
 if placing:
  candidate.x=int(floor((point.x+5.5)/1.1)); candidate.y=int(floor((point.z+17.6)/1.1))
  _update_validity(); _refresh(); return
 var target: int=_space_at(point)
 if not ghost.is_empty():
  var changed_room: bool=target!=selected_room
  if changed_room:
   _clear_ghost(); selected_room=target; _reset_session(); ghost.room=target
  var cell: Vector2=Interior.world_to_local(_room(),point)
  ghost.x=int(floor(cell.x)); ghost.y=int(floor(cell.y)); _check_ghost()
  if changed_room: _refresh(); restore_preview()
  if is_instance_valid(status): status.text=validity.get("message","")
  _update_action(); queue_redraw(); return
 # Check every space before selecting a room.
 var hits: Array=[]
 for room in [-2]+range(app.model.room_count(app.model.current_hotel)):
  var renderer=app.world.room_builder.renderer(room)
  if renderer==null: continue
  for uid in renderer.pick(camera,screen): hits.append({"room":room,"uid":uid})
 if not hits.is_empty():
  var preferred: Array=hits.filter(func(hit): return hit.room==target)
  var hit: Dictionary=preferred[0] if not preferred.is_empty() else hits[0]
  _select_room(hit.room); _select_object(hit.uid); return
 _select_room(target)

func restore_preview() -> void:
 if not visible: return
 if placing: _update_validity()
 else:
  app.world.room_builder.clear_draft()
  app.world.edited_room=selected_room
  _check_ghost()
 app.world.room_builder.select_room(selected_room if not placing else -1)

func focus_room() -> void:
 if not visible or metrics.is_empty(): return
 var world=app.world; var point: Vector3=Vector3(0,0,-8.2)
 if placing: point=Layout.center(candidate)
 elif selected_room>=0: point=Layout.center(_room())
 elif selected_room==-2: point=Vector3(0,0,-1.8)
 var rect: Rect2=input_context().world_rect; var vp: Vector2=get_viewport_rect().size
 world.overview=false
 world.camera.size=maxf(7.2*vp.x/maxf(1,rect.size.x),5.3*vp.x/maxf(1,rect.size.y)) if selected_room>=0 and not placing else 20.0
 var offset: Vector2=rect.get_center()-vp*0.5; var up: Vector3=world.camera.global_basis.y
 var horizontal_up: Vector3=Vector3(up.x,0,up.z).normalized()
 world.camera_target=point-world.camera.global_basis.x*offset.x*world.camera.size/vp.x+horizontal_up*offset.y*world.camera.size/vp.x/maxf(0.1,Vector2(up.x,up.z).length())
 world.camera_target.y=0; world._update_camera()
