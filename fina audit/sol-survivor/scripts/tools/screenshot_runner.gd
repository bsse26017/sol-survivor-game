extends Node

func _ready() -> void:
	_capture_all()

func _capture_all() -> void:
	var main_packed: PackedScene = load("res://scenes/main.tscn")
	var main: Node = main_packed.instantiate()
	add_child(main)

	# 1. Title Screen
	for i in 12:
		await get_tree().process_frame
	var img1 := get_viewport().get_texture().get_image()
	img1.save_png("screenshots/1_title_screen.png")
	print("Saved screenshots/1_title_screen.png")

	# 2. Spawn View (dismiss title screen, start Sol 1)
	var title: CanvasLayer = main.get_node("TitleScreen")
	title.visible = false
	var intro: CanvasLayer = main.get_node("IntroSequence")
	intro.visible = false
	GameManager.start_game()

	for i in 20:
		await get_tree().process_frame
	var img2 := get_viewport().get_texture().get_image()
	img2.save_png("screenshots/2_spawn_view.png")
	print("Saved screenshots/2_spawn_view.png")

	# 3. HUD Close-up
	var vp_size := get_viewport().get_visible_rect().size
	# Crop top-left O2 pill and Sol/Objective header
	var w: int = int(vp_size.x)
	var h: int = int(vp_size.y * 0.45)
	var img3 := img2.get_region(Rect2i(0, 0, w, h))
	img3.save_png("screenshots/3_hud_closeup.png")
	print("Saved screenshots/3_hud_closeup.png")

	# 4. Event Card
	var sd: Resource = GameManager.get_current_sol_data()
	if sd and "event" in sd and sd.event:
		GameManager.show_event.emit(sd.event)
	for i in 15:
		await get_tree().process_frame
	var img4 := get_viewport().get_texture().get_image()
	img4.save_png("screenshots/4_event_card.png")
	print("Saved screenshots/4_event_card.png")

	# 5. Night Summary
	var event_card: CanvasLayer = main.get_node("EventCard")
	event_card.visible = false
	var fact: String = sd.night_fact if (sd and "night_fact" in sd) else "Mars fact"
	var src: String = sd.night_fact_source if (sd and "night_fact_source" in sd) else "NASA"
	GameManager.show_night_summary.emit(1, fact, src)
	for i in 15:
		await get_tree().process_frame
	var img5 := get_viewport().get_texture().get_image()
	img5.save_png("screenshots/5_night_summary.png")
	print("Saved screenshots/5_night_summary.png")

	print("ALL_DONE_SCREENSHOTS")
	get_tree().quit()
