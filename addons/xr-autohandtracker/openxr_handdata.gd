extends Node

func _ready():
	var autohands = get_tree().get_nodes_in_group("AutoHandGroup")
	print("**** trackerws")
	print(XRServer.get_trackers(127))
	await get_tree().create_timer(5).timeout
	print("**** trackerws2")
	print(XRServer.get_trackers(127))
	
