extends SceneTree

const ARTIFACT_DIR := "/home/snowz/.gemini/antigravity/brain/db19d3e6-5897-4bec-b12d-4a1222e63add"

func _init() -> void:
	DisplayServer.window_set_size(Vector2i(450, 960))
	DisplayServer.warp_mouse(Vector2i(-200, -200))
	call_deferred("_run")

func _run() -> void:
	var main_scene = load("res://scenes/main_menu.tscn")
	var menu = main_scene.instantiate()
	root.add_child(menu)

	# Populate save data matching user's exact state: ~195 stars
	if menu.save_mgr:
		# Complete first 65 levels with 3 stars = 195 stars
		for i in range(65):
			menu.save_mgr.record_level_completion(i, 12, 3)
		menu.save_mgr.last_played_level = 2
		# Claim all unlocked star vaults so modal doesn't block the view
		for v_idx in range(12):
			menu.save_mgr.claim_star_vault(v_idx)

	menu._update_menu_state()
	menu._show_main_view()
	for i in range(10):
		DisplayServer.warp_mouse(Vector2i(-200, -200))
		await process_frame

	var main_img = root.get_texture().get_image()
	if main_img != null:
		var out_main = ARTIFACT_DIR + "/main_menu_branded.png"
		main_img.save_png(out_main)
		print("Saved main menu: ", out_main)

	# Show level select view
	menu._show_level_select()
	menu._hide_star_vault_modal()

	# Force scroll to top so we capture the Campaign Manifest & Sector Navigation Deck
	var scroll_cnt = menu.find_child("Scroll", true, false) as ScrollContainer
	if scroll_cnt:
		scroll_cnt.scroll_vertical = 0

	# Wait a few frames for layout pass and animations to settle
	for i in range(15):
		DisplayServer.warp_mouse(Vector2i(-200, -200))
		if scroll_cnt:
			scroll_cnt.scroll_vertical = 0
		await process_frame

	# Take capture of top overview (Campaign Manifest, Sector Nav Deck, Sector 1 Cargo Bay)
	var img = root.get_texture().get_image()
	if img != null:
		var out_path = ARTIFACT_DIR + "/level_select_manifest.png"
		var err = img.save_png(out_path)
		print("Saved top manifest: ", out_path, " err=", err)

	# Scroll to Sector 2 Cold Storage and capture
	print("Before click, scroll_vertical=", scroll_cnt.scroll_vertical)
	var btn15 = menu.level_grid.get_child(15)
	print("level_grid pos=", menu.level_grid.position, " btn15 pos=", btn15.position)
	menu._on_sector_tab_pressed(1)
	for i in range(30):
		DisplayServer.warp_mouse(Vector2i(-200, -200))
		await process_frame
	print("After click, scroll_vertical=", scroll_cnt.scroll_vertical)

	var img2 = root.get_texture().get_image()
	if img2 != null:
		var out_path2 = ARTIFACT_DIR + "/level_select_cold_storage.png"
		var err2 = img2.save_png(out_path2)
		print("Saved cold storage: ", out_path2, " err=", err2)

	# Scroll to Sector 4 Quantum Vault and capture
	menu._on_sector_tab_pressed(3)
	for i in range(30):
		DisplayServer.warp_mouse(Vector2i(-200, -200))
		await process_frame

	var img3 = root.get_texture().get_image()
	if img3 != null:
		var out_path3 = ARTIFACT_DIR + "/level_select_quantum_vault.png"
		var err3 = img3.save_png(out_path3)
		print("Saved quantum vault: ", out_path3, " err=", err3)

	quit()
