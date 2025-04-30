extends Node3D

func _ready():
	var manim : Animation = ResourceLoader.load("res://data/manimrec.anim")
	var danim : Animation = Animation.new()
	danim.length = manim.length
	danim.loop_mode = manim.loop_mode
	for i in range(manim.get_track_count()):
		var x = String(manim.track_get_path(i))
		var x2 = manim.track_get_type(i)
		if int(x) == XRBodyTracker.JOINT_HEAD:
			print([x[0], int(x), x2])
			var j = danim.add_track(x2)
			danim.track_set_path(j, ":Head")
			for k in range(manim.track_get_key_count(i)):
				var t = manim.track_get_key_time(j, k)
				var v = manim.track_get_key_value(j, k)
				danim.track_insert_key(j, t, v)

	var animlibrary : AnimationLibrary = $AnimationPlayer.get_animation_library("dreclibrary")
	animlibrary.add_animation("danim", danim)
	$AnimationPlayer.active = true
	$AnimationPlayer.play("dreclibrary/danim")
		
