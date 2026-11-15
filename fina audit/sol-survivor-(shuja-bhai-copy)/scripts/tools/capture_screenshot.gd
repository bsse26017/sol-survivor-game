extends SceneTree

func _init() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	_capture()

func _capture() -> void:
	# Wait for scene to mount
	for i in 5:
		await process_frame
		
	var main := root.get_node_or_null("Main")
	if main:
		var title := main.get_node_or_null("TitleScreen")
		if title: title.visible = false
		var intro := main.get_node_or_null("IntroSequence")
		if intro: intro.visible = false
		GameManager.start_game()

	# Wait for rendering to complete
	for i in 25:
		await process_frame

	var img := root.get_viewport().get_texture().get_image()
	img.save_png("screenshot_ingame.png")
	print("Captured screenshot_ingame.png successfully!")
	quit()
