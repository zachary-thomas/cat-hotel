extends SceneTree
const Cat = preload("res://scripts/world/voxel_cat.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var cat=Cat.new(); root.add_child(cat); cat.build(Color("d99c51"))
	if not cat.has_method("set_social_pose"):
		check(false,"Cats need coordinated speaking and listening poses"); cat.free(); quit(1); return
	var at: Vector3=cat.position
	cat.set_social_pose("wave",0.4); cat._process(0.01)
	check(absf(cat.legs[1].rotation.x)>0.3,"Greeting visibly lifts a front paw")
	cat.set_social_pose("talk",0.6); cat._process(0.01)
	check(absf(cat.head.rotation.y)>0.01,"Speaking moves the face toward a partner")
	check(cat.position==at,"Gestures never move the collision root")
	cat.set_social_pose("dig",1.15); cat._process(0.01)
	check(absf(cat.legs[0].rotation.x)>0.1,"A litter kick has a visible paw pose at its burst marker")
	cat.motion_enabled=false; cat._process(0.1)
	var pose: Transform3D=cat.body.transform
	cat.set_social_pose("happy",1.0); cat._process(0.5)
	check(cat.body.transform==pose,"Reduced motion leaves a steady resting body")
	cat.motion_enabled=true; cat.set_social_pose("",0); cat.action="walk"; cat.moving=true; cat._process(0.1)
	check(cat.social_pose=="" and cat.position==at,"Clearing a gesture restores ordinary walking without teleporting")
	cat.free(); print("CREATIVE GESTURES: %d failures" % failures); quit(1 if failures else 0)
