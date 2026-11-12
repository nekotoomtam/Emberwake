extends Node3D
## A playable, bounded combat trial: pixel bodies, independently weighted blade.
const ReadyRules=preload("res://scripts/weapon_ready.gd")
const ReadyPose=preload("res://scripts/ready_pose.gd")
const ReadyVisual=preload("res://scripts/ready_visual.gd")
var readiness=ReadyRules.new()
var anatomy=preload("res://scripts/anatomy_state.gd").new()
var flasks=preload("res://scripts/health_flask.gd").new()
var anatomy_panel
var body_lab_open:=false
var _crawl_still:=.25
var _body_key:=""
const CharacterStats = preload("res://scripts/character_stats.gd")
var stats=preload("res://data/player_base_stats.tres").duplicate(true)
var energy=preload("res://scripts/stamina_rules.gd").new()
var combat_rng:=RandomNumberGenerator.new()
var _pair_aimed:=false
var _shot_aimed:=false
var _dodge_step_protected:=false
var rewards=preload("res://scripts/combat_rewards.gd").new()
var vision
var ready_visual
var shot_rng:=RandomNumberGenerator.new()
var _primary_specs: Dictionary={}
const RiflePose=preload("res://scripts/rifle_action_pose.gd")
const RifleMotion = preload("res://scripts/rifle_motion.gd")
const StaffMotion = preload("res://scripts/staff_motion.gd")
const StaffGroundSpells = preload("res://scripts/staff_ground_spells.gd")
const ReloadVisual = preload("res://scripts/reload_visual.gd")
const DualHandVisual = preload("res://scripts/dual_hand_visual.gd")
const PairedStrikes = preload("res://scripts/paired_strikes.gd")
const InventoryModel = preload("res://scripts/loadout_inventory.gd")
const ArsenalUI = preload("res://scripts/arsenal_ui.gd")
const Motion = preload("res://scripts/weapon_motion.gd")
const TwinCut = preload("res://scripts/twin_cut_motion.gd")
const ArmorPierce = preload("res://scripts/armor_pierce_motion.gd")
const SwordSkillMotion = preload("res://scripts/sword_skill_motion.gd")
const SwordMotion = preload("res://scripts/sword_motion.gd")
const MaceSkillMotion = preload("res://scripts/mace_skill_motion.gd")
const MaceGroundEffects = preload("res://scripts/mace_ground_effects.gd")
const MaceImpactVisual = preload("res://scripts/mace_impact_visual.gd")
const MaceFireLobs = preload("res://scripts/mace_fire_lobs.gd")
const MaceRiftVisual = preload("res://scripts/mace_rift_visual.gd")
const MaceSweepVisual = preload("res://scripts/mace_sweep_visual.gd")
const SkillTags = preload("res://scripts/skill_tags.gd")
const SwordSkillUI = preload("res://scripts/sword_skill_ui.gd")
const Hero = preload("res://scripts/hero_visual.gd")
var use_cutout_avatar := false
var expedition_starting_flasks := -1
const ExpeditionRoster = preload("res://scripts/opening/expedition_roster.gd")
var expedition_recruit_id := ""
const Talents = preload("res://scripts/character_talents.gd")
const TALENT_REWARD_ROOMS := 3
var _talent_rng := RandomNumberGenerator.new()
var _last_talent_reward_room := 0
var expedition_leader_talents: Dictionary = {}
var expedition_leader_attributes: Dictionary = {}
var expedition_companions: Array[Dictionary] = []
const Companion = preload("res://scripts/expedition_companion.gd")
const FRIENDLY_FIRE_FRACTION := .20
var companions: Array[Companion] = []
const REVIVE_DURATION := 1.5
var revive_target: Companion
var revive_elapsed := 0.0
var dungeon_peek = preload("res://scripts/dungeon_peek.gd").new()
var party_mark_target: Node3D
var party_mark_point := Vector3.INF
var party_mark_left := 0.0
var party_mark_marker: Label3D
const Captain = preload("res://scripts/captain.gd")
const BeachArena=preload("res://scripts/beach_arena.gd")
const CoastalEnemy=preload("res://scripts/coastal_enemy.gd")
const EnemyImageHurt=preload("res://scripts/enemy_image_hurt.gd")
const FishermanEnemy=preload("res://scripts/fisherman_enemy.gd")
const BrinehoundEnemy=preload("res://scripts/brinehound_enemy.gd")
const CrewmanEnemy=preload("res://scripts/crewman_enemy.gd")
const SpitterEnemy=preload("res://scripts/spitter_enemy.gd")
const NetHaulerEnemy=preload("res://scripts/net_hauler_enemy.gd")
const CoastalRoster=preload("res://scripts/coastal_roster.gd")
const CoastEncounter=preload("res://scripts/coast_encounter.gd")
const DungeonRun=preload("res://scripts/dungeon_run.gd")
const DungeonRoom=preload("res://scripts/dungeon_room.gd")
var coast=CoastEncounter.new()
var dungeon=DungeonRun.new()
var _coast_mode:=false
const HarborArena = preload("res://scripts/harbor_arena.gd")
var encounter_mode: String=""
var _harbor_mode:=false
const Enemy = preload("res://scripts/enemy.gd")
const Arena = preload("res://scripts/arena.gd")
const Effects = preload("res://scripts/effects.gd")
const HUD = preload("res://scripts/hud.gd")
const Audio = preload("res://scripts/audio.gd")
const ShortLunge = preload("res://scripts/short_lunge.gd")
const AttackStep = preload("res://scripts/attack_step.gd")
const MeleeApproach = preload("res://scripts/melee_approach.gd")
const StaffFlight = preload("res://scripts/staff_projectiles.gd")
const RifleCycle=preload("res://scripts/rifle_cycle.gd")
const Magazine = preload("res://scripts/magazine.gd")
const CasingFX = preload("res://scripts/casing_fx.gd")

var staff_energy=preload("res://scripts/staff_charge.gd").new()
var _staff_ground := StaffGroundSpells.new()
var _staff_charge_slot := -1
var _staff_charge_skill := StaffMotion.CHARGED_FIRE_ID
var _staff_breath_slot := -1
var _staff_breath_ticks := 0
var _staff_breath_elapsed := 0.0
var _staff_breath_angle := 0.0
var _staff_breath_bonus := Vector2.ONE
var staff_orbs
var status_icons
var pistol_aim_state=preload("res://scripts/pistol_aim.gd").new()
var pistol_reticle
var rifle_scope
var _shot_spread:=0.0
var _pistol_shot_bonus:=0.0
const DualRules=preload("res://scripts/dual_wield_rules.gd")
var rifle_focus_state=preload("res://scripts/rifle_focus.gd").new()
var ground_fire
var brine_zones
var _staff_committing:=false

var reload_visual = ReloadVisual.new()
var pair_strikes = PairedStrikes.new()
var loadout = InventoryModel.new()
var arsenal
var inventory_open := false
var stats_open:=false
var stats_panel
var loadout_mode := false
var active_item := ""
var pending_set := -1
var _loadout_attack_index := 0
var item_magazines: Dictionary = {}
var dual_visual

var player: CharacterBody3D
var camera: Camera3D
var avatar: Node3D
var arena: Node3D
var fx: Node3D
var ui: CanvasLayer
var _room_fade: Tween
var _room_shade: ColorRect
var audio: Node
var enemies: Array = []
var projectiles: Array[Dictionary] = []
var _enemy_tick_phase:=false
var _crowd_neighbors=preload("res://scripts/crowd_neighbors.gd").new()
var _crowd_index_active:=false
var stagger_distant_ai:=true
var motion = Motion.new()
var _basic_motion = motion
var _skill_motion = TwinCut.new()
var _armor_motion = ArmorPierce.new()
var active_skill_id: String = ""
var _skill_generation: int = 0
var armor_lunge_travelled: float = 0.0
var _armor_lunge = ShortLunge.new()
var skill_active := false
var skill_cut_index := -1
var _sword_skill_motion = SwordSkillMotion.new()
var _mace_skill_motion = MaceSkillMotion.new()
var _mace_ground := MaceGroundEffects.new()
var mace_fire_lobs: MaceFireLobs
var mace_fire_buff_left := 0.0
var _mace_fire_lift_damage := 0.0
var _mace_fire_blast_damage := 0.0
var _mace_fire_next_side := 0
var _mace_charge_slot := -1
var _mace_parried_attacker_id := 0
var _mace_leap_offset := Vector3.ZERO
var _mace_impact_flash: Sprite3D
var _mace_fire_scoop_flash: Sprite3D
const MACE_CHARGE_WALK_SPEED := 4.7 * .35
var _sword_skill_lunge = ShortLunge.new()
const STORM_STEP_DISTANCE := 0.80
const STORM_STEP_DURATION := 0.14
var _storm_step_direction := Vector3.ZERO
var _storm_step_start := 0.0
var _sword_stance_branch := -1
var sword_skill_cooldowns: Dictionary = {}
var sword_wave_buff_left := 0.0
var _storm_blade_item := ""
var _storm_blade_wave_damage := Vector3.ZERO
var _storm_blade_wave_speed := 1.0
var _storm_blade_single_swing := false
var sword_skills_open := false
var sword_skill_ui
var weapon_family: String = "sword"
var staff_flight: Node3D
var pistol_magazine = Magazine.new()
var rifle_magazine = RifleCycle.new()
var _rifle_pending_fire:=false
var _rifle_target_origin := Vector3.INF
var _rifle_target_ray := Vector3.ZERO
var _rifle_release_height := INF
var casing_fx: Node3D
var rifle_recoil_travelled := 0.0
var _rifle_recoil = ShortLunge.new()
var _rifle_retreat_distance := 0.0
const BOW_MEDIUM_TIME := 0.34
const BOW_FULL_TIME := 0.82
const BOW_RETREAT_TIME := 0.16
const BOW_RETREAT_DISTANCE := 1.12
const BOW_SHOTS := [
	{"damage": 12.0, "projectile_range": 4.0, "projectile_speed": 13.0},
	{"damage": 23.0, "projectile_range": 7.5, "projectile_speed": 19.0},
	{"damage": 37.0, "projectile_range": 11.5, "projectile_speed": 25.0},
]
var bow_charge := -1.0
var _bow_recovery := 0.0
var _bow_shot_direction := Vector3.ZERO
var _bow_retreat = ShortLunge.new()
var _crossbow_magazines: Dictionary = {}
var _crossbow_loading
const CROSSBOW_RELOAD_TIME := 1.05
const CROSSBOW_WOUND_TICKS := 4
var mace_dash_travelled: float = 0.0
var _short_lunge = ShortLunge.new()
var attack_step_travelled: float = 0.0
var _attack_step = AttackStep.new()
var melee_approach_plan: Dictionary = {}
var _melee_approach = MeleeApproach.new()
var mode: String = "menu"
var wave: int = 0
var kills: int = 0
var hits: int = 0
const SANITY_REVELATION := 100
const FRENZY_THRESHOLD := ExpeditionRoster.FINAL_STAND_THRESHOLD
const STAND_UP_SANITY := ExpeditionRoster.STAND_UP_SANITY
const STAND_UP_HEALTH := ExpeditionRoster.STAND_UP_HEALTH
var sanity := 0
var frenzy := false
var _sanity_marked := false
var character_lost := false
var _mode_before_fall := "combat"
var health: float = 100.0
var mana: float = stats.value("max_mana")
var stamina: float = 100.0
var total_damage: float = 0.0
var run_time: float = 0.0
var move_input := Vector2.ZERO
var arrival_motion := Vector3.ZERO
var _arrival_locked := false
var test_aim := Vector3.ZERO
var aim := Vector3.RIGHT
var debug_range: bool = false
var _held: bool = false
var _practice: bool = true
var village_zoom:=21.0
var drill_kind: String=""
var _next_combo: int = 0
var _idle_time: float = 0.0
var _dummy_idle: float = 0.0
var _hit_stop: float = 0.0
var _hit_targets: Dictionary = {}
var _double_slash_first_hits: Dictionary = {}
var _hurt: float = 0.0
var _iframes: float = 0.0
var _dodge_left: float = 0.0
var _dodge_dir := Vector3.RIGHT
var _dodge_facing := Vector3.RIGHT
const DashVisual=preload("res://scripts/dash_visual.gd")
var _dodge_recharge: float = 0.0
var _shake: float = 0.0
var _wave_wait: float = 0.0
var _previous_mode: String = "practice"
var _camera_focus := Vector3.ZERO
var _range_clock: float = 0.0
var _trail_clock: float = 0.0
var _in_physics_tick := false
var _pending_presentation := 0.0
var _mouse_position := Vector2.ZERO
const CAMERA_OFFSET := Vector3(0, 12.5, 11.5)

func _ready() -> void:
	_talent_rng.randomize()
	_bind_inputs()
	shot_rng.randomize();combat_rng.randomize()
	ready_visual=ReadyVisual.new();add_child(ready_visual)
	motion.set_family("pistol")
	pistol_magazine.configure(motion.definition(0))
	motion.set_family("rifle")
	rifle_magazine.configure(motion.definition(0))
	arena = Arena.new()
	add_child(arena)
	fx = Effects.new()
	add_child(fx)
	casing_fx = CasingFX.new()
	add_child(casing_fx)
	brine_zones=preload("res://scripts/brine_zones.gd").new();add_child(brine_zones)
	ground_fire=preload("res://scripts/ground_fire.gd").new();add_child(ground_fire)
	ground_fire.damage_hit.connect(_ground_burn)
	mace_fire_lobs = MaceFireLobs.new()
	add_child(mace_fire_lobs)
	mace_fire_lobs.detonated.connect(_mace_fire_impact)
	mace_fire_lobs.ember_sample.connect(fx.mace_ember_trail)
	mace_fire_lobs.impacted.connect(fx.mace_ember_impact)
	staff_orbs=preload("res://scripts/staff_charge_visual.gd").new();add_child(staff_orbs)
	staff_flight = StaffFlight.new()
	add_child(staff_flight)
	staff_flight.fire_patch.connect(ground_fire.spawn_patch)
	staff_flight.rifle_hit.connect(_rifle_damage)
	staff_flight.rifle_armor_hit.connect(_rifle_armor_damage)
	staff_flight.rifle_mark_hit.connect(_rifle_mark_damage)
	staff_flight.rifle_pellet_hit.connect(_rifle_pellet_damage)
	staff_flight.rifle_pellet_impact.connect(func(at: Vector3, color: Color): fx.burst(at, color.lightened(.25), 3))
	staff_flight.rifle_split.connect(func(at: Vector3, direction: Vector3, reach: float, half_angle: float):
		fx.burst(at, Color("#fff0c6"), 12)
		var angle := atan2(direction.z, direction.x)
		fx.sector(at, reach, angle - half_angle, angle + half_angle, Color(1.0, .55, .25, .36), 0.0, .18)
		fx.sector(at + Vector3.UP * .015, reach, angle - half_angle, angle + half_angle, Color(1.0, .83, .53, .65), reach - .09, .13)
		audio.play("bullet_impact"))
	staff_flight.rifle_pierce_spark.connect(func(point: Vector3): fx.burst(point, Color("#bdeeff"), 8))
	staff_flight.damage_hit.connect(_projectile_damage)
	staff_flight.friendly_hit.connect(_friendly_hit)
	staff_flight.companion_hit.connect(_companion_projectile_damage)
	staff_flight.ice_volley_hit.connect(_ice_volley_damage)
	staff_flight.ice_volley_contact.connect(fx.staff_ice_volley_contact)
	staff_flight.chain_lightning_contact.connect(fx.staff_chain_lightning_contact)
	staff_flight.lightning_jump.connect(_staff_chain_lightning_jump)
	staff_flight.sword_wave_hit.connect(_sword_wave_damage)
	staff_flight.vacuum_wake_segment.connect(fx.vacuum_wake_segment)
	staff_flight.bolt_hit.connect(_crossbow_hit)
	staff_flight.impact_element.connect(_projectile_impact)
	staff_flight.area_visual.connect(_projectile_area_impact)
	player = CharacterBody3D.new()
	player.name = "Ember"
	player.collision_layer = 4
	player.collision_mask = 1
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.35
	collision.shape = shape
	collision.position.y = 0.68
	player.add_child(collision)
	add_child(player)
	avatar = Hero.new()
	player.add_child(avatar)
	if use_cutout_avatar:avatar.enable_cutout()
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 13.5
	camera.current = true
	add_child(camera)
	camera.position = CAMERA_OFFSET
	camera.look_at(Vector3.ZERO)
	party_mark_marker = Label3D.new()
	party_mark_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	party_mark_marker.no_depth_test = true
	party_mark_marker.font_size = 42
	party_mark_marker.pixel_size = .012
	party_mark_marker.outline_size = 8
	party_mark_marker.modulate = Color("#ffd38a")
	party_mark_marker.visible = false
	add_child(party_mark_marker)
	audio = Audio.new()
	audio.ambient_enabled = false
	audio.volume_db = -14.0
	add_child(audio)
	pistol_reticle=preload("res://scripts/pistol_reticle.gd").new();add_child(pistol_reticle)
	rifle_scope=preload("res://scripts/rifle_scope.gd").new();add_child(rifle_scope)
	status_icons=preload("res://scripts/status_icons.gd").new();status_icons.game=self;add_child(status_icons)
	add_child(dungeon_peek)
	_build_room_shade()
	ui = HUD.new()
	ui.game = self
	add_child(ui)
	vision=preload("res://scripts/sight_sense.gd").new();vision.game=self;add_child(vision)
	fx.visibility_test=vision.can_see
	stats_panel=preload("res://scripts/stats_panel.gd").new();stats_panel.game=self;add_child(stats_panel)
	set_weapon_family("sword")
	loadout.load_data()
	for id: String in loadout.items:
		var family: String = loadout.items[id].family
		if family in ["pistol", "rifle"]:
			var mag = RifleCycle.new() if family=="rifle" else Magazine.new()
			var spec = Motion.new()
			spec.set_family(family)
			mag.configure(spec.definition(0))
			item_magazines[id] = mag
	loadout_mode = true
	arsenal = ArsenalUI.new()
	arsenal.game = self
	arsenal.model = loadout
	add_child(arsenal)
	sword_skill_ui = SwordSkillUI.new()
	sword_skill_ui.game = self
	sword_skill_ui.model = loadout
	add_child(sword_skill_ui)
	dual_visual = DualHandVisual.new()
	player.add_child(dual_visual)
	if use_cutout_avatar:
		for rig in dual_visual.rigs: rig.use_articulated_equipment()
	loadout_edited()
	avatar.anatomy=anatomy
	anatomy_panel=preload("res://scripts/anatomy_panel.gd").new();anatomy_panel.game=self;add_child(anatomy_panel)
	_body_key=anatomy.capability_key()
	_mouse_position = get_viewport().get_visible_rect().size * Vector2(0.65, 0.5)
	_visual_tick(0)
	DisplayServer.window_set_title("Emberwake — Tidal Headland v76")
	if "--harbor" in OS.get_cmdline_user_args():call_deferred("start_captain")

func _bind_inputs() -> void:
	for entry in [["move_left", KEY_A], ["move_right", KEY_D], ["move_up", KEY_W], ["move_down", KEY_S]]:
		if not InputMap.has_action(entry[0]): InputMap.add_action(entry[0])
		var event := InputEventKey.new()
		event.physical_keycode = entry[1]
		InputMap.action_add_event(entry[0], event)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if _mace_charge_slot >= 0: _cancel_skill()
		_cancel_revive()
		_cancel_great_charge();_cancel_staff_actions();_cancel_rifle_action();_cancel_bow();_cancel_crossbow_load()
		_held = false
		readiness.release();pistol_aim_state.reset()

func _input(event: InputEvent) -> void:
	if _room_fade != null: return
	if sword_skills_open: return
	if event is InputEventKey and not event.pressed:
		var key: int = event.physical_keycode if event.physical_keycode else event.keycode
		if key == KEY_E: _cancel_revive()
		if key in [KEY_1, KEY_2, KEY_3]: release_charged_skill_slot(key - KEY_1)
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and not event.pressed:
		readiness.release(true);pistol_aim_state.reset();staff_energy.stop_load()
	if event is InputEventMouseMotion:
		_mouse_position = event.position
		if dungeon_peek.visible: dungeon_peek.aim_at(event.position)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_held = false
		if _staff_breath_ticks > 0: _stop_staff_breath()
		if bow_charge >= 0.0: release_bow()
		if mode in ["practice","combat"] and not inventory_open and not stats_open:release_great_charge()
		else:_cancel_great_charge()

func _unhandled_input(event: InputEvent) -> void:
	if mode == "downed":
		if event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode == KEY_E or event.keycode == KEY_E):
			stand_up()
		get_viewport().set_input_as_handled()
		return
	if _room_fade != null:
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode == KEY_K or event.keycode == KEY_K):
		toggle_sword_skills()
		get_viewport().set_input_as_handled()
		return
	if sword_skills_open:
		if event is InputEventKey and event.pressed and (event.physical_keycode == KEY_ESCAPE or event.keycode == KEY_ESCAPE):
			toggle_sword_skills()
		get_viewport().set_input_as_handled()
		return
	if dungeon_peek.visible:
		if event is InputEventKey and event.pressed and not event.echo:
			var peek_key: int = event.physical_keycode if event.physical_keycode else event.keycode
			if peek_key in [KEY_E, KEY_ESCAPE]: dungeon_peek.close()
		get_viewport().set_input_as_handled()
		return
	if encounter_mode=="wreck_shore" and mode=="practice" and event is InputEventKey and event.pressed:
		var shore_key: int=event.physical_keycode if event.physical_keycode else event.keycode
		if shore_key==KEY_ENTER and not arena.intro_done():arena.skip_intro();player.position=arena.landing_point;get_viewport().set_input_as_handled();return
		if shore_key in [KEY_I,KEY_G,KEY_P,KEY_Q,KEY_R,KEY_F,KEY_E]:get_viewport().set_input_as_handled();return
	if encounter_mode=="coast_forms" and mode=="practice" and event is InputEventKey and event.pressed and not event.echo:
		var form_key: int=event.physical_keycode if event.physical_keycode else event.keycode
		if form_key>=KEY_1 and form_key<=KEY_5:jump_coast_form(form_key-KEY_1);get_viewport().set_input_as_handled();return
	if encounter_mode in ["village_study","coast_forms","wreck_shore"] and mode=="practice" and event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		village_zoom=clampf(village_zoom+(-1.5 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.5),10,24);get_viewport().set_input_as_handled();return
	if event is InputEventKey and event.pressed and (event.physical_keycode==KEY_B or event.keycode==KEY_B):return
	if body_lab_open:
		if event is InputEventKey and event.pressed and (event.physical_keycode==KEY_T or event.keycode==KEY_T):restart()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var code: int = event.physical_keycode if event.physical_keycode else event.keycode
		if code==KEY_P or (stats_open and code==KEY_ESCAPE):
			toggle_stats();get_viewport().set_input_as_handled();return
		if stats_open:return
		if code == KEY_I or (inventory_open and code == KEY_ESCAPE):
			toggle_inventory()
			get_viewport().set_input_as_handled()
			return
	if inventory_open or stats_open or body_lab_open: return
	if skill_active and active_skill_id == "square_off" and motion.stage == 0 and event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			_choose_square_followup(1 if event.button_index == MOUSE_BUTTON_LEFT else 2)
			get_viewport().set_input_as_handled()
			return
	if is_instance_valid(revive_target) and event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
		if mode in ["practice","combat"]:
			if primary_family()=="staff":
				begin_staff_load();get_viewport().set_input_as_handled();return
			readiness.press(not has_shield() and primary_family() in ReadyRules.MELEE and _can_parry())
			get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if mode in ["practice", "combat"]:
			if primary_family() == "rifle": _mouse_position = event.position
			if primary_family()=="staff":
				if _staff_breath_slot >= 0: _start_staff_breath()
				else: request_staff_basic()
				get_viewport().set_input_as_handled();return
			if primary_family() in ["bow", "crossbow"]:
				request_attack();get_viewport().set_input_as_handled();return
			_held = true
			_refresh_aim()
			request_attack()
			get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode if event.physical_keycode else event.keycode
		match key:
			KEY_1, KEY_2, KEY_3: request_skill_slot(key - KEY_1, true)
			KEY_SPACE: request_dodge()
			KEY_ESCAPE: toggle_pause()
			KEY_R:
				if primary_family() == "staff": cycle_staff_element()
				else: request_reload()
			KEY_Q: request_loadout_swap()
			KEY_F: use_health_flask()
			KEY_E:
				if not _begin_revive() and not try_peek_dungeon_exit(): request_armor_skill()
			KEY_T: restart()
			KEY_H: debug_range = not debug_range
			KEY_M: audio.set_enabled(not audio.enabled)
			KEY_G: toggle_inventory()
			KEY_V: cycle_drill()
			KEY_C:
				if event.shift_pressed: recall_companions()
				else: mark_party_cursor()

func cycle_weapon() -> bool:
	var families: Array[String] = ["rifle", "pistol", "staff", "mace", "greatsword", "sword", "bow", "crossbow", "shield"]
	return set_weapon_family(families[(families.find(weapon_family) + 1) % families.size()])

func set_weapon_family(value: String) -> bool:
	if value not in ["sword", "greatsword", "mace", "staff", "pistol", "rifle", "bow", "crossbow", "shield"] or mode not in ["menu", "practice", "combat"] or motion.busy or _dodge_left > 0 or guns_reloading():
		return false
	if not motion.set_family(value): return false
	if not avatar.set_weapon_family(value): return false
	_cancel_bow()
	_cancel_crossbow_load()
	loadout_mode = false
	weapon_family = value
	rewards.clear_chain()
	motion.reset()
	_next_combo = 0
	_idle_time = 0
	_held = false
	_hit_targets.clear()
	_short_lunge.reset()
	mace_dash_travelled = 0
	_reset_attack_step()
	_rifle_recoil.reset()
	rifle_recoil_travelled = 0
	if is_instance_valid(ui): ui.refresh()
	return true

func clear_hostile_projectiles() -> void:
	if is_instance_valid(brine_zones):brine_zones.clear()
	for entry in projectiles:
		if is_instance_valid(entry.node):entry.node.queue_free()
	projectiles.clear()
func start_wreck_shore() -> void:
	start_run(true,false);clear_actors();arena.free();arena=preload("res://scripts/wreck_shore.gd").new();add_child(arena)
	_harbor_mode=false;_coast_mode=true;encounter_mode="wreck_shore";_practice=true;mode="practice";player.collision_mask=9
	player.position=arena.spawn_point;player.velocity=Vector3.ZERO;aim=Vector3(1,0,-.3).normalized();_camera_focus=arena.camera_focus(player.position);camera.size=18.5;camera.position=_camera_focus+CAMERA_OFFSET;camera.look_at(_camera_focus)
	ui.show_mode(mode);_visual_tick(0)
func start_coast_forms() -> void:
	start_run(true,false);clear_actors();arena.free();arena=preload("res://scripts/coast_forms.gd").new();add_child(arena)
	_harbor_mode=false;_coast_mode=true;encounter_mode="coast_forms";_practice=true;mode="practice";player.collision_mask=9
	village_zoom=18.5;camera.size=village_zoom;player.position=arena.inspection_point(0);_camera_focus=player.position+Vector3(2.5,0,-2);camera.position=_camera_focus+CAMERA_OFFSET;camera.look_at(_camera_focus)
	ui.show_mode(mode);_visual_tick(0)
func jump_coast_form(index: int) -> void:
	if encounter_mode!="coast_forms":return
	_cancel_body_actions();player.position=arena.inspection_point(index);player.velocity=Vector3.ZERO;_camera_focus=player.position+Vector3(2.5,0,-2);camera.position=_camera_focus+CAMERA_OFFSET;camera.look_at(_camera_focus);_visual_tick(0)
func start_village_study() -> void:
	start_run(true,false);clear_actors();arena.free();arena=preload("res://scripts/village_study.gd").new();add_child(arena)
	_harbor_mode=false;_coast_mode=true;encounter_mode="village_study";_practice=true;mode="practice";player.collision_mask=9
	village_zoom=21.0;camera.size=village_zoom
	player.position=arena.spawn_point;_camera_focus=player.position+Vector3(0,0,-6.5);camera.position=_camera_focus+CAMERA_OFFSET;camera.look_at(_camera_focus)
	ui.show_mode(mode);_visual_tick(0)
func start_coast() -> void:
	start_run(true,false);clear_actors();arena.free();arena=BeachArena.new();add_child(arena)
	_harbor_mode=false;_coast_mode=true;encounter_mode="coast";_practice=false;mode="combat";player.collision_mask=9
	player.position=arena.spawn_point;_camera_focus=player.position;camera.position=_camera_focus+CAMERA_OFFSET;camera.look_at(_camera_focus)
	coast.populate(self);ui.show_mode(mode);_visual_tick(0)
func finish_coast() -> void:
	mace_fire_lobs.clear()
	mace_fire_buff_left = 0.0
	_cancel_body_actions();clear_hostile_projectiles();fx.clear_transients();staff_flight.clear();ground_fire.clear();_staff_ground.clear();_mace_ground.clear();casing_fx.clear();reset_gun_magazines();_held=false;mode="victory";audio.play("victory");ui.show_mode(mode)
func start_dungeon(seed_value: int = -1) -> void:
	if character_lost and not expedition_recruit_id.is_empty(): return
	start_run(true)
	_apply_expedition_attributes()
	if expedition_starting_flasks >= 0:
		flasks.charges = expedition_starting_flasks
	arena.free()
	arena = DungeonRoom.new()
	add_child(arena)
	encounter_mode = "dungeon"
	mode = "combat"
	_practice = false
	_spawn_expedition_companions()
	dungeon.generate(randi() if seed_value == -1 else seed_value)
	dungeon.enter(self, dungeon.start)
	ui.show_mode(mode)
	_visual_tick(0)

func _build_room_shade() -> void:
	var overlay := CanvasLayer.new()
	overlay.layer = 40
	add_child(overlay)
	_room_shade = ColorRect.new()
	_room_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/dungeon_room_wipe.gdshader")
	_room_shade.material = material
	overlay.add_child(_room_shade)
	_room_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_room_shade.hide()


func change_dungeon_room(target: Vector2i, direction: Vector2i) -> void:
	if _room_fade != null: return
	_cancel_body_actions()
	_held = false
	player.velocity = Vector3.ZERO
	var axis := Vector3(direction.x, 0, direction.y)
	var view := camera.global_basis
	var screen_direction := Vector2(axis.dot(view.x), -axis.dot(view.y)).normalized()
	_room_shade.material.set_shader_parameter("direction", screen_direction)
	_set_room_fade(0.0)
	_room_shade.show()
	_room_fade = create_tween()
	_room_fade.tween_method(_set_room_fade, 0.0, 1.0, .14)
	_room_fade.tween_callback(_arrive_in_dungeon_room.bind(target, -direction))
	_room_fade.tween_interval(.02)
	_room_fade.tween_method(_set_room_fade, 1.0, 2.0, .16)
	_room_fade.finished.connect(_finish_room_fade)


func _arrive_in_dungeon_room(target: Vector2i, entrance: Vector2i) -> void:
	dungeon.enter(self, target, entrance)
	_visual_tick(0.0)


func _set_room_fade(progress: float) -> void:
	_room_shade.material.set_shader_parameter("progress", progress)


func _finish_room_fade() -> void:
	_room_fade = null
	_room_shade.hide()


func _end_room_fade() -> void:
	if _room_fade != null:
		_room_fade.kill()
		_finish_room_fade()


func start_captain() -> void:start_run(true,true)
func _set_arena(harbor: bool) -> void:
	if harbor==_harbor_mode and not _coast_mode and encounter_mode!="dungeon":return
	arena.free();arena=HarborArena.new() if harbor else Arena.new();add_child(arena);_harbor_mode=harbor;_coast_mode=false
func start_run(practice: bool = false,harbor: bool=false) -> void:
	if character_lost and not expedition_recruit_id.is_empty(): return
	_end_room_fade()
	stats.attributes = {}
	stats.set_talents({})
	_last_talent_reward_room = 0
	flasks.healing_multiplier = 1.0
	stats.level = 1
	for companion in companions:
		remove_child(companion)
		companion.queue_free()
	companions.clear()
	_set_arena(harbor);encounter_mode="captain" if harbor else "";player.collision_mask=1
	sanity = 0
	frenzy = false
	_sanity_marked = false
	character_lost = false
	anatomy.bind_max_hp(stats.value("max_health"));anatomy.reset();flasks.reset();body_lab_open=false;_crawl_still=.25;_body_key=anatomy.capability_key()
	readiness.reset();rewards.reset();energy.reset()
	sword_skill_cooldowns.clear()
	sword_wave_buff_left = 0.0
	sword_skills_open = false
	if is_instance_valid(vision):vision.reset_cues()
	drill_kind=""
	if inventory_open: toggle_inventory()
	pending_set = -1
	_cancel_skill()
	_reset_crossbows()
	clear_actors()
	_practice = practice
	mode = "practice" if practice else "combat"
	wave = 0
	kills = 0
	hits = 0
	total_damage = 0
	health = max_health()
	stamina = stats.value("max_stamina")
	mana = stats.value("max_mana")
	reset_gun_magazines()
	run_time = 0
	motion.reset()
	_short_lunge.reset()
	mace_dash_travelled = 0
	_reset_attack_step()
	_next_combo = 0
	_idle_time = 0
	_dummy_idle = 0
	_held = false
	_dodge_left = 0
	_dodge_recharge = 0
	_iframes = 0
	_hurt = 0
	_hit_stop = 0
	_shake = 0
	_wave_wait = 0
	_hit_targets.clear()
	player.position = Vector3(0, 0.03, 0)
	player.velocity = Vector3.ZERO
	aim = Vector3.RIGHT
	_camera_focus = Vector3.ZERO
	camera.position = CAMERA_OFFSET
	camera.look_at(Vector3.ZERO)
	if harbor:
		player.position=Vector3(-3,.03,0);spawn_enemy("captain",Vector3(2.5,.03,0))
	elif practice:
		spawn_enemy("dummy", Vector3(2, 0.03, 0))
	else:
		spawn_wave()
	if loadout_mode: loadout_edited()
	ui.show_mode(mode)
	_visual_tick(0)

func clear_actors() -> void:
	if is_instance_valid(dungeon_peek): dungeon_peek.close()
	_cancel_revive()
	_clear_party_mark()
	if is_instance_valid(brine_zones):brine_zones.clear()
	rifle_focus_state.reset();pistol_aim_state.reset()
	_rifle_pending_fire=false
	_stop_staff_breath();staff_energy.reset()
	_staff_ground.clear()
	_cancel_bow()
	_cancel_crossbow_load()
	_cancel_skill()
	if is_instance_valid(fx): fx.clear_transients()
	if is_instance_valid(staff_flight): staff_flight.clear()
	if is_instance_valid(ground_fire):ground_fire.clear()
	_mace_ground.clear()
	if is_instance_valid(mace_fire_lobs): mace_fire_lobs.clear()
	mace_fire_buff_left = 0.0
	if is_instance_valid(casing_fx): casing_fx.clear()
	for enemy in enemies:
		if is_instance_valid(enemy):
			remove_child(enemy)
			enemy.queue_free()
	enemies.clear()
	for entry in projectiles:
		if is_instance_valid(entry.node): entry.node.queue_free()
	projectiles.clear()

func restart() -> void:
	if mode == "downed" or (character_lost and not expedition_recruit_id.is_empty()): return
	if encounter_mode=="wreck_shore":start_wreck_shore()
	elif encounter_mode=="coast_forms":start_coast_forms()
	elif encounter_mode=="village_study":start_village_study()
	elif encounter_mode=="coast":start_coast()
	elif encounter_mode=="dungeon":start_dungeon()
	elif encounter_mode=="captain":start_captain()
	elif drill_kind=="brinehound":start_brinehound_trial()
	elif drill_kind=="crewman":start_crewman_trial()
	elif drill_kind=="spitter":start_spitter_trial()
	elif drill_kind=="net_hauler":start_net_hauler_trial()
	elif drill_kind=="fisherman":start_fisherman_trial()
	elif drill_kind!="":start_parry_drill(drill_kind)
	else:start_run(_practice)

func return_menu() -> void:
	if character_lost and not expedition_recruit_id.is_empty():
		get_tree().change_scene_to_file("res://scenes/prologue.tscn")
		return
	sword_wave_buff_left = 0.0
	flasks.cancel_effects()
	readiness.release();pistol_aim_state.reset()
	_cancel_skill()
	clear_actors()
	reset_gun_magazines()
	mode = "menu"
	motion.reset()
	_reset_attack_step()
	_held = false
	_shake = 0
	_hurt = 0
	health = max_health()
	stamina = stats.value("max_stamina")
	ui.show_mode(mode)

func toggle_pause() -> void:
	_cancel_revive()
	_cancel_bow()
	_cancel_crossbow_load()
	_cancel_rifle_action()
	_cancel_staff_actions()
	_cancel_great_charge()
	readiness.release();pistol_aim_state.reset()
	_held = false
	if mode in ["combat", "practice"]:
		_mace_ground.clear_landing()
		_previous_mode = mode
		mode = "paused"
	elif mode == "paused":
		mode = _previous_mode
	else:
		return
	ui.show_mode(mode)
	pistol_reticle.update_view(self)
	rifle_scope.update_view(self)

func _refresh_aim(allow_locked: bool = false) -> void:
	var rifle_charging := rifle_finisher_charging()
	if motion.busy and not motion.is_great_charging() and not rifle_charging and not allow_locked: return
	if test_aim.length_squared() > 0.001:
		aim = Vector3(test_aim.x, 0, test_aim.z).normalized()
	else:
		var height := rifle_cursor_height() if rifle_aiming() else 0.0
		var point := cursor_world_at_height(height)
		if point.is_finite():
			var direction := point - player.global_position
			direction.y = 0
			if direction.length_squared() > 0.1: aim = direction.normalized()
	if motion.is_great_charging():motion.retarget_charge(atan2(aim.z,aim.x))
	elif rifle_charging:
		_capture_rifle_target()
		_basic_motion.retarget_rifle_finisher(atan2(aim.z,aim.x))
	elif not motion.busy:motion.rebase_idle_aim(atan2(aim.z, aim.x))

func cursor_world_at_height(height: float) -> Vector3:
	return _point_on_cursor_ray(camera.project_ray_origin(_mouse_position), camera.project_ray_normal(_mouse_position), height)

func rifle_cursor_height() -> float:
	return player.global_position.y + (RifleMotion.RAISED_AIM_HEIGHT if avatar.articulated_equipment else RifleMotion.AIM_HEIGHT)

func _point_on_cursor_ray(origin: Vector3, ray: Vector3, height: float) -> Vector3:
	if not origin.is_finite() or absf(ray.y) <= .001: return Vector3.INF
	return origin + ray * ((height - origin.y) / ray.y)

func _capture_rifle_target() -> void:
	_rifle_target_origin = Vector3.INF
	if test_aim.length_squared() > .001: return
	_rifle_target_origin = camera.project_ray_origin(_mouse_position)
	_rifle_target_ray = camera.project_ray_normal(_mouse_position)

func locked_rifle_reticle() -> Vector2:
	if primary_family() != "rifle" or not motion.busy or not _rifle_target_origin.is_finite(): return Vector2.INF
	var pose: Dictionary = motion.sample()
	if pose.phase not in ["windup", "active"]: return Vector2.INF
	var height := _rifle_release_height if is_finite(_rifle_release_height) else _aimed_rifle_muzzle(_staff_tip(pose)).y
	var point := _point_on_cursor_ray(_rifle_target_origin, _rifle_target_ray, height)
	return camera.unproject_position(point) if point.is_finite() else Vector2.INF

func _relax_idle_pose() -> void:
	if motion.busy: return
	# Relax the stance after a pause, retaining the next attack in the chain.
	# Walking and repositioning no longer discard an earned follow-up.
	if _idle_time > 0.85 and weapon_family in ["sword", "greatsword", "mace"] and motion.stage >= 0:
		motion.reset()
		motion.rebase_idle_aim(atan2(aim.z, aim.x))

func request_attack() -> bool:
	if not body_action_ready() or not active_weapon_possible():return false
	if primary_family() == "shield": return false
	if primary_family() == "bow": return _begin_bow()
	if primary_family() == "crossbow": return _fire_crossbow()
	if primary_family()=="staff" and not _staff_committing:return request_staff_basic()
	if right_action()=="guard" or readiness.broken_left>0:return false
	if inventory_open or stats_open or pair_strikes.active:return false
	if mode not in ["practice","combat"] or anatomy.dead() or motion.busy or _dodge_left>0:return false
	if primary_family()=="rifle" and not _rifle_request_gate():return false
	if guns_reloading():return false
	var ids: Array=[]
	if loadout_mode:
		ids=available_body_items().filter(func(id): return loadout.items[id].family != "shield")
		if ids.is_empty():return false
		for id: String in ids:
			if item_magazines.has(id) and not item_magazines[id].can_fire():
				_select_loadout_item(id);request_reload();return false
	var counter: bool=rewards.counter_left>0 and primary_family() in ReadyRules.MELEE
	var fire_mace := primary_family() == "mace" and mace_fire_buff_left > 0.0
	if fire_mace:
		_next_combo = 0
		if ids.size() > 1: ids.resize(1)
	elif counter:_next_combo=2
	elif rewards.combo_left<=0:_next_combo=0
	_pair_aimed=right_action()=="aim"
	var total_cost:=.0
	if loadout_mode:
		for id: String in ids:total_cost+=attack_cost(loadout.items[id].family,_next_combo,_pair_aimed)
	else:total_cost=attack_cost(weapon_family,_next_combo,_pair_aimed)
	if not _can_spend(total_cost):return false
	if loadout_mode:
		_loadout_attack_index=_next_combo
		if not _select_loadout_item(ids[0]):return false
		if ids.size()==2:pair_strikes.begin(_next_combo,ids)
	if not _start_weapon_attack(_next_combo,counter):
		pair_strikes.cancel();return false
	rewards.counter_left=0;rewards.combo_left=0
	if weapon_family=="greatsword":_held=false
	return true

func _start_weapon_attack(index: int,counter: bool=false,rifle_finisher: bool=false) -> bool:
	if not active_weapon_possible() or not body_action_ready():return false
	if weapon_family=="rifle" and not active_magazine().can_fire():return false
	if weapon_family in ["pistol", "rifle"] and not active_magazine().can_fire():
		request_reload()
		return false
	var energy_cost:=0.0 if weapon_family=="staff" or rifle_finisher else attack_cost(weapon_family,index,_pair_aimed)
	if not _can_spend(energy_cost):return false
	_relax_idle_pose()
	_refresh_aim()
	var attack_stage := index
	if weapon_family == "sword": motion.configure_sword_power(sword_weapon_power())
	var fire_lift: bool = weapon_family == "mace" and primary_family() == "mace" and mace_fire_buff_left > 0.0 and not pair_strikes.active
	if fire_lift: attack_stage = _mace_fire_next_side
	if weapon_family in ["staff", "pistol", "rifle"]: attack_stage = 0
	var plan: Dictionary = {}
	var attack_aim := aim
	if weapon_family in ["sword", "greatsword", "mace"] and not fire_lift:
		plan = _melee_approach.choose(weapon_family, attack_stage, player.global_position, aim, motion.definition(attack_stage), enemies, player.get_world_3d())
		if plan.assisted: attack_aim = plan.direction
	if counter and weapon_family=="greatsword":motion.great_charge.prime_finisher(3)
	if weapon_family=="rifle":
		var cycle = active_magazine()
		_rifle_target_origin = Vector3.INF
		_rifle_release_height = INF
		if _pair_aimed or rifle_finisher: _capture_rifle_target()
		var handling := RifleMotion.time_scale(stats.attributes, float(rifle_weapon_stats().handling))
		motion.configure_rifle(_pair_aimed or rifle_finisher, cycle.rapid_fire_left > 0.0, rifle_finisher, handling)
		cycle.configure_shot(_pair_aimed or rifle_finisher, 1.0 if rifle_finisher else handling)
	_pistol_shot_bonus=pistol_aim_state.speed_bonus() if weapon_family=="pistol" and _pair_aimed and readiness.held else 0.0
	var attack_angle := atan2(attack_aim.z, attack_aim.x)
	if fire_lift:
		if not motion.start_mace_fire_lift(attack_stage, attack_angle, _mace_fire_lift_damage): return false
		_mace_fire_next_side = 1 - _mace_fire_next_side
	else:
		if not motion.start(attack_stage, attack_angle): return false
	_storm_blade_single_swing = _storm_blade_has_current_sword()
	_spend_stamina(energy_cost)
	_shot_aimed=_pair_aimed
	_shot_spread=gun_spread(weapon_family,_shot_aimed)
	aim = attack_aim
	melee_approach_plan = plan
	if fire_lift:
		_reset_attack_step()
	else:
		_attack_step.begin(weapon_family, motion.stage, motion.aim_angle, plan.get("distance", -1.0), plan.get("distance_limit", 0.85), plan.get("assisted", false))
	attack_step_travelled = 0.0
	if weapon_family == "rifle":
		_rifle_recoil.reset()
		_rifle_retreat_distance = 0.0
		rifle_recoil_travelled = 0
	if weapon_family == "mace" and _next_combo in [0, 1]:
		_short_lunge.reset()
		mace_dash_travelled = 0
	_idle_time = 0
	_dummy_idle = 0
	_hit_targets.clear()
	if motion.is_great_charging():_reset_attack_step()
	if weapon_family not in ["pistol", "rifle"]: audio.play("windup" if _next_combo == 2 else "equip")
	return true

func request_skill() -> bool:
	return request_skill_slot(0)

func request_armor_skill() -> bool:
	return false

func _begin_skill(id: String) -> bool:
	var mace_skill := MaceSkillMotion.SKILLS.has(id)
	if mace_skill:
		if not mace_skills_available(): return false
	elif not SwordSkillMotion.SKILLS.has(id) or not sword_skills_available(): return false
	if encounter_mode == "wreck_shore" and not arena.intro_done(): return false
	if sword_skills_open or _arrival_locked or dungeon_peek.visible or _room_fade != null or is_instance_valid(revive_target): return false
	if float(sword_skill_cooldowns.get(id, 0.0)) > 0.0: return false
	if not body_action_ready() or not active_weapon_possible(): return false
	if right_action()=="guard" or readiness.broken_left>0:return false
	if pair_strikes.active: return false
	if inventory_open or stats_open or body_lab_open: return false
	if mode not in ["practice", "combat"] or anatomy.dead() or skill_active or motion.busy or _dodge_left > 0 or guns_reloading(): return false
	var skill: Dictionary = MaceSkillMotion.SKILLS[id] if mace_skill else SwordSkillMotion.SKILLS[id]
	var cost: float = (float(skill.cost) if mace_skill else SwordSkillMotion.mana_cost(id, stats.attributes)) * stats.talent_factor("skill_mana")
	if mana < cost: return false
	if loadout_mode and not _select_loadout_item(_body_default_item()): return false
	_refresh_aim()
	var skill_motion = _mace_skill_motion if mace_skill else _sword_skill_motion
	if mace_skill:
		if not _mace_skill_motion.configure(id, motion.sample(), mace_weapon_power(), float(stats.attributes.get("strength", 3)), stats.talent_factor("skill_area"), stats.talent_factor("area_windup")): return false
	else:
		if not _sword_skill_motion.configure(id, stats.attributes, sword_weapon_power(), stats.talent_factor("skill_area"), stats.talent_factor("area_windup")): return false
		_sword_skill_motion.seed_pose(motion.sample())
	if not skill_motion.start(0, atan2(aim.z, aim.x)): return false
	mana -= cost
	sword_skill_cooldowns[id] = float(skill.cooldown) * stats.talent_factor("skill_cooldown")
	motion = skill_motion
	active_skill_id = id
	_skill_generation += 1
	_sword_skill_lunge.reset()
	_storm_step_direction = Vector3.ZERO
	_sword_stance_branch = -1
	skill_active = true
	skill_cut_index = 0
	readiness.release()
	_held = false
	_idle_time = 0
	_dummy_idle = 0
	_hit_targets.clear()
	_reset_attack_step()
	_trail_clock = 0
	audio.play("equip")
	if id == "mace_armor_counter":
		var angle: float = skill_motion.aim_angle
		fx.sector(player.position + Vector3.UP * .045, .95, angle - PI / 3.0, angle + PI / 3.0, Color("#9edfdc"), .88, MaceSkillMotion.ARMOR_COUNTER_WINDOW)
	return true

func request_skill_slot(index: int, hold_charge: bool = false) -> bool:
	var family := primary_family()
	var slots: Array = loadout.slots_for_family(family)
	if index < 0 or index >= slots.size(): return false
	if family == "rifle":
		return _use_rifle_skill(str(slots[index]))
	if family == "staff":
		if slots[index] == StaffMotion.FOCUS_ID:
			return _activate_staff_focus()
		if slots[index] == StaffMotion.FIRE_BREATH_ID:
			return _arm_staff_breath(index)
		if not begin_staff_cast(slots[index]): return false
		_staff_charge_slot = index
		return true
	if not _begin_skill(str(slots[index])): return false
	if hold_charge and MaceSkillMotion.SKILLS.get(slots[index], {}).get("chargeable", false):
		_mace_skill_motion.charging = true
		_mace_charge_slot = index
	return true

func _use_rifle_skill(id: String) -> bool:
	if not RifleMotion.SKILLS.has(id): return false
	var skill: Dictionary = RifleMotion.SKILLS[id]
	var refill := int(skill.get("refill", 0))
	var duration := float(skill.get("duration", 0.0))
	var cost: float = RifleMotion.skill_cost(id, stats.attributes) * stats.talent_factor("skill_mana")
	var cooldown: float = RifleMotion.skill_cooldown(id, stats.level) * stats.talent_factor("skill_cooldown")
	if not rifle_skills_available(id): return false
	if mana < cost or float(sword_skill_cooldowns.get(id, 0.0)) > 0.0: return false
	var cycle = active_magazine()
	if not cycle is RifleCycle: return false
	if id == RifleMotion.FINISHER_ID:
		if loadout_mode and not _select_loadout_item(loadout.primary()): return false
		if not _start_weapon_attack(0, false, true): return false
		_held = false
		_rifle_pending_fire = false
		sword_skill_cooldowns[id] = cooldown
	elif duration > 0.0:
		cycle.rapid_fire_left = duration
		sword_skill_cooldowns[id] = cooldown
		ui.start_rifle_rapid_gears()
	elif refill > 0:
		if not cycle.refill_now(refill): return false
		_rifle_pending_fire = false
		reload_visual.cancel()
		_rifle_events(cycle)
		for i in refill: ui.turn_rifle_gears(true)
		sword_skill_cooldowns[id] = cooldown
	else:
		if not cycle.prepare_round(id, int(skill.get("rounds", 1))): return false
		_refresh_aim()
		var receiver := _staff_tip(_hand_pose(current_visual_sample())) - aim * .90
		if avatar.articulated_equipment and avatar.weapon_family == "rifle":
			receiver = avatar.rifle_receiver()
		fx.rifle_load_round(receiver, aim, camera, id)
	mana -= cost
	audio.play("charge" if id == RifleMotion.FINISHER_ID else ("equip" if duration > 0.0 else "rifle_insert"))
	ui.refresh()
	return true

func release_charged_skill_slot(index: int) -> void:
	if staff_energy.casting and index == _staff_charge_slot:
		if not release_staff_cast(): _cancel_staff_actions()
		return
	release_mace_charge(index)

func release_mace_charge(index: int) -> void:
	if index != _mace_charge_slot or not _mace_skill_motion.charging: return
	_mace_charge_slot = -1
	if mode not in ["practice", "combat"] or inventory_open or stats_open or body_lab_open:
		_cancel_skill()
		return
	if active_skill_id == "mace_earth_wave":
		_refresh_aim(true)
		_mace_leap_offset = _mace_leap_landing(_mace_skill_motion.charge_grade()) - player.position
		_mace_skill_motion.steer_charge(_mace_leap_angle(_mace_leap_offset), 1.0)
	_mace_ground.clear_landing()
	_mace_skill_motion.release_charge()
	sword_skill_cooldowns[active_skill_id] = float(MaceSkillMotion.SKILLS[active_skill_id].cooldown) * stats.talent_factor("skill_cooldown")

func mace_charge_grade(index: int) -> int:
	return _mace_skill_motion.charge_grade() if index == _mace_charge_slot else 0

func toggle_sword_skills() -> void:
	if sword_skills_open:
		sword_skills_open = false
		return
	if _arrival_locked or dungeon_peek.visible or body_lab_open or stats_open or _room_fade != null: return
	if mode not in ["menu", "practice", "combat", "paused"] or motion.busy or _dodge_left > 0 or is_instance_valid(revive_target): return
	if inventory_open: toggle_inventory()
	_cancel_bow()
	_cancel_crossbow_load()
	_cancel_rifle_action()
	_cancel_staff_actions()
	readiness.release()
	_held = false
	sword_skills_open = true
	loadout.message = "เลือกท่าที่ต้องการ แล้วกดใส่ช่อง 1 / 2 / 3"
	if is_instance_valid(sword_skill_ui): sword_skill_ui.refresh()

func _choose_square_followup(index: int) -> void:
	if not skill_active or active_skill_id != "square_off" or motion.stage != 0: return
	_sword_stance_branch = index
	if motion.elapsed >= float(motion.definition(0).windup):
		_start_skill_stage(index)

func _start_skill_stage(index: int) -> void:
	if active_skill_id == "double_slash" and index == 1:
		_double_slash_first_hits = _hit_targets.duplicate()
	motion.busy = false
	if not motion.start(index, motion.aim_angle):
		_cancel_skill()
		return
	skill_cut_index = index
	_sword_stance_branch = -1
	_sword_skill_lunge.reset()
	_storm_step_direction = Vector3.ZERO
	_hit_targets.clear()
	_trail_clock = 0.0
	if motion == _sword_skill_motion: audio.play("equip")

func _cancel_skill() -> void:
	_double_slash_first_hits.clear()
	_cancel_staff_actions()
	pair_strikes.cancel()
	_skill_generation += 1
	if skill_active:
		motion = _basic_motion
	_skill_motion.reset()
	_armor_motion.reset()
	_armor_lunge.reset()
	_sword_skill_motion.reset()
	_mace_skill_motion.reset()
	_mace_charge_slot = -1
	_mace_parried_attacker_id = 0
	_mace_leap_offset = Vector3.ZERO
	_mace_impact_flash = null
	_mace_ground.clear_landing()
	_sword_skill_lunge.reset()
	_storm_step_direction = Vector3.ZERO
	_sword_stance_branch = -1
	active_skill_id = ""
	skill_active = false
	skill_cut_index = -1

func _finish_skill_cut() -> void:
	if not skill_active or motion.busy: return
	if motion == _sword_skill_motion and active_skill_id != "square_off" and skill_cut_index + 1 < _sword_skill_motion.stage_count():
		_start_skill_stage(skill_cut_index + 1)
	else:
		_cancel_skill()
		_idle_time = 0
		_dummy_idle = 0

func request_reload() -> bool:
	if is_instance_valid(revive_target): return false
	if primary_family() == "crossbow": return _load_crossbow()
	if not body_action_ready() or not active_weapon_possible():return false
	if right_action()=="guard" or readiness.broken_left>0:return false
	if inventory_open or stats_open or pair_strikes.active: return false
	if mode not in ["practice","combat"] or anatomy.dead() or motion.busy or _dodge_left>0:return false
	if loadout_mode:
		var chosen := ""
		if _body_item_usable(active_item) and item_magazines.has(active_item) and item_magazines[active_item].rounds<item_magazines[active_item].capacity:chosen=active_item
		if chosen=="":
			for id: String in available_body_items():
				if item_magazines.has(id) and item_magazines[id].rounds<item_magazines[id].capacity:
					chosen=id;break
		if chosen=="" or not _select_loadout_item(chosen):return false
	if weapon_family not in ["pistol", "rifle"] or mode not in ["practice", "combat"] or motion.busy or _dodge_left > 0:
		return false
	if not active_magazine().start_reload(): return false
	if weapon_family=="rifle":_rifle_pending_fire=false
	reload_visual.begin(weapon_family)
	audio.play(weapon_family+"_reload_open")
	_visual_tick(0)
	return true

func request_dodge(direction: Vector3 = Vector3.ZERO) -> bool:
	if rifle_finisher_charging(): return false
	if motion == _basic_motion and weapon_family == "rifle" and motion.busy and motion.definition(0).get("rifle_finisher", false) and motion.elapsed < RifleMotion.FINISHER_CHARGE + DashVisual.DURATION * 1.5: return false
	if encounter_mode=="wreck_shore" and not arena.intro_done():return false
	if anatomy.dash_multiplier()<=0 or body_lab_open:return false
	if inventory_open or stats_open or body_lab_open: return false
	if mode not in ["practice", "combat"] or anatomy.dead() or _dodge_left > 0 or _dodge_recharge > 0:
		return false
	var dodge_cost: float = rewards.DODGE_COST * stats.value("stamina_cost_multiplier") * anatomy.action_cost_multiplier() * anatomy.dash_cost_multiplier() * stats.talent_factor("dash_cost")
	if not _can_spend(dodge_cost): return false
	_cancel_revive()
	var keep_rifle_aim: bool=primary_family()=="rifle" and readiness.held
	readiness.release();pistol_aim_state.reset();_cancel_staff_actions();_cancel_rifle_action();_cancel_bow();_cancel_crossbow_load()
	_cancel_skill()
	motion.reset()
	_refresh_aim()
	motion.rebase_idle_aim(atan2(aim.z, aim.x))
	pistol_magazine.cancel_reload()
	rifle_magazine.cancel_reload()
	for magazine in item_magazines.values(): magazine.cancel_reload()
	reload_visual.cancel()
	_hit_stop = 0
	_hit_targets.clear()
	_held = false
	_short_lunge.reset()
	mace_dash_travelled = 0
	_rifle_recoil.reset()
	rifle_recoil_travelled = 0
	var movement := _movement()
	_dodge_dir = direction.normalized() if direction.length_squared() > 0.001 else (movement.normalized() if movement.length_squared() > 0.001 else aim)
	_dodge_dir.y = 0
	_dodge_facing = aim
	_spend_stamina(dodge_cost)
	_dodge_left = DashVisual.DURATION
	if anatomy.leg_count()==0:_crawl_still=0
	_dodge_recharge = rewards.DODGE_RECHARGE
	_iframes = 0
	rewards.begin_dodge(player.position)
	_next_combo = 0
	_idle_time = 0
	_reset_attack_step()
	if keep_rifle_aim:readiness.held=true
	audio.play("dodge")
	fx.ring(player.position, 0.6, Color(0.5, 0.9, 0.9, 0.5), 0.22)
	return true

func set_arrival_lock(locked: bool) -> void:
	_arrival_locked = locked
	ui.visible = not locked
	anatomy_panel.visible = not locked
	set_process(not locked)
	set_physics_process(not locked)
	set_process_input(not locked)
	set_process_unhandled_input(not locked)


func _movement() -> Vector3:
	if _arrival_locked:
		return arrival_motion
	if rifle_finisher_charging(): return Vector3.ZERO
	if encounter_mode=="wreck_shore" and not arena.intro_done():return Vector3.ZERO
	var input := move_input if move_input.length_squared() > 0 else Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var right := camera.global_basis.x
	var forward := -camera.global_basis.z
	right.y = 0
	forward.y = 0
	return (right.normalized() * input.x - forward.normalized() * input.y).limit_length(1)

func _physics_process(delta: float) -> void:
	_in_physics_tick = true
	tick(delta)
	_in_physics_tick = false

func _process(_delta: float) -> void:
	if _pending_presentation > 0.0:
		var elapsed := _pending_presentation
		_pending_presentation = 0.0
		_present_frame(elapsed)

func tick(delta: float) -> void:
	if inventory_open or stats_open or body_lab_open or sword_skills_open or dungeon_peek.visible or _room_fade != null: return
	if not is_finite(delta) or delta <= 0: return
	# Preserve each cut's active interval and hit identities when a slow frame
	# crosses the automatic cut boundary. Other attacks retain their old tick.
	var remaining := delta
	while remaining > 0:
		var part := remaining
		# Residual brine retains its pulse/expiry clock after its caster is gone.
		if not brine_zones.zones.is_empty():part=minf(part,1.0/120)
		if mode in ["practice", "combat"] and not _mace_ground.echoes.is_empty():
			part = minf(part, maxf(.00000001, _mace_ground.echoes[0].remaining))
		if mode in ["practice","combat"] and _hit_stop<=0:
			part = minf(part, _staff_ground.time_to_boundary())
			if sword_wave_buff_left > 0.0: part = minf(part, sword_wave_buff_left)
			if _dodge_left>.0000001:part=minf(part,_dodge_left)
			if primary_family()=="rifle" and active_magazine().bolt_active:
				part=minf(part,maxf(.00000001,(active_magazine().bolt_duration-active_magazine().bolt_elapsed)/attack_rate()))
			if motion.busy and not motion.is_great_charging() and not skill_active and not pair_strikes.active:
				var timing: Dictionary=motion.definition(motion.stage)
				part=minf(part,maxf(.00000001,(float(timing.windup+timing.active+timing.recovery)-motion.elapsed)/attack_rate()))
				if timing.get("kind") == "fire_lift" or (SkillTags.has_tag(timing, SkillTags.GROUND_IMPACT) and not _mace_ground.rift.is_empty()):
					var release_time: float = timing.windup + timing.active * timing.impact_progress
					if release_time > motion.elapsed + .00000001: part = minf(part, (release_time - motion.elapsed) / attack_rate())
				if weapon_family=="rifle":
					for boundary in [timing.windup,timing.windup+timing.active]:
						if float(boundary)>motion.elapsed+.00000001:part=minf(part,maxf(.00000001,(float(boundary)-motion.elapsed)/attack_rate()))
			if motion.busy and _storm_blade_can_release():
				var active_start: float = float(motion.definition(motion.stage).windup)
				if active_start > motion.elapsed + .00000001:
					part = minf(part, maxf(.00000001, (active_start - motion.elapsed) / attack_rate()))
			for magazine in [pistol_magazine,rifle_magazine]+item_magazines.values():
				if magazine.reloading:
					var boundary: float=magazine.next_boundary() if magazine.has_method("next_boundary") else magazine.reload_duration-magazine.elapsed
					part=minf(part,maxf(.00000001,boundary/reload_rate(magazine)))
		# Resolve real impact boundaries before expiring a fresh parry window.
		if mode in ["practice","combat"] and _hit_stop<=0:
			for window in [rewards.PERFECT_WINDOW,rewards.DODGE_IFRAMES]:
				var until: float=window-rewards.dodge_age
				if until>.0000001:part=minf(part,until)
			for window in [rewards.counter_left,rewards.combo_left]:
				if window>.0000001:part=minf(part,window)
			if rewards.can_perfect() or rewards.invulnerable():
				for projectile in projectiles:
					if not is_instance_valid(projectile.node):continue
					var contact: float=Enemy.Attacks.projectile_contact_time(projectile.node.position,projectile.direction,rewards.dodge_origin if rewards.can_perfect() else player.position)
					if is_finite(contact):part=minf(part,maxf(.000001,contact+.000001))
			if readiness.parry_left>.0000001:
				part=minf(part,readiness.parry_left)
				for projectile in projectiles:
					if not is_instance_valid(projectile.node):continue
					var contact: float=Enemy.Attacks.projectile_contact_time(projectile.node.position,projectile.direction,player.position)
					if is_finite(contact):part=minf(part,maxf(.000001,contact+.000001))
			for enemy in enemies:
				if not is_instance_valid(enemy) or enemy.dead:continue
				if enemy.has_method("next_boundary"):
					var enemy_boundary: float=enemy.next_boundary()
					if enemy_boundary>.0000001:part=minf(part,enemy_boundary)
				if enemy.kind in ["captain","spitter"]:part=minf(part,1.0/120) # Curved anchor and return hits share the gameplay clock.
				if enemy.state=="windup" and enemy.telegraph_left>.0000001:part=minf(part,enemy.telegraph_left)
				elif enemy.state=="attack" and enemy.active_left>.0000001:part=minf(part,enemy.active_left)
		if skill_active and mode in ["practice", "combat"]:
			if _hit_stop > 0:
				part = minf(part, _hit_stop)
			else:
				var definition: Dictionary = motion.definition(motion.stage)
				var until_end: float = definition.windup + definition.active + definition.recovery - motion.elapsed
				var rate := attack_rate()
				if active_skill_id == "armor_pierce":
					# Split at real contacts, so the thrust moves and resolves at its
					# visible contact pose even when one frame spans the whole cast.
					var boundaries: Array = [definition.windup, definition.windup + definition.active]
					if skill_cut_index == 1: boundaries.append(definition.windup + definition.active * definition.impact_progress)
					for boundary in boundaries:
						if boundary > motion.elapsed + .00000001: until_end = minf(until_end, boundary - motion.elapsed)
				if motion == _sword_skill_motion:
					for boundary in [definition.windup, definition.windup + definition.active * 0.5, definition.windup + definition.active]:
						if float(boundary) > motion.elapsed + .00000001: until_end = minf(until_end, float(boundary) - motion.elapsed)
				elif motion == _mace_skill_motion:
					var contact_time: float = definition.windup + definition.active * definition.impact_progress
					if contact_time > motion.elapsed + .00000001: until_end = minf(until_end, contact_time - motion.elapsed)
					if _mace_armor_parry_windup():
						until_end = MaceSkillMotion.ARMOR_COUNTER_WINDOW - motion.elapsed
						rate = 1.0
				part = minf(part, maxf(until_end / rate, .00000001))
		if pair_strikes.active and mode in ["practice", "combat"]:
			if _hit_stop > 0:
				part = minf(part,_hit_stop)
			else:
				var spec: Dictionary = motion.definition(motion.stage)
				var boundary: float = pair_strikes.handoff_time(spec) if pair_strikes.cursor==0 else float(spec.windup+spec.active+spec.recovery)
				part = minf(part,maxf((boundary-motion.elapsed)/attack_rate(),.00000001))
		_tick_frame(part)
		_dodge_step_protected=false
		if _room_fade != null: break
		remaining = maxf(0, remaining - part)

func _tick_frame(delta: float) -> void:
	# Surf is a separate player; synchronize before the paused-mode return.
	if encounter_mode=="wreck_shore" and is_instance_valid(arena):arena.surge.set_audio(audio.enabled and mode=="practice")
	if anatomy.leg_count()==0:
		_crawl_still=0.0 if _movement().length_squared()>.001 or _dodge_left>0 else minf(.25,_crawl_still+delta)
	else:_crawl_still=.25
	if not is_finite(delta) or delta <= 0: return
	_shake = maxf(0, _shake - delta * 0.65)
	if mode not in ["combat", "practice"]:
		if mode != "paused":
			fx.tick(delta)
			_visual_tick(delta)
		return
	run_time += delta
	_mace_ground.advance_rift(delta)
	mana = minf(stats.value("max_mana"), mana + stats.value("mana_regen") * delta)
	staff_energy.focus_left = maxf(0.0, staff_energy.focus_left - delta)
	var expiring_storm_rate := 0.0
	if motion.busy and sword_wave_buff_left <= delta and _storm_blade_has_current_sword():
		expiring_storm_rate = attack_rate()
	sword_wave_buff_left = maxf(0.0, sword_wave_buff_left - delta)
	mace_fire_buff_left = maxf(0.0, mace_fire_buff_left - delta)
	for id in sword_skill_cooldowns:
		sword_skill_cooldowns[id] = maxf(0.0, float(sword_skill_cooldowns[id]) - delta)
	if _coast_mode:arena.tick(delta)
	if encounter_mode=="wreck_shore" and not arena.intro_done():
		arena.apply_intro(self);_visual_tick(delta);return
	fx.tick(delta)
	casing_fx.tick(delta, camera)
	for rift_echo in _mace_ground.advance_echoes(delta):
		var generation := _mace_ground.generation
		_resolve_mace_rift_echo(rift_echo)
		if generation != _mace_ground.generation or mode not in ["practice", "combat"]: return
	if _hit_stop > 0:
		_hit_stop = maxf(0, _hit_stop - delta)
		_visual_tick(delta)
		return
	# Expire statuses at this simulation instant before any contact resolves.
	# Hitstop and paused modes reach neither this pass nor Enemy.tick.
	var staff_impacts := _staff_ground.advance(delta, camera)
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.has_method("advance_combat_status"):
			enemy.advance_combat_status(delta)
			if not enemy.dead and enemy.crossbow_wound_ticks > 0:
				enemy.crossbow_wound_time += delta
				while enemy.crossbow_wound_time >= 1.0 and enemy.crossbow_wound_ticks > 0 and not enemy.dead:
					enemy.crossbow_wound_time -= 1.0
					enemy.crossbow_wound_ticks -= 1
					enemy_hit(enemy, 5.0, Vector3.ZERO, "physical", -1.0, true, "", enemy.crossbow_wound_from_player)
	if _crossbow_loading != null:
		if not _crossbow_allowed(): _cancel_crossbow_load()
		elif _crossbow_loading.tick(delta * reload_rate()):
			_crossbow_loading = null
			audio.play("reload_done")
	readiness.tick(delta)
	_dodge_step_protected=rewards.invulnerable()
	rewards.advance(delta)
	if not skill_active and not motion.busy and not pair_strikes.active and rewards.combo_left<=0:
		_next_combo=0;motion.great_charge.clear_finisher()
	_sync_staff_key()
	if bow_charge >= 0.0:
		if _bow_allowed(): bow_charge = minf(BOW_FULL_TIME, bow_charge + delta * attack_rate())
		else: _cancel_bow()
	var staff_was_busy: bool=staff_energy.loading or staff_energy.casting
	var cast_was_ready: bool=staff_energy.cast_ready()
	var previous_staff_element: String=staff_energy.element
	var gained: int=staff_energy.advance(delta,Callable(self,"_staff_pay_unit"),attack_rate()) if primary_family()=="staff" else 0
	if staff_energy.element != previous_staff_element:
		var staff_tip := _staff_tip(_hand_pose(current_visual_sample()))
		fx.burst(staff_tip, staff_energy.ELEMENT_COLORS[staff_energy.element], 9)
		audio.play("ui")
	if gained>0:audio.play("staff_charge%d"%staff_energy.units)
	elif staff_energy.cast_ready() and not cast_was_ready:audio.play("staff_charge3")
	ground_fire.tick(delta,_player_attack_targets(),player.get_world_3d())
	mace_fire_lobs.tick(delta, camera, player.get_world_3d())
	var energy_busy: bool=_crossbow_loading != null or bow_charge >= 0.0 or _bow_recovery > 0.0 or motion.busy or pair_strikes.active or _dodge_left>0 or staff_was_busy or staff_energy.loading or staff_energy.casting or _staff_breath_ticks > 0 or (primary_family()=="rifle" and active_magazine().bolt_active)
	_hurt = maxf(0, _hurt - delta)
	_iframes = maxf(0, _iframes - delta)
	_dodge_recharge = maxf(0, _dodge_recharge - delta)
	_dodge_left = maxf(0, _dodge_left - delta)
	var before_energy: float=stamina
	stamina=energy.recover(stamina,delta,stats,energy_busy,right_action() in ["aim","guard"] or guns_reloading())
	if not anatomy.functional("torso"):stamina=before_energy+(stamina-before_energy)*.25
	health = flasks.advance(delta, health, max_health())
	health = minf(max_health(), health + stats.value("health_regen") * delta)
	var rifle_ready_this_frame:=false
	var current_mag=active_magazine()
	if primary_family()=="rifle" and current_mag.bolt_active:
		current_mag.tick_bolt(delta*attack_rate());rifle_ready_this_frame=not current_mag.bolt_active
	for magazine in [pistol_magazine, rifle_magazine] + item_magazines.values():
		if magazine is RifleCycle:
			magazine.rapid_fire_left = maxf(0.0, magazine.rapid_fire_left - delta)
		var was_reloading: bool=magazine.reloading
		var completed: bool=magazine.tick(delta*reload_rate(magazine)) if was_reloading else false
		if was_reloading and reload_visual.active and magazine==active_magazine() and not magazine.has_method("start_bolt"):
			for cue in reload_visual.events(magazine.progress()):audio.play(cue)
		if magazine.has_method("start_bolt"):_rifle_events(magazine)
		if completed:
			if magazine==current_mag and primary_family()=="rifle":rifle_ready_this_frame=true
			audio.play(reload_visual.family+"_reload_done" if reload_visual.active else "reload_done")
			reload_visual.cancel()
	var steering_mace: bool = skill_active and motion == _mace_skill_motion and _mace_skill_motion.can_steer_followup()
	var charging_mace := _mace_charge_slot >= 0
	_refresh_aim(steering_mace or charging_mace)
	var movement := _movement()
	if not motion.busy:
		_idle_time += delta
		_relax_idle_pose()
		if weapon_family in ["pistol", "rifle"] and active_magazine().rounds == 0: request_reload()
		if not rifle_ready_this_frame and _rifle_pending_fire and primary_family()=="rifle" and active_magazine().can_fire():
			_rifle_pending_fire=false;request_attack()
		elif _held and not rifle_ready_this_frame: request_attack()
	var prior_sample: Dictionary = _hand_pose(motion.sample())
	var motion_elapsed_before: float = motion.elapsed
	var motion_rate := expiring_storm_rate if expiring_storm_rate > 0.0 else attack_rate()
	if _mace_armor_parry_windup(): motion_rate = 1.0
	if steering_mace:
		_mace_skill_motion.steer_followup(atan2(aim.z, aim.x), delta * motion_rate)
	if charging_mace:
		_mace_skill_motion.steer_charge(atan2(aim.z, aim.x), delta)
	var step: Dictionary = motion.advance(delta if charging_mace else delta * motion_rate)
	if skill_active and active_skill_id == "square_off" and motion.stage == 0 and _sword_stance_branch >= 0 and motion.elapsed >= float(motion.definition(0).windup):
		_start_skill_stage(_sword_stance_branch)
		step = {"entered_active": false, "active": false, "damage_ready": false, "finished": false, "previous_angle": motion.aim_angle, "current_angle": motion.aim_angle}
	if _is_left_hand():
		for field in ["previous_angle","current_angle"]:step[field]=2*motion.aim_angle-float(step[field])
		for field in ["trail_from","trail_to","release_pose","contact_pose"]:
			if not step.get(field,{}).is_empty():step[field]=_hand_pose(step[field])
	var sample: Dictionary = _hand_pose(motion.sample())
	var sword_wave_release: Dictionary = {}
	if step.entered_active and _storm_blade_can_release():
		sword_wave_release = {"damage": _storm_blade_wave_damage[motion.stage],
			"projectile_speed": 12.0 * _storm_blade_wave_speed, "projectile_range": 7.0, "projectile_radius": .7}
	if skill_active and motion == _sword_skill_motion:
		var skill_definition: Dictionary = motion.definition(motion.stage)
		var lunge_limit: float = float(skill_definition.get("lunge_distance", 0.0))
		var lunge_window: bool = not skill_definition.get("windup_lunge", false) or motion_elapsed_before < float(skill_definition.windup) - 0.00000001
		if lunge_limit > 0.0 and lunge_window and anatomy.leg_count() > 0:
			var skill_direction := Vector3(cos(motion.aim_angle), 0, sin(motion.aim_angle))
			_sword_skill_lunge.advance(player, skill_direction, float(sample.get("lunge_offset", 0.0)), enemies, lunge_limit)
		if step.get("projectile_ready", false):
			sword_wave_release = skill_definition.duplicate()
			sword_wave_release.projectile_visual = "vacuum_wave" if active_skill_id == "vacuum_slice" else "sword_wave"
		if step.entered_active and active_skill_id == "storm_blade":
			sword_wave_buff_left = float(skill_definition.buff_duration)
			_storm_blade_item = active_item if loadout_mode else ""
			_storm_blade_wave_damage = skill_definition.wave_damage
			_storm_blade_wave_speed = float(skill_definition.wave_speed_multiplier)
			fx.ring(player.position, 1.0, Color(.3, .9, 1.0, .9), .35)
		if step.entered_active and skill_definition.kind == "thrust":
			fx.thrust_wind(player.position, motion.aim_angle, skill_definition.reach)
		if step.active and skill_definition.projectile and _trail_clock <= 0:
			fx.sword_edge(_hand_origin(), step.trail_from, step.trail_to, Color(.7, .95, 1.0, .8), .10)
			_trail_clock = .016
	if weapon_family=="rifle" and (motion.busy or step.finished) and active_magazine().needs_bolt:
		var rifle_spec: Dictionary=motion.definition(0)
		active_magazine().sync_bolt(maxf(0,motion.elapsed-rifle_spec.windup-rifle_spec.active));_rifle_events(active_magazine())
	var armor_stab := active_skill_id == "armor_pierce" and skill_cut_index == 1
	if armor_stab:
		_apply_armor_travel(step.get("contact_pose", sample).get("lunge_offset", 0.0))
	if anatomy.leg_count()>0:_attack_step.advance(player, motion.elapsed, motion.definition(motion.stage), enemies)
	attack_step_travelled = _attack_step.travelled
	var rifle_release: Dictionary = {}
	if weapon_family == "rifle" and motion.stage == 0:
		var retreat_releasing: bool = step.get("projectile_ready", false) and (
			motion.definition(0).get("rifle_finisher", false) or active_magazine().next_round().get("id") == RifleMotion.SCATTER_ROUND_ID)
		if not retreat_releasing:
			_apply_rifle_recoil(sample.get("recoil_offset", 0.0))
	if weapon_family in ["staff", "pistol", "rifle"] and step.get("projectile_ready", false):
		if weapon_family == "rifle":
			rifle_release = step.release_pose
		else:
			_release_ranged(step.release_pose)
	var mace_skill: bool = skill_active and motion == _mace_skill_motion
	if mace_skill:
		_advance_mace_skill(step, sample)
	var fire_lift: bool = weapon_family == "mace" and not mace_skill and motion.definition(motion.stage).get("kind") == "fire_lift"
	var ordinary_mace: bool = weapon_family == "mace" and not mace_skill and not fire_lift
	if fire_lift and step.has("ground_pose"):
		var scrape := _mace_head_at(step.ground_pose) + Vector3.UP * .025
		fx.mace_fire_scoop(scrape, _mace_scoop_mirrored(step.ground_pose), true)
		fx.mace_ember_spray(scrape, Vector3(cos(motion.aim_angle), 0.0, sin(motion.aim_angle)), .65, true)
	if fire_lift and step.damage_ready:
		_launch_mace_fire_lob(step.contact_pose)
	var mace_dash: bool = ordinary_mace and motion.stage == 1
	if mace_dash:
		var desired: float = sample.get("lunge_offset", 0.0)
		if step.get("damage_ready", false) and not step.get("contact_pose", {}).is_empty():
			desired = step.contact_pose.lunge_offset
		_apply_mace_travel(desired)
	if step.entered_active and armor_stab:
		fx.thrust_wind(player.position, motion.aim_angle, motion.definition(motion.stage).reach)
	if step.entered_active and not mace_skill and weapon_family not in ["staff", "pistol", "rifle"]:
		audio.play("sword" if weapon_family == "sword" else (("guard" if mace_dash else "heavy") if weapon_family == "mace" else ("heavy" if motion.stage == 2 else "sword")))
	if step.active and not mace_skill and weapon_family not in ["staff", "pistol", "rifle"] and not (skill_active and bool(motion.definition(motion.stage).get("projectile", false))):
		var definition: Dictionary = motion.definition(motion.stage)
		var blade_direction := Vector3(cos(step.current_angle), 0, sin(step.current_angle))
		var slam: bool = definition.get("kind", "sweep") == "slam"
		var vertical: bool = definition.get("kind", "sweep") in ["lift", "slam"]
		if _trail_clock <= 0 and armor_stab:
			fx.armor_thrust(player.position, motion.aim_angle, definition.reach)
			_trail_clock = .025
		elif _trail_clock <= 0 and skill_active and definition.kind == "thrust":
			fx.armor_thrust(player.position, motion.aim_angle, definition.reach)
			_trail_clock = .025
		elif _trail_clock <= 0 and skill_active and definition.get("spin", false):
			if active_skill_id != "stormcaller":
				var spin_origin := _hand_origin() + Vector3.UP * .72
				fx.sector(spin_origin, definition.reach, step.previous_angle, step.current_angle, Color(.65, .92, 1.0, .5), definition.reach * .72, .16)
				if active_skill_id == "spinning_slash":
					fx.spinning_slash_wisps(spin_origin, definition.reach, step.current_angle, step.trail_to.progress * definition.arc * definition.direction)
			_trail_clock = .016
		elif _trail_clock <= 0 and active_skill_id in ["twin_cut", "armor_pierce"]:
			fx.legacy_sword_trail(_hand_origin(), definition.reach, step.previous_angle, step.current_angle)
			_trail_clock = .02
		elif _trail_clock <= 0 and weapon_family == "sword":
			var edge_from: Dictionary = step.get("trail_from", {})
			var edge_to: Dictionary = step.get("trail_to", {})
			if skill_active and active_skill_id != "double_slash" and not edge_from.is_empty() and not edge_to.is_empty():
				fx.sword_edge(_hand_origin(), edge_from, edge_to, Color(1.0, 0.93, 0.74, 0.72), 0.07 if motion.stage == 2 else 0.055)
				fx.sword_swing_wind(_hand_origin(), edge_from, edge_to, motion.stage == 2)
			_trail_clock = 0.016
		elif _trail_clock <= 0 and vertical and not ordinary_mace:
			fx.blade_ribbon(_hand_origin(), motion.aim_angle, sample.radius, sample.blade_length, prior_sample.get("pitch", 0.0), sample.pitch, prior_sample.get("grip_height", 0.8), sample.grip_height, Color(1, 0.79, 0.42, 0.65), 0.11)
			_trail_clock = 0.016
		elif _trail_clock <= 0:
			var color := Color(1, 0.76, 0.32, 0.75) if motion.stage == 2 else Color(0.55, 0.95, 0.91, 0.7)
			var swing_sign: float = signf(float(step.current_angle) - float(step.previous_angle))
			if swing_sign != 0:
				fx.sector(_hand_origin() + Vector3(0, 0.68, 0), definition.reach, step.current_angle - swing_sign * 0.72, step.current_angle, color, definition.reach * 0.5, 0.12)
				fx.sector(_hand_origin() + Vector3(0, 0.69, 0), definition.reach, step.current_angle - swing_sign * 0.4, step.current_angle, Color(1, 1, 0.85, 0.9), definition.reach - 0.07, 0.09)
			_trail_clock = 0.02
		if step.get("damage_ready", step.active):
			var ground_impact := Vector3.INF
			var slam_hits: Dictionary = {}
			var impact_generation := _skill_generation
			var armor_stacks: int = definition.get("armor_stacks", 0)
			if encounter_mode == "dungeon" and is_instance_valid(arena.hazards):
				var root_ambush = arena.hazards.root_ambush
				if root_ambush != null and root_ambush.try_melee(_hand_origin(), motion, step.previous_angle, step.current_angle):
					audio.play("guard")
			if slam:
				var tip: Vector3 = _hand_origin() + Vector3(cos(motion.aim_angle), 0, sin(motion.aim_angle)) * definition.reach
				ground_impact = tip
				if ordinary_mace:
					var head := _mace_head_at(step.contact_pose)
					ground_impact = Vector3(head.x, player.position.y, head.z)
					_mace_impact_flash = fx.mace_impact_sprite(head, .88, MaceImpactVisual.Style.BASIC)
				else:
					fx.lane(_hand_origin(), motion.aim_angle, definition.reach, definition.width, Color(1, 0.78, 0.38, 0.24), 0.14)
					fx.burst(tip + Vector3(0, 0.07, 0), Color("#ffd18b"), 12)
				audio.play("slam")
				_shake = maxf(_shake, 0.025)
			for enemy in _player_attack_targets():
				if not _can_hit_player_target(enemy) or _hit_targets.has(enemy.get_instance_id()): continue
				if enemy is Companion and not _armor_line_clear(enemy): continue
				if active_skill_id == "armor_pierce" and not _armor_line_clear(enemy): continue
				if skill_active and motion == _sword_skill_motion and not _armor_line_clear(enemy): continue
				var region: String=_melee_contact_region(enemy,step)
				if region!="":
					_hit_targets[enemy.get_instance_id()] = true
					var force: float = definition.get("knockback", 7.0 if motion.stage == 2 else 3.5)
					if weapon_family == "sword" and not skill_active: force = 4.2 if motion.stage == 2 else 2.3
					var hit_direction: Vector3 = Vector3(cos(motion.aim_angle), 0, sin(motion.aim_angle)) if weapon_family == "mace" or slam else blade_direction
					if definition.get("radial", false): hit_direction = (enemy.position - player.position).normalized()
					var contact_generation := _skill_generation
					var contact_mode := mode
					var stagger: float = definition.get("stagger_duration", -1.0)
					if definition.has("repeat_target_stagger") and _double_slash_first_hits.has(enemy.get_instance_id()):
						stagger = float(definition.repeat_target_stagger)
					if weapon_family == "greatsword" and motion.stage == 2:
						stagger = float(definition.get("stagger", -1.0))
					var health_before: float = enemy.health
					var damage: float = definition.damage * (stats.talent_factor("melee_damage") if _is_normal_melee() else 1.0)
					enemy_hit(enemy, damage, hit_direction * force, "", stagger, false, region)
					if enemy is Companion:
						if ground_impact.is_finite(): _record_mace_slam_hit(slam_hits, enemy, health_before)
						continue
					if armor_stacks > 0 and _skill_generation == contact_generation and mode == contact_mode:
						_apply_skill_armor_stacks(enemy, health_before, armor_stacks)
					if ground_impact.is_finite(): _record_mace_slam_hit(slam_hits, enemy, health_before)
					if armor_stab:
						# Damage callbacks may cancel, kill, or restart the caster.
						# Only the same live cast may commit its post-damage break.
						if _skill_generation != contact_generation or mode != contact_mode or mode not in ["practice", "combat"] or active_skill_id != "armor_pierce" or skill_cut_index != 1:
							continue
						if is_instance_valid(enemy) and enemy.has_method("apply_armor_break") and enemy.apply_armor_break(.2, 4.0):
							fx.armor_break(enemy.position + Vector3.UP * .8)
					_hit_stop = (0.02 if mace_dash else 0.055) if weapon_family == "mace" else (0.065 if motion.stage == 2 else 0.035)
					_shake = (0.025 if mace_dash else 0.09) if weapon_family == "mace" else (0.11 if motion.stage == 2 else 0.045)
					if weapon_family == "sword":
						_hit_stop = 0.045 if motion.stage == 2 else 0.025
						_shake = .045 if skill_active else (0.035 if motion.stage == 2 else 0.018)
			var triggers_rift := weapon_family != "mace" or SkillTags.has_tag(definition, SkillTags.GROUND_IMPACT)
			if triggers_rift and ground_impact.is_finite() and impact_generation == _skill_generation:
				_trigger_mace_rift(ground_impact, slam_hits)
	if mace_dash:
		_apply_mace_travel(sample.get("lunge_offset", 0.0))
	if step.finished and not skill_active:
		if fire_lift: motion.finish_mace_fire_lift()
		if pair_strikes.active:
			# First hand is clipped at its recovery handoff, never completed here.
			if pair_strikes.cursor==1: pair_strikes.cancel()
		_next_combo = 0 if fire_lift else ((_loadout_attack_index + 1) % 3 if loadout_mode else (0 if weapon_family in ["staff", "pistol", "rifle"] else (motion.stage + 1) % 3))
		rewards.combo_left=rewards.CHAIN_WINDOW
		_idle_time = 0
		if weapon_family in ["pistol", "rifle"] and active_magazine().rounds == 0: request_reload()
	_trail_clock -= delta
	_range_clock -= delta
	if debug_range and not mace_skill and motion.busy and _range_clock <= 0:
		var definition: Dictionary = motion.definition(motion.stage)
		if weapon_family in ["staff", "pistol", "rifle"]:
			var muzzle := _staff_tip(sample)
			var start := Vector3(muzzle.x, player.position.y, muzzle.z)
			var angle: float = motion.aim_angle
			if weapon_family == "rifle" and definition.get("rifle_aimed", false):
				var line := aimed_rifle_line(sample)
				start = line.origin - Vector3.UP * .036
				angle = atan2(line.direction.z, line.direction.x)
				var round_id: String = RifleMotion.FINISHER_ID if definition.get("rifle_finisher", false) else active_magazine().next_round().get("id", "")
				definition.merge(rifle_projectile_profile(round_id), true)
			for offset: float in definition.get("scatter_angles", [0.0]):
				fx.lane(start, angle + deg_to_rad(offset), definition.projectile_range, definition.projectile_radius * 2.0, Color(1.0, 0.53, 0.2, 0.16), 0.06)
		elif definition.get("kind", "sweep") in ["lift", "lunge", "slam"]:
			fx.lane(_hand_origin(), motion.aim_angle, definition.reach, definition.width, Color(0.3, 0.9, 0.8, 0.14), 0.06)
		else:
			fx.sector(_hand_origin() + Vector3(0, 0.035, 0), definition.reach, motion.aim_angle - definition.arc * 0.5, motion.aim_angle + definition.arc * 0.5, Color(0.3, 0.9, 0.8, 0.14), 0.3, 0.06)
		_range_clock = 0.04
	var speed: float = 4.7
	if motion.busy: speed = 0.5 if sample.phase == "active" else 1.0
	if motion.is_great_charging():speed=4.7*.55
	if weapon_family == "mace" and (motion.busy or step.finished): speed = 0.0
	if weapon_family == "rifle" and (motion.busy or step.finished): speed = 0.0
	if armor_stab: speed = 0.0
	if skill_active:
		speed = 1.4 if active_skill_id == "square_off" and motion.stage == 0 else 0.0
		if _mace_charge_slot >= 0: speed = MACE_CHARGE_WALK_SPEED
	if staff_energy.loading or staff_energy.casting or bow_charge >= 0.0 or _crossbow_loading != null:speed=minf(speed,4.7*.55)
	if _staff_breath_ticks > 0: speed = minf(speed, 4.7 * .45)
	if _bow_recovery > 0.0:
		speed = 0.0
		_bow_recovery = maxf(0.0, _bow_recovery - delta)
		if _bow_shot_direction != Vector3.ZERO:
			var progress := 1.0 - _bow_recovery / BOW_RETREAT_TIME
			_bow_retreat.advance(player, -_bow_shot_direction, BOW_RETREAT_DISTANCE * ease(progress, 0.6), enemies, BOW_RETREAT_DISTANCE)
	if right_action()=="aim":speed=minf(speed,4.7*.55)
	elif right_action()=="guard":speed=minf(speed,4.7*.45)
	if readiness.broken_left>0:speed=minf(speed,4.7*.25)
	if anatomy.leg_count()==0 and (motion.busy or staff_energy.loading or staff_energy.casting or _staff_breath_ticks > 0 or guns_reloading() or right_action()!=""):speed=0
	player.velocity = movement * speed*stats.value("move_speed")*anatomy.move_multiplier()
	if encounter_mode == "dungeon" and is_instance_valid(arena.hazards):
		player.velocity *= arena.hazards.speed_scale(player.global_position)
	if _dodge_left > 0: player.velocity = _dodge_dir * rewards.DODGE_SPEED * anatomy.dash_multiplier() * stats.talent_factor("dash_distance")
	player.velocity.y = -2
	player.move_and_slide()
	if skill_active and active_skill_id == "stormcaller" and not step.active:
		_advance_storm_step(movement, motion_elapsed_before)
	if _coast_mode:player.position=arena.clamp_point(player.position)
	elif encounter_mode!="dungeon":
		player.position.x = clampf(player.position.x, -11.6, 11.6)
		player.position.z = clampf(player.position.z, -9.0, 9.0)
	if skill_active and active_skill_id == "stormcaller" and step.active:
		fx.stormcaller_ring(player.global_position, sample.effect_radius, sample.angle, motion.stage == 2)
	# Recoil's swept movement can leave a tiny vertical floor correction for
	# move_and_slide. Fire from the settled rifle muzzle shown this same frame.
	if not rifle_release.is_empty():
		_release_ranged(rifle_release)
	party_mark_left = maxf(0.0, party_mark_left - delta)
	if is_instance_valid(party_mark_target) and party_mark_target.dead: _clear_party_mark()
	for companion in companions: companion.tick(delta, self)
	brine_zones.tick(delta,self)
	_enemy_tick_phase=true
	var snapshot := enemies.duplicate()
	_crowd_index_active=encounter_mode=="dungeon" and snapshot.size()>20
	if _crowd_index_active:_crowd_neighbors.rebuild(snapshot)
	for index in snapshot.size():
		var enemy = snapshot[index]
		if not is_instance_valid(enemy): continue
		if enemy.has_method("advance_combat_status"):
			enemy.tick(delta, self, false)
		else:
			enemy.tick(delta, self)
		if _crowd_index_active:_crowd_neighbors.refresh(index)
		if enemy.dead and enemy.death_time > 0.75:
			enemies.erase(enemy)
			enemy.queue_free()
	_enemy_tick_phase=false
	_crowd_index_active=false
	_update_projectiles(delta)
	_resolve_staff_ground_impacts(staff_impacts)
	var breath_was_active := _staff_breath_ticks > 0
	_advance_staff_breath(delta)
	staff_flight.tick(delta, enemies, get_world_3d(), Callable(), camera, companions)
	if not sword_wave_release.is_empty() and mode in ["practice", "combat"]:
		_release_sword_wave(sword_wave_release)
	if mode == "practice" and encounter_mode not in ["village_study","coast_forms","wreck_shore"]:
		if not motion.busy and not breath_was_active and staff_impacts.is_empty():
			_dummy_idle += delta
			if _dummy_idle > 0.2:
				for enemy in enemies:
					if enemy.kind == "dummy" and not enemy.dead and enemy.health < enemy.max_health:
						enemy.health = enemy.max_health
						enemy.update_bar()
		if enemies.is_empty():
			if encounter_mode=="captain":mode="victory";_cancel_body_actions();ui.show_mode(mode)
			else:spawn_enemy(drill_kind if drill_kind!="" else "dummy",Vector3(2.4 if drill_kind!="" else 2,.03,0))
	elif mode == "combat" and encounter_mode=="coast":
		coast.tick(delta,self)
	elif mode == "combat" and encounter_mode=="dungeon":
		dungeon.tick(self, delta)
	elif mode == "combat":
		var living: int = 0
		for enemy in enemies:
			if not enemy.dead: living += 1
		if living == 0:
			_wave_wait += delta
			if _wave_wait > 1.0:
				if wave >= 3:
					_cancel_skill()
					mode = "victory"
					fx.clear_transients()
					_reset_attack_step()
					staff_flight.clear()
					ground_fire.clear()
					_staff_ground.clear()
					_mace_ground.clear()
					mace_fire_lobs.clear()
					mace_fire_buff_left = 0.0
					casing_fx.clear()
					reset_gun_magazines()
					_held = false
					audio.play("victory")
					ui.show_mode(mode)
				else:
					spawn_wave()
	_advance_revive(delta)
	if mace_skill and skill_active and not motion.busy and skill_cut_index == 0 and not _mace_skill_motion.definition(1).is_empty():
		_start_skill_stage(1)
	_visual_tick(delta)
	_finish_skill_cut()
	_advance_paired_hand()
	if pending_set >= 0 and not pair_strikes.active and not motion.busy and not skill_active and not guns_reloading():
		var destination := pending_set
		pending_set = -1
		activate_loadout(destination)

func _reset_attack_step() -> void:
	_attack_step.reset()
	melee_approach_plan.clear()
	attack_step_travelled = 0.0

func _advance_storm_step(movement: Vector3, elapsed_before: float) -> void:
	if motion.stage >= 2 or anatomy.leg_count() == 0: return
	var sweep: Dictionary = motion.definition(motion.stage)
	var recovery_start: float = sweep.windup + sweep.active
	if elapsed_before + 0.00000001 < recovery_start or motion.elapsed <= recovery_start: return
	if _storm_step_direction.is_zero_approx():
		if movement.length_squared() < 0.001: return
		_storm_step_direction = movement.normalized()
		_storm_step_start = maxf(recovery_start, elapsed_before)
		_sword_skill_lunge.reset()
	var distance: float = STORM_STEP_DISTANCE * anatomy.dash_multiplier()
	if encounter_mode == "dungeon" and is_instance_valid(arena.hazards):
		distance *= arena.hazards.speed_scale(player.global_position)
	var progress := clampf((motion.elapsed - _storm_step_start) / STORM_STEP_DURATION, 0.0, 1.0)
	var eased := 1.0 - (1.0 - progress) * (1.0 - progress)
	_sword_skill_lunge.advance(player, _storm_step_direction, distance * eased, enemies, distance)

func _armor_line_clear(enemy) -> bool:
	var query := PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP * .68, enemy.global_position + Vector3.UP * .68, 1)
	query.hit_from_inside = true
	return player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _apply_skill_armor_stacks(enemy, health_before: float, amount: int, fill: bool = false) -> void:
	if is_instance_valid(enemy) and enemy.health < health_before and enemy.apply_mace_break(amount, fill):
		var contact: Vector3 = enemy.position + Vector3.UP * .8
		fx.armor_break(contact, enemy.position)
		if fill:
			fx.burst(contact, Color("#ffe6ad"), 13, enemy.position)

func _advance_mace_skill(step: Dictionary, sample: Dictionary) -> void:
	var spec: Dictionary = _mace_skill_motion.definition(motion.stage)
	if active_skill_id == "mace_earth_wave":
		var distance := _mace_leap_offset.length()
		if distance > 0.0:
			_sword_skill_lunge.advance(player, _mace_leap_offset, distance * smoothstep(0.0, 1.0, _mace_leap_progress()), [], distance)
		if step.damage_ready: _land_mace_leap(step.contact_pose, spec)
		return
	if spec.lunge_distance > 0.0 and anatomy.leg_count() > 0:
		var forward := Vector3(cos(motion.aim_angle), 0, sin(motion.aim_angle))
		_sword_skill_lunge.advance(player, forward, float(sample.lunge_offset), enemies, float(spec.lunge_distance))
	if not step.damage_ready: return
	if spec.get("fire_buff", false):
		mace_fire_buff_left = MaceSkillMotion.FIRE_BUFF_DURATION
		_mace_fire_lift_damage = spec.lift_damage
		_mace_fire_blast_damage = spec.blast_damage
		_mace_fire_next_side = 0
		fx.burst(_mace_head_at(step.contact_pose), Color("#ffad65"), 12, player.position)
		audio.play("fire_cast")
		return
	var center: Vector3 = _mace_skill_motion.area_center(player.position, step.contact_pose)
	var angle: float = motion.aim_angle
	var places_rift := spec.has("rift_radius")
	var ground_impact := SkillTags.has_tag(spec, SkillTags.GROUND_IMPACT)
	if places_rift and not _mace_ground_line_clear(player.position, center): return
	var half_arc: float = spec.arc * .5
	var radius: float = spec.area_radius
	var color := Color("#ffd19a") if motion.stage == 1 else Color("#efa467")
	var pulling: bool = spec.get("gathers", false)
	if pulling: color = Color("#8de0cf")
	if places_rift: color = Color("#74bfae")
	if active_skill_id == "mace_impact":
		_mace_impact_flash = fx.mace_impact_sprite(center, radius)
	elif active_skill_id == "mace_double_impact":
		var style := MaceImpactVisual.Style.DOUBLE_FINISHER if motion.stage == 1 else MaceImpactVisual.Style.DOUBLE_START
		_mace_impact_flash = fx.mace_impact_sprite(center, radius, style)
	elif active_skill_id not in ["mace_sweep", "mace_gather", "mace_aftershock"]:
		fx.sector(center + Vector3.UP * .045, radius, angle - half_arc, angle + half_arc, Color(color, .20), 0.0, .20)
		fx.sector(center + Vector3.UP * .055, radius, angle - half_arc, angle + half_arc, Color(color, .80), radius - .09, .25)
	if spec.kind == "slam":
		fx.burst(center + Vector3.UP * .08, color, 16, center)
	match active_skill_id:
		"mace_sweep":
			fx.burst(_mace_head_at(step.contact_pose), color, 7 if motion.stage == 1 else 4, player.position)
		"mace_gather":
			_mace_impact_flash = fx.mace_ground_contact(center, minf(radius, 1.35), .53)
			fx.mace_pull_vortex(center, radius)
		"mace_aftershock":
			_mace_impact_flash = fx.mace_ground_contact(center, 1.2, .53)
		"mace_armor_counter":
			fx.burst(_mace_head_at(step.contact_pose), Color("#dcf4ff"), 7, player.position)
	audio.play("heavy")
	_shake = maxf(_shake, .07 if spec.kind == "slam" else .045)
	var generation := _skill_generation
	var direct_hits: Dictionary = {}
	var armor_stacks: int = spec.get("armor_stacks", 0)
	for enemy in _player_attack_targets():
		if not _can_hit_player_target(enemy) or not _mace_skill_motion.area_contains(center, enemy.position): continue
		if not _armor_line_clear(enemy): continue
		if (places_rift or pulling) and not _mace_ground_line_clear(center, enemy.position): continue
		var outward: Vector3 = enemy.position - center
		outward.y = 0.0
		var health_before: float = enemy.health
		enemy_hit(enemy, spec.damage, outward.normalized() * float(spec.knockback), "physical")
		if generation != _skill_generation: return
		if enemy is Companion:
			if ground_impact: _record_mace_slam_hit(direct_hits, enemy, health_before)
			continue
		if armor_stacks > 0 and is_instance_valid(enemy):
			_apply_skill_armor_stacks(enemy, health_before, armor_stacks, enemy.get_instance_id() == _mace_parried_attacker_id)
		if ground_impact: _record_mace_slam_hit(direct_hits, enemy, health_before)
		if pulling and is_instance_valid(enemy) and not enemy.dead and enemy.health < health_before:
			var slow_fraction: float = spec.slow_fraction
			enemy.apply_movement_slow(slow_fraction, MaceSkillMotion.GATHER_SLOW_DURATION)
			enemy.gather_to(center)
		_hit_stop = maxf(_hit_stop, .035)
	if places_rift:
		var rift_radius: float = spec.rift_radius
		var cracks: Sprite3D = fx.mace_rift_decal(center, rift_radius, angle, MaceRiftVisual.Phase.PLACEMENT, .18)
		_mace_ground.place_rift(center, rift_radius, cracks, angle)
	elif ground_impact:
		_trigger_mace_rift(center, direct_hits)

func _mace_leap_landing(grade: int) -> Vector3:
	var origin: Vector3 = player.position
	var dash_count: float = MaceSkillMotion.LEAP_GRADES[grade - 1].dash_count
	if dash_count == 0.0 or anatomy.leg_count() == 0: return origin
	var max_distance: float = dash_count * rewards.DODGE_SPEED * DashVisual.DURATION
	var destination := origin + aim * max_distance
	if test_aim.length_squared() <= .001:
		var ray_origin := camera.project_ray_origin(_mouse_position)
		var ray := camera.project_ray_normal(_mouse_position)
		if absf(ray.y) > .001:
			destination = ray_origin + ray * ((origin.y - ray_origin.y) / ray.y)
	var offset := destination - origin
	offset.y = 0.0
	destination = origin + offset.limit_length(max_distance)
	if _coast_mode:
		destination = arena.clamp_point(destination)
	elif encounter_mode != "dungeon":
		destination.x = clampf(destination.x, -11.6, 11.6)
		destination.z = clampf(destination.z, -9.0, 9.0)
	offset = destination - origin
	offset.y = 0.0
	var collision := KinematicCollision3D.new()
	if player.test_move(player.global_transform, offset, collision, .001) and collision.get_normal().y < .7:
		return origin + offset.normalized() * clampf(collision.get_travel().dot(offset.normalized()), 0.0, offset.length())
	return origin + offset

func _mace_leap_angle(offset: Vector3) -> float:
	var direction := aim if offset.is_zero_approx() else offset
	return atan2(direction.z, direction.x)

func _update_mace_charge_preview() -> void:
	if _mace_charge_slot < 0 or mode not in ["practice", "combat"]: return
	var grade: int = _mace_skill_motion.charge_grade()
	var footprint: Dictionary = _mace_skill_motion.charge_footprint()
	if active_skill_id == "mace_gather":
		var contact := _hand_pose(_mace_skill_motion.charge_contact_pose())
		var center: Vector3 = _mace_skill_motion.area_center(player.position, contact)
		_mace_ground.show_charge_preview(fx, center, 0.0, footprint, grade)
	else:
		var landing := _mace_leap_landing(grade)
		var angle := _mace_leap_angle(landing - player.position)
		_mace_ground.show_charge_preview(fx, landing, angle, footprint, grade)

func _mace_leap_progress() -> float:
	var spec: Dictionary = _mace_skill_motion.definition(0)
	var contact_time: float = spec.windup + spec.active * spec.impact_progress
	return clampf(_mace_skill_motion.elapsed / contact_time, 0.0, 1.0)

func _land_mace_leap(contact_pose: Dictionary, spec: Dictionary) -> void:
	var center: Vector3 = player.position
	var impact := _mace_head_at(contact_pose)
	var color := MaceGroundEffects.LEAP_COLOR
	var angle: float = motion.aim_angle
	var strength := inverse_lerp(MaceSkillMotion.LEAP_GRADES[0].arc, MaceSkillMotion.LEAP_GRADES[2].arc, float(spec.arc))
	_mace_impact_flash = fx.mace_ground_contact(impact, lerpf(1.15, 1.65, strength), lerpf(.68, .95, strength))
	fx.mace_leap_wave(center, spec.area_radius, angle, spec.arc, strength)
	fx.burst(impact + Vector3.UP * .08, color, 24, center)
	audio.play("slam")
	_shake = maxf(_shake, .15)
	var direct_hits: Dictionary = {}
	var generation := _skill_generation
	for enemy in _player_attack_targets():
		if not _can_hit_player_target(enemy): continue
		var outward: Vector3 = enemy.position - center
		if absf(outward.y) > 1.0: continue
		outward.y = 0.0
		var distance_squared := outward.length_squared()
		if not _mace_skill_motion.area_contains(center, enemy.position) or not _mace_ground_line_clear(center, enemy.position): continue
		var damage: float = spec.damage if distance_squared <= float(spec.core_radius) ** 2 else spec.edge_damage
		var health_before: float = enemy.health
		enemy_hit(enemy, damage, outward.normalized() * float(spec.knockback), "physical", spec.stagger_duration)
		if generation != _skill_generation or mode not in ["practice", "combat"]: return
		_record_mace_slam_hit(direct_hits, enemy, health_before)
		_hit_stop = maxf(_hit_stop, .045)
	if SkillTags.has_tag(spec, SkillTags.GROUND_IMPACT):
		_trigger_mace_rift(impact, direct_hits)

func _record_mace_slam_hit(hit_damage: Dictionary, enemy, health_before: float) -> void:
	if _can_hit_player_target(enemy) and enemy.health < health_before:
		hit_damage[enemy.get_instance_id()] = health_before - enemy.health

func _trigger_mace_rift(impact: Vector3, hit_damage: Dictionary) -> void:
	if not _mace_ground.can_trigger_rift(impact): return
	var center: Vector3 = _mace_ground.rift.center
	if not _mace_ground_line_clear(_hand_origin(), impact) or not _mace_ground_line_clear(impact, center): return
	fx.mace_rift_decal(center, _mace_ground.rift.radius, _mace_ground.rift.angle, MaceRiftVisual.Phase.CHARGE, MaceGroundEffects.RIFT_ECHO_DELAY)
	_mace_ground.queue_rift_echo(hit_damage)

func _resolve_mace_rift_echo(echo: Dictionary) -> void:
	var center: Vector3 = echo.center
	var radius: float = echo.radius
	var color := Color("#bff1df")
	var deals_damage: bool = not echo.hit_damage.is_empty()
	fx.mace_rift_decal(center, radius, echo.angle, MaceRiftVisual.Phase.ECHO, .38)
	fx.burst(center + Vector3.UP * .10, Color("#6b8f80"), 12, center)
	fx.burst(center + Vector3.UP * .18, color, 16, center)
	_shake = maxf(_shake, .135 if deals_damage else .07)
	audio.play("nova")
	var generation := _mace_ground.generation
	for enemy in _player_attack_targets():
		if not _can_hit_player_target(enemy): continue
		var dealt: float = echo.hit_damage.get(enemy.get_instance_id(), 0.0)
		if dealt <= 0.0: continue
		if enemy is Companion:
			var offset: Vector3 = enemy.position - center
			if Vector2(offset.x, offset.z).length_squared() > radius * radius: continue
			if not _mace_ground_line_clear(center, enemy.position): continue
		fx.burst(enemy.position + Vector3.UP * .65, color, 6, enemy.position)
		if enemy is Companion:
			_apply_friendly_damage(enemy, dealt * MaceGroundEffects.RIFT_DAMAGE_FRACTION)
		else:
			_apply_enemy_hit(enemy, dealt * MaceGroundEffects.RIFT_DAMAGE_FRACTION, Vector3.ZERO, "physical")
		if generation != _mace_ground.generation or mode not in ["practice", "combat"]: return

func _mace_ground_line_clear(from: Vector3, to: Vector3) -> bool:
	if from.is_equal_approx(to): return true
	var query := PhysicsRayQueryParameters3D.create(from + Vector3.UP * .4, to + Vector3.UP * .4, 1)
	query.hit_from_inside = true
	return player.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _mace_head_at(pose: Dictionary) -> Vector3:
	var direction := Vector3(cos(pose.angle), 0.0, sin(pose.angle))
	var weapon_axis := direction * cos(pose.pitch) + Vector3.UP * sin(pose.pitch)
	return _hand_origin() + direction * float(pose.radius) + Vector3.UP * float(pose.grip_height) + weapon_axis * float(pose.blade_length)

func _mace_scoop_mirrored(pose: Dictionary) -> bool:
	var tangent := Vector3(-sin(pose.angle), 0, cos(pose.angle))
	if motion.stage == 1: tangent = -tangent
	return tangent.dot(camera.global_basis.x) < 0.0

func _launch_mace_fire_lob(pose: Dictionary) -> void:
	var origin := _mace_head_at(pose)
	if not _mace_ground_line_clear(player.position, origin): return
	_mace_fire_scoop_flash = fx.mace_fire_scoop(origin, _mace_scoop_mirrored(pose))
	var angle: float = motion.aim_angle + shot_rng.randf_range(-.105, .105)
	var distance: float = MaceFireLobs.LANDING_DISTANCE + shot_rng.randf_range(-.35, .35)
	var direction := Vector3(cos(angle), 0.0, sin(angle))
	var target := player.position + direction * distance + Vector3.UP * .04
	mace_fire_lobs.launch(origin, target, direction, camera, _mace_fire_blast_damage)

func _mace_fire_impact(point: Vector3, direct: Node3D, hit_ids: Dictionary, damage: float) -> void:
	if mode not in ["practice", "combat"]: return
	if direct != null:
		fx.mace_fire_scoop(point, false)
	audio.play("fire_impact")
	var generation := _mace_ground.generation
	for enemy in _player_attack_targets():
		if not _can_hit_player_target(enemy): continue
		var target_id: int = enemy.get_instance_id()
		if hit_ids.has(target_id): continue
		var offset: Vector3 = enemy.position - point
		var height_difference := absf(offset.y)
		offset.y = 0.0
		if enemy != direct and (height_difference > 1.3 or offset.length_squared() > (MaceFireLobs.BLAST_RADIUS * stats.talent_factor("skill_area")) ** 2
			or not _mace_ground_line_clear(point, enemy.position)): continue
		hit_ids[target_id] = true
		enemy_hit(enemy, damage, offset.normalized(), "fire")
		if generation != _mace_ground.generation or mode not in ["practice", "combat"]: return

func _apply_armor_travel(desired: float) -> void:
	if anatomy.leg_count()==0:return
	var direction := Vector3(cos(motion.aim_angle), 0, sin(motion.aim_angle))
	# The arena also has authored play bounds inside the wall colliders.
	# Clip the swept distance before moving, so telemetry never counts a
	# displacement that the later common player clamp would undo.
	var limit := .65
	if absf(direction.x) > .000001:
		var edge_x := 11.6 if direction.x > 0 else -11.6
		limit = minf(limit, _armor_lunge.travelled + maxf(0, (edge_x - player.position.x) / direction.x))
	if absf(direction.z) > .000001:
		var edge_z := 9.0 if direction.z > 0 else -9.0
		limit = minf(limit, _armor_lunge.travelled + maxf(0, (edge_z - player.position.z) / direction.z))
	_armor_lunge.advance(player, direction, desired, enemies, limit)
	armor_lunge_travelled = _armor_lunge.travelled

func _apply_mace_travel(desired: float) -> void:
	if anatomy.leg_count()==0:return
	var direction := Vector3(cos(motion.aim_angle), 0, sin(motion.aim_angle))
	var before: float = _short_lunge.travelled
	var authored_limit: float = motion.definition(1).get("lunge_distance", 0.75)
	var limit := authored_limit
	if melee_approach_plan.get("assisted", false):
		limit = melee_approach_plan.distance
		desired *= limit / authored_limit
	_short_lunge.advance(player, direction, desired, enemies, limit)
	mace_dash_travelled = _short_lunge.travelled
	if _short_lunge.travelled > before + 0.001 and _trail_clock <= 0:
		fx.burst(player.position + Vector3(0, 0.06, 0), Color(0.55, 0.62, 0.61, 0.5), 2)
		_trail_clock = 0.04

func _staff_tip(pose: Dictionary) -> Vector3:
	# The same rigid vector drives the sprite endpoints and the launch point.
	var direction := Vector3(cos(float(pose.angle)), 0, sin(float(pose.angle)))
	return _hand_origin() + direction * float(pose.radius) + Vector3.UP * float(pose.grip_height) + (direction * cos(float(pose.pitch)) + Vector3.UP * sin(float(pose.pitch))) * float(pose.blade_length)

func _release_sword_wave(definition: Dictionary) -> void:
	var direction := Vector3(cos(motion.aim_angle), 0, sin(motion.aim_angle))
	var origin := player.position + Vector3.UP * .75
	var projectile := definition.duplicate()
	projectile.element = "physical"
	projectile.projectile_visual = definition.get("projectile_visual", "sword_wave")
	projectile.launch_origin = origin
	if projectile.projectile_visual == "vacuum_wave":
		projectile.wake_ground_y = player.global_position.y
	projectile.knockback = 2.0
	staff_flight.spawn_fireball(origin + direction * .65, direction, projectile, camera)
	audio.play("sword")

func _storm_blade_can_release() -> bool:
	return not skill_active and _storm_blade_has_current_sword()

func _storm_blade_has_current_sword() -> bool:
	return sword_wave_buff_left > 0.0 and weapon_family == "sword" and _storm_blade_item == (active_item if loadout_mode else "")

func _storm_blade_single_item() -> String:
	if not loadout_mode or _storm_blade_item.is_empty(): return ""
	# Let the last one-handed cut finish with the same grip if the buff expires mid-swing.
	var finishing_swing: bool = _storm_blade_single_swing and motion.busy and not skill_active and active_item == _storm_blade_item
	if sword_wave_buff_left <= 0.0 and not finishing_swing: return ""
	if not loadout.for_pair().has(_storm_blade_item) or not _body_item_usable(_storm_blade_item): return ""
	return _storm_blade_item

func _storm_blade_coated_rig() -> Node3D:
	if not loadout_mode:
		return avatar if _storm_blade_item.is_empty() and weapon_family == "sword" else null
	if _storm_blade_item.is_empty(): return null
	if dual_visual.visible:
		var pair: Dictionary = loadout.sets[loadout.active]
		if _storm_blade_item == pair.main: return dual_visual.rigs[0]
		if _storm_blade_item == pair.off: return dual_visual.rigs[1]
	elif _storm_blade_item == active_item:
		return avatar
	return null

func _apply_rifle_recoil(desired: float) -> void:
	if anatomy.leg_count()==0:return
	var backwards := -Vector3(cos(motion.aim_angle), 0, sin(motion.aim_angle))
	var definition: Dictionary = motion.definition(0)
	var limit := float(definition.get("recoil_distance", .22))
	if _rifle_retreat_distance > 0.0:
		limit = _rifle_retreat_distance
		var duration := DashVisual.DURATION * (1.5 if definition.get("rifle_finisher", false) else 1.0)
		var progress := (float(motion.elapsed) - float(definition.windup)) / duration
		desired = limit * smoothstep(0.0, 1.0, progress)
	_rifle_recoil.advance(player, backwards, desired, enemies, limit)
	rifle_recoil_travelled = _rifle_recoil.travelled

func active_magazine():
	if loadout_mode and item_magazines.has(active_item): return item_magazines[active_item]
	return rifle_magazine if weapon_family == "rifle" else pistol_magazine

func guns_reloading() -> bool:
	if loadout_mode: return active_magazine().reloading
	return pistol_magazine.reloading or rifle_magazine.reloading

func reset_gun_magazines() -> void:
	_rifle_target_origin = Vector3.INF
	_rifle_release_height = INF
	reload_visual.cancel()
	if is_instance_valid(ui): ui.reset_rifle_gears()
	if is_instance_valid(rifle_scope): rifle_scope.zoom = 0.0
	for magazine in item_magazines.values(): magazine.reset()
	pistol_magazine.reset()
	rifle_magazine.reset()
	_rifle_recoil.reset()
	rifle_recoil_travelled = 0

func _aimed_rifle_muzzle(authored_muzzle: Vector3) -> Vector3:
	if not avatar.rifle_raised_aim: return authored_muzzle
	var art_tip: Vector3 = avatar.get_blade_points().tip
	var view_axis := camera.global_basis.z.normalized()
	# Resolve the drawn muzzle on the same level shot plane in every view.
	# Moving along the view axis preserves its exact position on screen.
	if absf(view_axis.y) < .001: return authored_muzzle
	return art_tip + view_axis * ((rifle_cursor_height() - art_tip.y) / view_axis.y)

func aimed_rifle_line(pose: Dictionary) -> Dictionary:
	var muzzle := _aimed_rifle_muzzle(_staff_tip(pose))
	var direction := Vector3(cos(motion.aim_angle), 0, sin(motion.aim_angle))
	var target := _point_on_cursor_ray(_rifle_target_origin, _rifle_target_ray, muzzle.y)
	if target.is_finite():
		var toward := target - muzzle
		toward.y = 0.0
		if toward.dot(direction) > .05: direction = toward.normalized()
	return {"origin": muzzle, "direction": direction}

func _release_ranged(pose: Dictionary) -> void:
	if not active_weapon_possible():return
	if weapon_family in ["pistol","rifle"] and not active_magazine().can_fire():return
	var definition: Dictionary = motion.definition(0)
	var next_round: Dictionary = active_magazine().next_round() if weapon_family == "rifle" else {}
	var finisher := bool(definition.get("rifle_finisher", false))
	var round_id: String = RifleMotion.FINISHER_ID if finisher else next_round.get("id", "")
	var round_skill: Dictionary = RifleMotion.SKILLS.get(round_id, {})
	var first_special_round := not finisher and not next_round.is_empty() and not bool(next_round.fired)
	if weapon_family == "rifle":
		definition.merge(rifle_projectile_profile(round_id, active_item if loadout_mode else ""), true)
		definition.block_on_ally = round_id.is_empty()
	if not round_skill.is_empty():
		definition.tracer_color = round_skill.color
		if int(definition.max_targets) == 1:
			definition.erase("pierce_after_exit")
	# A physics step can end slightly past release, already showing recoil.
	# Start a normal bullet at that visible muzzle; hitches crossing the whole
	# release interval retain the exact authored release snapshot.
	if weapon_family in ["pistol", "rifle"] and motion.sample().phase == "active":
		pose = _hand_pose(motion.sample())
	var muzzle := _staff_tip(pose)
	var direction := Vector3(cos(motion.aim_angle), 0, sin(motion.aim_angle))
	var scatter := round_id == RifleMotion.SCATTER_ROUND_ID
	var aimed_rifle := weapon_family == "rifle" and bool(definition.get("rifle_aimed", false))
	if aimed_rifle:
		var line := aimed_rifle_line(pose)
		muzzle = line.origin
		direction = line.direction
		_rifle_release_height = muzzle.y
	elif weapon_family in ReadyRules.GUNS and not scatter and not finisher:
		var spread := minf(_shot_spread, deg_to_rad(2.0) * stats.talent_factor("spread")) if not round_skill.is_empty() else _shot_spread
		if weapon_family == "rifle": spread *= clampf(1.0 - float(rifle_weapon_stats().accuracy), .25, 2.0)
		var shot_angle: float=motion.aim_angle+spread*shot_rng.randf_range(-1,1)
		direction=Vector3(cos(shot_angle),0,sin(shot_angle))
	# Check the short path along the staff too, so close targets/cover cannot
	# be skipped merely because they stand between the character and muzzle.
	var hand_origin := _hand_origin()
	definition.launch_origin = Vector3(hand_origin.x, muzzle.y, hand_origin.z)
	if weapon_family == "staff":
		definition.splash_ground_y = player.global_position.y
		if definition.has("splash_radius"): definition.splash_radius *= stats.talent_factor("skill_area")
	var launched: bool
	if scatter:
		launched = not staff_flight.spawn_rifle_pellets(muzzle, direction, definition, definition.scatter_angles, camera).is_empty()
	elif definition.has("ice_angles"):
		for angle: float in definition.ice_angles:
			var ice_direction := direction.rotated(Vector3.DOWN, deg_to_rad(angle))
			if staff_flight.spawn_fireball(muzzle, ice_direction, definition, camera): launched = true
	else:
		launched = staff_flight.spawn_fireball(muzzle, direction, definition, camera)
	if launched:
		if weapon_family in ["pistol", "rifle"]:
			var cycle: Variant = active_magazine()
			var rapid := bool(definition.get("rifle_rapid", false))
			if finisher: cycle.prepare_round(RifleMotion.FINISHER_ID)
			var fired: bool = cycle.consume(rapid) if cycle is RifleCycle else cycle.consume()
			if fired and weapon_family == "rifle":
				ui.turn_rifle_gears(false)
				ui.rifle_ammo_strip.feed_shot(round_id, cycle.round_ids())
				if rapid: _rifle_events(cycle)
				if first_special_round:
					sword_skill_cooldowns[round_id] = RifleMotion.skill_cooldown(round_id, stats.level) * stats.talent_factor("skill_cooldown")
				if scatter or finisher:
					_rifle_retreat_distance = rewards.DODGE_SPEED * DashVisual.DURATION * anatomy.dash_multiplier() * (1.5 if finisher else 1.0)
					_apply_rifle_recoil(0.0)
				if finisher:
					_shake = maxf(_shake, .32)
					fx.burst(muzzle, Color("#d2f2ff"), 16)
			if weapon_family=="pistol" and _shot_aimed and readiness.held and primary_family()=="pistol":pistol_aim_state.record_shot()
			fx.burst(muzzle, round_skill.get("color", Color("#ffe5a3")), 8 if weapon_family == "rifle" else 4)
			audio.play("rifle" if weapon_family == "rifle" else "gun")
			var eject_pose: Dictionary=pose
			var eject_angle: float=eject_pose.get("grip_angle",eject_pose.angle)
			var breech: Vector3=_hand_origin()+Vector3(cos(eject_angle),0,sin(eject_angle))*float(eject_pose.radius)+Vector3.UP*float(eject_pose.grip_height)
			if weapon_family!="rifle":casing_fx.spawn(breech+direction*.08, direction, camera)
		else:
			var color: Color = staff_energy.ELEMENT_COLORS.get(definition.get("element", "fire"), Color("#ffb64a"))
			fx.burst(muzzle, color, 9 if definition.has("ice_angles") else 5)
			fx.ring(Vector3(muzzle.x, player.position.y, muzzle.z), .22, Color(color, .5), .12)
			audio.play("fire_cast")

func _projectile_damage(enemy, damage: float, knock: Vector3, element: String) -> void:
	enemy_hit(enemy, damage, knock, element)

func _ice_volley_damage(enemy, damage: float, knock: Vector3) -> void:
	var previous_health: float = enemy.health
	enemy_hit(enemy, damage, knock, "ice")
	if is_instance_valid(enemy) and enemy.health < previous_health:
		enemy.apply_ice_slow()

func _staff_chain_lightning_jump(from: Vector3, to: Vector3) -> void:
	fx.staff_lightning_arc(from, to)
	fx.staff_chain_lightning_contact(to)

func _sword_wave_damage(enemy, damage: float, knock: Vector3, kind: String) -> void:
	enemy_hit(enemy, damage, knock, "physical", .45 if kind == "vacuum_wave" else -1.0)

func _projectile_impact(where: Vector3, reason: String, element: String) -> void:
	var color: Color = staff_energy.ELEMENT_COLORS.get(element, Color("#ffe5a3"))
	fx.burst(where, color, 8 if reason == "enemy" else 4)
	if reason != "range": audio.play("bullet_impact" if element == "physical" else "fire_impact")

func _projectile_area_impact(where: Vector3, ground_y: float, radius: float, element: String, charged_fire: bool) -> void:
	if charged_fire:
		fx.fire_blast(Vector3(where.x, ground_y, where.z), radius, element, camera)
	else:
		fx.fire_blast(where, radius, element)

func current_visual_sample() -> Dictionary:
	var sample: Dictionary = _hand_pose(motion.sample())
	sample.action_tag=active_skill_id+":"+str(motion.stage)
	if weapon_family == "crossbow":
		var magazine = crossbow_magazine()
		var drawing: bool = magazine.reloading
		var angle := atan2(aim.z, aim.x)
		return {"phase": "reload" if drawing else "idle", "angle": angle, "grip_angle": angle,
			"radius": 0.27, "grip_height": 0.80, "pitch": 0.32 if drawing else 0.0,
			"blade_length": 0.91, "crossbow_loaded": magazine.can_fire(), "trail": false,
			"ready_carry": true, "progress": magazine.progress(),
			"support_pull": sin(PI * magazine.progress()) if drawing else 0.0}
	if weapon_family == "bow":
		var angle := atan2(aim.z, aim.x)
		if _bow_recovery > 0.0 and _bow_shot_direction != Vector3.ZERO:
			angle = atan2(_bow_shot_direction.z, _bow_shot_direction.x)
		return {"phase": "charge" if bow_charge >= 0.0 else ("recovery" if _bow_recovery > 0.0 else "idle"),
			"angle": angle, "grip_angle": angle, "radius": 0.46, "grip_height": 0.86,
			"pitch": 0.0, "blade_length": 0.23, "bow_tier": bow_tier(), "trail": false,
			"body_lean": -0.08 if _bow_recovery > 0.0 else 0.0, "progress": 0.0}
	if weapon_family in ["pistol","rifle"] and active_magazine().reloading:
		sample=ReloadVisual.pose(weapon_family,active_magazine().progress(),atan2(aim.z,aim.x),1 if _is_left_hand() else (0 if _uses_dual_hands() else -1))
		sample.action_tag="reload:"+active_item+":"+str(reload_visual.serial)
	if weapon_family=="rifle" and active_magazine().has_method("start_bolt"):
		var cycle=active_magazine()
		if cycle.reloading:sample=RiflePose.reload_pose(cycle,atan2(aim.z,aim.x))
		elif cycle.bolt_active:sample=RiflePose.bolt_pose(cycle.bolt_elapsed/cycle.bolt_duration,atan2(aim.z,aim.x))
		elif motion.busy and sample.phase=="recovery" and cycle.needs_bolt:sample=RiflePose.bolt_pose(sample.progress,motion.aim_angle)
	if weapon_family=="staff" and not motion.busy and (staff_energy.loading or staff_energy.casting):
		sample.phase="charge";sample.pitch=1.1 if staff_energy.loading else .60
		sample.grip_height=.85;sample.radius=.28;sample.angle=atan2(aim.z,aim.x);sample.body_lean=-.025
		sample.staff_loading = staff_energy.loading
	if weapon_family == "staff" and _staff_breath_slot >= 0:
		var breath_angle := _staff_breath_angle if _staff_breath_ticks > 0 else atan2(aim.z, aim.x)
		sample.merge({"phase": "active", "angle": breath_angle, "grip_angle": breath_angle,
			"pitch": .7, "grip_height": .72, "radius": .28, "body_lean": .055}, true)
	if weapon_family == "staff" and not motion.busy and staff_energy.switching:
		var progress: float = 1.0 - staff_energy.switch_left / staff_energy.SWITCH_TIME
		var lift := sin(PI * progress)
		var sweep := sin(TAU * progress)
		var angle := atan2(aim.z, aim.x) - .82 * sweep
		sample.merge({"phase": "active", "staff_switch": true, "stance_managed": false,
			"angle": angle, "grip_angle": angle, "pitch": 1.1 - .76 * lift,
			"grip_height": .76 + .16 * lift, "radius": .28 + .19 * lift,
			"body_lean": .06 * sweep, "progress": progress}, true)
	var action := right_action()
	if not motion.busy and not guns_reloading() and action != "" and not (weapon_family=="rifle" and active_magazine().bolt_active):
		sample = ReadyPose.pose(weapon_family, atan2(aim.z,aim.x), "shield" if action == "guard" and has_shield() else action)
	if weapon_family == "staff":
		sample.staff_element = staff_energy.NEUTRAL if staff_energy.focus_left > 0.0 else staff_energy.element
	return sample

func _visual_tick(delta: float) -> void:
	_sync_staff_key()
	if primary_family()!="rifle":rifle_focus_state.reset()
	rifle_focus_state.advance(delta,rifle_aiming())
	rifle_scope.advance(delta,rifle_finisher_charging())
	if primary_family()!="pistol" or not readiness.held or mode not in ["practice","combat"] or inventory_open or stats_open:pistol_aim_state.reset()
	pistol_aim_state.advance(delta,primary_family()=="pistol" and right_action()=="aim")
	# The 120 Hz simulation may split a hit interval further. In crowded
	# rooms only the last pose, sight mask and HUD can reach the screen.
	if _in_physics_tick and encounter_mode=="dungeon":
		_pending_presentation += delta
		return
	var elapsed := _pending_presentation + delta
	_pending_presentation = 0.0
	_present_frame(elapsed)

func _present_frame(delta: float) -> void:
	if dungeon_peek.visible: return
	var focus_amount: float=rifle_focus_state.amount()
	camera.size=lerpf(camera.size,arena.camera_size(),1.0-exp(-3*delta)) if encounter_mode=="wreck_shore" else (lerpf(camera.size,village_zoom,1.0-exp(-8*delta)) if encounter_mode in ["village_study","coast_forms"] else rifle_focus_state.camera_size())
	if encounter_mode=="dungeon":camera.size+=3.0*(1.0-focus_amount)
	camera.size-=1.8*float(rifle_scope.zoom)
	var focus := player.position + Vector3(aim.x*rifle_focus_state.lookahead(),0,aim.z*lerpf(.45,6.0 if aim.z<0 else 3.6,focus_amount))
	if encounter_mode=="village_study":focus=player.position+Vector3(0,0,-6.5)
	elif encounter_mode=="coast_forms":focus=player.position+Vector3(2.5,0,-2)
	elif encounter_mode=="wreck_shore":focus=arena.camera_focus(player.position)
	var x_limit: float=lerpf(3,6,focus_amount)
	var z_limit: float=lerpf(2.7,7,focus_amount)
	if _coast_mode:x_limit=arena.camera_limits.x;z_limit=arena.camera_limits.y
	if encounter_mode=="dungeon":x_limit=arena.room_half.x-5.0;z_limit=arena.room_half.y-3.0
	focus.x=clampf(focus.x,-x_limit,x_limit);focus.z=clampf(focus.z,-z_limit,z_limit)
	focus.y = 0
	_camera_focus = _camera_focus.lerp(focus, 1.0 - exp(-lerpf(5,20,focus_amount)*delta))
	camera.position = _camera_focus + CAMERA_OFFSET + Vector3(randf_range(-_shake, _shake), 0, randf_range(-_shake, _shake))
	camera.look_at(_camera_focus)
	_update_mace_charge_preview()
	_update_staff_ground_preview()
	var sample: Dictionary = current_visual_sample()
	sample.rifle_aim_pose = weapon_family == "rifle" and (rifle_aiming() or (motion.busy and _pair_aimed))
	# Completed melee cuts retain their authored side so the next windup
	# starts from the same visible pose. Only a fresh stance uses this fallback.
	if not motion.busy and motion.stage < 0 and _staff_breath_slot < 0 and not sample.get("staff_switch", false):
		sample.angle = atan2(aim.z, aim.x) + (0.0 if weapon_family in ["mace", "staff", "pistol", "rifle"] else 0.35)
	var reach: float = motion.definition(motion.stage).get("reach", 2.1)
	sample.smooth_body = _uses_dual_hands()
	sample.paired_body = sample.smooth_body
	var dash: Dictionary=DashVisual.sample(_dodge_left,_dodge_facing,_dodge_dir,camera)
	var body_aim := aim
	if skill_active:
		var body_angle: float = motion.aim_angle + float(sample.get("body_spin", 0.0))
		body_aim = Vector3(cos(body_angle), 0, sin(body_angle))
	var leap_height := 0.0
	if active_skill_id == "mace_earth_wave" and not _mace_leap_offset.is_zero_approx():
		var progress := _mace_leap_progress()
		leap_height = sin(PI * progress) * minf(1.35, _mace_leap_offset.length() * .31)
	avatar.set_leap_height(leap_height)
	dual_visual.position.y = leap_height
	avatar.crawl_ready=_crawl_pose_ready()
	avatar.update_pose(camera, _dodge_facing if _dodge_left>0 else body_aim, _movement().length_squared() > 0.01 and mode in ["practice", "combat"], sample, reach, _hurt, _dodge_left, delta, mode in ["dead", "downed"],dash)
	_update_dual(delta)
	if use_cutout_avatar:avatar.update_cutout(dual_visual)
	var playing := mode in ["practice", "combat"]
	var sword_in_play := weapon_family == "sword" and playing
	var left_hand := _is_left_hand()
	var weapon_rig = dual_visual.rigs[int(left_hand)] if dual_visual.visible else avatar
	var mace_blade: Dictionary = {}
	var mace_trail_id := ""
	var mace_strike := Vector2i(_skill_generation, motion.stage)
	if playing and weapon_family == "mace" and weapon_rig.weapon.visible:
		mace_blade = weapon_rig.get_blade_points()
		if is_instance_valid(_mace_impact_flash):
			if use_cutout_avatar or active_skill_id == "mace_double_impact":
				_mace_impact_flash.align_flash(mace_blade.tip, camera.global_basis.z)
			_mace_impact_flash = null
		if is_instance_valid(_mace_fire_scoop_flash):
			_mace_fire_scoop_flash.align_head(mace_blade.tip)
			_mace_fire_scoop_flash = null
		if motion.busy and sample.phase == "active":
			if skill_active and motion == _mace_skill_motion:
				mace_trail_id = active_skill_id
				if active_skill_id in ["mace_sweep", "mace_armor_counter"]:
					var tangent := Vector3(-sin(sample.angle), 0, cos(sample.angle))
					if left_hand: tangent = -tangent
					var style := MaceSweepVisual.Style.SWEEP
					if active_skill_id == "mace_armor_counter":
						style = MaceSweepVisual.Style.COUNTER if _mace_parried_attacker_id != 0 else MaceSweepVisual.Style.ARMOR
					fx.mace_sweep_head(camera, mace_blade.tip, tangent, sample.progress, mace_strike, style)
			elif motion.definition(motion.stage).get("kind") == "fire_lift":
				mace_trail_id = "mace_fissure"
			elif not skill_active and motion.stage in [0, 1, 2]:
				var forward := Vector3(cos(motion.aim_angle), 0, sin(motion.aim_angle))
				fx.mace_basic_head(camera, mace_blade.tip, forward, sample.progress, motion.stage, left_hand)
				if motion.stage == 0: mace_trail_id = "basic_lift"
				elif motion.stage == 2: mace_trail_id = "basic_slam"
	fx.mace_swing(mace_blade if not mace_trail_id.is_empty() else {}, mace_strike, mace_trail_id)
	fx.mace_ember_coat(camera, mace_blade if mace_fire_buff_left > 0.0 and primary_family() == "mace" else {}, run_time)
	var coat_blade: Dictionary = {}
	if playing and sword_wave_buff_left > 0.0:
		var coat_rig := _storm_blade_coated_rig()
		if coat_rig != null and coat_rig.weapon.visible:
			coat_blade = coat_rig.get_blade_points()
	fx.storm_blade_coat(camera, coat_blade, run_time, sword_wave_buff_left)
	if sword_in_play and not skill_active and motion.busy and sample.phase == "active":
		var blade: Dictionary = weapon_rig.get_blade_points()
		fx.basic_sword_slash(camera, blade.grip, blade.tip, sample.progress, motion.stage, left_hand)
	elif skill_active and active_skill_id == "double_slash" and motion.busy and sample.phase == "active" and playing:
		fx.double_slash(camera, avatar.get_blade_points(), sample, motion.stage, _skill_generation)
	elif skill_active and active_skill_id == "stormcaller" and motion.busy and sample.phase == "active" and playing:
		fx.spin_slash(camera, avatar.get_blade_points(), sample.progress, motion.stage)
	var nearby := _nearby_downed_companion()
	for companion in companions: companion.present(camera, delta, companion == nearby)
	_present_party_mark()
	if encounter_mode == "dungeon":
		arena.present_revelation(has_sanity_revelation(), player.global_position)
		arena.update_peek_hints(player.global_position, _can_peek_dungeon_exit())
	if encounter_mode=="dungeon" and dungeon.remaining==0:
		vision.fog.hide();vision.indicator.hide()
	else:
		vision.update_view(delta)
	if encounter_mode in ["village_study","coast_forms","wreck_shore"]:
		vision.fog.visible=false;vision.indicator.visible=false;arena.update_player(player.position)
	brine_zones.refresh(self)
	pistol_reticle.update_view(self)
	rifle_scope.update_view(self)
	staff_orbs.update_view(self,delta)
	status_icons.refresh()
	fx.refresh_visibility()
	# Resolve the birth point after this frame's held-weapon interpolation.
	ready_visual.update_view(self)
	if encounter_mode=="wreck_shore":arena.present(self)
	ui.refresh()
	if is_instance_valid(anatomy_panel):
		anatomy_panel.refresh();anatomy_panel.compact.visible=encounter_mode not in ["village_study","coast_forms","wreck_shore"]
	if encounter_mode=="wreck_shore" and mode=="practice" and arena.exit_reached:
		_cancel_body_actions();mode="shore_end";arena.present(self);ui.show_mode(mode)

func _apply_expedition_attributes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	if expedition_leader_attributes.is_empty():
		expedition_leader_attributes = CharacterStats.roll_level_one(rng)
	stats.attributes = expedition_leader_attributes.duplicate()
	stats.set_talents(expedition_leader_talents)
	flasks.healing_multiplier = stats.talent_factor("flask_heal")
	for recruit in expedition_companions:
		if not recruit.has("attributes"):
			recruit.attributes = CharacterStats.roll_level_one(rng)
	health = max_health()
	stamina = stats.value("max_stamina")
	mana = stats.value("max_mana")


func _spawn_expedition_companions() -> void:
	for index in expedition_companions.size():
		var companion := Companion.new()
		add_child(companion)
		companion.configure(expedition_companions[index], index)
		companions.append(companion)

func place_companions() -> void:
	for index in companions.size():
		var side := -1.0 if index == 0 else 1.0
		var position_: Vector3 = player.position + Vector3(side * 1.45, 0, .65)
		position_.x = clampf(position_.x, -arena.room_half.x + .6, arena.room_half.x - .6)
		position_.z = clampf(position_.z, -arena.room_half.y + .6, arena.room_half.y - .6)
		companions[index].place(position_)

func recall_companions() -> void:
	if mode != "combat" or inventory_open or stats_open or body_lab_open: return
	_clear_party_mark()
	for companion in companions: companion.recall()

func mark_party_cursor() -> void:
	if mode != "combat" or encounter_mode != "dungeon" or inventory_open or stats_open or body_lab_open: return
	if not companions.any(func(companion: Companion) -> bool: return not companion.downed): return
	var origin := camera.project_ray_origin(_mouse_position)
	var ray := camera.project_ray_normal(_mouse_position)
	if absf(ray.y) < .001: return
	var point := origin + ray * (-origin.y / ray.y)
	if has_sanity_revelation() and is_instance_valid(arena.hazards) and arena.hazards.root_ambush != null:
		point = arena.hazards.root_ambush.mark_point(point)
	var target: Node3D
	var nearest := 30.0 * 30.0
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.dead or not vision.can_see(enemy.global_position): continue
		var screen := camera.unproject_position(enemy.global_position + Vector3.UP * .8)
		var distance := screen.distance_squared_to(_mouse_position)
		if distance < nearest:
			target = enemy
			nearest = distance
	party_mark_target = target
	party_mark_point = Vector3(clampf(point.x, -arena.room_half.x + .8, arena.room_half.x - .8), .03,
		clampf(point.z, -arena.room_half.y + .8, arena.room_half.y - .8))
	party_mark_left = 6.0 if target == null else 0.0
	for companion in companions:
		if not companion.downed:
			companion.retreat_left = 0.0
			companion.target_refresh_left = 0.0
	var ping_position := party_mark_point if target == null else target.global_position
	fx.ring(ping_position, .62, Color("#ffd38a"), .45)
	_present_party_mark()

func _clear_party_mark() -> void:
	party_mark_target = null
	party_mark_point = Vector3.INF
	party_mark_left = 0.0
	if is_instance_valid(party_mark_marker): party_mark_marker.hide()

func _present_party_mark() -> void:
	var on_enemy: bool = is_instance_valid(party_mark_target) and not party_mark_target.dead
	var show_marker := mode == "combat" and not inventory_open and not stats_open and not body_lab_open
	show_marker = show_marker and (vision.can_see(party_mark_target.global_position) if on_enemy else party_mark_left > 0.0)
	party_mark_marker.visible = show_marker
	if not show_marker: return
	party_mark_marker.text = "▼" if on_enemy else "◇"
	party_mark_marker.global_position = (party_mark_target.bar.global_position + camera.global_basis.y * .66
		if on_enemy else party_mark_point + Vector3.UP * .30)

func _can_peek_dungeon_exit() -> bool:
	return mode == "combat" and encounter_mode == "dungeon" and not inventory_open and not stats_open \
		and not body_lab_open and dungeon.rooms.get(dungeon.current, {}).get("cleared", false)

func try_peek_dungeon_exit() -> bool:
	if not _can_peek_dungeon_exit(): return false
	var direction: Vector2i = arena.peek_direction(player.global_position)
	if direction == Vector2i.ZERO: return false
	var next: Vector2i = dungeon.rooms[dungeon.current].links[direction]
	if dungeon.visited.has(next): return false
	_held = false
	readiness.release()
	dungeon.prepare_room(next, -direction)
	dungeon.rooms[next].scouted = true
	dungeon_peek.open(dungeon.rooms[next], direction, camera.global_basis, vision.reach(), _create_enemy, has_sanity_revelation())
	return true

func _nearby_downed_companion() -> Companion:
	var closest: Companion
	var nearest := INF
	for companion in companions:
		if not companion.can_revive_from(player.global_position): continue
		var distance := companion.global_position.distance_squared_to(player.global_position)
		if distance < nearest:
			closest = companion
			nearest = distance
	return closest

func _begin_revive() -> bool:
	if not _can_revive_now() or motion.busy or skill_active or pair_strikes.active or guns_reloading(): return false
	if bow_charge >= 0.0 or staff_energy.loading or staff_energy.casting or _staff_breath_slot >= 0 or _crossbow_loading != null: return false
	var companion := _nearby_downed_companion()
	if companion == null: return false
	revive_target = companion
	revive_elapsed = 0.0
	_held = false
	readiness.release()
	return true

func _can_revive_now() -> bool:
	return mode == "combat" and not inventory_open and not stats_open and body_action_ready() \
		and _dodge_left <= 0.0 and _movement().length_squared() < .001

func _advance_revive(delta: float) -> void:
	if not is_instance_valid(revive_target): return
	if not _can_revive_now() or not revive_target.can_revive_from(player.global_position):
		_cancel_revive()
		return
	revive_elapsed += delta
	if revive_elapsed + .000001 < revive_duration(): return
	var companion := revive_target
	_cancel_revive()
	companion.revive()
	fx.number(companion.position + Vector3.UP * 1.8, "+%d%%" % roundi(companion.revive_health_fraction() * 100.0), false)

func revive_duration() -> float:
	return REVIVE_DURATION * stats.talent_factor("revive_time")

func _cancel_revive() -> void:
	revive_target = null
	revive_elapsed = 0.0

func enemy_target_for(enemy: Node3D) -> Node3D:
	var target: Node3D = player
	var nearest := enemy.global_position.distance_squared_to(player.global_position)
	for companion in companions:
		if companion.downed: continue
		var distance := enemy.global_position.distance_squared_to(companion.global_position)
		if distance < nearest:
			nearest = distance
			target = companion
	return target

func damage_companions_in_attack(enemy, contact: Callable = Callable()) -> void:
	if companions.is_empty(): return
	var touched: Array = enemy.attack_data.get("companions_hit", [])
	for companion in companions:
		if companion.downed or companion.get_instance_id() in touched: continue
		if contact.is_valid():
			if not contact.call(companion.global_position): continue
			var ray := PhysicsRayQueryParameters3D.create(enemy.global_position + Vector3.UP * .65,
				companion.global_position + Vector3.UP * .65, 1)
			if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): continue
		elif not enemy.threatens(companion.global_position) or not enemy.line_of_sight(companion.global_position): continue
		companion.receive_hit(enemy.attack_data.damage)
		touched.append(companion.get_instance_id())
	if not touched.is_empty(): enemy.attack_data.companions_hit = touched

func steering_neighbors(at: Vector3, radius: float) -> Array:
	return _crowd_neighbors.nearby(at,radius) if _crowd_index_active else enemies

func _create_enemy(kind: String) -> Node3D:
	var enemy = SpitterEnemy.new() if kind=="spitter" else NetHaulerEnemy.new() if kind=="net_hauler" else CrewmanEnemy.new() if kind=="harpooner" else BrinehoundEnemy.new() if kind=="brinehound" else FishermanEnemy.new() if kind=="fisherman" else Captain.new() if kind=="captain" else (CoastalEnemy.new() if kind in CoastalRoster.kinds() else Enemy.new())
	enemy.kind = kind
	return enemy

func spawn_enemy(kind: String, where: Vector3) -> Node3D:
	var enemy = _create_enemy(kind)
	enemy.position = where
	add_child(enemy)
	if _coast_mode:enemy.collision_mask |= 8
	if encounter_mode=="dungeon":
		enemy.attack_visual.cache_static_walls=true
		if enemy is CoastalEnemy:
			enemy.chase_slot=enemies.size()%CoastalEnemy.CHASE_INTERVAL
			for guide in enemy.fan_guides:guide.cache_static_walls=true
	enemies.append(enemy)
	if kind=="captain":enemy.view_right=camera.global_basis.x
	if vision.can_see(where):fx.ring(where, 0.55 if kind != "elite" else 0.85, Color(0.9, 0.5, 0.25, 0.6), 0.55)
	return enemy

func spawn_wave() -> void:
	wave += 1
	_wave_wait = 0
	if mode in ["combat", "practice"]: health = minf(max_health(), health + 16)
	stamina = stats.value("max_stamina")
	var types: Array = ["melee", "melee", "melee"] if wave == 1 else (["melee", "melee", "ranged", "ranged"] if wave == 2 else ["elite", "melee", "melee", "ranged"])
	var locations: Array[Vector3] = [Vector3(-4.0, 0.03, -3.5), Vector3(4.5, 0.03, -3.0), Vector3(3.8, 0.03, 3.2), Vector3(-4.0, 0.03, 3.5)]
	for i in range(types.size()): spawn_enemy(types[i], locations[i])
	fx.number(Vector3(0, 2.4, -1.5), "WAVE %d" % wave, true)
	audio.play("warning")

func _melee_contact_region(enemy,step: Dictionary) -> String:
	var origin := _hand_origin()
	if enemy is CoastalEnemy:
		var attack: Dictionary = motion.definition(motion.stage)
		var reach := Vector2(float(attack.reach), float(attack.get("width", 0.0)) * .5).length() + .001
		if attack.get("radial", false): reach = maxf(reach, float(attack.effect_radius) + float(attack.ring_width))
		var offset: Vector3 = enemy.position - origin
		offset.y = 0
		# Keep the fallback body disk as well as the projected sprite in bounds.
		var fallback_reach: float = reach + float(enemy._profile.get("body_radius", .33))
		if offset.length_squared() > fallback_reach * fallback_reach and not EnemyImageHurt.may_overlap(enemy.sprite, origin, origin.y + .7, reach):
			return ""
	if enemy.has_method("hurt_regions"):
		var regions: Array=enemy.image_hurt_regions(origin.y+.7) if enemy.has_method("image_hurt_regions") else enemy.hurt_regions()
		for region in regions:
			if motion.is_target_hit(origin,region.position,region.radius,step.previous_angle,step.current_angle):return region.id
		return ""
	return "body" if motion.is_target_hit(origin,enemy.position,.55 if enemy.kind=="elite" else .36,step.previous_angle,step.current_angle) else ""
func enemy_hit(enemy, damage: float, knock: Vector3, element: String = "",slam_stagger: float=-1.0,ongoing: bool=false,contact_region: String="", from_player: bool = true) -> void:
	if is_instance_valid(enemy) and enemy is Companion:
		if from_player: _friendly_hit(enemy, damage, ongoing)
		return
	if not is_instance_valid(enemy) or enemy.dead or not is_finite(damage) or damage <= 0: return
	var critical: bool = not ongoing and combat_rng.randf() < stats.value("critical_chance")
	damage *= stats.value("damage_multiplier") * (stats.value("critical_multiplier") if critical else 1.0)
	if from_player: damage *= stats.range_damage(player.global_position, enemy.global_position)
	if enemy.has_method("calculate_incoming_damage"):
		damage = enemy.calculate_incoming_damage(damage, element)
	if not is_finite(damage) or damage <= 0: return
	_apply_enemy_hit(enemy, damage, knock, element, slam_stagger, ongoing, contact_region, critical, from_player)

func _player_attack_targets() -> Array:
	return enemies if companions.is_empty() else enemies + companions

func _can_hit_player_target(target) -> bool:
	return is_instance_valid(target) and (not target.downed if target is Companion else not target.dead)

func _friendly_hit(ally: Companion, damage: float, ongoing: bool = false) -> void:
	if not _can_hit_player_target(ally) or not is_finite(damage) or damage <= 0.0: return
	var critical: bool = not ongoing and combat_rng.randf() < stats.value("critical_chance")
	var outgoing: float = damage * stats.value("damage_multiplier") * (stats.value("critical_multiplier") if critical else 1.0)
	_apply_friendly_damage(ally, outgoing * FRIENDLY_FIRE_FRACTION * stats.range_damage(player.global_position, ally.global_position))

func _apply_friendly_damage(ally: Companion, damage: float) -> void:
	var before: float = ally.health
	ally.receive_friendly_damage(damage)
	if ally.health < before:
		var at := ally.global_position
		fx.number(at + Vector3.UP * 1.65, "-%s เพื่อน" % String.num(before - ally.health, 2), false, at)
		fx.burst(at + Vector3.UP * .75, Color("#ffb18c"), 4, at)

func _apply_enemy_hit(enemy, damage: float, knock: Vector3, element: String, slam_stagger: float = -1.0, ongoing: bool = false, contact_region: String = "", critical: bool = false, from_player: bool = true) -> void:
	var heavy: bool = (element == "physical" and damage >= 45.0) or (element.is_empty() and (motion.stage == 2 or damage >= 100 or (weapon_family == "mace" and motion.stage == 0)))
	if ongoing:heavy=false
	var ordinary_sword := weapon_family == "sword" and element.is_empty() and not skill_active
	var actual_stagger:=.0
	if ongoing:enemy.receive_burn(damage)
	elif slam_stagger>0 and enemy.has_method("receive_great_slam"):actual_stagger=enemy.receive_great_slam(damage,knock,slam_stagger)
	else:enemy.receive_damage(damage, knock)
	if contact_region!="" and enemy.has_method("register_melee_contact") and enemy.register_melee_contact(contact_region,damage,weapon_family):
		fx.number(enemy.position+Vector3.UP*1.7,"แขนโซ่ขาด",true);fx.burst(enemy.position+Vector3.UP*.8,Color("#c6d7bd"),18)
	if actual_stagger>0 and vision.can_see(enemy.position):fx.number(enemy.position+Vector3.UP*2.5,"STAGGER",false,enemy.position)
	hits += 1
	total_damage += damage
	var damage_text: String = str(int(damage)) if is_equal_approx(damage, roundf(damage)) else ("%.2f" % damage).trim_suffix("0")
	if vision.can_see(enemy.position):
		fx.number(enemy.position + Vector3(0, 1.4, 0), damage_text+("!" if critical else ""), critical or (heavy and not ordinary_sword),enemy.position)
		fx.burst(enemy.position + Vector3(0, 0.75, 0), Color("#ffb347") if element == "fire" else (Color("#ffe5a3") if element == "physical" else (Color("#ffcc80") if heavy else Color("#8ce9db"))), (6 if heavy else 4) if ordinary_sword else (16 if heavy else 8),enemy.position)
	audio.play("enemy_hit")
	if enemy.dead:
		if from_player: _refund_staff_mana(enemy.global_position)
		if enemy.kind != "dummy": kills += 1
		audio.play("enemy_death")
		if vision.can_see(enemy.position):fx.burst(enemy.position + Vector3(0, 0.6, 0), Color("#ef9f60"), 14,enemy.position)

func frenzy_threshold() -> int:
	return FRENZY_THRESHOLD


func has_sanity_revelation() -> bool:
	return _sanity_marked


func add_sanity(amount: int) -> void:
	if mode not in ["combat", "practice"]: return
	sanity = maxi(SANITY_REVELATION if _sanity_marked else 0, sanity + amount)
	_sanity_marked = _sanity_marked or sanity >= SANITY_REVELATION

func enemy_attack_parryable(base_parryable: bool, _origin: Vector3) -> bool:
	return base_parryable


func reward_dungeon_clear_health() -> void:
	if mode != "combat": return
	health = minf(max_health(), health + max_health() * .22)
	if encounter_mode != "dungeon" or dungeon.cleared <= _last_talent_reward_room or dungeon.cleared % TALENT_REWARD_ROOMS != 0: return
	_last_talent_reward_room = dungeon.cleared
	if not expedition_leader_talents.is_empty():
		var id := Talents.roll_gain(expedition_leader_talents, _talent_rng)
		if id >= 0:
			stats.set_talents(expedition_leader_talents)
			stamina = minf(stamina, stats.value("max_stamina"))
			mana = minf(mana, stats.value("max_mana"))
			flasks.healing_multiplier = stats.talent_factor("flask_heal")
			fx.number(player.global_position + Vector3.UP * 1.8, Talents.title(id, stats.talents[id]), false)
	for index in companions.size():
		var companion := companions[index]
		if companion.downed or companion.stats.talents.is_empty(): continue
		var entries: Dictionary = expedition_companions[index].talents
		var id := Talents.roll_gain(entries, _talent_rng)
		if id >= 0:
			companion.stats.set_talents(entries)
			companion.stamina = minf(companion.stamina, companion.stats.value("max_stamina"))
			companion.mana = minf(companion.mana, companion.stats.value("max_mana"))
			fx.number(companion.global_position + Vector3.UP * 1.8, Talents.title(id, entries[id]), false)


func stand_up_sanity_cost() -> int:
	return STAND_UP_SANITY + roundi(stats.talent("stand_up_sanity"))

func stand_up_health_fraction() -> float:
	return STAND_UP_HEALTH + stats.talent("stand_up_health")

func stand_up() -> bool:
	if mode != "downed": return false
	mode = _mode_before_fall
	add_sanity(stand_up_sanity_cost())
	frenzy = sanity >= frenzy_threshold()
	health = max_health() * stand_up_health_fraction()
	_iframes = .5
	_hurt = 0.0
	ui.show_mode(mode)
	_visual_tick(0)
	return true


func _fall_at_zero_health() -> void:
	if frenzy:
		character_lost = true
		if not expedition_recruit_id.is_empty():
			ExpeditionRoster.record_loss(expedition_recruit_id)
		_die_from_body()
		return
	_mode_before_fall = mode
	_cancel_body_actions()
	pair_strikes.cancel()
	flasks.cancel_effects()
	_end_room_fade()
	player.velocity = Vector3.ZERO
	mode = "downed"
	ui.show_mode(mode)
	_visual_tick(0)


func receive_forest_poison(amount: float, _integrity_loss: float) -> void:
	damage_player(amount, Vector3.INF, 0.0, "poison", "torso", 0.0, false, &"area")


func damage_player(amount: float,source: Vector3=Vector3.INF,guard_cost: float=1.0,element: String="physical",_body_part: String="torso",_body_amount: float=-1,_red: bool=false,delivery: StringName=&"melee",_all_part_loss: float=0.0) -> void:
	if mode not in ["combat","practice"] or body_lab_open or (_iframes>0 or rewards.invulnerable() or _dodge_step_protected) or not is_finite(amount) or amount<=0:return
	amount=stats.incoming(amount,element)
	if amount <= 0.000001: return
	var guarded:=false
	var holding_guard := right_action() == "guard"
	var shield_guard := holding_guard and has_shield()
	var can_block := holding_guard and (not shield_guard or delivery != &"area")
	if can_block and ReadyRules.frontal(source, player.position, aim):
		guarded = true
		if shield_guard:
			amount *= 1.0 - ReadyRules.SHIELD_REDUCTION
			var cost_per_damage := maxf(0.01, guard_cost * stats.value("stamina_cost_multiplier") * anatomy.action_cost_multiplier())
			var absorbed := minf(amount, stamina / cost_per_damage)
			_spend_stamina(absorbed * cost_per_damage)
			amount = maxf(0.0, amount - absorbed)
			if amount > 0.000001: energy.flash = .3
		else:
			var block: Dictionary = readiness.receive(amount, source, player.position, aim, stamina, guard_cost)
			amount = block.damage
		fx.parry_clash(_guard_contact_point(source),false);fx.number(player.position+Vector3.UP*1.8,"BLOCK",false);audio.play("guard")
		if amount <= 0.000001: return
	var previous_health := health
	health = maxf(0.0, health - amount)
	_cancel_revive()
	_iframes=0.0 if guarded else .5;_hurt=.17;_shake=.1
	if health < previous_health:
		fx.number(player.position + Vector3.UP * 1.7, "-%d" % int(previous_health - health), true)
	audio.play("hit")
	if health <= 0.0:
		_fall_at_zero_health()


func _die_from_body() -> void:
	sword_wave_buff_left = 0.0
	mace_fire_buff_left = 0.0
	mace_fire_lobs.clear()
	if is_instance_valid(brine_zones):brine_zones.clear()
	if mode=="dead":return
	if encounter_mode=="coast":clear_hostile_projectiles()
	_cancel_body_actions();flasks.cancel_effects();body_lab_open=false;mode="dead"
	fx.clear_transients();staff_flight.clear();ground_fire.clear();_staff_ground.clear();_mace_ground.clear();casing_fx.clear();reset_gun_magazines()
	audio.play("death");ui.show_mode(mode)

func shoot(where: Vector3,direction: Vector3,damage: float,parryable: bool=false,owner_enemy: Node=null,guard_cost: float=1.0,max_range: float=16.5,body_part: String="torso",body_amount: float=-1) -> void:
	var bolt := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.10
	mesh.height = 0.2
	bolt.mesh = mesh
	bolt.material_override = fx.tint(Color("#ffe7a0") if parryable else Color("#ff3939"))
	if is_instance_valid(owner_enemy) and owner_enemy.has_method("coastal_projectile_style"):
		var art=preload("res://scripts/coastal_art.gd")
		var texture: Texture2D=art.projectile(owner_enemy.kind)
		if owner_enemy.has_method("projectile_texture"):texture=owner_enemy.projectile_texture()
		var quad:=QuadMesh.new();quad.size=Vector2(.85,.425) if owner_enemy.kind=="harpooner" else Vector2(.30,.30);bolt.mesh=quad
		if owner_enemy.has_method("projectile_size"):quad.size=owner_enemy.projectile_size()
		quad.center_offset=preload("res://scripts/projectile_image_geometry.gd").quad_offset(texture,quad.size,owner_enemy.coastal_projectile_style())
		var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;mat.albedo_texture=texture;mat.albedo_color=Color.WHITE if parryable else Color("#ff3939");mat.no_depth_test=true;mat.cull_mode=BaseMaterial3D.CULL_DISABLED;bolt.material_override=mat
		bolt.basis=camera.global_basis;bolt.rotate_object_local(Vector3.BACK,atan2(direction.dot(camera.global_basis.y),direction.dot(camera.global_basis.x)))
	bolt.position = where
	add_child(bolt)
	var contact_pin:=MeshInstance3D.new();contact_pin.name="ContactPin";var pin_mesh:=SphereMesh.new();pin_mesh.radius=.035;pin_mesh.height=.07;contact_pin.mesh=pin_mesh
	contact_pin.material_override=fx.tint(Color("70fff1"));contact_pin.visible=debug_range;bolt.add_child(contact_pin)
	direction.y = 0
	projectiles.append({"node": bolt, "direction": direction.normalized(), "damage":damage,"life":max_range/5.5,"parryable":parryable,"owner_enemy":owner_enemy,"guard_cost":guard_cost,"body_part":body_part,"body_amount":body_amount,"defer_step":_enemy_tick_phase})
	audio.play("enemy_attack")

func _update_projectiles(delta: float) -> void:
	for entry in projectiles.duplicate():
		# Enemy windup expires at the end of this interval; its new bolt starts now.
		if entry.get("defer_step",false):
			entry.defer_step=false
			continue
		var old: Vector3 = entry.node.position
		entry.node.position += entry.direction * minf(delta,maxf(0,entry.life)) * 5.5
		entry.life = maxf(0,entry.life-delta)
		if entry.get("parryable",false):
			var arrival: float=Enemy.Attacks.projectile_contact_time(entry.node.position,entry.direction,player.position)
			entry.node.material_override.albedo_color=Color("#fffbd3") if arrival<=ReadyRules.PARRY_WINDOW else Color("#f4c26d")
		var contact_pin: Node=entry.node.get_node_or_null("ContactPin")
		if contact_pin!=null:contact_pin.visible=debug_range
		var query := PhysicsRayQueryParameters3D.create(old, entry.node.position, 1)
		var blocker: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
		var target := Vector3(player.position.x, old.y, player.position.z)
		var end: Vector3 = blocker.position if not blocker.is_empty() else entry.node.position
		if rewards.can_perfect():
			var dodge_target:=Vector3(rewards.dodge_origin.x,old.y,rewards.dodge_origin.z)
			if Geometry3D.get_closest_point_to_segment(dodge_target,old,end).distance_to(dodge_target)<.4:_award_perfect_dodge()
		var near := Geometry3D.get_closest_point_to_segment(target, old, end)
		var nearest_distance := old.distance_squared_to(near) if near.distance_to(target) < .4 else INF
		var struck_companion: Companion
		for companion in companions:
			if companion.downed: continue
			var ally_point := Vector3(companion.position.x, old.y, companion.position.z)
			var ally_contact := Geometry3D.get_closest_point_to_segment(ally_point, old, end)
			var along := old.distance_squared_to(ally_contact)
			if ally_contact.distance_squared_to(ally_point) >= .16 or along >= nearest_distance: continue
			nearest_distance = along
			struck_companion = companion
			near = ally_contact
		if struck_companion != null:
			struck_companion.receive_hit(entry.damage)
			entry.node.position = near
			entry.life = 0
		elif nearest_distance < INF:
			var attacker: Variant=entry.get("owner_enemy")
			if not is_instance_valid(attacker):attacker=null
			incoming_attack(entry.damage,player.position-entry.direction*2,entry.get("parryable",false),attacker,entry.get("guard_cost",1.0),entry.get("body_part","torso"),entry.get("body_amount",-1.0), &"projectile")
			entry.node.position = near
			entry.life = 0
		elif not blocker.is_empty():
			entry.node.position = blocker.position
			entry.life = 0
			fx.burst(blocker.position, Color("#e9ae80"), 3)
		if entry.life <= 0:
			entry.node.queue_free()
			projectiles.erase(entry)

func toggle_inventory() -> bool:
	_cancel_revive()
	_cancel_bow()
	_cancel_crossbow_load()
	_cancel_rifle_action()
	_cancel_staff_actions()
	if stats_open:return false
	if not inventory_open and _dodge_left > 0: return false
	if not inventory_open and mode not in ["menu", "practice", "combat"]: return false
	readiness.release();pistol_aim_state.reset()
	inventory_open = not inventory_open
	_held = false
	if inventory_open:
		pending_set = -1
		_cancel_skill()
		motion.reset()
		_reset_attack_step()
		_short_lunge.reset()
		_rifle_recoil.reset()
		_hit_stop = 0
		for magazine in [pistol_magazine, rifle_magazine] + item_magazines.values(): magazine.cancel_reload()
		arsenal.selected = {}
		arsenal.refresh()
	arsenal.surface.visible = inventory_open
	pistol_reticle.update_view(self)
	rifle_scope.update_view(self)
	return true

func _select_loadout_item(id: String) -> bool:
	if id == "" or not loadout.items.has(id): return false
	var combo := _next_combo
	var held := _held
	var family: String = loadout.items[id].family
	if family != weapon_family:
		if not set_weapon_family(family): return false
	loadout_mode = true
	active_item = id
	_next_combo = combo
	_held = held
	return true

func loadout_edited() -> void:
	_cancel_bow()
	_cancel_crossbow_load()
	rewards.clear_chain()
	if is_instance_valid(dual_visual):dual_visual.reset_stance()
	if not is_instance_valid(arsenal): return
	_cancel_skill()
	motion.reset()
	loadout_mode = true
	pending_set = -1
	_next_combo = 0
	active_item = ""
	_select_loadout_item(_body_default_item())
	loadout_mode = true
	arsenal.refresh()
	_visual_tick(0)

func request_loadout_swap() -> bool:
	if is_instance_valid(revive_target): return false
	if not loadout_mode or inventory_open or mode not in ["practice", "combat"] or anatomy.dead() or _dodge_left > 0: return false
	var target: int = 1 - loadout.active
	if loadout.primary(target) == "": return false
	if motion.busy or pair_strikes.active or skill_active or guns_reloading():
		pending_set = target
		return true
	return activate_loadout(target)

func activate_loadout(index: int) -> bool:
	_cancel_bow()
	_cancel_crossbow_load()
	_cancel_rifle_action()
	_cancel_staff_actions()
	if mode not in ["menu", "practice", "combat"] or anatomy.dead(): return false
	if index not in [0,1] or loadout.primary(index) == "" or _dodge_left > 0: return false
	if not inventory_open and (motion.busy or pair_strikes.active or skill_active or guns_reloading()):
		pending_set = index
		return true
	var combo := _next_combo
	var previous: int = loadout.active
	loadout.active = index
	if not _select_loadout_item(_body_default_item()):
		loadout.active = previous
		return false
	readiness.parry_left=0
	rewards.clear_chain()
	_next_combo = combo
	pending_set = -1
	loadout.save_data()
	arsenal.refresh()
	_visual_tick(0)
	return true

func _uses_dual_hands() -> bool:
	if not loadout_mode or skill_active: return false
	if weapon_family == "mace" and motion.definition(motion.stage).get("kind") == "fire_lift": return false
	var pair: Dictionary=loadout.sets[loadout.active]
	var single_item := _storm_blade_single_item()
	# The left-hand rig still presents a lone sword if that hand received the buff.
	return pair.off != "" and (single_item.is_empty() or single_item == pair.off)

func _is_left_hand() -> bool:
	return _uses_dual_hands() and active_item==loadout.sets[loadout.active].off

func _hand_pose(pose: Dictionary) -> Dictionary:
	var result: Dictionary=DualHandVisual.mirror(pose,motion.aim_angle) if _is_left_hand() else pose
	return DualHandVisual.weighted_pose(result,weapon_family,_is_left_hand()) if _uses_dual_hands() else result

func _hand_origin() -> Vector3:
	if not _uses_dual_hands():return player.position
	var angle: float=motion.aim_angle if motion.busy else atan2(aim.z,aim.x)
	return DualHandVisual.origin(player.position,angle,1 if _is_left_hand() else 0)

func _update_dual(delta: float) -> void:
	if not is_instance_valid(dual_visual):return
	dual_visual.visible=false
	if not _uses_dual_hands():
		avatar.set_equipment_visible(active_weapon_possible() and mode!="dead" and (anatomy.leg_count()>0 or _crawl_pose_ready()))
		return
	avatar.set_equipment_visible(false)
	if anatomy.leg_count()>0 or _crawl_pose_ready():avatar.grip_visual.visible=false
	var pair: Dictionary=loadout.sets[loadout.active]
	var angle: float=atan2(_dodge_facing.z,_dodge_facing.x) if _dodge_left>0 else (motion.aim_angle if motion.busy else atan2(aim.z,aim.x))
	var direction:=Vector3(cos(angle),0,sin(angle))
	var families: Array=[loadout.items[pair.main].family if pair.main!="" else "sword",loadout.items[pair.off].family if pair.off!="" else "sword"]
	dual_visual.update_hands(camera,direction,[pair.main,pair.off],families,1 if _is_left_hand() else 0,current_visual_sample(),motion.busy or guns_reloading(),delta,mode=="dead",skill_active,avatar.facing,avatar.paired_shoulders(),DashVisual.sample(_dodge_left,_dodge_facing,_dodge_dir,camera),"shield" if right_action()=="guard" and has_shield() else right_action())
	var visible_items := available_body_items()
	for i in range(2):dual_visual.rigs[i].set_equipment_visible((pair.main if i==0 else pair.off) in visible_items and mode!="dead" and (anatomy.leg_count()>0 or _crawl_pose_ready()))

func sword_skills_available() -> bool:
	return primary_family() == "sword" and _weapon_skills_available()

func mace_skills_available() -> bool:
	return primary_family() == "mace" and _weapon_skills_available()

func rifle_skills_available(id: String) -> bool:
	var independent := id in [RifleMotion.REFILL_SKILL_ID, RifleMotion.RAPID_FIRE_ID]
	return primary_family() == "rifle" and _weapon_skills_available(independent) and right_action() != "guard" \
		and not is_instance_valid(revive_target) and (independent or equipped_rifle_cycle().can_fire())

func rifle_rapid_fire_left() -> float:
	return equipped_rifle_cycle().rapid_fire_left if primary_family() == "rifle" else 0.0

func _weapon_skills_available(allow_reload: bool = false) -> bool:
	return body_action_ready() and active_weapon_possible() and mode in ["practice", "combat"] and not skill_active and not motion.busy and not pair_strikes.active and _dodge_left <= 0.0 and (allow_reload or not guns_reloading()) and not _arrival_locked and not sword_skills_open and not inventory_open and not stats_open and not dungeon_peek.visible and _room_fade == null

func _advance_paired_hand() -> void:
	if not pair_strikes.active or pair_strikes.cursor!=0: return
	if mode not in ["practice","combat"] or anatomy.dead() or inventory_open or _dodge_left>0:
		pair_strikes.cancel()
		return
	var definition: Dictionary = motion.definition(motion.stage)
	if motion.elapsed + .00000001 < pair_strikes.handoff_time(definition): return
	var id := pair_strikes.next_hand()
	var stage: int = pair_strikes.stage
	motion.reset()
	_hit_targets.clear()
	_trail_clock=0
	if not _select_loadout_item(id) or not _start_weapon_attack(stage): pair_strikes.cancel()

func primary_family() -> String:
	if not loadout_mode:return weapon_family
	var ids: Array=available_body_items()
	for id: String in ids:
		if loadout.items[id].family != "shield": return loadout.items[id].family
	return "shield" if not ids.is_empty() else ""

func has_shield() -> bool:
	if not loadout_mode: return weapon_family == "shield" and active_weapon_possible()
	for id in available_body_items():
		if loadout.items[id].family == "shield": return true
	return false

func primary_definition() -> Dictionary:
	var family:=primary_family()
	if not _primary_specs.has(family):
		var spec=Motion.new();spec.set_family(family);_primary_specs[family]=spec
	return _primary_specs[family].definition(0)
func right_action() -> String:
	if not body_action_ready() or not active_weapon_possible():return ""
	var available: bool=mode in ["practice","combat"] and not anatomy.dead() and not inventory_open and not stats_open and _dodge_left<=0 and not guns_reloading()
	var can_guard: bool = not motion.busy and not skill_active and not pair_strikes.active
	var family := "shield" if readiness.held and has_shield() else primary_family()
	return readiness.mode(family,available,can_guard)

func _can_parry() -> bool:
	if not body_action_ready():return false
	return mode in ["practice","combat"] and not anatomy.dead() and not inventory_open and not stats_open and _dodge_left<=0 and not motion.busy and not skill_active and not pair_strikes.active and not guns_reloading() and readiness.broken_left<=0

func _mace_armor_parry_windup() -> bool:
	return skill_active and active_skill_id == "mace_armor_counter" and motion.busy and motion.elapsed < MaceSkillMotion.ARMOR_COUNTER_WINDOW - .00000001

func incoming_attack(amount: float,source: Vector3,parryable: bool,attacker: Node=null,guard_cost: float=1.0,body_part: String="torso",body_amount: float=-1,delivery: StringName=&"melee") -> void:
	if mode not in ["practice","combat"] or (_iframes>0 or rewards.invulnerable() or _dodge_step_protected) or not is_finite(amount) or amount<=0:return
	if parryable:
		var mace_parry: bool = delivery == &"melee" and _mace_armor_parry_windup() and _mace_parried_attacker_id == 0 and is_instance_valid(attacker) and not attacker.get("dead") and body_action_ready()
		if mace_parry or (primary_family() in ReadyRules.MELEE and _can_parry()):
			var cost: float = ReadyRules.PARRY_COST * stats.value("stamina_cost_multiplier") * anatomy.action_cost_multiplier()
			if readiness.try_parry(source,player.position,aim,stamina,cost,mace_parry):
				_spend_stamina(cost)
				var clash_point := _guard_contact_point(source)
				if mace_parry:
					_mace_parried_attacker_id = attacker.get_instance_id()
					fx.burst(clash_point, Color("#e5fbff"), 10, player.position)
					_shake = maxf(_shake, .07)
				else:
					rewards.grant_counter()
				if is_instance_valid(attacker) and attacker.has_method("receive_parry"):attacker.receive_parry()
				fx.number(player.position+Vector3.UP*1.8,"PARRY!",true)
				fx.parry_clash(clash_point,true)
				fx.ring(player.position,.85,Color(.7,1,1,.9),.22)
				audio.play("parry");return
	damage_player(amount,source,guard_cost,"physical",body_part,body_amount,not parryable,delivery)
func start_spitter_trial() -> void:
	start_run(true);clear_actors();drill_kind="spitter"
	spawn_enemy("spitter",player.position+Vector3(3.0,0,0));_visual_tick(0)
func start_net_hauler_trial() -> void:
	start_run(true);clear_actors();drill_kind="net_hauler"
	spawn_enemy("net_hauler",player.position+Vector3(3.0,0,0));_visual_tick(0)
func start_crewman_trial() -> void:
	start_run(true);clear_actors();drill_kind="crewman"
	spawn_enemy("harpooner",player.position+Vector3(5.0,0,0));_visual_tick(0)
func start_brinehound_trial() -> void:
	start_run(true);clear_actors();drill_kind="brinehound"
	spawn_enemy("brinehound",player.position+Vector3(3.0,0,0));_visual_tick(0)
func start_fisherman_trial() -> void:
	start_run(true);clear_actors();drill_kind="fisherman"
	spawn_enemy("fisherman",player.position+Vector3(2.4,0,0));_visual_tick(0)
func start_parry_drill(kind: String="melee") -> void:
	if kind not in ["melee","ranged","elite"]:return
	start_run(true);clear_actors();drill_kind=kind
	spawn_enemy(kind,Vector3(2.4,.03,0));_visual_tick(0)
func cycle_drill() -> void:
	if drill_kind in ["fisherman","brinehound","crewman","net_hauler","spitter"]:return
	if inventory_open or mode!="practice" or drill_kind=="":return
	var kinds: Array=["melee","ranged","elite"]
	start_parry_drill(kinds[(kinds.find(drill_kind)+1)%3])

func _guard_contact_point(source: Vector3) -> Vector3:
	var direction:=source-player.position if source.is_finite() else aim
	direction.y=0
	if direction.length_squared()<.000001:direction=aim
	direction.y=0
	if direction.length_squared()<.000001:direction=Vector3.RIGHT
	return player.position+direction.normalized()*.8+Vector3.UP*.85

func _award_perfect_dodge() -> void:
	if not rewards.reward():return
	stamina=minf(stats.value("max_stamina"),stamina+rewards.PERFECT_REFUND)
	fx.number(player.position+Vector3.UP*1.8,"PERFECT DODGE +15",true)
	fx.ring(player.position,1.0,Color(.5,1,.85,.9),.28)
	audio.play("parry")
func check_perfect_evade(enemy) -> void:
	if not rewards.can_perfect() or enemy.kind=="ranged" or enemy.attack_data.is_empty():return
	if not (enemy.threatens(rewards.dodge_origin) if enemy.has_method("threatens") else Enemy.Attacks.contains(enemy.position,enemy.attack_angle,rewards.dodge_origin,enemy.attack_data)):return
	var query:=PhysicsRayQueryParameters3D.create(enemy.position+Vector3.UP*.65,rewards.dodge_origin+Vector3.UP*.65,1)
	if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():return
	_award_perfect_dodge()

func attack_cost(family: String,stage: int,aimed: bool=false) -> float:
	return energy.cost(family,stage,aimed)*stats.value("stamina_cost_multiplier")*anatomy.action_cost_multiplier()
func _can_spend(amount: float) -> bool:
	if stamina+.0000001>=amount:return true
	energy.flash=.3
	return false
func _spend_stamina(amount: float) -> bool:
	if not _can_spend(amount):return false
	stamina=maxf(0,stamina-amount);energy.delay_left=stats.value("stamina_delay")
	return true

func toggle_stats() -> void:
	_cancel_revive()
	_cancel_bow()
	_cancel_crossbow_load()
	_cancel_rifle_action()
	_cancel_staff_actions()
	if not stats_open:
		if inventory_open or mode not in ["menu","practice","combat","paused"] or motion.busy or pair_strikes.active or _dodge_left>0:return
		readiness.release();pistol_aim_state.reset();_held=false
	stats_open=not stats_open
	stats_panel.refresh();stats_panel.surface.visible=stats_open
	pistol_reticle.update_view(self)
	rifle_scope.update_view(self)


func release_great_charge() -> bool:
	if not motion.is_great_charging():return false
	_refresh_aim()
	if not motion.release_great_charge():return false
	var spec: Dictionary=motion.definition(motion.stage)
	var plan: Dictionary=_melee_approach.choose("greatsword",motion.stage,player.global_position,aim,spec,enemies,player.get_world_3d())
	if plan.assisted:aim=plan.direction
	motion.retarget_charge(atan2(aim.z,aim.x));melee_approach_plan=plan
	_attack_step.begin("greatsword",motion.stage,motion.aim_angle,plan.get("distance",-1.0),plan.get("distance_limit",.85),plan.get("assisted",false))
	attack_step_travelled=0
	return true
func _cancel_great_charge() -> void:
	if not is_instance_valid(player) or not motion.is_great_charging():return
	motion.reset();_held=false;_reset_attack_step();rewards.clear_chain()

func crossbow_magazine():
	var key: String = active_item if loadout_mode else "free"
	if not _crossbow_magazines.has(key):
		var magazine = Magazine.new()
		magazine.configure({"magazine_capacity": 1, "reload_time": CROSSBOW_RELOAD_TIME})
		magazine.rounds = 0
		_crossbow_magazines[key] = magazine
	return _crossbow_magazines[key]

func _crossbow_allowed() -> bool:
	return primary_family() == "crossbow" and mode in ["practice", "combat"] and body_action_ready() \
		and active_weapon_possible() and not inventory_open and not stats_open and _dodge_left <= 0.0 \
		and not skill_active and not motion.busy and readiness.broken_left <= 0.0

func _load_crossbow() -> bool:
	if not _crossbow_allowed(): return false
	var magazine = crossbow_magazine()
	if not magazine.start_reload(): return false
	_crossbow_loading = magazine
	readiness.release()
	_held = false
	audio.play("charge")
	return true

func _fire_crossbow() -> bool:
	if not _crossbow_allowed(): return false
	var magazine = crossbow_magazine()
	if not magazine.can_fire() or not _spend_stamina(8.0): return false
	_refresh_aim()
	var origin := player.global_position + Vector3.UP * 0.80
	var shot := {"element": "physical", "projectile_visual": "bolt", "damage": 36.0,
		"projectile_range": 10.0, "projectile_speed": 27.0, "projectile_radius": 0.09,
		"knockback": 0.45, "launch_origin": origin}
	if not staff_flight.spawn_fireball(origin + aim * 0.95, aim, shot, camera): return false
	magazine.consume()
	audio.play("equip")
	return true

func _companion_projectile_damage(enemy, damage: float, knock: Vector3, element: String, bolt: bool) -> void:
	if bolt: _crossbow_hit(enemy, damage, knock, false)
	else: enemy_hit(enemy, damage, knock, element, -1.0, false, "", false)

func _crossbow_hit(enemy, damage: float, knock: Vector3, from_player: bool = true) -> void:
	var before: float = enemy.health
	enemy_hit(enemy, damage, knock, "physical", -1.0, false, "", from_player)
	if not is_instance_valid(enemy) or enemy.dead or enemy.health >= before: return
	if enemy.crossbow_wound_ticks == 0:
		enemy.crossbow_wound_time = 0.0
		if vision.can_see(enemy.position):
			fx.number(enemy.position + Vector3.UP * 1.9, "แผลลึก", false, enemy.position)
	enemy.crossbow_wound_ticks = CROSSBOW_WOUND_TICKS
	enemy.crossbow_wound_from_player = from_player

func _cancel_crossbow_load() -> void:
	if _crossbow_loading == null: return
	_crossbow_loading.cancel_reload()
	_crossbow_loading = null

func _reset_crossbows() -> void:
	_cancel_crossbow_load()
	_crossbow_magazines.clear()

func bow_tier() -> int:
	if bow_charge < 0.0: return 0
	if bow_charge >= BOW_FULL_TIME: return 3
	return 2 if bow_charge >= BOW_MEDIUM_TIME else 1

func _bow_allowed() -> bool:
	return primary_family() == "bow" and mode in ["practice", "combat"] and body_action_ready() \
		and active_weapon_possible() and not inventory_open and not stats_open and _dodge_left <= 0.0 \
		and _bow_recovery <= 0.0 and not skill_active and not motion.busy

func _begin_bow() -> bool:
	if bow_charge >= 0.0 or not _bow_allowed(): return false
	_held = false
	readiness.release()
	_refresh_aim()
	bow_charge = 0.0
	return true

func release_bow() -> bool:
	var tier := bow_tier()
	if tier == 0: return false
	bow_charge = -1.0
	if not _bow_allowed() or not _spend_stamina(4.0 + tier * 2.0): return false
	_refresh_aim()
	var shot: Dictionary = BOW_SHOTS[tier - 1].duplicate()
	shot.element = "physical"
	shot.projectile_visual = "arrow"
	shot.projectile_radius = 0.08
	shot.knockback = 0.35
	shot.launch_origin = player.global_position + Vector3.UP * 0.86
	if not staff_flight.spawn_fireball(shot.launch_origin + aim * 0.58, aim, shot, camera): return false
	audio.play("equip")
	_bow_recovery = BOW_RETREAT_TIME
	_bow_shot_direction = aim if tier == 3 else Vector3.ZERO
	_bow_retreat.reset()
	return true

func _cancel_bow() -> void:
	bow_charge = -1.0
	_bow_recovery = 0.0
	_bow_shot_direction = Vector3.ZERO
	_bow_retreat.reset()

func _sync_staff_key() -> void:
	var id: String=(loadout.primary() if loadout_mode else "free:staff") if primary_family()=="staff" else ""
	if id != staff_energy.key: _cancel_staff_actions()
	staff_energy.bind(id)
func _staff_allowed() -> bool:
	if not body_action_ready() or not active_weapon_possible():return false
	return primary_family()=="staff" and mode in ["practice","combat"] and not anatomy.dead() and not inventory_open and not stats_open and _dodge_left<=0 and not motion.busy and not pair_strikes.active and not skill_active and readiness.broken_left<=0
func _staff_pay_unit() -> bool:return _spend_stamina(attack_cost("staff",0))
func staff_skills_available(id: String = StaffMotion.CHARGED_FIRE_ID) -> bool:
	var skill: Dictionary = StaffMotion.SKILLS.get(id, {})
	return not skill.is_empty() and _staff_allowed() and not staff_energy.casting and not staff_energy.switching \
		and _staff_breath_ticks == 0 and staff_energy.units >= int(skill.orbs) and mana >= staff_skill_cost(id) \
		and float(sword_skill_cooldowns.get(id, 0.0)) <= 0.0

func staff_skill_cost(id: String) -> float:
	var skill: Dictionary = StaffMotion.SKILLS.get(id, {})
	var cost: float = float(skill.get("cost", 0.0)) * stats.talent_factor("skill_mana")
	return cost * .5 if id != StaffMotion.FOCUS_ID and staff_energy.focus_left > 0.0 else cost

func staff_weapon_power(item_id: String = "") -> float:
	var id := item_id if not item_id.is_empty() else (loadout.primary() if loadout_mode else "")
	return float(loadout.items.get(id, {}).get("staff_power", StaffMotion.BASE_WEAPON_POWER))

func sword_weapon_power(item_id: String = "") -> float:
	var id := item_id if not item_id.is_empty() else (active_item if loadout_mode else "")
	return float(loadout.items.get(id, {}).get("sword_power", SwordMotion.BASE_WEAPON_POWER))

func mace_weapon_power(item_id: String = "") -> float:
	var id := item_id if not item_id.is_empty() else (active_item if loadout_mode else "")
	return float(loadout.items.get(id, {}).get("mace_power", MaceSkillMotion.BASE_WEAPON_POWER))

func staff_skill_scaling(id: String) -> Vector2:
	return StaffMotion.scaling(id, staff_weapon_power(), stats.value("intelligence"), stats.level)

func staff_charge_time(id: String) -> float:
	var skill: Dictionary = StaffMotion.SKILLS[id]
	var windup: float = stats.talent_factor("area_windup") if SkillTags.is_area(skill) or id == StaffMotion.CHARGED_FIRE_ID else 1.0
	return float(skill.charge_time) * windup / StaffMotion.charge_speed(stats.value("intelligence"))

func _staff_ground_spec(id: String) -> Dictionary:
	var spec := StaffMotion.ground_spell(id, staff_energy.casting_elements(), staff_skill_scaling(id), stats.level)
	if spec.has("radius"): spec.radius *= stats.talent_factor("skill_area")
	return spec

func _activate_staff_focus() -> bool:
	if not staff_skills_available(StaffMotion.FOCUS_ID): return false
	_sync_staff_key()
	_cancel_staff_actions()
	_held = false
	mana -= staff_skill_cost(StaffMotion.FOCUS_ID)
	sword_skill_cooldowns[StaffMotion.FOCUS_ID] = StaffMotion.focus_cooldown(stats.level) * stats.talent_factor("skill_cooldown")
	staff_energy.focus_left = staff_energy.FOCUS_DURATION
	staff_energy.prepend_neutral(2)
	var tip := _staff_tip(current_visual_sample())
	fx.staff_focus_flash(tip)
	fx.burst(tip, staff_energy.ELEMENT_COLORS[staff_energy.NEUTRAL], 14)
	audio.play("staff_charge3")
	return true

func _pay_staff_skill(id: String, orbs_spent: int) -> void:
	mana -= staff_skill_cost(id)
	if staff_energy.focus_left > 0.0: staff_energy.grant_neutral(floori(orbs_spent / 2.0))

func staff_skill_charging(index: int) -> bool:
	return index == _staff_charge_slot and staff_energy.casting

func request_staff_basic() -> bool:
	if not _staff_allowed() or staff_energy.casting or staff_energy.switching or _staff_breath_slot >= 0: return false
	_sync_staff_key()
	var element: String = staff_energy.element
	var spent_element: String = element if staff_energy.slots.has(element) else staff_energy.NEUTRAL
	if not staff_energy.slots.has(spent_element):
		staff_energy.empty_flash = .3
		return false
	staff_energy.stop_load()
	var no_cast_orbs: Array[String] = []
	motion.configure_staff(1, element, no_cast_orbs, "", staff_skill_scaling(""))
	_staff_committing = true
	var started := _start_weapon_attack(0)
	_staff_committing = false
	if started: staff_energy.spend_orb(spent_element)
	return started

func cycle_staff_element() -> bool:
	if not _staff_allowed() or staff_energy.casting or _staff_breath_ticks > 0: return false
	_stop_staff_breath()
	_sync_staff_key()
	if not staff_energy.cycle_element(): return false
	ui.refresh()
	return true

func begin_staff_load() -> bool:
	if not _staff_allowed() or _staff_breath_ticks > 0:return false
	_stop_staff_breath()
	_sync_staff_key();_held=false;readiness.release();pistol_aim_state.reset()
	var ok: bool=staff_energy.begin_load()
	if ok:audio.play("charge")
	return ok
func begin_staff_cast(id: String = StaffMotion.CHARGED_FIRE_ID) -> bool:
	if not staff_skills_available(id): return false
	var skill: Dictionary = StaffMotion.SKILLS[id]
	if not skill.has("charge_time"): return false
	_stop_staff_breath()
	_sync_staff_key();_held=false;_refresh_aim()
	var ok: bool=staff_energy.begin_cast(skill.orbs, staff_charge_time(id), skill.element)
	if ok:
		_staff_charge_skill = id
		audio.play("staff_charge1")
	else:audio.play("ui")
	return ok
func release_staff_cast() -> bool:
	if not _staff_allowed() or not staff_energy.casting:return false
	_staff_charge_slot = -1
	var skill: Dictionary = StaffMotion.SKILLS[_staff_charge_skill]
	if not staff_energy.cast_ready() or mana < staff_skill_cost(_staff_charge_skill):
		_cancel_staff_actions()
		return false
	_refresh_aim()
	var ground_spec := _staff_ground_spec(_staff_charge_skill)
	if not ground_spec.is_empty():
		var destination := _staff_ground_target()
		staff_energy.release_cast()
		_pay_staff_skill(_staff_charge_skill, skill.orbs)
		_staff_ground.clear_preview()
		_staff_ground.place(fx, destination, ground_spec, camera)
		fx.burst(destination + Vector3.UP * .3, ground_spec.color, 11)
		audio.play("fire_cast")
		return true
	motion.configure_staff(skill.tier, skill.element, staff_energy.casting_elements(), _staff_charge_skill, staff_skill_scaling(_staff_charge_skill))
	_staff_committing=true
	var ok: bool=_start_weapon_attack(0)
	_staff_committing=false;_held=false
	if ok:
		staff_energy.release_cast()
		_pay_staff_skill(_staff_charge_skill, skill.orbs)
	else:
		_cancel_staff_actions()
	return ok

func _cancel_staff_actions() -> void:
	staff_energy.cancel_actions()
	_staff_ground.clear_preview()
	_stop_staff_breath()

func _staff_ground_target() -> Vector3:
	var origin := player.global_position
	var target := origin + aim * StaffMotion.GROUND_CAST_REACH
	if test_aim.length_squared() <= .001:
		var ray_origin := camera.project_ray_origin(_mouse_position)
		var ray := camera.project_ray_normal(_mouse_position)
		if absf(ray.y) > .001:
			target = ray_origin + ray * ((origin.y - ray_origin.y) / ray.y)
	target = origin + (target - origin).limit_length(StaffMotion.GROUND_CAST_REACH)
	if arena.has_method("clamp_point"):
		target = arena.clamp_point(target)
	elif encounter_mode == "dungeon":
		target.x = clampf(target.x, -arena.room_half.x + .3, arena.room_half.x - .3)
		target.z = clampf(target.z, -arena.room_half.y + .3, arena.room_half.y - .3)
	else:
		target.x = clampf(target.x, -11.6, 11.6)
		target.z = clampf(target.z, -9.0, 9.0)
	target.y = origin.y
	if target.is_equal_approx(origin): return target
	var height := Vector3.UP * .55
	var query := PhysicsRayQueryParameters3D.create(origin + height, target + height, 1)
	query.hit_from_inside = true
	var cover := get_world_3d().direct_space_state.intersect_ray(query)
	if not cover.is_empty():
		target = cover.position - height - origin.direction_to(target) * .1
	return target

func _update_staff_ground_preview() -> void:
	if not staff_energy.casting: return
	var spec := _staff_ground_spec(_staff_charge_skill)
	if not spec.is_empty():
		_staff_ground.show_preview(fx, _staff_ground_target(), spec.radius, spec.color, staff_energy.cast_ready())

func _resolve_staff_ground_impacts(fields: Array[Dictionary]) -> void:
	for field in fields:
		var center: Vector3 = field.center
		_dummy_idle = 0.0
		var meteor: bool = field.element == "fire"
		if meteor:
			fx.staff_meteor_impact(center, field.radius, camera)
			fx.ring(center + Vector3.UP * .06, field.radius, Color("#ffc270", .8), .26)
			_shake = maxf(_shake, .23)
		else:
			fx.staff_ice_crystals(center, field.radius, camera)
		audio.play("nova")
		for enemy in _player_attack_targets().duplicate():
			if not _can_hit_player_target(enemy): continue
			if not StaffGroundSpells.contains(field, enemy.global_position): continue
			if not _mace_ground_line_clear(center, enemy.global_position): continue
			var health_before: float = enemy.health
			enemy_hit(enemy, field.damage, Vector3.ZERO, field.element)
			if not meteor and is_instance_valid(enemy) and not enemy is Companion and enemy.health < health_before:
				enemy.apply_ice_root()
		if meteor and int(field.sparks) > 0: _staff_meteor_sparks(field)

func _staff_meteor_sparks(field: Dictionary) -> void:
	var center: Vector3 = field.center
	var outer_radius: float = field.radius + StaffMotion.METEOR_SPARK_REACH
	var candidates: Array[Dictionary] = []
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.dead: continue
		var offset: Vector3 = enemy.global_position - center
		var distance_squared := Vector2(offset.x, offset.z).length_squared()
		if distance_squared <= float(field.radius) ** 2 or distance_squared > outer_radius ** 2: continue
		if not _mace_ground_line_clear(center, enemy.global_position): continue
		candidates.append({"enemy": enemy, "distance": distance_squared})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary): return a.distance < b.distance)
	for index in range(mini(int(field.sparks), candidates.size())):
		var enemy: Node3D = candidates[index].enemy
		if not is_instance_valid(enemy) or enemy.dead: continue
		var contact := enemy.global_position + Vector3.UP * .85
		var direction := ((contact - center) * Vector3(1, 0, 1)).normalized()
		var edge := center + direction * float(field.radius)
		fx.staff_lightning_arc(edge + Vector3.UP * .45, contact)
		enemy_hit(enemy, field.spark_damage, Vector3.ZERO, "lightning")

func _refund_staff_mana(at: Vector3) -> void:
	var refund := _staff_ground.mana_refund(at)
	if refund <= 0.0: return
	var previous_mana := mana
	mana = minf(stats.value("max_mana"), mana + refund)
	if mana > previous_mana:
		fx.burst(at + Vector3.UP * .72, Color("#d5aeff"), 7, at)
		fx.number(at + Vector3.UP * 1.95, "+%s MP" % String.num(mana - previous_mana, 1), false, at)

func staff_breath_status(index: int) -> String:
	if index != _staff_breath_slot: return ""
	return "กำลังพ่นไฟ" if _staff_breath_ticks > 0 else "คลิกซ้ายค้างเพื่อพ่นไฟ"

func _arm_staff_breath(index: int) -> bool:
	if _staff_breath_slot == index and _staff_breath_ticks == 0:
		_stop_staff_breath()
		return true
	if not staff_skills_available(StaffMotion.FIRE_BREATH_ID): return false
	_sync_staff_key()
	staff_energy.stop_load()
	_held = false
	_staff_breath_slot = index
	audio.play("staff_charge1")
	return true

func _start_staff_breath() -> bool:
	if _staff_breath_slot < 0 or not staff_skills_available(StaffMotion.FIRE_BREATH_ID): return false
	var skill: Dictionary = StaffMotion.SKILLS[StaffMotion.FIRE_BREATH_ID]
	var orbs: Array[String] = staff_energy.spend_prefix(skill.orbs)
	_staff_breath_bonus = StaffMotion.orb_multipliers(skill.element, orbs) * staff_skill_scaling(StaffMotion.FIRE_BREATH_ID)
	_pay_staff_skill(StaffMotion.FIRE_BREATH_ID, orbs.size())
	_refresh_aim()
	_staff_breath_angle = atan2(aim.z, aim.x)
	_staff_breath_ticks = StaffMotion.BREATH_TICKS
	_staff_breath_elapsed = 0.0
	_dummy_idle = 0.0
	audio.play("fire_cast")
	return true

func _stop_staff_breath() -> void:
	_staff_breath_slot = -1
	_staff_breath_ticks = 0
	if is_instance_valid(fx): fx.hide_staff_fire_breath()

func _advance_staff_breath(delta: float) -> void:
	if _staff_breath_ticks <= 0: return
	if not _staff_allowed():
		_stop_staff_breath()
		return
	var desired := atan2(aim.z, aim.x)
	_staff_breath_angle = rotate_toward(_staff_breath_angle, desired, StaffMotion.BREATH_TURN_RATE * delta)
	var half_angle := StaffMotion.BREATH_HALF_ANGLE * _staff_breath_bonus.y
	var origin := player.global_position
	var muzzle := _staff_tip(current_visual_sample())
	var breath_age := (StaffMotion.BREATH_TICKS - _staff_breath_ticks) * StaffMotion.BREATH_INTERVAL + _staff_breath_elapsed + delta
	fx.staff_fire_breath(muzzle, origin, _staff_breath_angle, half_angle, StaffMotion.BREATH_REACH * stats.talent_factor("skill_area"), camera, breath_age)
	_staff_breath_elapsed += delta
	while _staff_breath_ticks > 0 and _staff_breath_elapsed >= StaffMotion.BREATH_INTERVAL - StaffMotion.EPSILON:
		_staff_breath_elapsed -= StaffMotion.BREATH_INTERVAL
		_staff_breath_ticks -= 1
		_staff_breath_damage(origin, half_angle)
		if _staff_breath_ticks == 0: _stop_staff_breath()

func _staff_breath_damage(origin: Vector3, half_angle: float) -> void:
	var damage := StaffMotion.BREATH_DAMAGE * _staff_breath_bonus.x
	for enemy in _player_attack_targets().duplicate():
		if not _can_hit_player_target(enemy): continue
		var offset: Vector3 = enemy.global_position - origin
		var ground := Vector2(offset.x, offset.z)
		if ground.length_squared() > (StaffMotion.BREATH_REACH * stats.talent_factor("skill_area")) ** 2: continue
		if absf(angle_difference(_staff_breath_angle, ground.angle())) > half_angle: continue
		if not _armor_line_clear(enemy): continue
		var contact: Vector3 = enemy.global_position + Vector3.UP * .8
		fx.burst(contact, Color("#ff9b49"), 3)
		enemy_hit(enemy, damage, Vector3.ZERO, "fire", -1.0, true)
		if _staff_breath_slot < 0: return

func _ground_burn(enemy,amount: float) -> void:
	enemy_hit(enemy,amount,Vector3.ZERO,"fire",-1.0,true)

func rifle_finisher_charging() -> bool:
	return motion == _basic_motion and _basic_motion.rifle_finisher_charging()

func rifle_aiming() -> bool:return primary_family()=="rifle" and (rifle_finisher_charging() or right_action()=="aim")

func equipped_rifle_cycle() -> RifleCycle:
	var cycle = item_magazines.get(loadout.primary()) if loadout_mode else null
	return cycle if cycle is RifleCycle else rifle_magazine

func rifle_display_queue() -> Array[String]:
	var queue := equipped_rifle_cycle().round_ids()
	if rifle_finisher_charging() and not queue.is_empty():
		queue.pop_back()
		queue.push_front(RifleMotion.FINISHER_ID)
	return queue
func _rifle_request_gate() -> bool:
	var mag=active_magazine()
	if mag.reloading:
		if mag.rounds>0:mag.close_reload();_rifle_pending_fire=true
		return false
	if mag.rounds<=0:request_reload();return false
	if mag.needs_bolt:
		if not mag.bolt_active:mag.start_bolt()
		_rifle_pending_fire=true;return false
	return true
func _cancel_rifle_action() -> void:
	_rifle_pending_fire=false
	if primary_family()=="rifle":active_magazine().cancel_bolt()
func _rifle_events(mag) -> void:
	var cues: Array=mag.events.duplicate();mag.events.clear()
	if mag!=active_magazine():return
	for cue in cues:
		if cue=="eject":
			var at: Vector3=player.position+Vector3.UP*.85+aim*.3
			casing_fx.spawn(at,aim,camera);audio.play("rifle_rack")
		elif cue=="insert":
			ui.turn_rifle_gears(true)
			audio.play("rifle_insert")
		else:audio.play("rifle_reload_done")
func _rifle_damage(enemy,damage: float,knock: Vector3) -> void:
	if not is_instance_valid(enemy) or enemy.dead: return
	var health_before: float = enemy.health
	enemy_hit(enemy, damage * enemy.rifle_mark.multiplier(), knock, "physical")
	if is_instance_valid(enemy) and enemy.health < health_before:
		enemy.rifle_mark.clear()

func _rifle_mark_damage(enemy, damage: float, knock: Vector3) -> void:
	if not is_instance_valid(enemy) or enemy.dead: return
	var health_before: float = enemy.health
	enemy_hit(enemy, damage, knock, "physical")
	if is_instance_valid(enemy) and enemy.health < health_before and enemy.apply_rifle_mark():
		fx.burst(enemy.position + Vector3.UP * .8, Color("#e7acff"), 6, enemy.position)

func _rifle_armor_damage(enemy, damage: float, knock: Vector3, stacks: int) -> void:
	var health_before: float = enemy.health
	_rifle_damage(enemy, damage, knock)
	_apply_skill_armor_stacks(enemy, health_before, stacks)

func _rifle_pellet_damage(enemy, damage: float, knock: Vector3, volley: Dictionary) -> void:
	if not is_instance_valid(enemy) or enemy.dead: return
	var target_id: int = enemy.get_instance_id()
	var multiplier: float = volley.get(target_id, enemy.rifle_mark.multiplier())
	var health_before: float = enemy.health
	enemy_hit(enemy, damage * multiplier, knock, "physical")
	if is_instance_valid(enemy) and enemy.health < health_before and not volley.has(target_id):
		volley[target_id] = multiplier
		enemy.rifle_mark.clear()

func has_dual_weapons() -> bool:
	if not loadout_mode:return false
	var ids: Array=available_body_items()
	if ids.size()!=2:return false
	for id: String in ids:
		if bool(loadout.items[id].two_hand) or loadout.items[id].family == "shield":return false
	return true
func _is_normal_melee() -> bool:
	return not skill_active and weapon_family in ["sword", "greatsword", "mace"] and motion.definition(motion.stage).get("kind") != "fire_lift"

func attack_rate() -> float:
	if rifle_finisher_charging(): return 1.0
	var bonus := 0.10 if _storm_blade_has_current_sword() else 0.0
	if weapon_family=="pistol":bonus=_pistol_shot_bonus if motion.busy else (pistol_aim_state.speed_bonus() if readiness.held else 0.0)
	var melee_speed: float = stats.talent_factor("melee_speed") if _is_normal_melee() else 1.0
	return stats.value("attack_speed") * melee_speed * DualRules.speed(has_dual_weapons()) * (1.0 + bonus) * weapon_injury_factor()
func rifle_weapon_stats(item_id: String = "") -> Dictionary:
	var id: String = item_id if not item_id.is_empty() else (loadout.primary() if loadout_mode else "")
	return loadout.items.get(id, {}).get("rifle_stats", RifleMotion.DEFAULT_WEAPON_STATS)

func rifle_projectile_profile(id: String, item_id: String = "") -> Dictionary:
	var profile := RifleMotion.projectile_profile(id, float(rifle_weapon_stats(item_id).power), stats.attributes, stats.level)
	if profile.has("rifle_split"): profile.rifle_split.reach *= stats.talent_factor("skill_area")
	if profile.has("scatter_angles"):
		var spread: float = stats.talent_factor("spread")
		for index in profile.scatter_angles.size(): profile.scatter_angles[index] *= spread
	return profile

func reload_rate(magazine: Variant = null) -> float:
	var rate: float = stats.value("reload_speed") * DualRules.speed(has_dual_weapons()) * weapon_injury_factor()
	if magazine is RifleCycle:
		var item_id: String = str(item_magazines.find_key(magazine)) if magazine != rifle_magazine else ""
		var bonus: float = RifleMotion.DEFAULT_WEAPON_STATS.reload if magazine == rifle_magazine else float(rifle_weapon_stats(item_id).reload)
		rate /= RifleMotion.time_scale(stats.attributes, bonus)
	return rate
func weapon_injury_factor() -> float:
	var two_hand: bool=bool(loadout.items[active_item].two_hand) if loadout_mode and active_item in loadout.items else weapon_family in ["greatsword","staff","rifle","bow","crossbow"]
	return anatomy.weapon_speed("left_arm" if _is_left_hand() else "right_arm",two_hand)
func gun_spread(family: String,aimed: bool) -> float:
	if family == "rifle" and aimed: return 0.0
	var spread: float=pistol_aim_state.spread(aimed) if family=="pistol" else ReadyRules.spread(family,aimed)
	return spread * DualRules.dispersion(has_dual_weapons()) * stats.talent_factor("spread")

func max_health() -> float:
	anatomy.bind_max_hp(stats.value("max_health"))
	return stats.value("max_health")*anatomy.hp_multiplier()
func use_health_flask() -> bool:
	if mode not in ["practice","combat"] or inventory_open or stats_open or not body_action_ready() or flasks.charges<=0 or health>=max_health():return false
	health=flasks.drink(health,max_health())
	_visual_tick(0)
	return true
func available_body_items() -> Array:
	var result: Array=[]
	if not loadout_mode:return result
	var single_item := _storm_blade_single_item()
	if not single_item.is_empty(): return [single_item]
	for id in loadout.for_pair():
		if _body_item_usable(id):result.append(id)
	return result
func _body_item_usable(id: String) -> bool:
	if id=="" or not loadout.items.has(id):return false
	var pair: Dictionary=loadout.sets[loadout.active]
	var arm: String="left_arm" if id==pair.off else "right_arm"
	return anatomy.functional(arm) and (not bool(loadout.items[id].two_hand) or anatomy.arm_count()==2)
func active_weapon_possible() -> bool:
	if encounter_mode=="wreck_shore":return false
	if anatomy.dead():return false
	if loadout_mode:return not available_body_items().is_empty()
	return anatomy.functional("right_arm") and (weapon_family not in ["greatsword","staff","rifle","bow","crossbow"] or anatomy.arm_count()==2)
func body_action_ready() -> bool:
	return mode != "downed" and not body_lab_open and not anatomy.dead() and (anatomy.leg_count()>0 or (_dodge_left<=0 and _movement().length_squared()<.001 and _crawl_still>=.25-.000001))
func _cancel_body_actions() -> void:
	_cancel_revive()
	_cancel_bow()
	_cancel_crossbow_load()
	_cancel_skill();_cancel_staff_actions();_cancel_rifle_action();motion.reset();_reset_attack_step()
	readiness.release();pistol_aim_state.reset();_held=false;_dodge_left=0;_next_combo=0
	for mag in [pistol_magazine,rifle_magazine]+item_magazines.values():mag.cancel_reload()
	reload_visual.cancel()
func _sync_body_state() -> void:
	var key: String=anatomy.capability_key()
	if key!=_body_key:
		_cancel_body_actions();_crawl_still=0 if anatomy.leg_count()==0 else .25;_body_key=key
		var ids: Array=available_body_items()
		if not ids.is_empty():_select_loadout_item(ids[0])
	health=minf(health,max_health())
	if anatomy.dead():_die_from_body()
	if is_instance_valid(anatomy_panel):anatomy_panel.refresh()
func set_body_integrity(part: String,value: float) -> void:
	anatomy.set_integrity(part,value);_sync_body_state();_visual_tick(0)
func remove_body_part(part: String) -> void:
	anatomy.remove(part);_sync_body_state();_visual_tick(0)
func hit_body_part(part: String,value: float,red: bool=false) -> void:
	max_health();anatomy.damage(part,value,red);_sync_body_state();_visual_tick(0)
func restore_body_part(part: String) -> void:
	anatomy.restore(part);_sync_body_state();_visual_tick(0)
func restore_body() -> void:
	anatomy.reset();_sync_body_state();health=max_health();stamina=stats.value("max_stamina");_visual_tick(0)
func set_debug_health_zero() -> void:
	health=0;_visual_tick(0)
func toggle_body_lab() -> void:
	if mode not in ["practice","combat"] or inventory_open or stats_open or sword_skills_open or dungeon_peek.visible:return
	if not body_lab_open:_cancel_body_actions()
	body_lab_open=not body_lab_open;_visual_tick(0)

func _body_default_item() -> String:
	var ids: Array=available_body_items()
	for id: String in ids:
		if loadout.items[id].family != "shield": return id
	return ids[0] if not ids.is_empty() else loadout.primary()

func _crawl_pose_ready() -> bool:
	if _dodge_left>0:return false
	return body_action_ready() or motion.busy or staff_energy.loading or staff_energy.casting or guns_reloading()
