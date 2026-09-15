extends RefCounted
## Short authored exchanges. The simulation chooses context; rendering never writes dialogue.
const EXCHANGES: Array = [
	["sunbeam","sunny","I saved you a sunbeam.","The warm bit?","Obviously."],
	["sun_toes","sunny","My toes are solar powered.","Mine need another charge."],
	["sun_cloud","sunny","That cloud stole my spot.","I'll keep an eye on it."],
	["sun_share","sunny","Room for one more?","Always room for your paws."],
	["sun_schedule","sunny","Busy afternoon?","Sunbeam. Nap. Repeat."],
	["nap_minutes","quiet","Five more minutes.","You said that three naps ago."],
	["nap_practice","quiet","I've been practicing naps.","Your hard work is showing."],
	["nap_dream","quiet","I dreamed of a giant pillow.","Was there room for me?","I saved the soft side."],
	["nap_contest","quiet","Who can nap the longest?","I'll sleep on it."],
	["nap_whisper","quiet","Is this the quiet corner?","Shh. The cushions are sleeping."],
	["snack_foam","food","Extra foam, please!","One cloud in a cup."],
	["snack_whiskers","food","You've got foam on your nose.","I'm saving it for later."],
	["snack_flavor","food","What's your favorite flavor?","The next one."],
	["snack_share","food","Want a sip?","Just a whiskerful."],
	["snack_menu","food","I studied the whole menu.","Very important research."],
	["play_box","play","I found a magnificent castle.","Is it the box again?","It has excellent walls."],
	["play_tail","play","Your tail is following you.","It's my little assistant."],
	["play_pounce","play","Watch my mighty pounce!","I'll be the cheering section."],
	["play_tunnel","play","I explored the tunnel.","What did you discover?","The other end!"],
	["play_toy","play","That toy looked at me funny.","Better give it a gentle boop."],
	["water_catch","fountain","I almost caught the water.","Try asking it to stay."],
	["water_paws","fountain","The fountain clapped for me.","Those were little splashes."],
	["water_ripple","fountain","Look! Tiny water circles.","Maybe it's drawing us a hug."],
	["water_sing","fountain","The water knows a song.","Plip, plop, purr."],
	["water_mirror","fountain","There's a cat in the water.","Very handsome. Looks like you."],
	["warm_toes","warm","My paws are getting toasty.","Save a little warmth for me."],
	["warm_sparks","warm","Look at those tiny stars.","The fire is feeling fancy."],
	["friend_seat","social","This seat felt lonely.","Good thing I brought my paws."],
	["friend_day","social","Best part of your day?","This little bit with you."],
	["friend_hello","social","Hello, favorite neighbor.","Hello, excellent whiskers."],
	["friend_adventure","explore","Shall we go exploring?","After a very small nap."],
	["friend_leaf","explore","I found a leaf shaped like a paw.","The garden is a fan of ours."]
]

static func choose(topic: String, recent: Array, seed_value: int) -> Dictionary:
	var choices: Array = []
	for row in EXCHANGES:
		if String(row[1])==topic and not recent.has(row[0]): choices.append(row)
	if choices.is_empty():
		for row in EXCHANGES:
			if String(row[1])=="social" and not recent.has(row[0]): choices.append(row)
	if choices.is_empty(): return {}
	var selected: Array = choices[posmod(seed_value,choices.size())]
	var lines: Array = []
	for i in range(2,selected.size()):
		lines.append({"role":(i-2)%2,"text":String(selected[i]),"gesture":"happy" if i==selected.size()-1 else "talk","duration":3.1})
	return {"id":String(selected[0]),"topic":String(selected[1]),"lines":lines}
