package com.example.vityazi

import android.graphics.Color

/** Colors for a level's scene. */
class Palette(
    val skyTop: Int,
    val skyBottom: Int,
    val sun: Int,
    val far: Int,       // distant silhouettes (kremlin / domes)
    val mid: Int,       // midground structures
    val ground: Int,
    val groundTop: Int,
    val haze: Int       // atmospheric band near horizon
)

class SpawnDef(val t: Float, val type: EnemyType, val fromRight: Boolean)

class LevelDef(
    val name: String,
    val subtitle: String,
    val scene: Int,           // which background to draw
    val palette: Palette,
    val spawns: List<SpawnDef>
)

object Levels {

    private fun rgb(hex: Int) = hex or (0xFF shl 24)

    val all: List<LevelDef> = listOf(
        // 1 — Dawn at the Kremlin walls
        LevelDef(
            name = "СТЕНЫ ДЕТИНЦА",
            subtitle = "Рассвет над кремлём",
            scene = 0,
            palette = Palette(
                skyTop = rgb(0x2E3B57), skyBottom = rgb(0xE0A06B), sun = rgb(0xFFE3B3),
                far = rgb(0x3C4A63), mid = rgb(0x6E5742), ground = rgb(0x5A4632),
                groundTop = rgb(0x6E573F), haze = rgb(0xD79A6A)
            ),
            spawns = buildList {
                var t = 1.5f
                repeat(4) { add(SpawnDef(t, EnemyType.RAIDER, true)); t += 2.6f }
                add(SpawnDef(t + 1f, EnemyType.RAIDER, false));
                add(SpawnDef(t + 1.4f, EnemyType.RAIDER, true))
                add(SpawnDef(t + 4.5f, EnemyType.RAIDER, true))
                add(SpawnDef(t + 5.0f, EnemyType.RAIDER, false))
            }
        ),
        // 2 — Day at the marketplace (Torg)
        LevelDef(
            name = "НОВГОРОДСКИЙ ТОРГ",
            subtitle = "Защити купеческие ряды",
            scene = 1,
            palette = Palette(
                skyTop = rgb(0x6FA6CC), skyBottom = rgb(0xCFE6F2), sun = rgb(0xFFFBE6),
                far = rgb(0x8AA0B5), mid = rgb(0x8C6A45), ground = rgb(0x6B5536),
                groundTop = rgb(0x826642), haze = rgb(0xCADAE6)
            ),
            spawns = buildList {
                var t = 1.5f
                add(SpawnDef(t, EnemyType.RAIDER, true)); t += 2f
                add(SpawnDef(t, EnemyType.ARCHER, true)); t += 2.4f
                add(SpawnDef(t, EnemyType.RAIDER, false)); t += 1.8f
                add(SpawnDef(t, EnemyType.RAIDER, true)); t += 2.6f
                add(SpawnDef(t, EnemyType.ARCHER, false)); t += 2.2f
                add(SpawnDef(t, EnemyType.RAIDER, true))
                add(SpawnDef(t + 0.4f, EnemyType.RAIDER, false)); t += 3.5f
                add(SpawnDef(t, EnemyType.ARCHER, true))
                add(SpawnDef(t + 0.3f, EnemyType.RAIDER, true))
            }
        ),
        // 3 — Sunset on the Volkhov bridge
        LevelDef(
            name = "МОСТ ЧЕРЕЗ ВОЛХОВ",
            subtitle = "Удержи переправу",
            scene = 2,
            palette = Palette(
                skyTop = rgb(0x3A2E55), skyBottom = rgb(0xE2734A), sun = rgb(0xFFCF8F),
                far = rgb(0x4A3A5C), mid = rgb(0x5A3F49), ground = rgb(0x47323C),
                groundTop = rgb(0x6A4A52), haze = rgb(0xD98A5E)
            ),
            spawns = buildList {
                var t = 1.2f
                add(SpawnDef(t, EnemyType.RAIDER, true)); t += 1.8f
                add(SpawnDef(t, EnemyType.ARCHER, true)); t += 1.6f
                add(SpawnDef(t, EnemyType.BRUTE, true)); t += 3.2f
                add(SpawnDef(t, EnemyType.RAIDER, false))
                add(SpawnDef(t + 0.3f, EnemyType.ARCHER, true)); t += 3f
                add(SpawnDef(t, EnemyType.BRUTE, false))
                add(SpawnDef(t + 0.5f, EnemyType.RAIDER, true)); t += 3.5f
                add(SpawnDef(t, EnemyType.ARCHER, true))
                add(SpawnDef(t + 0.2f, EnemyType.ARCHER, false))
                add(SpawnDef(t + 0.6f, EnemyType.BRUTE, true))
            }
        ),
        // 4 — Night, boss at St. Sophia
        LevelDef(
            name = "ВРАГ У СВЯТОЙ СОФИИ",
            subtitle = "Останови воеводу",
            scene = 3,
            palette = Palette(
                skyTop = rgb(0x10162B), skyBottom = rgb(0x2A3550), sun = rgb(0xE9EEF6),
                far = rgb(0x1B2440), mid = rgb(0x2A3350), ground = rgb(0x232838),
                groundTop = rgb(0x333A50), haze = rgb(0x394566)
            ),
            spawns = buildList {
                var t = 1.2f
                add(SpawnDef(t, EnemyType.RAIDER, true))
                add(SpawnDef(t + 0.4f, EnemyType.RAIDER, false)); t += 3f
                add(SpawnDef(t, EnemyType.ARCHER, true))
                add(SpawnDef(t + 0.3f, EnemyType.BRUTE, true)); t += 4f
                add(SpawnDef(t, EnemyType.BOSS, true)); t += 0.1f
                add(SpawnDef(t + 4f, EnemyType.RAIDER, false))
                add(SpawnDef(t + 4.5f, EnemyType.ARCHER, true))
                add(SpawnDef(t + 9f, EnemyType.RAIDER, true))
                add(SpawnDef(t + 9.5f, EnemyType.RAIDER, false))
            }
        )
    )

    val count get() = all.size
}
