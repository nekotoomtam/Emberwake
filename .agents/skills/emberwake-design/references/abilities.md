# Combat abilities

## ABIL-001 — Give the ability a distinct reason to use it

Name the role, the situation where the ability is useful, and the relevant basic command or alternative. Specify eligible targets, cost, timing, effect, limit or cooldown, visible feedback, and any way to prevent or respond to it. Label unresolved values as candidate values or leave them open.

## ABIL-002 — Resolve timing where actions interact

For reactions and status effects, state the trigger, who is eligible, event order, stacking or precedence, and when the effect or limit resets. Walk through normal use and the closest conflict, such as two allies reacting to one hit, a target losing eligibility, or an interaction triggering itself. Include HP and body-part effects separately when the selected combat rules support both.

## ABIL-003 — Show the effect in the battle view

Show who acts, which target or body part was selected, and what changed after resolution. For protection or redirection, make the original target, protector, and final recipient readable. Use [BAL-002](balance.md#bal-002--check-whether-a-choice-crowds-out-another) to check the effect on competing actions.

## ABIL-004 — Build weapon trails from the visible swing

For an afterimage attached to a weapon, drive the trail from recent positions of the rendered weapon edge or tip during the active swing. Anchor painted highlights to the same weapon pose and clear the trail history at each new strike or handoff. Give finishers their own width, brightness, or fade using that same path. Time any separate projectile or impact effect to its own release or contact event.

Check the trail in motion and frame by frame in the playable view. Cover each combo strike, opposing swing directions, and views toward and away from the camera. The highlight should stay at the visible edge and the trail should occupy the path the edge has already swept. Use [QC-002](review.md#qc-002--match-proof-to-the-claim) for evidence and the [combat VFX checklist](../../../../docs/combat-vfx-th.md#ข้อที่ต้องตรวจรอบต่อไป) for the sword case.
