# Sol Survivor – Audit Log

Running log of audit findings and fixes. Newest entry at the bottom.

## Entry 1 – Initial audit
- MCP: godot-ai connected (Godot 4.7.2-stable), scene `res://scenes/main.tscn`.
- Ran main scene; read editor + game logs.
- Findings:
  1. ERROR `outpost.gd:71` – `global_position` set on a node not yet in the tree (x7, once per interactable).
  2. WARN `meter_system.gd:7` – signal `all_meters_safe` declared, never emitted or connected.
  3. WARN `player.gd:158` – unused parameter `input_dir` in `_process_camera_bob()`.
- Housekeeping notes (not changed): stale `addons/.godot_ai_update/backup/4.3.1/` (300+ files); repo root shows `sol-survivor/` and `sol-survivor.zip` untracked.

## Entry 2 – Fixes applied
| # | File | Change |
|---|------|--------|
| 1 | `scripts/world/outpost.gd` | Moved `node.global_position = m.global_position` to after `add_child(node)` in `_create_marker_interactable`. |
| 2 | `scripts/autoloads/meter_system.gd` | Removed dead signal `all_meters_safe` (grep: no other references). |
| 3 | `scripts/player/player.gd` | Dropped unused `input_dir` param from `_process_camera_bob` and its call site. |

- Verification: filesystem scan, cleared logs, re-ran main scene.

## Entry 3 – Verification
- Re-ran main scene for ~9 s (past the point where the 7 errors fired before). Editor and game logs: 0 errors, 0 warnings.
- Not verified: in-game interactable positions (no screenshot or scene-tree check), and later gameplay (sol progression, event cards, ending).
- Open items: housekeeping notes from Entry 1 (user decision).

## Entry 4 – Second audit
- MCP still connected. Editor log had 2 new errors from user play sessions after Entry 3 (same root cause):
  - ERROR `meter_system.gd:53` and `:62` – signal `meter_changed` (3 args) hit a `hud.gd` lambda that accepted only 2 (`Method expected 2 argument(s), but called with 3`). Hit on `start_game()` and bonus-task completion, so the HUD likely did not refresh on meter changes.
- Fix: `scripts/ui/hud.gd:150` – lambda now `func(_a = null, _b = null, _c = null)`.
- Verification: scan, cleared logs, ran main scene, called `GameManager.start_game()` and `MeterSystem.change_value(&"power", -1.0)` via game_eval. Logs: 0 errors, 0 warnings.
- Not verified: HUD visually updating; later sols and endings; interactable positions (carried from Entry 3).
- Open items: housekeeping notes from Entry 1.

## Entry 5 – Runtime verification (HUD, interactables, playthrough)
- Title screen -> START MISSION (real UI clicks) -> briefing -> DEPLOY TO OUTPOST: works, state PLAYING, Sol 1. Screenshots OK.
- Interactable positions (Entry 2 fix): all 7 Outpost interactables' global_position equals their OutpostAssembly marker. VERIFIED.
- Ray targeting: when aimed directly, all 7 interactables are hit by InteractRay. O2Console and ShelterWall are occluded from one side by model colliders (tanks_col, shelter_col) – minor design note, not changed.
- HUD (Entry 4 fix): `MeterSystem.change_value(life_support, -10)` updated the HUD label "O2 60%" -> "O2 50%". VERIFIED.
- Sol 1 loop: PowerSwitch.complete_interaction() -> EVENT_CARD (Dusty Solar Panels) -> key 1 -> meters changed (power 40->60) -> Bed.complete_interaction() -> NIGHT_SUMMARY (values correct) -> Continue -> Sol 2 PLAYING. Editor log: 0 errors/warnings throughout.
- Test caveats (my tooling, not project bugs): a malformed game_eval (nested func) put the game into a debugger break once; one run bypassed the intro and left the overlay up. Both runs discarded and restarted.
- Not verified: real hold-E input (player script resets camera pitch each frame, so synthetic aiming was unreliable; completion was called directly instead); Sols 2-6, bonus tasks, Dusty bot/drone, ending/debrief/credits.
- Open items: housekeeping notes from Entry 1.

## Entry 6 – Full playthrough (Sols 1-6, both endings, credits)
Method: real UI clicks/keys; real hold-E (input_sequence) for every repair and the bed; meters topped up once (life_support set to 80 on retried Sol 5) to reach the win ending. Runtime errors: 0 throughout (editor + game logs).

Works: title -> briefing -> Sol 1-6 repairs (PowerSwitch, HeaterUnit, O2Console, DomePatch, ShelterWall, DishConsole) -> event cards (keys 1/2/3) -> bed -> night summary -> next sol; failure ending (O2 0% -> "MISSION ABORTED", Debrief); Retry Sol; win ending ("MISSION ACCOMPLISHED", 6 sols); Play Again; credits panel.

Hurdles / issues found (none fixed; all design/polish, awaiting user call):
1. Interactable reach: model colliders from OutpostAssembly partly occlude interactables. PowerSwitch from the front at eye level cannot be targeted (only slightly up/down or from the side); Bed/Dish need ~10-40 deg downward look; O2Console and ShelterWall blocked from one side. Prompt does not appear when the ray hits the model collider instead.
2. Balance: O2 drains ~8%/night plus event costs. Sol 4 choice 1 (water the plants) + night took O2 26 -> 3; Sol 5 night took it to 0 = mission failure with a reasonable-looking path.
3. Retry Sol soft-lock: retry restores sol-start meters (O2 3%) so a retried Sol 5 is nearly unwinnable.
4. Repair sparks (RepairSparks CPUParticles3D) render as very large flat yellow squares at close range.
5. HUD O2 formatting inconsistent: "O2 60%" vs "O2 72.72%" / "O2 0.0%" (decimals when not whole).
6. Night summary: NASA fact header text ("NASA FIELD DATA // NASA ... DATABASE") runs to/past the card's right edge on longer source names.
7. HUD stays visible behind Debrief, intro briefing and credits overlays.
8. Event-card effect tags are very small/low-contrast; option 3 on some cards has no tag (reads as no effect).
9. After Play Again, GameManager.current_state stays DEBRIEF (4) during the intro briefing until DEPLOY.
- Not tested: other resolutions/aspect ratios, gamepad, Dusty bot/drone behaviours and bonus tasks in detail, Escape pause, NASA ARCHIVE button through the real title click (credits panel shown via eval).
- Test-tooling note: warnings from "name" variable in my eval snippets are not project issues.

## Entry 7 – Recommended fix order (no code changed)
1. Interactable vs model-collider occlusion (#1) – blocks core loop, no prompt shown.
2. Retry Sol soft-lock (#3) – player trapped in unwinnable state.
3. O2 balance (#2) – Sol 4-5 failure on a plausible path.
4. HUD number format (#5) – trivial, visible every frame.
5. Repair sparks size (#4).
6. Night-summary header overflow (#6).
7. Event-card tag legibility / missing tags (#8).
8. HUD hidden behind overlays (#7), then state stays DEBRIEF in intro (#9).

## Entry 8 – Quick fixes (#4-#9 from Entry 6)
| Issue | File | Change | Verified |
|---|---|---|---|
| #4 sparks look large | scripts/player/player.gd | BoxMesh 0.04 -> 0.02; scale_amount 0.4-1.0 | Screenshot mid-hold: small, varied sparks |
| #5 HUD O2 decimals | (none) | FALSE ALARM: hud.gd already formats with %d; label reads "O2 73%" for 72.72. Earlier decimals were my misreading of downscaled screenshots. Retracted. | Label text read via eval |
| #6 night-summary header overflow | scripts/ui/night_summary.gd | autowrap (WORD_SMART) + expand-fill on _nasa_header | Sol 6 header wraps inside card |
| #7 tiny event chips / no tag | scripts/ui/event_card.gd | chip font 11 -> 13; "NO IMMEDIATE EFFECT" chip when a choice has no deltas | Sol 3 card screenshot |
| #8 HUD behind overlays | scripts/ui/hud.gd | hide HUD root for state DEBRIEF (4) as well as TITLE | Hidden on Debrief and on the post-Play-Again briefing |
| #9 stale DEBRIEF state in intro | (not changed) | Left as is; with HUD hiding it has no visible effect, and changing it risks title-screen side effects. | - |
- Editor log after all runs: 0 errors, 0 warnings.
- Side effect to know: the wrapped header shifted the night-summary Continue button slightly left (layout, not behaviour).
- Remaining (need a decision): #1 collider occlusion, #3 Retry Sol soft-lock, #2 O2 balance.

## Entry 9 – Fix #1: interactables blocked by model colliders
Cause: interact ray (mask 1) hit decorative model colliders (power_switch_col, tanks_col, shelter_col...) sitting on the same layer, in front of the interactable's box, so no prompt and no interaction.
Changes:
- scripts/world/outpost.gd: interactable StaticBody3D `collision_layer = 1 | 2` (still solid for walking; layer 2 = interactables).
- scripts/player/player.gd: interact ray `collision_mask = 2` set in _ready; constants WORLD_LAYER_MASK / INTERACT_LAYER_MASK / LINE_OF_SIGHT_TOLERANCE (0.5 m); new `_has_line_of_sight(hit_point)` so solid world geometry (layer 1) clearly in front of the target still blocks interaction.
Verification (in game, after scan + cleared logs):
- Before: from 1.8 m at eye level the ray hit the model collider for PowerSwitch front; Bed/Dish/Heater only worked from some sides/pitches.
- After: all 7 interactables targeted from all 4 sides (eye level; Bed and Dish with a natural -12 deg look down). 28/28.
- Wall test: synthetic wall 0.8 m in front of the player blocks the prompt; a thin wall hugging the object does not (by design, 0.5 m tolerance).
- Real hold-E on PowerSwitch from the FRONT (previously failing) completes: state -> EVENT_CARD, repair_completed true.
- Editor log: 0 errors/warnings.
Caveats: first tolerance (1.2 m) was too loose and did not block the near-wall test; tightened to 0.5 m and retested. Walls thinner than 0.5 m directly against an interactable will not block (acceptable). Walking collision with interactable boxes unchanged (layer 1 kept) but not re-tested by walking.
Remaining: #3 Retry Sol soft-lock, #2 O2 balance (both need a design decision).

## Entry 10 – Fix #3: Retry Sol now rewinds one full sol
Decision: user chose "the one with the most impact" -> rewind to the start of the PREVIOUS sol (Sol 1 retries Sol 1).
Problems with the old retry (found while reading the code): it only restored meters from the current sol's start, so (a) a bad earlier choice left O2 at ~3% = unwinnable; (b) night-rule flags were not restored (e.g. sol3_delayed_harvest is consumed on night 5, so a retried Sol 5 lost its +35 food); (c) panels_clean/choice side effects of the retried sol were not undone; (d) future repair objects stayed green; (e) the lander stayed visible after retrying a win.
Changes:
- scripts/autoloads/game_manager.gd: `_sol_snapshots` (per-sol: meters, panels_clean, greenhouse_working, greenhouse_seed_bonus, sol3_delayed_harvest, sol5_dish_head_start, choices) recorded in advance_to_next_sol; cleared in start_game; new `get_retry_target_sol()`; `retry_sol()` rewritten to restore all of it, reset assembly visuals (panels, greenhouse patch = target>4, shelter = target>5, dish, lander), reset REPAIR interactables with sol_number >= target, unpause, re-emit sol_started.
- scripts/outpost_assembly.gd: new `reset_lander()` (also called from start_game, fixing Play Again after a win leaving the lander up).
- scripts/ui/debrief.gd: retry button text is now "RETRY FROM SOL NN".
Verification (in game): drove Sols 1-4 via game logic, forced O2 failure on Sol 5 -> debrief shows "RETRY FROM SOL 04"; real button click -> sol 4, PLAYING, meters exactly the Sol 4 start (36/85/41/40), flags restored, 3 choices kept, DomePatch active, others correct, debrief hidden, tree unpaused; greenhouse crack visible again / patch hidden; replaying Sol 4 with another choice -> Sol 5 with O2 23 (vs 3 before). Lander hidden after retry. Editor log: 0 project errors (one warning from my eval variable named "log").
Not tested: retry from Sol 1 and from a win by real play-through; retry then reaching the true win; interaction of retry with the O2 balance issue (#2).
Remaining: #2 O2 balance (design decision).

## Entry 11 – Decision on #2 (O2 balance) + remaining untested items
Decision (made by me, per user's "make all high-impact decisions"): NO balance number changes.
Evidence (read from resources/events + game_manager night rules): night costs 6 x -8 O2 = -48 from 60. Safe event choices net +15 (sol2 c1 +10, sol4 c3 +5), so a safe run ends ~27% O2 even with zero field tasks. Field-task beacons add +36 O2 more (sol1 +8, sol3 +8, sol4 +10, sol6 +10). The failure seen in earlier tests came from (a) risky choices (sol4 c1 = -15 O2) and (b) my test runs never scanning beacons. Risky choices are intended trade-offs; retry now rewinds a sol (Entry 10), covering the recovery path. Entry 6 issue #2 re-classified: not a bug.
Verified in game (real input):
- NASA ARCHIVE button on the title opens the credits panel; CLOSE hides it. OK.
- Field-task beacon: standing 1.2 m from BonusFieldTask_0 and holding E ~1.25 s gave +10 shield (40 -> 50), beacon turned green, toast text set. OK.
- Escape: frees the mouse cursor only. It does NOT pause the game and there is no pause menu, quit or back-to-title option in game (hurdle, not changed: nothing is time-pressured, so pausing is not required for fairness).
Found, not changed:
- scripts/gameplay/dusty_bot.gd and dusty_drone.gd (+ assets/models/dusty_bot.glb) are never instantiated anywhere (no scene or script references them): dead code / unused feature. Needs user decision: wire up or delete.
- HUD shows only O2 (top-left) and a tiny shield bar (bottom-left); POWER and FOOD are only visible on the night summary, so players choose without seeing them. Event chips do show the deltas.
Still untested: other resolutions/aspect ratios, gamepad input, full real-input hold of every repair after Entry 9 (only PowerSwitch re-run with real hold).

## Entry 12 – HUD: Power and Food meters added
Decision: add to the existing top-left pill (not a new panel) so it matches the current HUD: same SLATE_HUD pill, TEAL_CHIP icon tint, 14 px CREAM_SHEET labels, 1 px 25%-white separators, same icon set as the night summary ("lightning", "apple"). Shield stays as the existing bottom-left bar.
Change: scripts/ui/hud.gd – new _power_label/_food_label, _make_separator(), _set_meter_label() (also used for O2); labels turn TERRACOTTA when a meter is <= LOW_METER_THRESHOLD (20). Pill now reads: [lungs] O2 60% | [bolt] PWR 40% | [apple] FOOD 50% | [house] Base.
Verified in game: screenshot shows the pill in the same style; set_value/change_value update labels live (PWR 75%, FOOD 15%); FOOD 15% shows in warning colour (0.85,0.36,0.22). Editor log: 0 errors.
Notes: terracotta on the dark pill is readable but lower contrast than the cream text; the pill is ~220 px wide at 1920x1080. Not tested at other resolutions. O2 also uses the warning colour now (new behaviour).
Next (user request): level work – placement of the level and building structures.

## Entry 13 – Level survey (layout + building structure) and first fixes
Method: runtime AABBs of every structure, overhead + ground-level camera views, collision rays at doors, terrain probes, distance estimates. Layout is defined in scripts/outpost_assembly.gd (hab (0,-8), greenhouse (-11.85,-8), workshop (10.7,-8), shelter (14.5,-0.5), tanks (6,-4.2), dish (9,4.5), crash pod (-5,10), lander (3,22), spawn (0,1,7.2)).
Findings:
 OK: overhead composition is clean (greenhouse - corridor - hab - corridor - workshop line, raised-pad shelter, solar field, crash site with debris + footprint trail to the hab). Spawn is not inside the crash pod (only the player's own collider overlaps). Walking distances spawn -> objectives are 9-17 m (<= ~4 s at walk speed); objective to bed 8-18 m. Compact, no long dead walks.
 FIXED:
  1. crates_a (crate_stack) sat in the 0.7 m gap between workshop and shelter, overlapping the shelter's bounds and closing the path. Moved to (15.2,0,-8.6) (beside the workshop's far end); rock-exclusion circle updated. Verified AABB (14.3,-9.5)->(17.3,-7.9): clear of workshop (x<=13.6) and shelter (z>=-5.2).
  2. No play-area limit: terrain is a 240 m bowl, rim (~30 m high) is walkable (floor_max_angle 45) and ends in empty space; no kill plane. player.gd now clamps to radius 80 m (PLAY_AREA_RADIUS) and resets to spawn below y=-30 (FALL_RESET_Y). Verified: teleport to x=100 -> clamped to 80; teleport to y=-60 -> back at spawn (0,0.8,7.2). Editor log 0 errors.
 NOT FIXED (needs a design decision):
  3. Hab, workshop, shelter and greenhouse are solid props: doors are closed collision (hab door ray hits hab_col at z=-4.59; shelter z=1.51; workshop z=-6.4). Nothing is enterable.
  4. Because of (3) the "camp" is outdoors: power switch, heater, terminal and BED stand in the open in front of the hab/tanks (the assembly script comments "the hab has no interior yet"). Sleeping outside in a -78 C scene undermines the story, and the Sol 5 radiation-shelter choice ("hide in the shelter") has no shelter you can enter.
  5. Spawn views: hab front is the hero shot (good); crash pod is behind the spawn (player must turn around); lander lands at (3,22), also behind the spawn.
Fog note: Sol 1 storm fog (density 0.02) washes out overhead views; not a bug.

## Entry 14 – Option B: intentional camp (canopy + sleep pod) and a soft-lock found on the way
User chose option B for the structures (keep outdoor camp, make it deliberate).
Change (scripts/outpost_assembly.gd, `_build_camp_canopy()` + `_camp_material()` + `_camp_box()`): lean-to over the bed and terminal built from primitives in the hab palette: 4 solid posts, 5-degree sloped roof at 2.9 m (above head height) with an orange trim strip, windbreak on the +X side (solid), floor pad, warm OmniLight3D + cyan light bar, and a "SLEEP POD" Label3D over the bed. Footprint x 2.2..7.6, z -3.0..0.6: clear of the tanks (z<=-3.4), hab dome, terminal and crate; the front (+Z) is open. Bed/terminal models and interactable markers unchanged.
Verified in game: screenshot (canopy, label, lights, bed and terminal under it); bed targetable from (5.6,2.0), (5.6,0.3) and (4.2,1.2); from (3.0,-0.2) it was not (the small crate beside it blocks line of sight - pre-existing, not caused by the canopy).
BUG FOUND + FIXED (high impact, pre-existing): sleeping before the day's repair+event were done called Interactable.complete_interaction(), which set `_completed = true` BEFORE GameManager rejected it ("COMPLETE PRIMARY OUTPOST REPAIR BEFORE SLEEPING"). The bed then stayed non-interactable for the rest of the sol, so after finishing the repair the player could never sleep: the sol could not end (soft-lock; reproduced: bed.is_interactable() == false with event_completed == true).
Fix: scripts/gameplay/interactable.gd - BED interactions bail out early (toast only, bed stays usable) unless `GameManager.can_sleep()`; scripts/autoloads/game_manager.gd - new can_sleep() (= event_completed), used by on_bed_interacted().
Verified: early attempt -> toast, bed still interactable; then repair + event -> bed interactable -> real hold -> NIGHT_SUMMARY (state 3). Editor log: 0 errors.
Not done / notes: west camp (power switch, heater) stays in the open (equipment, not shelter); the shelter you "hide in" on Sol 5 is still a closed prop; label text is Label3D (not localised/themed); not tested at night or in the Sol 5 storm lighting, nor on other resolutions.

## Entry 15 – Radiation shelter awning (option B for the Sol 5 shelter)
Change (scripts/outpost_assembly.gd): new `_build_shelter_awning()` (called after `_build_camp_canopy()`), plus shared `_camp_palette()` (the camp canopy now uses it too, so both structures use identical materials). Roof attached to the shelter's front wall (z 1.5, y 3.4) falling to two front posts (z 3.9, y 2.9) at x 13.4 and 17.4; orange trim, solid posts, solid +X windbreak, light bar + warm lamp, "RADIATION SHELTER" Label3D. Positions come from measured ground heights (pad top 0.6 at the wall, ~0.2 at z 3.9, 0 outside the pad), shelter front face z ~1.4-1.5, powerbox part at (12.4,3.2) left clear.
Verified in game: screenshot matches the camp's look; ShelterWall interactable targeted from under the awning (16.1,3.3) and from (15.0,4.6), not from 7 m (out of reach); real hold (250 frames) completes the repair (state EVENT_CARD, repair_completed true). Editor log: 0 errors.
Notes: the roof is visual only (no collision; jump apex 2.7 m < roof); the label sits over the shelter's hazard stripe but stays legible; not tested in the real Sol 5 storm lighting or night; the shelter and other buildings remain closed props.
Remaining ideas (not requested): west camp (power switch + heater) canopy; hollow/enterable hab (option A); Dusty bot/drone decision; resolutions/gamepad testing.

## Entry 16 – Cleanup, Dusty removal, west camp, hab interior (Blender script)
CLEANUP
- Sent to the Windows Recycle Bin (recoverable): addons/.godot_ai_update/backup/ (updater rollback copy of plugin 4.3.1; active plugin is 4.4.1, updater status "success"). Left in place: the small pending.json / activation.json / .gdignore / .gitignore in that folder.
- NOT touched: C:\src\sol-survivor.zip (18.9 MB, outside the project, modified today 21:00) - could be the user's submission/backup, so asked instead of deleting. The project folder is still untracked in git (repo root is C:\src); nothing committed.
DUSTY BOT / DRONE REMOVED (to Recycle Bin): scripts/gameplay/dusty_bot.gd(+.uid), dusty_drone.gd(+.uid), assets/models/dusty_bot.glb(+.import). Neither script was referenced by any scene/script, so no code needed changing. Related content changed: resources/events/sol1_choice_2.tres "Send the helper bot" -> "Rig a dust blower from spare parts" (icon robot -> wrench; same +10 power effect); GDD.md: removed helper-bot character, "Could have" item, open question; fail text now says Mission Aborted + retry from previous sol; event table updated. Kept on purpose: "Dusty Solar Panels" event title and solar_row_dusty model (they mean dust, not the bot). Filesystem search for "dusty" now only finds solar_row_dusty.glb. Global class count still reported 70 by scan (cache); no errors.
WEST CAMP: scripts/outpost_assembly.gd - refactored the sleep-pod canopy into a shared `_build_canopy(...)` (camp + west camp use it), new `_build_west_camp()` over the power switch + heater: x -6.5..-2.3, z -3.7..-1.7 (solar rows start at z -1.4), 3.2 m posts, "POWER & HEAT" label, open on both ends, no windbreak. Verified in game: screenshot matches the other structures; PowerSwitch and HeaterUnit targeted from under and in front of the canopy (not from 3.7 m, out of reach). The earlier sleep-pod camp and shelter awning were left unchanged.
HAB INTERIOR - measurements of the CURRENT hab.glb (runtime probes):
 - hollow shell, inner radius ~3.2, but interior floor top y=0.72, flat ceiling plate at y=1.9 (1.18 m headroom), door lintel y=2.1 (opening 0.3..2.1), closed door leaf = surface 9 of the mesh, stairs rise 0.1 per step to y=0.3, player capsule 1.8 m x 0.35 radius. A player cannot enter even with the door opened, so a kit that fits inside it is not possible without remodelling.
 - Decision: deliver a COMPLETE enterable hab module instead: tools/blender/build_hab_enterable.py (Blender 3.6-4.x). Shell with open 1.37 x 2.15 m door (faces -Y => Godot +Z), 3 steps flush with floor at Z=0.30, dome interior ~4.4 m high, inner radius 3.2, floor/rug/inlay, bunk, terminal desk, power panel, heater, lockers, table + stools, corridor hatches at +-X, windows, antenna, light ring + pendant lamp; same palette as the outpost kit; one flat-shaded mesh per material (Hab_*); empties MARKER_bed/terminal/power_switch/heater/door/spawn_inside/light_center/light_desk; re-runnable; exports hab_enterable.glb next to the .blend (or home folder if unsaved).
 - Verified WITHOUT Blender (not installed here): py_compile OK, and a dry run against stand-in bpy/bmesh/mathutils modules ran clean (18 objects, ~2,690 faces, bounds x/y +-3.5, shell z 0..5.43, marker positions sane). NOT verified: real Blender execution, glTF export options on the user's Blender version, face winding after recalc_face_normals, appearance. If the script errors in Blender, send me the console text.
 - Blender cannot be run here, so .blend -> .glb conversion by me is not possible; the script exports the GLB itself (or File > Export > glTF 2.0).
NEXT (after the GLB arrives, nothing done yet): load hab_enterable.glb instead of hab.glb at HAB_POS (0,0,-8); move bed/terminal/power switch/heater interactables to the MARKER_* positions and decide what to do with the outdoor camp canopies/props; add interior OmniLights at MARKER_light_*; add an entry ramp if the 0.1 m steps are not climbable by the capsule; make sure corridors still dock at x=+-3.7; re-run LOS/targeting tests inside the hab.

## Entry 17 – Blender hab script rewritten to match the game's model detail
Feedback: the v1 script (boxes + prisms, flat, ~5k tris) looked far lower-poly than the models in the game.
What I measured in the running game (hab.glb and the kit props): hab = 22.6k triangles, 13 surfaces, smooth-shaded + beveled, no textures; shared PBR material set (colours + metallic/roughness/emission strengths, e.g. silver 0.85/0.30, slate 0.55/0.45, glass 0.20/0.12, teal emissive 1.0/1.9, amber 2.3, red beacon 4.0). Visual motifs from close-up screenshots: riveted cream wall plates with dark seams, orange bands, thick rounded dark rim ring, bolt heads round a dark base plate, silver dome with dark meridian ribs + latitude rings + glowing light bars, apex hub + dish + mast + red beacon, hazard-striped door frame with dark pillars, framed windows (navy glass, mullions, teal strip), steps with amber nosing and silver rails, ribbed corridor tubes.
Rewrite (tools/blender/build_hab_enterable.py, v2): same layout/dimensions as v1 (door -Y, floor Z 0.30, inner radius 3.2) but now: shared-vertex arc panels and lathe solids (round dome/rings with 48 segments), 24 riveted wall plates with seams, orange bands, rounded rim ring, bolted base plate, 12-rib dome with latitude rings and light bars, apex hub/dish/mast/beacon, door pillars + hazard lintel + slid-open grooved door leaves, 5 framed windows outside and matching blind windows inside, interior beige lined wall with rivets, skirting/trim, interior dome ribs + conduit rings + light bars + hub + pendant lamp, floor deck with inlays/rug, lockers, round table + stools, wall conduits, corridor docking collars outside and hatches (wheel, flange, lamp) inside, steps + rails. Game PBR material table copied exactly. Bevel + Edge Split modifiers on every object (applied by the GLB export), smooth shading; rivets/bolts unbevelled, thin parts 1 bevel segment, chunky parts 2.
Furniture: NOT rebuilt - bed.glb, terminal.glb, power_switch.glb, heater.glb already exist in the game kit, so the script only drops MARKER_* empties (position + yaw so the model front faces the room centre) and I place the real models there in Godot. PLACEHOLDER_FURNITURE=True gives rough boxes if wanted.
Verification (no Blender available): py_compile OK; dry run against stand-in bpy/bmesh/mathutils: 39 objects, 9,636 polys = 19,880 triangles BEFORE bevel, ALL 31 mesh groups are closed manifolds (every edge shared by exactly 2 faces: 0 problems), bounds x/y +-3.98 (y min -4.75 steps), z max 6.57 (whip antenna), marker positions/yaws sane, door 1.81 m. The bevel modifier adds triangles at export; expected roughly 35-50k, i.e. more detailed than the game's 22k hab; if the GLB is heavy, lower ROUND_SEGS or set bevel segments to 1.
NOT verified: real Blender run, how it looks, glTF export on the user's version, modifier application, face winding after recalc, whether blind windows/door-leaf overlaps look right. Windows are decorative (no holes through the wall).

## Entry 18 – updated_rehab.blend received
Found C:\src\sol-survivor\sol-survivor\updated_rehab.blend (339,622 bytes, modified 14 Nov 2026 22:27, zstd-compressed Blender 3.0+ format). It cannot be opened or converted here (no Blender installed; zstd not available to the local Python). Offered: download portable Blender / user exports / existing Blender path. User chose: export the GLB themselves (File > Export > glTF 2.0, Apply Modifiers ticked, save as hab_enterable.glb in the project folder). Nothing changed in the project. Waiting for the GLB; integration plan unchanged (see Entry 16 NEXT).

## Entry 19 – Walk-in hab imported, furniture placed, layout updated
INPUT: user exported the model themselves (updated_rehab.glb, "Khronos glTF Blender I/O v5.2.40"), exactly the output of tools/blender/build_hab_enterable.py (31 meshes Hab_<mat>_bNN, 16 materials, 8 MARKER_* empties; door markers on +Z as designed).
PROJECT TIDY: moved updated_rehab.glb -> assets/models/outpost/hab_enterable.glb; moved updated_rehab.blend -> tools/blender/; added tools/.gdignore (Godot no longer scans the .blend/.py). Godot's importer sat in "importing" for several minutes after the files appeared (editor busy/background), then finished; the GLB imported as a PackedScene and the global class count dropped 70 -> 69 (DustyDrone gone).
FINDINGS IN THE EXPORT (not blocking, worth fixing on the Blender side):
 1. Modifiers were NOT applied on export: 19,880 triangles = the pre-bevel count (a bevelled export would be several times larger). So the hab has no rounded bevels; it is smooth-shaded unbevelled geometry. It still reads well in game. To get the bevelled look re-run the script in Blender (it exports with Apply Modifiers) or tick Apply Modifiers in File > Export, then overwrite assets/models/outpost/hab_enterable.glb.
 2. Stale materials: the .blend already held HabMat_* from the v1 script, so beige/cream/mauve/orange/teal/amber kept v1 values (metallic 0, roughness 0.85) and amber glowed. Fixed twice: (a) script v2 now always re-applies the game's values and deletes unused HabMat_* on each run; (b) assembly re-applies the game's values by material name at load, so the current GLB already renders correctly.
GODOT CHANGES (scripts/outpost_assembly.gd, scripts/world/outpost.gd):
 - `_spawn_hab()` prefers hab_enterable.glb when imported, else the old hab + outdoor camp (fallback kept).
 - Collision only on structural meshes (bevel suffix >= b20: walls, floor, dome, steps, door frame, lockers); rivets, ribs, lights stay collision-free. Box collider for the table.
 - `_tune_hab_materials()` by name; `_add_hab_lights()` (2 OmniLights at MARKER_light_center/desk, no shadows).
 - `_place_hab_furniture()`: the game's own bed/terminal/power_switch/heater models placed at MARKER_* (position + yaw), then `_fit_inside_hab()` pulls each inward until all corners are inside radius 3.08 (result: bed (1.43,0.3,-9.70) yaw -40, terminal (-0.98,-10.09) yaw 25, power switch (-2.15,-9.24) yaw 60, heater (-2.31,-6.67) yaw 120).
 - `_retarget_markers_to_furniture()` moves the interactable markers with the models; outpost.gd now copies the marker's yaw onto the interaction boxes; bed box changed to (2.6,1.4,1.4) to match the 2.5 m-long bed model.
 - Outdoor camp (4 models + both canopies) is skipped when the walk-in hab is present; the shelter awning stays.
 - Layout adjustments for the walk-in layout: cables re-run from the solar field to the hab's base plate (`_run_cable`, tags cable_a/cable_b), footprint trail ends at the bottom step (-0.3,-3.2). Checked all structure footprints: no new overlaps (hab collars overlap corridor ends by 0.26 m on purpose; remaining listed overlaps are old AABB-corner artefacts: shelter/dish pad edge, greenhouse/workshop touching corridors).
VERIFIED IN GAME (real input):
 - Player walks in: from z=-0.5, forward 200 frames -> z=-7.9, y=0.30 (on the interior floor). The 0.1 m steps are climbable; no ramp needed. Door/headroom clear for the 1.8 m capsule.
 - Interior screenshots: ribbed dome, light bars, riveted lining, hatches, lockers, bed, terminal, heater, power switch, table; exterior: bolted base plate, rim ring, hazard lintel, framed windows, steps + rails; first view from the spawn shows the interior through the open door.
 - Sol 1 full loop inside the hab: PowerSwitch hold-E -> event card -> choice -> Bed hold-E -> night summary (50->42 O2 etc.); Sol 2: HeaterUnit hold-E completes (state EVENT_CARD). Editor log: 0 errors/warnings.
NOT VERIFIED: Sols 3-6 inside the new layout; night lighting inside; hatch/corridor sightline; other resolutions; performance with the 20k-triangle hab (not measured); the re-export with bevels (not yet received).

## Entry 20 - Simple Points PDF features (coins, map, how to play, labels, pause, sol placement)
CHANGED:
 - Title menu: START MISSION / HOW TO PLAY / MAP / NASA ARCHIVE / QUIT (title_screen.gd matches on button text).
 - New autoloads: CoinSystem, MapScreen, HowToPlay, PauseMenu (class_name removed from map_screen/pause_menu: it clashes with the autoload name). New input action `map` = M.
 - Instructions page (goal, controls, 4 meters + fail rule, sol flow, coin rules, BACK). Map screen (title + M in game; all 8 places named, SOL OBJECTIVE ring, YOU ARE HERE chip + arrow, field-task dots, scale bar); world rect tightened so the map fills the panel.
 - 3D billboard name labels for Hab, Greenhouse, Workshop, Radiation Shelter, O2 Tanks, Solar Field, Comms Dish, Crash Pod (same names as map; one shared `Locations` data file).
 - Coins: repair +20, field task +10 (toast "+10 COINS"), survive night +25, win +50; HUD counter; totals in night summary and debrief; retry restores coins.
 - Esc now pauses (Resume / Map / How to Play); player.gd no longer toggles the mouse on Esc.
 - Sol placement: objectives progress hab (1-2) -> O2 tanks (3) -> greenhouse far west (4) -> shelter far east (5) -> dish south-east (6). Field-task markers were all landing by the spawn (broken marker lookup) - fixed; offsets moved off the solar panels, workshop wall and shelter body.
VERIFIED IN GAME: title buttons, How to Play page, map from title and with M in play, pause menu, HUD coin counter, repair +20 + toast, field task +10, night +25 (night summary shows +55 / 55), no errors in log.
NOT VERIFIED: win +50 and debrief coin line, retry restoring coins, sols 3-6 task positions in 3D (only sol 1 checked on the map), toast overlaps the meter bar at top-left (cosmetic, existing).
OPEN: delete C:\src\sol-survivor.zip? keep canopy fallback code? hab GLB re-export with Apply Modifiers.

## Entry 21 - HUD / first-play clarity
CHANGED: HUD objective banner (top-centre) fed by GameManager.objective_updated (signal had no listener before) with the place name, e.g. "GET THE POWER BACK ON - FIND THE MAIN SWITCH (HAB)"; sol-1-only controls hint line (fades after 25 s of play); toast moved below the banner (was covering the meter bar).
VERIFIED: sol 1 start screenshot, no errors. NOT VERIFIED: banner text on sols 2-6 and after the night ("Go to bed"); O2 TANKS 3D label is large near the spawn and overlaps WORKSHOP's label from there (cosmetic).

## Entry 22 - Final polish audit
FOUND + FIXED: (1) 3D name labels were world-sized (huge beside the player, overlapping O2 TANKS/WORKSHOP) -> fixed_size constant screen size; (2) victory debrief offered "RETRY FROM SOL 05" -> retry button hidden on a win.
VERIFIED: labels readable from spawn; sol 6 banner "FIX THE COMMS DISH ... (COMMS DISH)"; coins 125 -> 200 on win (+25 night +50 win) and debrief shows "COINS: 200 (INCL. +50 WIN BONUS)"; retry restores the snapshot's coins (rewinds one sol, so coins earned since are dropped); 0 errors in log.
NOT VERIFIED / LEFT: world labels also show over the debrief/briefing backdrops (cosmetic); debrief lesson log is empty only because my test skipped the event cards (real choices fill it - not re-checked); sol 3-5 task positions only reasoned from coordinates, not seen in 3D; hab GLB still needs Apply-Modifiers re-export; zip deletion unanswered.

## Entry 23 - UI polish pass + repair sparks removed
REMOVED: player "RepairSparks" CPUParticles3D (emitted at the hit point while holding E) and all its code; GameManager `_refine_outpost_sparks()` (it also clamped the player's drifting-dust particles to 10). Verified at runtime: 0 CPUParticles3D in the scene, hold-E repair completes with no particles.
HUD rebuilt (scripts/ui/hud.gd):
 - VITALS card top-left: O2 / POWER / FOOD / SHIELD each with icon, colour bar, % (shield used to be an unlabeled bar bottom-left); bars tween; <=20% turns terracotta and pulses. Removed the unused "Base" zone label.
 - SOL "1 / 6" + COINS card top-right; coins pop "+N" under the card and the number bounces; card stays up behind the event card.
 - Objective banner: target glyph, "SOL n // OBJECTIVE" caption, objective text, teal place chip ("HAB  [M] MAP"), flash/scale when the objective changes; sol-1 controls strip as key chips on a dark backing, fades out after 25 s.
 - Hold-E prompt: "HOLD E" key chip + action (prefixes "Hold E to" / "[HOLD E]" normalised), rounded progress bar.
Other: toast is a compact centred pill that slides/fades (runs while paused, so the repair toast shows behind the event card); event card sized to content and vertically centred (was full height, half empty); briefing title "SOL 00" -> "BEFORE SOL 01"; 3D place labels hidden behind the briefing and debrief.
VERIFIED (screenshots): title -> briefing (no labels) -> sol 1 HUD; hold-E prompt + bar inside hab; repair -> toast + "+20" + event card; field task toast "+10"; 0 errors in game log.
NOT VERIFIED: critical-meter pulse (no meter <=20 in this run), objective flash on "Go to bed", other resolutions/aspect ratios.

## Entry 24 - Vitals as ring gauges
CHANGED: the VITALS list card (tiny text, hairline bars) replaced by four ring gauges in one row on a soft rounded backing: coloured arc from 12 o'clock filling to the value with a glow pass and round caps, meter icon inside the ring, value in the heavy font (20 px) and the name under it. Rings tween on change; <=20% turns the ring, icon and number terracotta and the gauge pulses. New `RingGauge` widget class in hud.gd.
VERIFIED: sol 1 screenshot (O2 60, PWR 40, FOOD forced to 15 -> red, SHIELD 40); 0 errors in game log.
NOT VERIFIED: other resolutions.
