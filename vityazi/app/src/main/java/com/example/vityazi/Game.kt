package com.example.vityazi

import kotlin.math.abs
import kotlin.math.hypot
import kotlin.random.Random

enum class Phase { MENU, LEVELCARD, PLAY, CLEARED, GAMEOVER, WIN }

class Game {

    var w = 1f
    var h = 1f
    var s = 1f                  // global scale (design height = 720)
    var groundY = 0f

    var phase = Phase.MENU
    var phaseTimer = 0f

    var levelIndex = 0
    var level: LevelDef = Levels.all[0]
    private var spawnCursor = 0
    var levelTime = 0f

    val player = Player()
    val enemies = ArrayList<Enemy>()
    val arrows = ArrayList<Arrow>()
    val particles = ArrayList<Particle>()

    var score = 0
    var combo = 0
    private var comboTimer = 0f
    var totalKills = 0

    // input
    var moveLeft = false
    var moveRight = false
    private var attackQueued = false
    private var jumpQueued = false

    // camera shake
    var shakeT = 0f
    private var shakeMag = 0f
    var shakeX = 0f
    var shakeY = 0f

    private val rnd = Random(System.nanoTime())

    fun resize(nw: Int, nh: Int) {
        w = nw.toFloat(); h = nh.toFloat()
        s = h / 720f
        groundY = h * 0.84f
        if (phase == Phase.PLAY) {
            player.y = groundY
            player.x = player.x.coerceIn(margin(), w - margin())
        }
    }

    private fun margin() = 60f * s

    // ---- input from view ----
    fun queueAttack() { attackQueued = true }
    fun queueJump() { jumpQueued = true }

    /** Tap anywhere on non-gameplay screens advances state. */
    fun onTap() {
        when (phase) {
            Phase.MENU -> startGame()
            Phase.GAMEOVER -> startGame()
            Phase.WIN -> { phase = Phase.MENU; phaseTimer = 0f }
            else -> {}
        }
    }

    fun startGame() {
        score = 0; combo = 0; totalKills = 0
        player.hp = player.maxHp
        beginLevel(0)
    }

    private fun beginLevel(i: Int) {
        levelIndex = i
        level = Levels.all[i]
        enemies.clear(); arrows.clear(); particles.clear()
        spawnCursor = 0
        levelTime = 0f
        player.x = w * 0.30f
        player.y = groundY
        player.vy = 0f; player.onGround = true
        player.attackTimer = 0f; player.attackCooldown = 0f; player.invuln = 0f
        player.facing = 1
        moveLeft = false; moveRight = false
        attackQueued = false; jumpQueued = false
        phase = Phase.LEVELCARD
        phaseTimer = 2.2f
    }

    private fun addShake(mag: Float, time: Float) {
        shakeMag = maxOf(shakeMag, mag)
        shakeT = maxOf(shakeT, time)
    }

    fun update(dtRaw: Float) {
        val dt = dtRaw.coerceAtMost(0.033f)
        phaseTimer -= dt

        // shake
        if (shakeT > 0f) {
            shakeT -= dt
            shakeX = (rnd.nextFloat() - 0.5f) * shakeMag
            shakeY = (rnd.nextFloat() - 0.5f) * shakeMag
            if (shakeT <= 0f) { shakeX = 0f; shakeY = 0f; shakeMag = 0f }
        }
        updateParticles(dt)

        when (phase) {
            Phase.LEVELCARD -> { if (phaseTimer <= 0f) phase = Phase.PLAY }
            Phase.PLAY -> updatePlay(dt)
            Phase.CLEARED -> {
                if (phaseTimer <= 0f) {
                    if (levelIndex + 1 < Levels.count) beginLevel(levelIndex + 1)
                    else { phase = Phase.WIN; phaseTimer = 0f }
                }
            }
            else -> {}
        }
    }

    private fun updatePlay(dt: Float) {
        levelTime += dt
        if (comboTimer > 0f) { comboTimer -= dt; if (comboTimer <= 0f) combo = 0 }

        spawnDue()
        updatePlayer(dt)
        updateEnemies(dt)
        updateArrows(dt)
        resolvePlayerAttack()

        if (player.hp <= 0f && phase == Phase.PLAY) {
            player.hp = 0f
            phase = Phase.GAMEOVER
            phaseTimer = 0f
            addShake(18f * s, 0.4f)
        }

        // level cleared?
        if (phase == Phase.PLAY && spawnCursor >= level.spawns.size && enemies.isEmpty()) {
            phase = Phase.CLEARED
            phaseTimer = 2.6f
        }
    }

    private fun spawnDue() {
        while (spawnCursor < level.spawns.size && level.spawns[spawnCursor].t <= levelTime) {
            spawnEnemy(level.spawns[spawnCursor])
            spawnCursor++
        }
    }

    private fun spawnEnemy(def: SpawnDef) {
        val e = Enemy(def.type)
        when (def.type) {
            EnemyType.RAIDER -> { e.maxHp = 30f; e.hp = 30f }
            EnemyType.ARCHER -> { e.maxHp = 20f; e.hp = 20f }
            EnemyType.BRUTE -> { e.maxHp = 85f; e.hp = 85f }
            EnemyType.BOSS -> { e.maxHp = 380f; e.hp = 380f }
        }
        e.y = groundY
        if (def.fromRight) { e.x = w + 70f * s; e.facing = -1 }
        else { e.x = -70f * s; e.facing = 1 }
        e.actCd = 0.8f + rnd.nextFloat() * 0.6f
        enemies.add(e)
    }

    private fun updatePlayer(dt: Float) {
        val p = player
        if (p.invuln > 0f) p.invuln -= dt
        if (p.flash > 0f) p.flash -= dt
        if (p.attackCooldown > 0f) p.attackCooldown -= dt

        // horizontal
        var vx = 0f
        val speed = 235f * s
        if (moveLeft && !moveRight) { vx = -speed; p.facing = -1 }
        else if (moveRight && !moveLeft) { vx = speed; p.facing = 1 }
        p.moving = vx != 0f && p.onGround
        p.x = (p.x + vx * dt).coerceIn(margin(), w - margin())
        if (p.moving) p.walk += dt * 9f

        // jump
        if (jumpQueued) {
            jumpQueued = false
            if (p.onGround && p.attackTimer <= 0f) { p.vy = -680f * s; p.onGround = false }
        }
        // gravity
        if (!p.onGround) {
            p.vy += 1650f * s * dt
            p.y += p.vy * dt
            if (p.y >= groundY) { p.y = groundY; p.vy = 0f; p.onGround = true }
        }

        // attack
        if (p.attackTimer > 0f) p.attackTimer -= dt
        if (attackQueued) {
            attackQueued = false
            if (p.attackCooldown <= 0f) {
                p.attackTimer = p.attackDuration
                p.attackCooldown = 0.42f
                p.swing++
            }
        }
    }

    /** Active window of the swing where it can damage. */
    private fun swingActive(): Boolean {
        val p = player
        if (p.attackTimer <= 0f) return false
        val prog = 1f - (p.attackTimer / p.attackDuration)
        return prog in 0.18f..0.62f
    }

    private fun resolvePlayerAttack() {
        val p = player
        if (!swingActive()) return
        val reach = 110f * s
        val cx = p.x + p.facing * (40f * s)
        val cyTop = p.y - 130f * s
        val cyBot = p.y - 10f * s
        // deflect arrows
        for (a in arrows) {
            if (a.dead) continue
            if (a.fromEnemy && a.x in (cx - reach)..(cx + reach) && a.y in cyTop..cyBot) {
                a.dead = true
                spawnSparks(a.x, a.y, 6, 0xFFFFE3B3.toInt())
            }
        }
        for (e in enemies) {
            if (e.dead || e.hitSwing == p.swing) continue
            val half = enemyHalf(e)
            val dx = e.x - p.x
            // must be in front and within reach
            if (p.facing > 0 && dx < -10f * s) continue
            if (p.facing < 0 && dx > 10f * s) continue
            if (abs(dx) <= reach + half) {
                e.hitSwing = p.swing
                val dmg = 14f + combo * 0.6f
                e.hp -= dmg
                e.hurt = 0.18f
                e.stagger = if (e.type == EnemyType.BOSS) 0.06f else 0.22f
                e.x += p.facing * 16f * s
                spawnSparks(e.x - p.facing * half, e.y - 70f * s, 9, 0xFFFFFFFF.toInt())
                addShake(5f * s, 0.08f)
                if (e.hp <= 0f) killEnemy(e)
            }
        }
    }

    private fun killEnemy(e: Enemy) {
        if (e.dead) return
        e.dead = true
        combo++; comboTimer = 3f
        totalKills++
        val base = when (e.type) {
            EnemyType.RAIDER -> 100; EnemyType.ARCHER -> 120
            EnemyType.BRUTE -> 250; EnemyType.BOSS -> 2000
        }
        score += base * maxOf(1, combo)
        val col = if (e.type == EnemyType.BOSS) 0xFFE2734A.toInt() else 0xFFB07566.toInt()
        spawnSparks(e.x, e.y - 70f * s, if (e.type == EnemyType.BOSS) 40 else 16, col)
        if (e.type == EnemyType.BOSS) addShake(22f * s, 0.6f)
    }

    private fun enemyHalf(e: Enemy): Float = when (e.type) {
        EnemyType.BOSS -> 70f * s
        EnemyType.BRUTE -> 46f * s
        else -> 30f * s
    }

    private fun updateEnemies(dt: Float) {
        val p = player
        val it = enemies.iterator()
        while (it.hasNext()) {
            val e = it.next()
            if (e.dead) { it.remove(); continue }
            if (e.spawnIn > 0f) e.spawnIn -= dt
            if (e.hurt > 0f) e.hurt -= dt
            if (e.stagger > 0f) { e.stagger -= dt; continue }

            val dx = p.x - e.x
            e.facing = if (dx >= 0) 1 else -1
            val dist = abs(dx)
            if (e.actCd > 0f) e.actCd -= dt
            if (e.attackTimer > 0f) e.attackTimer -= dt

            val speed = when (e.type) {
                EnemyType.RAIDER -> 105f * s
                EnemyType.ARCHER -> 75f * s
                EnemyType.BRUTE -> 62f * s
                EnemyType.BOSS -> 70f * s
            }

            when (e.type) {
                EnemyType.ARCHER -> {
                    val keep = 320f * s
                    if (dist > keep + 20f * s) { e.x += e.facing * speed * dt; e.walk += dt * 7f }
                    else if (dist < keep - 60f * s) { e.x -= e.facing * speed * dt; e.walk += dt * 7f }
                    if (e.actCd <= 0f && e.attackTimer <= 0f) {
                        e.attackTimer = 0.5f; e.actCd = 2.0f
                        shootArrowAt(e)
                    }
                }
                else -> {
                    val reach = enemyHalf(e) + 44f * s
                    if (dist > reach) { e.x += e.facing * speed * dt; e.walk += dt * 8f }
                    else {
                        if (e.actCd <= 0f && e.attackTimer <= 0f) {
                            e.attackTimer = if (e.type == EnemyType.BOSS) 0.55f else 0.45f
                            e.actCd = if (e.type == EnemyType.BOSS) 1.1f else 1.4f
                        }
                    }
                    // deal damage mid-swing
                    if (e.attackTimer > 0f) {
                        val prog = when (e.type) {
                            EnemyType.BOSS -> 0.55f; else -> 0.45f
                        }.let { 1f - (e.attackTimer / it) }
                        if (prog in 0.35f..0.6f && dist <= reach + 14f * s) {
                            hitPlayer(when (e.type) {
                                EnemyType.BRUTE -> 16f; EnemyType.BOSS -> 22f; else -> 9f
                            }, e.facing)
                        }
                    }
                }
            }
            e.x = e.x.coerceIn(-90f * s, w + 90f * s)
        }
    }

    private fun shootArrowAt(e: Enemy) {
        val a = Arrow()
        val sx = e.x + e.facing * 26f * s
        val sy = e.y - 96f * s
        val tx = player.x
        val ty = player.y - 96f * s
        val d = hypot((tx - sx).toDouble(), (ty - sy).toDouble()).toFloat().coerceAtLeast(1f)
        val spd = 560f * s
        a.x = sx; a.y = sy
        a.vx = (tx - sx) / d * spd
        a.vy = (ty - sy) / d * spd - 60f * s
        a.fromEnemy = true
        a.dmg = 8f
        arrows.add(a)
    }

    private fun updateArrows(dt: Float) {
        val it = arrows.iterator()
        while (it.hasNext()) {
            val a = it.next()
            if (a.dead) { it.remove(); continue }
            a.vy += 320f * s * dt
            a.x += a.vx * dt
            a.y += a.vy * dt
            a.life -= dt
            if (a.y >= groundY - 4f * s) { a.dead = true; spawnSparks(a.x, groundY, 4, 0xFF8A8578.toInt()) }
            if (a.x < -50f * s || a.x > w + 50f * s || a.life <= 0f) { a.dead = true; continue }
            if (a.fromEnemy && player.invuln <= 0f) {
                if (abs(a.x - player.x) < 26f * s && a.y in (player.y - 150f * s)..(player.y - 8f * s)) {
                    a.dead = true
                    hitPlayer(a.dmg, if (a.vx >= 0) 1 else -1)
                }
            }
        }
    }

    private fun hitPlayer(dmg: Float, dir: Int) {
        val p = player
        if (p.invuln > 0f) return
        p.hp -= dmg
        p.invuln = 0.7f
        p.flash = 0.25f
        p.x = (p.x + dir * 22f * s).coerceIn(margin(), w - margin())
        combo = 0
        spawnSparks(p.x, p.y - 80f * s, 10, 0xFFE2734A.toInt())
        addShake(9f * s, 0.18f)
    }

    // ---- particles ----
    private fun spawnSparks(x: Float, y: Float, n: Int, color: Int) {
        repeat(n) {
            val pt = Particle()
            pt.x = x; pt.y = y
            val ang = rnd.nextFloat() * 6.2832f
            val sp = (60f + rnd.nextFloat() * 260f) * s
            pt.vx = kotlin.math.cos(ang) * sp
            pt.vy = kotlin.math.sin(ang) * sp - 80f * s
            pt.maxLife = 0.35f + rnd.nextFloat() * 0.4f
            pt.life = pt.maxLife
            pt.size = (2.5f + rnd.nextFloat() * 3.5f) * s
            pt.color = color
            pt.gravity = 1f
            particles.add(pt)
        }
    }

    private fun updateParticles(dt: Float) {
        val it = particles.iterator()
        while (it.hasNext()) {
            val pt = it.next()
            pt.life -= dt
            if (pt.life <= 0f) { it.remove(); continue }
            pt.vy += 900f * s * pt.gravity * dt
            pt.x += pt.vx * dt
            pt.y += pt.vy * dt
        }
    }

    fun isBossAlive(): Boolean = enemies.any { it.type == EnemyType.BOSS && !it.dead }
    fun bossHpFraction(): Float {
        val b = enemies.firstOrNull { it.type == EnemyType.BOSS } ?: return 0f
        return (b.hp / b.maxHp).coerceIn(0f, 1f)
    }
}
