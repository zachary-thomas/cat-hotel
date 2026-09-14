extends RefCounted
## Local avoidance shared by guests, staff and outdoor cats. All checks use world
## coordinates so cats under amenity roots still see the rest of the hotel.
const GROUP = &"navigating_cats"
const BODY_RADIUS: float = 0.60
const GAP: float = 0.06
const STEP: float = 0.10

static func radius(cat: Node3D) -> float:
	return BODY_RADIUS * maxf(cat.global_basis.x.length(),cat.global_basis.z.length())

static func neighbors(cat: Node3D) -> Array:
	var result: Array = []
	if not cat.is_inside_tree():
		return result
	for other in cat.get_tree().get_nodes_in_group(GROUP):
		if other != cat and not other.is_queued_for_deletion() and other.is_visible_in_tree() and other.get_world_3d() == cat.get_world_3d():
			result.append(other)
	return result

static func same_height(cat: Node3D, point: Vector3, other: Node3D) -> bool:
	var bottom: float = point.y + 0.12 * cat.global_basis.y.length()
	var top: float = point.y + 0.95 * cat.global_basis.y.length()
	var other_bottom: float = other.global_position.y + 0.12 * other.global_basis.y.length()
	var other_top: float = other.global_position.y + 0.95 * other.global_basis.y.length()
	return bottom < other_top and other_bottom < top

static func clear_at(cat: Node3D, point: Vector3, peers: Array) -> bool:
	for other in peers:
		if same_height(cat,point,other):
			var distance := Vector2(point.x-other.global_position.x,point.z-other.global_position.z)
			if distance.length() < radius(cat) + radius(other) + GAP:
				return false
	return true

static func place(cat: Node3D, local_point: Vector3) -> void:
	if not cat.is_inside_tree():
		cat.position = local_point
		return
	var desired: Vector3 = cat.get_parent_node_3d().to_global(local_point)
	var peers: Array = neighbors(cat)
	if clear_at(cat,desired,peers):
		cat.global_position = desired
		return
	# Placement is explicit (spawn, room move, reunion); never push resting cats.
	for ring in range(1,25):
		var distance: float = ring * 0.20
		for slot in range(16):
			var angle: float = slot * TAU / 16.0
			var candidate: Vector3 = desired + Vector3(sin(angle),0,cos(angle)) * distance
			if clear_at(cat,candidate,peers):
				cat.global_position = candidate
				return

static func move(cat: Node3D, local_target: Vector3, distance: float, guard: Callable = Callable()) -> bool:
	if distance <= 0.0 or not cat.is_visible_in_tree():
		return false
	var target: Vector3 = cat.get_parent_node_3d().to_global(local_target)
	var start: Vector3 = cat.global_position
	var peers: Array = neighbors(cat)
	var remaining: float = distance
	# Bound each move as well as checking its entire swept path. A slow frame
	# cannot leap through another cat and emerge clear on the other side.
	while remaining > 0.00001:
		var point: Vector3 = cat.global_position
		var offset: Vector3 = target-point
		if offset.length() < 0.001:
			break
		var step: float = minf(STEP,minf(remaining,offset.length()))
		var forward := Vector2(offset.x,offset.z).normalized()
		var steer: Vector2 = forward
		var target_occupied: bool = false
		for other in peers:
			var clearance: float = radius(cat)+radius(other)+GAP
			var resting: bool = not other.moving or not other.motion_enabled or other.reaction != ""
			if resting and same_height(cat,target,other) and Vector2(target.x-other.global_position.x,target.z-other.global_position.z).length() < clearance and offset.length() < clearance+0.5:
				target_occupied = true
				break
		if not target_occupied:
			for other in peers:
				if not same_height(cat,point,other):
					continue
				var relative := Vector2(other.global_position.x-point.x,other.global_position.z-point.z)
				var ahead: float = relative.dot(forward)
				var clearance: float = radius(cat)+radius(other)+GAP
				if ahead > 0.0 and ahead < clearance+0.9 and absf(relative.cross(forward)) < clearance+0.12:
					# Keep right for both cats: their opposite headings give opposite
					# passing lanes, avoiding the left/right oscillation of repulsion.
					steer += Vector2(-forward.y,forward.x) * (1.0-ahead/(clearance+0.9)) * 3.0
		var direction := Vector3(steer.x,0,steer.y).normalized()
		if offset.length() > 0.0:
			direction = (direction * Vector2(offset.x,offset.z).length() + Vector3(0,offset.y,0)).normalized()
		var candidate: Vector3 = point + direction * step
		if not clear_move(cat,point,candidate,peers) or (guard.is_valid() and not guard.call(point,candidate)):
			var found: bool = false
			if not target_occupied:
				for angle in [PI/3.0,PI/2.0]:
					var sideways: Vector2 = forward.rotated(angle)
					candidate = point + Vector3(sideways.x,0,sideways.y) * step
					if clear_move(cat,point,candidate,peers) and (not guard.is_valid() or guard.call(point,candidate)):
						found = true
						break
			if not found:
				break
		cat.global_position = candidate
		remaining -= step
	return cat.global_position.distance_squared_to(start) > 0.00000001

static func clear_move(cat: Node3D, start: Vector3, finish: Vector3, peers: Array) -> bool:
	var segment := Vector2(finish.x-start.x,finish.z-start.z)
	for other in peers:
		var relative := Vector2(other.global_position.x-start.x,other.global_position.z-start.z)
		var t: float = clampf(relative.dot(segment)/segment.length_squared(),0.0,1.0) if segment.length_squared() > 0.0 else 0.0
		if not same_height(cat,start.lerp(finish,t),other) and not same_height(cat,start,other) and not same_height(cat,finish,other):
			continue
		var clearance: float = radius(cat)+radius(other)+GAP
		if (relative-segment*t).length() < clearance:
			return false
	return true
