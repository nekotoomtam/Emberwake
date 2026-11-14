---
name: emberwake-design
description: Use when creating or editing images for Emberwake, designing or reviewing its game systems, combat abilities, character appearance, balance, or playtests, or capturing verified lessons for the project.
---

# Emberwake Design

## BASE-001 — Identify the target and its authority

Use the real-time action game in this repository as the default target for Emberwake design. For combat and weapon skills, start from the current build's player movement, attack timing, stamina, dodge, and parry where relevant. Inspect the relevant scene, data, decision record, or selected art reference. Keep standalone studies scoped to the work that selected them. A working feature is evidence of implementation in that build. An approved decision establishes design intent within its stated scope.

## BASE-002 — Load the rules for the work requested

| Work | Load |
| --- | --- |
| Game loops, encounters, progression, and combat rules | [Game design](references/game.md) |
| Character appearance and design variants | [Character design](references/character.md) |
| Image generation or editing for Emberwake | [Art direction and image generation](references/character.md#char-004--use-the-selected-art-direction-for-emberwake-images) |
| Combat skills, attack effects, reactions, and status effects | [Combat abilities](references/abilities.md) |
| Values, choice dominance, and playtest comparisons | [Balance](references/balance.md) |
| Design review, art QC, and regression evidence | [Review](references/review.md) |

Combine references only when the question crosses domains. Keep the requested stage. A design brief can describe a prototype without implementing it. A review can identify a fix without editing the artifact under review.

## LEARN-001 — Update the rule that owns the lesson

When a resolved issue exposes a reusable prevention step, capture the symptom, the supported cause, the change, and the smallest check that shows the change addressed it. Record useful evidence in the issue or work record when one exists. Treat a reported improvement with missing verification as an observation or a proposed check. Keep build-specific values and incident details with their evidence.

Search the skill and relevant specialist guidance by symptom, cause, and existing rule ID before writing. If a rule already covers the lesson, cite that ID and leave the skill as is. If the rule covers the same decision but misses a verified prevention step, extend it in its owning reference. Add a rule only for a distinct decision or check. Use the next ID in its family (`BASE`, `GAME`, `CHAR`, `ABIL`, `BAL`, `QC`, `LEARN`). Preserve existing IDs when editing or moving rules. Use cross-references where domains meet.

When asked to save a new lesson, verify it with the original failure or a representative scenario. If evidence is insufficient and replay is unavailable, record the observation and proposed check in the existing work record or in the reply if no record exists. For a verified gap, write when the rule applies, what to do, and how to verify it. Report the ID and the evidence limits. When the task only authorizes reviewing or fixing the game, surface a proposed skill change for review. Product rules, canon and accepted values require their own decision record.
