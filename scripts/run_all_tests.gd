extends SceneTree

## Master Test Runner for Pixel Porter.
## Executes all unit tests, integration tests, and level verification pipelines headless.
## Usage:
##   godot --headless --path . -s scripts/run_all_tests.gd

const TEST_SCRIPTS: Array[String] = [
	"tests/test_grid_logic.gd",
	"tests/test_save_manager.gd",
	"tests/test_solver.gd",
	"tests/test_audio_manager.gd",
	"tests/test_main_menu.gd",
	"tests/test_localization.gd",
	"tests/test_game_scene.gd",
	"tests/test_ad_manager.gd",
	"tests/test_end_screen.gd",
	"tests/test_haptic_manager.gd",
	"tests/test_safe_area_manager.gd",
	"tests/test_splash_screen.gd",
	"tests/test_achievement_manager.gd",
	"tests/test_game_feel.gd",
	"tests/test_hint_performance.gd",
	"tests/test_level3_hint_deadlock.gd",
	"tests/test_live_star_tracker.gd",
	"tests/test_non_square_framing.gd",
	"tests/test_terminal_console_ui.gd",
	"tests/test_visual_atmosphere.gd",
	"scripts/verify_levels.gd"
]


func _init() -> void:
	print("\n" + "=".repeat(64))
	print("       PIXEL PORTER - COMPREHENSIVE TEST RUNNER        ")
	print("=".repeat(64) + "\n")

	var godot_bin: String = OS.get_executable_path()
	var total_tests: int = TEST_SCRIPTS.size()
	var passed_count: int = 0
	var failed_count: int = 0
	var results: Array[Dictionary] = []

	var start_all_time: int = Time.get_ticks_msec()

	for i in range(total_tests):
		var test_path: String = TEST_SCRIPTS[i]
		print("[%d/%d] Running %s ..." % [i + 1, total_tests, test_path])

		var output: Array = []
		var t0: int = Time.get_ticks_msec()
		var exit_code: int = OS.execute(godot_bin, ["--headless", "--path", ".", "-s", test_path], output, true)
		var elapsed_ms: int = Time.get_ticks_msec() - t0

		var stdout_text: String = output[0] if output.size() > 0 else ""
		var is_success: bool = (exit_code == 0)

		if is_success:
			passed_count += 1
			print("       -> PASS (%d ms)" % elapsed_ms)
		else:
			failed_count += 1
			print("       -> FAIL (Exit Code: %d, %d ms)" % [exit_code, elapsed_ms])
			print("--- Output from %s ---" % test_path)
			print(stdout_text)
			print("--- End Output ---")

		results.append({
			"script": test_path,
			"passed": is_success,
			"exit_code": exit_code,
			"time_ms": elapsed_ms
		})

	var total_elapsed_ms: int = Time.get_ticks_msec() - start_all_time

	print("\n" + "=".repeat(64))
	print("                    SUMMARY REPORT                     ")
	print("=".repeat(64))
	for res in results:
		var status_icon: String = "✓ PASS" if res["passed"] else "✗ FAIL"
		print("  %-36s | %-6s | %5d ms" % [res["script"], status_icon, res["time_ms"]])

	print("-".repeat(64))
	print("Suites Executed: %d | Passed: %d | Failed: %d" % [total_tests, passed_count, failed_count])
	print("Total Duration : %.2f seconds" % (total_elapsed_ms / 1000.0))
	print("=".repeat(64) + "\n")

	if failed_count > 0:
		print("STATUS: FAILED - One or more test suites failed.\n")
		quit(1)
	else:
		print("STATUS: SUCCESS - All test suites and solver verifications passed!\n")
		quit(0)
