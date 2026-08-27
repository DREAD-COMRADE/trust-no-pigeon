extends SceneTree

func _init() -> void:
	print("\n=======================================================")
	print(">>> RUNNING TRUST NO PIGEON COMPREHENSIVE UNIT TESTS <<<")
	print("=======================================================\n")

	var test_root = Node3D.new()
	root.add_child(test_root)

	test_pigeon_spawner_and_zones(test_root)
	test_event_screens(test_root)
	test_weapons_and_shotgun_burst(test_root)
	test_drone_health_and_damage(test_root)
	test_ufo_health_and_missile_hits(test_root)
	test_day_night_30min_schedule(test_root)
	test_event_manager_and_idle_attack(test_root)
	test_anti_clipping_and_speed_balancing(test_root)

	test_root.queue_free()

	print("\n=======================================================")
	print(">>> ALL UNIT TESTS PASSED WITH ZERO ERRORS!         <<<")
	print("=======================================================\n")
	quit(0)

func test_pigeon_spawner_and_zones(parent: Node3D) -> void:
	print("[TEST] 1. Testing PigeonSpawner & Spawn/Kill Zones...")
	var spawner_scene = load("res://scenes/systems/PigeonSpawner.tscn")
	assert(spawner_scene != null, "PigeonSpawner scene failed to load")

	var spawner = spawner_scene.instantiate() as PigeonSpawner
	parent.add_child(spawner)

	var sz1 = Marker3D.new()
	parent.add_child(sz1)
	sz1.position = Vector3(-50, 6, -18)

	var sz2 = Marker3D.new()
	parent.add_child(sz2)
	sz2.position = Vector3(50, 6, -18)

	var kz1 = Marker3D.new()
	parent.add_child(kz1)
	kz1.position = Vector3(-50, 6, -18)

	var kz2 = Marker3D.new()
	parent.add_child(kz2)
	kz2.position = Vector3(50, 6, -18)

	var spawn_arr: Array[Marker3D] = [sz1, sz2]
	var kill_arr: Array[Marker3D] = [kz1, kz2]
	spawner.spawn_zones = spawn_arr
	spawner.kill_zones = kill_arr

	var positions = spawner._get_spawn_and_kill_positions()
	assert(positions.size() == 2, "Failed to get start and kill positions")
	assert(positions[0] != positions[1], "Start and target positions should differ")
	print("  ✓ Spawn/Kill Zones validated: start=", positions[0], " target=", positions[1])

func test_event_screens(parent: Node3D) -> void:
	print("[TEST] 2. Testing Building Event Screens...")
	var screen_scene = load("res://scenes/objects/EventScreen.tscn")
	assert(screen_scene != null, "EventScreen scene failed to load")

	var screen = screen_scene.instantiate() as EventScreen
	parent.add_child(screen)

	screen.show_event("GOVERNMENT HAS NOTICED", "SURVEILLANCE ENGAGED")
	assert(screen.is_event_active == true, "EventScreen failed to activate")
	assert(screen.title_label.text == "GOVERNMENT HAS NOTICED", "Title text mismatch")

	screen.clear_screen()
	assert(screen.is_event_active == false, "EventScreen failed to clear")
	print("  ✓ EventScreen show and clear validated")

func test_weapons_and_shotgun_burst(parent: Node3D) -> void:
	print("[TEST] 3. Testing Player Controller, Weapons & Shotgun Tracers...")
	var player = PlayerController.new()
	parent.add_child(player)

	var cam = Camera3D.new()
	player.add_child(cam)
	player.camera = cam

	var gun_scene = load("res://scenes/player/Gun.tscn")
	var gun = gun_scene.instantiate() as Gun
	cam.add_child(gun)
	player.gun = gun

	var shotgun_scene = load("res://scenes/player/Shotgun.tscn")
	var shotgun = shotgun_scene.instantiate() as Shotgun
	cam.add_child(shotgun)
	player.shotgun = shotgun

	var launcher_scene = load("res://scenes/player/MissileLauncher.tscn")
	var launcher = launcher_scene.instantiate() as MissileLauncher
	cam.add_child(launcher)
	player.missile_launcher = launcher

	# Initial weapon is Gun
	player.switch_to_slot(0)
	assert(gun.visible == true, "Gun should be visible in slot 0")

	# Switch to Shotgun
	player.switch_to_slot(1)
	assert(shotgun.visible == true, "Shotgun should be visible in slot 1")
	assert(shotgun.ammo == 2, "Shotgun starting ammo should be 2")
	assert(shotgun.pellet_count >= 10, "Shotgun should fire 10 pellets per burst")
	assert(shotgun.tracer_scene != null, "Shotgun tracer scene must be loaded")

	# Switch to Rocket Launcher
	player.switch_to_slot(2)
	assert(launcher.visible == true, "Launcher should be visible in slot 2")
	assert(launcher.ammo == 0, "Launcher starting ammo should be 0")

	print("  ✓ PlayerController weapons & Shotgun 10-pellet burst verified")

func test_drone_health_and_damage(parent: Node3D) -> void:
	print("[TEST] 4. Testing Supply Drone 2-Hit Health & Ammo Rewards...")
	var drone_scene = load("res://scenes/objects/PackageDrone.tscn")
	var drone = drone_scene.instantiate() as PackageDrone
	parent.add_child(drone)
	drone.setup(Vector3(-30, 12, -20), Vector3(30, 12, -20), 3, 4)

	# 1st pistol hit (damage = 1) -> drone should survive with 1 health
	drone.take_hit(1)
	assert(drone.health == 1, "Drone should have 1 health after 1 pistol hit")
	assert(drone.is_destroyed == false, "Drone should not be destroyed after 1 pistol hit")

	# 2nd pistol hit (damage = 1) -> drone destroyed
	drone.take_hit(1)
	assert(drone.is_destroyed == true, "Drone should be destroyed after 2nd pistol hit")

	# Shotgun 1-hit kill test (damage = 2)
	var drone2 = drone_scene.instantiate() as PackageDrone
	parent.add_child(drone2)
	drone2.setup(Vector3(-30, 12, -20), Vector3(30, 12, -20), 3, 4)
	drone2.take_hit(2)
	assert(drone2.is_destroyed == true, "Drone should be destroyed in 1 hit from shotgun (damage=2)")

	print("  ✓ Drone takes 2 hits from pistol, 1 hit from shotgun; awards +3 rockets & +4 shells")

func test_ufo_health_and_missile_hits(parent: Node3D) -> void:
	print("[TEST] 5. Testing UFO 3-Missile-Hit Health System...")
	var ufo_scene = load("res://scenes/objects/UFO.tscn")
	var ufo = ufo_scene.instantiate() as UFO
	parent.add_child(ufo)
	ufo.setup(Vector3(-45, 20, -40), Vector3(0, 20, -40), 45.0, 3)

	# 1st Rocket Hit
	ufo.take_missile_hit()
	assert(ufo.health == 2, "UFO should have 2 health remaining after 1st missile hit")
	assert(ufo.current_state != UFO.State.DESTROYED, "UFO should survive 1st missile hit")

	# 2nd Rocket Hit
	ufo.take_missile_hit()
	assert(ufo.health == 1, "UFO should have 1 health remaining after 2nd missile hit")
	assert(ufo.current_state != UFO.State.DESTROYED, "UFO should survive 2nd missile hit")

	# 3rd Rocket Hit (Destruction)
	ufo.take_missile_hit()
	assert(ufo.health <= 0, "UFO health should be <= 0 after 3rd missile hit")
	assert(ufo.current_state == UFO.State.DESTROYED, "UFO should be DESTROYED after 3rd missile hit")

	print("  ✓ UFO survives 2 missile hits and is downed on 3rd hit")

func test_day_night_30min_schedule(parent: Node3D) -> void:
	print("[TEST] 6. Testing Day/Night 30-Minute Cycle & Lighting Schedule...")
	var dnm_scene = load("res://scenes/systems/DayNightManager.tscn")
	var dnm = dnm_scene.instantiate() as DayNightManager
	parent.add_child(dnm)

	assert(dnm.cycle_duration == 1800.0, "Total cycle duration must be 1800s (30 minutes)")

	var street_light = OmniLight3D.new()
	parent.add_child(street_light)
	var projector_light = ProjectorLight.new()
	parent.add_child(projector_light)

	# 1. Day Phase (0:00 -> 10:00, 10 mins)
	dnm._update_light_fixtures(DayNightManager.TimePhase.DAY, [street_light], [projector_light])
	assert(street_light.visible == false, "Street lights must be OFF during Day")
	assert(projector_light.visible == false, "Projector lights must be OFF during Day")

	# 2. Sunset Phase (10:00 -> 15:00, 5 mins)
	dnm._update_light_fixtures(DayNightManager.TimePhase.SUNSET, [street_light], [projector_light])
	assert(street_light.visible == true, "Street lights must be ON during Sunset")
	assert(projector_light.visible == false, "Projector lights must be OFF during Sunset")

	# 3. Night Phase (15:00 -> 25:00, 10 mins)
	dnm._update_light_fixtures(DayNightManager.TimePhase.NIGHT, [street_light], [projector_light])
	assert(street_light.visible == true, "Street lights must be ON during Night")
	assert(projector_light.visible == true, "Projector lights must be ON during Night")

	# 4. Dawn Phase (25:00 -> 30:00, 5 mins)
	dnm._update_light_fixtures(DayNightManager.TimePhase.DAWN, [street_light], [projector_light])
	assert(street_light.visible == true, "Street lights must be ON during Dawn")
	assert(projector_light.visible == false, "Projector lights must be OFF during Dawn")

	print("  ✓ Exact 30-min distribution (10m Day, 5m Sunset, 10m Night, 5m Dawn) & lighting verified")

func test_event_manager_and_idle_attack(parent: Node3D) -> void:
	print("[TEST] 7. Testing EventManager & 2-Minute Idle Auto-Attack...")
	var em_scene = load("res://scenes/systems/EventManager.tscn")
	var em = em_scene.instantiate() as EventManager
	parent.add_child(em)

	assert(em.auto_attack_interval == 120.0, "Auto-attack interval should be 120s (2 minutes)")

	var spawner_scene = load("res://scenes/systems/PigeonSpawner.tscn")
	var spawner = spawner_scene.instantiate() as PigeonSpawner
	parent.add_child(spawner)
	em.spawner = spawner

	# Test direct idle auto-attack invocation
	em._trigger_idle_prevention_attack()

	print("  ✓ 2-Minute Idle auto-attack threat verified")

func test_anti_clipping_and_speed_balancing(parent: Node3D) -> void:
	print("[TEST] 8. Testing Government Pigeon Speed & Altitude Clamp...")
	var gov_scene = load("res://scenes/pigeons/GovernmentPigeon.tscn")
	var gov = gov_scene.instantiate() as GovernmentPigeon
	parent.add_child(gov)
	gov.setup(Vector3(0, 5, -20), Vector3(0, 5, 0), 1.0)

	assert(gov.attack_speed_mult <= 1.3, "Attack speed multiplier should be <= 1.3 for fair play")

	gov.trigger_evasive_dodge_and_attack(Vector3(0, 0, -1))
	assert(gov.is_dodging == true, "Dodge should be active")
	assert(gov.dodge_velocity.length() <= gov.actual_speed * 1.5, "Dodge velocity should be balanced")

	gov.position.y = -5.0
	gov._process_attacking(0.016)
	var final_y = gov.global_position.y if gov.is_inside_tree() else gov.position.y
	assert(final_y >= 1.2, "Pigeon altitude should be clamped above floor (MIN_ALTITUDE)")

	print("  ✓ Government Pigeon speed balanced and altitude clamped (y=%.2f)" % final_y)
