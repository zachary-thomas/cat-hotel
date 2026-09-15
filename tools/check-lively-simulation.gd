extends SceneTree
const Model=preload("res://scripts/creative/creative_model.gd")
func _initialize() -> void:
	for hotel in range(4):
		var model=Model.new(); model.new_game(1000); model.state.current_hotel=hotel
		var first: float=-1.0
		var samples: Array=[]
		var previous: int=0
		for step in range(2400):
			model.advance(0.1)
			if model.social.moments.serial!=previous:
				previous=model.social.moments.serial
				if first<0: first=float(step)/10.0
				samples.append({"time":float(step)/10.0,"topic":model.social.moments.active.get("topic",""),"cats":model.social.moments.active.get("participants",[])})
		print("LIVELY MAP %d: first %.1fs, %d exchanges, %d guests, %d visits; %s" % [hotel,first,previous,model.social.agents.size(),model.hotel().visits,str(samples)])
	quit()
