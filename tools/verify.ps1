param([Parameter(Mandatory=$true)][string]$GodotPath)
$ErrorActionPreference = 'Stop'
$projectFolder = Split-Path -Parent $PSScriptRoot
& $GodotPath --headless --path $projectFolder --editor --quit
if ($LASTEXITCODE -ne 0) { throw 'Project import failed' }
foreach ($name in @('test_direction_angles.gd','test_four_directions.gd','test_reload_style.gd','test_reload_events.gd','test_holding.gd','test_skill_hands.gd','test_mixed_reload.gd','qc_actions.gd','test_arsenal.gd','test_pixel_art.gd','test_weapon_motion.gd','test_sword_pace.gd','test_sword_motion.gd','test_greatsword_motion.gd','test_mace_motion.gd','test_staff_motion.gd','test_pistol_motion.gd','test_rifle_motion.gd','test_magazine.gd','test_greatsword_visual.gd','test_sword_visual_continuity.gd','test_mace_visual.gd','test_staff_visual.gd','test_pistol_visual.gd','test_rifle_visual.gd','test_staff_projectiles.gd','test_legacy_slash_fx.gd','test_armor_pierce.gd','test_armor_pierce_game.gd','test_twin_cut.gd','test_twin_cut_game.gd','test_fire_splash.gd','test_ranged_balance_game.gd','test_pistol_projectiles.gd','test_rifle_projectiles.gd','test_attack_step.gd','test_melee_approach.gd','test_melee_approach_game.gd','test_attack_step_game.gd','test_combo_continuation.gd','test_game.gd','test_combat_edges.gd','test_greatsword_game.gd','test_mace_game.gd','test_staff_game.gd','test_pistol_game.gd','test_rifle_game.gd')) {
    & $GodotPath --headless --fixed-fps 240 --disable-vsync --path $projectFolder --script (Join-Path $projectFolder "tests/$name")
    if ($LASTEXITCODE -ne 0) { throw "Failed: $name" }
}
foreach ($family in @('rifle','pistol','staff','mace','greatsword','sword')) {
    & $GodotPath --headless --fixed-fps 120 --disable-vsync --path $projectFolder --script (Join-Path $projectFolder 'tests/playthrough_bot.gd') -- "--family=$family"
    if ($LASTEXITCODE -ne 0) { throw "Normal-input playthrough did not reach victory: $family" }
}
