extends SceneTree

const Objects = preload("res://scripts/creative/creative_objects.gd")
const Content = preload("res://scripts/creative/creative_content.gd")
var failures: int = 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var shapes: Array[String] = ["fireplace","fountain","milkshake_counter","litter","box","scratch","tunnel","playpen","mat","plant","lamp","reception_counter"]
	for shape in shapes:
		var object: Node3D = Objects.make(Content.item(shape))
		root.add_child(object)
		var life: Node3D = object.get_node_or_null("LifeMotion")
		check(life != null,shape+" exposes the furniture life API")
		check(life.has_method("set_activity") and life.has_method("set_motion_enabled") and life.has_method("set_effects_visible") and life.has_method("set_phase_seed"),shape+" exposes all motion controls")
		object.free()

	var hearth: Node3D = Objects.make(Content.item("fireplace")); root.add_child(hearth)
	var fire = hearth.get_node("LifeMotion")
	check(fire.effect_capacity("embers")<=8,"Hearth ember batch is bounded")
	check(fire.visible_effect_count("flames")==3 and fire.flame_height(0)>0.0,"A new hearth has a meaningful static flame before its first process frame")
	var still_flame: Transform3D=fire.effect_transform("flames",0)
	fire.set_motion_enabled(false)
	check(fire.visible_effect_count("flames")==3 and fire.visible_effect_count("embers")==0 and fire.effect_transform("flames",0)==still_flame,"Starting with motion disabled preserves frozen flames and hides embers")
	fire.set_motion_enabled(true)
	fire._process(0.01)
	var flame_before: float = fire.flame_height(0)
	fire._process(0.31)
	check(not is_equal_approx(flame_before,fire.flame_height(0)),"Hearth voxel flames change height")
	check(fire.visible_effect_count("embers")<=8,"Hearth reuses at most eight ember cubes")
	fire.set_motion_enabled(false)
	check(fire.visible_effect_count("embers")==0,"Disabling motion hides hearth bursts")
	hearth.free()

	var fountain: Node3D = Objects.make(Content.item("fountain")); root.add_child(fountain)
	var fountain_life = fountain.get_node("LifeMotion")
	check(fountain.get_node("VoxelSpillways").multimesh.instance_count==56,"Fountain retains exactly 56 spillway cubes")
	check(fountain_life.effect_capacity("spout")>0,"Fountain has a distinct central spout")
	check(fountain_life.effect_capacity("splash")<=12,"Fountain splash batch is bounded")
	check(fountain_life.effect_node("spout") != fountain_life.effect_node("splash"),"Spout and splash use separate batches")
	fountain.free()

	var shake_a: Node3D = Objects.make(Content.item("milkshake_counter")); root.add_child(shake_a)
	var shake_b: Node3D = Objects.make(Content.item("milkshake_counter")); root.add_child(shake_b)
	var life_a = shake_a.get_node("LifeMotion"); var life_b = shake_b.get_node("LifeMotion")
	check(life_a.actual_part_kind()=="MilkshakeMachine" and life_a.actual_part_cube_count()==2,"Milkshake animation owns the two authored machine cubes")
	var root_rest: Transform3D = shake_a.transform
	var rest_a: Transform3D = life_a.actual_part_node().transform
	life_a.set_activity("serve",0.0,"server-a"); life_a._process(0.18)
	check(life_a.actual_part_node().transform!=rest_a,"The authored milkshake machine churns while serving")
	check(shake_a.transform==root_rest,"Milkshake counter root remains stable while its machine churns")
	check(absf(life_a.effect_position("foam",0).x-life_a.part_effect_anchor().x)<0.10,"Foam stays anchored to the authored milkshake machine")
	check(life_b.part_transform()==life_b.rest_part_transform(),"Multiple counters animate independently")
	life_a.set_activity("",0.0,"")
	check(life_a.part_transform()==rest_a,"Milkshake machine returns to rest")
	shake_a.free(); shake_b.free()

	var litter: Node3D = Objects.make(Content.item("litter")); root.add_child(litter)
	var litter_life = litter.get_node("LifeMotion")
	litter_life.set_activity("dig",2.0,"cat-a")
	check(litter_life.burst_count==0,"Rebuilt litter does not replay old dig markers")
	litter_life.set_activity("dig",2.31,"cat-a")
	check(litter_life.burst_count==1 and litter_life.visible_effect_count("burst")<=12,"Litter emits one bounded synchronized digging burst")
	var litter_start: Vector3 = litter_life.effect_position("burst",0)
	litter_life.set_activity("dig",2.55,"cat-a"); litter_life._process(0.01)
	check(litter_life.effect_position("burst",0)!=litter_start,"Litter cubes move outward and upward during a burst")
	litter_life.set_activity("dig",2.90,"cat-a"); litter_life._process(0.01)
	check(litter_life.visible_effect_count("burst")==0,"Litter burst expires and returns its batch to hidden rest")
	litter_life.set_effects_visible(false)
	litter_life.set_activity("dig",3.6,"cat-a")
	litter_life.set_effects_visible(true)
	check(litter_life.burst_count==1,"Hidden litter effects retain time without catching up")
	litter.free()

	var paused_litter: Node3D = Objects.make(Content.item("litter")); root.add_child(paused_litter)
	var paused_life = paused_litter.get_node("LifeMotion")
	paused_life.set_activity("dig",1.0,"paused-cat")
	paused_life.set_activity("dig",1.11,"paused-cat")
	check(paused_life.visible_effect_count("burst")==12,"Pause regression begins during a visible litter burst")
	paused_life.set_motion_enabled(false)
	paused_life.set_effects_visible(true)
	paused_life.set_activity("dig",1.30,"paused-cat")
	check(paused_life.visible_effect_count("burst")==0 and paused_life.burst_count==1,"World activity updates cannot resurrect litter while motion is disabled")
	paused_litter.free()

	var cancelled_litter: Node3D = Objects.make(Content.item("litter")); root.add_child(cancelled_litter)
	var cancelled_life = cancelled_litter.get_node("LifeMotion")
	cancelled_life.set_activity("dig",1.0,"cancel-cat")
	cancelled_life.set_activity("dig",1.11,"cancel-cat")
	check(cancelled_life.visible_effect_count("burst")==12,"Cancellation regression begins with an active dig burst")
	cancelled_life.set_activity("",0.0,"")
	cancelled_life._process(0.2)
	check(cancelled_life.visible_effect_count("burst")==0,"Ending dig cancels its burst permanently")
	cancelled_litter.free()

	var box_object: Node3D = Objects.make(Content.item("box")); root.add_child(box_object)
	var box_life = box_object.get_node("LifeMotion")
	check(box_life.actual_part_kind()=="BoxFlap" and box_life.actual_part_cube_count()==1,"Box motion owns the full authored flap")
	box_life.set_activity("peek",0.0,"cat-b"); box_life._process(0.2)
	check(box_life.actual_part_node().transform!=box_life.rest_part_transform(),"Authored delivery box flap reacts to peek")
	box_life.set_motion_enabled(false)
	check(box_life.part_transform()==box_life.rest_part_transform(),"Motion disable restores moving parts")
	box_object.free()

	var authored_cases: Array = [
		["scratch","ScratchRope",7,"scratch"],
		["tunnel","PlayToy",1,"play"],
		["playpen","PlayToy",1,"play"],
		["mat","BedCushion",45,"knead"],
		["cloud_sofa","Cushions",3,"rest"],
		["reception_counter","ReceptionBell",1,"greet"],
	]
	for entry in authored_cases:
		var furniture: Node3D = Objects.make(Content.item(entry[0])); root.add_child(furniture)
		var motion = furniture.get_node("LifeMotion")
		check(motion.actual_part_kind()==entry[1] and motion.actual_part_cube_count()>=entry[2],entry[0]+" extracts its recognizable authored part")
		var authored_rest: Transform3D = motion.actual_part_node().transform
		motion.set_activity(entry[3],0.0,"actor"); motion._process(0.21)
		check(motion.actual_part_node().transform!=authored_rest,entry[0]+" moves the extracted authored part")
		motion.set_motion_enabled(false)
		check(motion.actual_part_node().transform==authored_rest,entry[0]+" restores its authored part when motion is disabled")
		furniture.free()

	for ambient_case in [["plant","Foliage",20],["lamp","LanternGlow",1]]:
		var ambient: Node3D = Objects.make(Content.item(ambient_case[0])); root.add_child(ambient)
		var ambient_motion = ambient.get_node("LifeMotion")
		check(ambient_motion.actual_part_kind()==ambient_case[1] and ambient_motion.actual_part_cube_count()>=ambient_case[2],ambient_case[0]+" extracts its authored ambient geometry")
		var ambient_rest: Transform3D = ambient_motion.actual_part_node().transform
		ambient_motion._process(0.37)
		check(ambient_motion.actual_part_node().transform!=ambient_rest,ambient_case[0]+" animates the extracted authored geometry")
		ambient.free()

	var sleep_bed: Node3D = Objects.make(Content.item("mat")); root.add_child(sleep_bed)
	var sleep_motion = sleep_bed.get_node("LifeMotion")
	sleep_motion.set_activity("sleep",0.0,"sleeping-cat")
	check(is_equal_approx(sleep_motion.actual_part_node().scale.y,0.965) and not sleep_motion.is_processing(),"Sleep uses a stable shallow cushion dip")
	sleep_motion.set_activity("knead",0.0,"kneading-cat"); sleep_motion._process(0.22)
	check(sleep_motion.actual_part_node().scale.y>=0.95,"Kneading cushion motion stays shallow beneath the cat")
	sleep_bed.free()

	var still_table: Node3D = Objects.make(Content.item("table")); root.add_child(still_table)
	check(not still_table.get_node("LifeMotion").is_processing(),"Unsupported static furniture does not process")
	still_table.free()

	var phase_a: Node3D = Objects.make(Content.item("plant")); root.add_child(phase_a)
	var phase_b: Node3D = Objects.make(Content.item("plant")); root.add_child(phase_b)
	phase_a.get_node("LifeMotion").set_phase_seed(17)
	phase_b.get_node("LifeMotion").set_phase_seed(901)
	phase_a.get_node("LifeMotion")._process(0.2); phase_b.get_node("LifeMotion")._process(0.2)
	check(phase_a.get_node("LifePart").transform!=phase_b.get_node("LifePart").transform,"Stable phase seeds stagger ambient furniture motion")
	phase_a.free(); phase_b.free()

	print("CREATIVE OBJECT MOTION: %d failures" % failures)
	quit(1 if failures else 0)
