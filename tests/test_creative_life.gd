extends SceneTree
const Model=preload("res://scripts/creative/creative_model.gd")
const World=preload("res://scripts/creative/creative_world.gd")
var failures:=0
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var model=Model.new(); model.new_game(1000)
	model.hotel().rooms.clear(); model.hotel().objects.clear()
	for entry in [["bar_a","milkshake_counter",-4,0],["bar_b","milkshake_counter",1,0],["tray","litter",0,4]]:
		model.hotel().objects.append({"id":entry[0],"item":entry[1],"room":"","x":entry[2],"y":entry[3],"rotation":0,"paid":0})
	model._invalidate()
	var world=World.new(); root.add_child(world); world.setup(model)
	if world.get("life")==null:
		check(false,"The active hotel must connect real service state to furniture effects")
		world.free(); quit(1); return
	root.size=Vector2i(1280,800); root.content_scale_size=root.size
	world.set_world_rect(Rect2(0,0,1280,800)); world.focus_bounds(Rect2(-6,-3,13,12))
	model.social.agents.clear()
	model.social.agents[0]={"cat":0,"name":"Miso","position":Vector2(-3,2),"phase":"serve","action":"wait","venue":"bar_a","time":2.0,"drink":false,"life_elapsed":0.5,"life_token":"a1","checked_in":true,"velocity":Vector2.ZERO}
	world._sync_actors(0.01); world.life.update(0.01)
	var a=world.object_nodes.bar_a.get_node("LifeMotion")
	var b=world.object_nodes.bar_b.get_node("LifeMotion")
	check(a.action=="serve" and b.action=="","Only the counter actually serving a guest runs its blender")
	model.social.agents[0].phase="activity"; model.social.agents[0].action="drink"; model.social.agents[0].drink=true
	model.social.agents[1]={"cat":1,"name":"Clover","position":Vector2(-4,2),"phase":"serve","action":"wait","venue":"bar_a","activity_venue":"bar_a","time":2.0,"drink":false,"life_elapsed":0.2,"life_token":"a2","checked_in":true,"velocity":Vector2.ZERO}
	model.social.agents[2]={"cat":2,"name":"Juniper","position":Vector2(2,2),"phase":"serve","action":"wait","venue":"bar_b","activity_venue":"bar_b","time":2.0,"drink":false,"life_elapsed":0.2,"life_token":"b1","checked_in":true,"velocity":Vector2.ZERO}
	world._sync_actors(0.01); world.life.update(0.01)
	check(a.action=="serve" and b.action=="serve","Serving wins over a lower-ID drinker and two counters remain independent")
	model.social.agents[1].phase="activity"; model.social.agents[1].action="drink"; model.social.agents[1].drink=true
	world._sync_actors(0.01); world.life.update(0.01)
	check(a.action=="drink" and b.action=="serve","Completing one overlapping order stops only its own blender")
	model.social.agents[2].phase="idle"; model.social.agents[2].action="rest"; model.social.agents[2].drink=false
	world._sync_actors(0.01); world.life.update(0.01)
	check(b.action=="","Cancelling the final order stops its counter")
	model.social.agents.erase(1); model.social.agents.erase(2)
	model.social.agents[0].phase="walk_seat"; model.social.agents[0].action="walk"
	world._sync_actors(0.01); world.life.update(0.01)
	check(a.action=="","Leaving service stops the old counter")
	model.social.agents[0].phase="activity"; model.social.agents[0].action="dig"; model.social.agents[0].venue="tray"; model.social.agents[0].life_token="dig1"; model.social.agents[0].life_elapsed=0.4
	world._sync_actors(0.01); world.life.update(0.01)
	var tray=world.object_nodes.tray.get_node("LifeMotion")
	var count: int=tray.burst_count
	model.social.agents[0].life_elapsed=1.2
	world._sync_actors(0.01); world.life.update(0.01)
	check(tray.burst_count==count+1 and world.actors[0].social_pose=="dig","A real digging marker drives both litter particles and cat paws")
	world.life.update(0.01)
	check(tray.burst_count==count+1,"Repeated world updates do not duplicate litter bursts")
	world.set_life_context(false,false); world.life.update(0.01)
	check(not tray.motion_enabled and not world.life.speech.visible,"Pausing the app stops decorative motion and hides speech")
	world.set_life_context(true,false); world.life.update(0.01)
	check(not world.life.speech.visible,"Building suppresses dialogue")
	model.state.settings.motion=false; world.apply_visual_settings(); world.life.update(0.01)
	check(not tray.motion_enabled and not world.actors[0].motion_enabled,"Existing motion setting reaches both objects and cats")
	model.state.settings.motion=true; world.apply_visual_settings(); world.set_life_context(true,true); model.social.moments.cancel()
	# Exercise the actual bridge for a natural order and its counter attendant reply.
	model.state.time=20.0
	model.social.agents[0]={"cat":0,"name":"Miso","position":Vector2(-3,2),"phase":"order","action":"order","venue":"bar_a","activity_venue":"bar_a","time":2.0,"drink":false,"life_elapsed":0.1,"life_token":"order-1","checked_in":true,"velocity":Vector2.ZERO}
	model.social.agents[2001]={"cat":2001,"name":"Saffron","position":Vector2(-4,1),"phase":"service","action":"work","role":"bar","venue":"bar_a","life_elapsed":4.0,"life_token":"staff-work","velocity":Vector2.ZERO}
	world._sync_actors(0.01); world.life.update(0.01)
	check(String(world.life._service_line.get("text",""))=="One shake, please!" and int(world.life._service_line.get("speaker",-1))==0,"A real order starts with the local guest")
	model.state.time=22.05; model.social.agents[0].phase="serve"; model.social.agents[0].action="wait"; model.social.agents[0].life_token="serve-1"; model.social.agents[2001].action="serve"; model.social.agents[2001].life_token="staff-serve"
	world.life.update(0.01)
	check(String(world.life._service_line.get("text",""))=="Coming right up!" and int(world.life._service_line.get("speaker",-1))==2001,"The actual attendant replies inside the same exchange despite ambient cooldown")
	# Removal cancels an exchange and can never synthesize a handoff.
	model.state.time=30.0; world.life._service_line.clear(); world.life._service_exchange.clear(); world.life._service_next=0.0
	model.social.agents[0].phase="order"; model.social.agents[0].action="order"; model.social.agents[0].drink=false; model.social.agents[0].life_token="cancel-order"
	world.life.update(0.01); model.social.agents.erase(0); model.state.time=32.1; world.life.update(0.01)
	check(world.life._service_exchange.is_empty() and not world.life._service.has("bar_a"),"Removing an ordering guest cancels its reply without a false handoff")
	# Only an observed serve-to-drink transition produces the brief handoff.
	model.social.agents[3]={"cat":3,"name":"Poppy","position":Vector2(-3,2),"phase":"serve","action":"wait","venue":"bar_a","activity_venue":"bar_a","time":0.1,"drink":false,"life_elapsed":2.7,"life_token":"serve-ok","checked_in":true,"velocity":Vector2.ZERO}
	model.state.time=40.0; world._sync_actors(0.01); world.life.update(0.01)
	model.social.agents[3].phase="activity"; model.social.agents[3].action="drink"; model.social.agents[3].drink=true; model.social.agents[3].life_token="drink-ok"; model.social.agents[2001].action="work"; model.social.agents[2001].life_elapsed=0.1; model.social.agents[2001].life_token="staff-work-2"; model.state.time=40.1
	world._sync_actors(0.01); world.life.update(0.01)
	check(world.life._service.has("bar_a") and world.actors[2001].social_pose=="handoff","A completed drink produces one short attendant handoff")
	model.revision+=1; world.sync(); world.life.update(0.01)
	check(world.object_nodes.tray.get_node("LifeMotion").burst_count==0,"Rebuilding the world halfway through digging does not replay old puffs")
	world.free(); print("CREATIVE LIFE: %d failures" % failures); quit(1 if failures else 0)
