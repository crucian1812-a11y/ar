package com.example.vityazi

import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import kotlin.math.sin

class Renderer {

    private val pa = Paint(Paint.ANTI_ALIAS_FLAG)
    private val st = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE; strokeCap = Paint.Cap.ROUND; strokeJoin = Paint.Join.ROUND
    }
    private val tp = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        typeface = Typeface.create(Typeface.DEFAULT_BOLD, Typeface.BOLD)
        textAlign = Paint.Align.CENTER
    }
    private val rf = RectF()
    private val path = Path()

    private lateinit var g: Game
    private lateinit var cv: Canvas
    private val s get() = g.s

    private val BLADE = 0xFFEDEAE0.toInt()
    private val GOLD = 0xFFCBA85C.toInt()

    fun draw(canvas: Canvas, game: Game) {
        g = game
        cv = canvas
        cv.save()
        if (g.shakeT > 0f) cv.translate(g.shakeX, g.shakeY)

        drawBackground()

        for (e in g.enemies) drawEnemy(e)
        if (g.phase == Phase.PLAY || g.phase == Phase.CLEARED || g.phase == Phase.LEVELCARD)
            drawPlayer(g.player)
        for (a in g.arrows) drawArrow(a)
        for (p in g.particles) drawParticle(p)

        cv.restore()

        if (g.phase == Phase.PLAY) {
            drawHud()
            drawControls()
        }
        drawOverlays()
    }

    // ---------------- BACKGROUND ----------------

    private fun drawBackground() {
        val p = g.level.palette
        pa.style = Paint.Style.FILL
        pa.shader = LinearGradient(0f, 0f, 0f, g.groundY, p.skyTop, p.skyBottom, Shader.TileMode.CLAMP)
        cv.drawRect(0f, 0f, g.w, g.groundY, pa)
        pa.shader = null

        val sunX = g.w * 0.76f
        val sunY = g.groundY * 0.30f
        if (g.level.scene == 3) {
            pa.color = withAlpha(p.sun, 40); cv.drawCircle(sunX, sunY, 80f * s, pa)
            pa.color = p.sun; cv.drawCircle(sunX, sunY, 38f * s, pa)
            pa.color = p.skyTop; cv.drawCircle(sunX + 14f * s, sunY - 10f * s, 30f * s, pa)
            drawStars()
        } else {
            pa.color = withAlpha(p.sun, 55); cv.drawCircle(sunX, sunY, 78f * s, pa)
            pa.color = p.sun; cv.drawCircle(sunX, sunY, 46f * s, pa)
        }

        pa.shader = LinearGradient(0f, g.groundY - 150f * s, 0f, g.groundY,
            withAlpha(p.haze, 0), withAlpha(p.haze, 150), Shader.TileMode.CLAMP)
        cv.drawRect(0f, g.groundY - 150f * s, g.w, g.groundY, pa)
        pa.shader = null

        when (g.level.scene) {
            0 -> sceneWalls()
            1 -> sceneMarket()
            2 -> sceneBridge()
            else -> sceneSophia()
        }

        pa.color = p.ground
        cv.drawRect(0f, g.groundY, g.w, g.h, pa)
        pa.color = p.groundTop
        cv.drawRect(0f, g.groundY, g.w, g.groundY + 8f * s, pa)
        st.color = withAlpha(darker(p.ground), 160); st.strokeWidth = 2f * s
        var gx = 20f * s
        while (gx < g.w) {
            val gy = g.groundY + 26f * s + (gx.toInt() % 3) * 8f * s
            cv.drawLine(gx, gy, gx + 26f * s, gy, st)
            gx += 60f * s
        }
    }

    private fun drawStars() {
        val t = now()
        pa.color = Color.WHITE
        var i = 0
        var x = 30f * s
        while (x < g.w) {
            val y = ((i * 97) % 100) / 100f * g.groundY * 0.6f + 12f * s
            val tw = 0.5f + 0.5f * sin(t * 2f + i.toFloat())
            pa.alpha = (90 + 140 * tw).toInt().coerceIn(0, 255)
            cv.drawCircle(x, y, (1.0f + tw) * s, pa)
            x += 70f * s; i++
        }
        pa.alpha = 255
    }

    private fun sceneWalls() {
        val p = g.level.palette
        dome(p.far, g.w * 0.62f, g.groundY - 70f * s, 46f * s, 90f * s)
        dome(p.far, g.w * 0.70f, g.groundY - 70f * s, 34f * s, 70f * s)
        val wallTop = g.groundY - 120f * s
        pa.color = p.mid
        cv.drawRect(0f, wallTop, g.w, g.groundY, pa)
        var mx = 0f
        while (mx < g.w) { cv.drawRect(mx, wallTop - 18f * s, mx + 28f * s, wallTop, pa); mx += 50f * s }
        st.color = darker(p.mid); st.strokeWidth = 2f * s
        var py = wallTop + 18f * s
        while (py < g.groundY) { cv.drawLine(0f, py, g.w, py, st); py += 22f * s }
        tower(p.mid, g.w * 0.40f, g.groundY, 80f * s, 200f * s)
    }

    private fun sceneMarket() {
        val p = g.level.palette
        dome(p.far, g.w * 0.20f, g.groundY - 60f * s, 40f * s, 80f * s)
        tower(p.far, g.w * 0.30f, g.groundY - 60f * s, 36f * s, 120f * s)
        dome(p.far, g.w * 0.84f, g.groundY - 60f * s, 44f * s, 86f * s)
        stall(g.w * 0.12f, 0xFF9C3B32.toInt())
        stall(g.w * 0.50f, 0xFF3E6B5A.toInt())
        stall(g.w * 0.86f, 0xFFB5852F.toInt())
        barrel(g.w * 0.33f); barrel(g.w * 0.66f)
    }

    private fun sceneBridge() {
        val p = g.level.palette
        dome(p.far, g.w * 0.18f, g.groundY - 90f * s, 38f * s, 74f * s)
        dome(p.far, g.w * 0.26f, g.groundY - 90f * s, 30f * s, 60f * s)
        dome(p.far, g.w * 0.80f, g.groundY - 90f * s, 40f * s, 78f * s)
        val wy = g.groundY - 90f * s
        pa.shader = LinearGradient(0f, wy, 0f, g.groundY, p.haze, darker(p.haze), Shader.TileMode.CLAMP)
        cv.drawRect(0f, wy, g.w, g.groundY, pa); pa.shader = null
        st.color = withAlpha(p.sun, 120); st.strokeWidth = 3f * s
        var ry = wy + 16f * s
        while (ry < g.groundY) { cv.drawLine(g.w * 0.76f - 30f * s, ry, g.w * 0.76f + 30f * s, ry, st); ry += 16f * s }
        pa.color = p.mid
        cv.drawRect(0f, g.groundY - 26f * s, g.w, g.groundY, pa)
        var bx = 16f * s
        while (bx < g.w) { cv.drawRect(bx, g.groundY - 70f * s, bx + 10f * s, g.groundY - 26f * s, pa); bx += 90f * s }
        st.color = darker(p.mid); st.strokeWidth = 8f * s
        cv.drawLine(0f, g.groundY - 60f * s, g.w, g.groundY - 60f * s, st)
    }

    private fun sceneSophia() {
        val p = g.level.palette
        val baseY = g.groundY - 60f * s
        val cx = g.w * 0.5f
        pa.color = p.mid
        cv.drawRect(cx - 130f * s, baseY - 120f * s, cx + 130f * s, g.groundY, pa)
        domeGold(cx, baseY - 120f * s, 60f * s, 150f * s)
        dome(p.far, cx - 90f * s, baseY - 120f * s, 40f * s, 92f * s)
        dome(p.far, cx + 90f * s, baseY - 120f * s, 40f * s, 92f * s)
        dome(p.far, cx - 45f * s, baseY - 120f * s, 30f * s, 72f * s)
        dome(p.far, cx + 45f * s, baseY - 120f * s, 30f * s, 72f * s)
        pa.color = darker(p.mid)
        cv.drawRect(0f, g.groundY - 40f * s, g.w, g.groundY, pa)
        torch(g.w * 0.16f); torch(g.w * 0.84f)
    }

    private fun dome(color: Int, cx: Float, baseY: Float, wd: Float, ht: Float) {
        pa.color = color
        cv.drawRect(cx - wd * 0.34f, baseY - ht * 0.45f, cx + wd * 0.34f, baseY, pa)
        val by = baseY - ht * 0.45f
        path.reset()
        path.moveTo(cx - wd * 0.5f, by)
        path.cubicTo(cx - wd * 0.62f, by - ht * 0.32f, cx - wd * 0.22f, by - ht * 0.52f, cx, by - ht * 0.62f)
        path.cubicTo(cx + wd * 0.22f, by - ht * 0.52f, cx + wd * 0.62f, by - ht * 0.32f, cx + wd * 0.5f, by)
        path.close()
        cv.drawPath(path, pa)
        pa.color = GOLD
        cv.drawRect(cx - 1.6f * s, by - ht * 0.62f - 14f * s, cx + 1.6f * s, by - ht * 0.62f, pa)
        cv.drawRect(cx - 6f * s, by - ht * 0.62f - 10f * s, cx + 6f * s, by - ht * 0.62f - 7f * s, pa)
    }

    private fun domeGold(cx: Float, baseY: Float, wd: Float, ht: Float) {
        pa.color = 0xFF8C6A2F.toInt()
        cv.drawRect(cx - wd * 0.4f, baseY - ht * 0.45f, cx + wd * 0.4f, baseY, pa)
        val by = baseY - ht * 0.45f
        path.reset()
        path.moveTo(cx - wd * 0.5f, by)
        path.cubicTo(cx - wd * 0.64f, by - ht * 0.34f, cx - wd * 0.22f, by - ht * 0.55f, cx, by - ht * 0.66f)
        path.cubicTo(cx + wd * 0.22f, by - ht * 0.55f, cx + wd * 0.64f, by - ht * 0.34f, cx + wd * 0.5f, by)
        path.close()
        pa.color = GOLD; cv.drawPath(path, pa)
        pa.color = 0xFFE8CE86.toInt()
        cv.drawCircle(cx - wd * 0.12f, by - ht * 0.32f, wd * 0.10f, pa)
        pa.color = GOLD
        cv.drawRect(cx - 2f * s, by - ht * 0.66f - 20f * s, cx + 2f * s, by - ht * 0.66f, pa)
        cv.drawRect(cx - 9f * s, by - ht * 0.66f - 14f * s, cx + 9f * s, by - ht * 0.66f - 10f * s, pa)
    }

    private fun tower(color: Int, cx: Float, baseY: Float, wd: Float, ht: Float) {
        pa.color = color
        cv.drawRect(cx - wd / 2, baseY - ht, cx + wd / 2, baseY, pa)
        path.reset()
        path.moveTo(cx - wd / 2 - 4f * s, baseY - ht)
        path.lineTo(cx, baseY - ht - wd * 0.95f)
        path.lineTo(cx + wd / 2 + 4f * s, baseY - ht)
        path.close()
        pa.color = darker(color); cv.drawPath(path, pa)
        pa.color = 0xFF1A1F26.toInt()
        cv.drawRect(cx - wd * 0.16f, baseY - ht * 0.6f, cx + wd * 0.16f, baseY - ht * 0.4f, pa)
    }

    private fun stall(cx: Float, roof: Int) {
        val baseY = g.groundY
        pa.color = 0xFF6E4A2A.toInt()
        cv.drawRect(cx - 46f * s, baseY - 60f * s, cx + 46f * s, baseY, pa)
        path.reset()
        path.moveTo(cx - 60f * s, baseY - 60f * s)
        path.lineTo(cx, baseY - 96f * s)
        path.lineTo(cx + 60f * s, baseY - 60f * s)
        path.close()
        pa.color = roof; cv.drawPath(path, pa)
        st.color = 0xFFEDEAE0.toInt(); st.strokeWidth = 5f * s
        cv.drawLine(cx - 40f * s, baseY - 66f * s, cx, baseY - 90f * s, st)
        cv.drawLine(cx + 40f * s, baseY - 66f * s, cx, baseY - 90f * s, st)
    }

    private fun barrel(cx: Float) {
        pa.color = 0xFF6E4A2A.toInt()
        rf.set(cx - 16f * s, g.groundY - 40f * s, cx + 16f * s, g.groundY)
        cv.drawRoundRect(rf, 6f * s, 6f * s, pa)
        st.color = 0xFF3E2A18.toInt(); st.strokeWidth = 3f * s
        cv.drawLine(cx - 16f * s, g.groundY - 28f * s, cx + 16f * s, g.groundY - 28f * s, st)
        cv.drawLine(cx - 16f * s, g.groundY - 12f * s, cx + 16f * s, g.groundY - 12f * s, st)
    }

    private fun torch(cx: Float) {
        val topY = g.groundY - 70f * s
        pa.color = 0xFF3E2A18.toInt()
        cv.drawRect(cx - 3f * s, topY, cx + 3f * s, g.groundY - 10f * s, pa)
        val flick = 0.7f + 0.3f * sin(now() * 12f + cx)
        pa.color = withAlpha(0xFFFFB347.toInt(), 90)
        cv.drawCircle(cx, topY, 22f * s * flick, pa)
        pa.color = 0xFFFFD27A.toInt()
        cv.drawCircle(cx, topY, 9f * s * flick, pa)
    }

    // ---------------- CHARACTERS ----------------

    private fun drawPlayer(p: Player) {
        val u = s * 1.18f
        val atk = if (p.attackTimer > 0f) 1f - (p.attackTimer / p.attackDuration) else -1f
        val flashing = p.invuln > 0f && ((now() * 20f).toInt() % 2 == 0)
        drawWarrior(
            p.x, p.y, u, p.facing, p.walk, atk, p.moving,
            skin = 0xFFE2B58C.toInt(),
            cloth = 0xFF9C3B32.toInt(), clothDark = 0xFF6E2A24.toInt(),
            metal = 0xFFC2C8D0.toInt(), metalDark = 0xFF838A93.toInt(),
            accent = GOLD, head = 0, weapon = 0, shield = true, cape = false, dim = flashing
        )
    }

    private fun drawEnemy(e: Enemy) {
        val atk = if (e.attackTimer > 0f) {
            val dur = if (e.type == EnemyType.BOSS) 0.55f else if (e.type == EnemyType.ARCHER) 0.5f else 0.45f
            1f - (e.attackTimer / dur)
        } else -1f
        val rise = if (e.spawnIn > 0f) (e.spawnIn / 0.35f) else 0f
        cv.save()
        cv.translate(0f, rise * 30f * s)
        val hurt = e.hurt > 0f
        when (e.type) {
            EnemyType.RAIDER -> drawWarrior(
                e.x, e.y, s * 1.05f, e.facing, e.walk, atk, e.stagger <= 0f,
                0xFFCBA07A.toInt(), 0xFF4B5A3A.toInt(), 0xFF333F28.toInt(),
                0xFF6B5A45.toInt(), 0xFF4A3D2E.toInt(), 0xFF8A6A3A.toInt(),
                head = 1, weapon = 1, shield = false, cape = false, dim = hurt
            )
            EnemyType.ARCHER -> drawWarrior(
                e.x, e.y, s * 1.0f, e.facing, e.walk, atk, e.stagger <= 0f,
                0xFFCBA07A.toInt(), 0xFF6B5436.toInt(), 0xFF4A3A24.toInt(),
                0xFF5A5045.toInt(), 0xFF3E372E.toInt(), 0xFF8A6A3A.toInt(),
                head = 1, weapon = 2, shield = false, cape = false, dim = hurt
            )
            EnemyType.BRUTE -> drawWarrior(
                e.x, e.y, s * 1.45f, e.facing, e.walk, atk, e.stagger <= 0f,
                0xFFB98E68.toInt(), 0xFF553B2E.toInt(), 0xFF3A2820.toInt(),
                0xFF5A5550.toInt(), 0xFF3C3934.toInt(), 0xFF8A4A30.toInt(),
                head = 2, weapon = 1, shield = false, cape = false, dim = hurt
            )
            EnemyType.BOSS -> drawWarrior(
                e.x, e.y, s * 1.9f, e.facing, e.walk, atk, e.stagger <= 0f,
                0xFFD8AE86.toInt(), 0xFF6E2438.toInt(), 0xFF4A1726.toInt(),
                0xFF9098A2.toInt(), 0xFF5C636E.toInt(), GOLD,
                head = 3, weapon = 3, shield = true, cape = true, dim = hurt
            )
        }
        cv.restore()
        if (e.hp < e.maxHp && e.spawnIn <= 0f) {
            val barW = when (e.type) { EnemyType.BOSS -> 0f; EnemyType.BRUTE -> 70f * s; else -> 50f * s }
            if (barW > 0f) {
                val top = e.y - heightOf(e) - 14f * s
                pa.color = 0xCC1A1F26.toInt()
                cv.drawRect(e.x - barW / 2, top, e.x + barW / 2, top + 7f * s, pa)
                pa.color = 0xFFE2734A.toInt()
                cv.drawRect(e.x - barW / 2, top, e.x - barW / 2 + barW * (e.hp / e.maxHp), top + 7f * s, pa)
            }
        }
    }

    private fun heightOf(e: Enemy): Float = when (e.type) {
        EnemyType.BOSS -> 240f * s; EnemyType.BRUTE -> 185f * s; else -> 135f * s
    }

    private fun drawWarrior(
        x: Float, footY: Float, u: Float, facing: Int,
        walk: Float, atk: Float, moving: Boolean,
        skin: Int, cloth: Int, clothDark: Int, metal: Int, metalDark: Int, accent: Int,
        head: Int, weapon: Int, shield: Boolean, cape: Boolean, dim: Boolean
    ) {
        cv.save()
        cv.translate(x, footY)
        cv.scale(facing.toFloat(), 1f)

        pa.color = 0x44000000
        rf.set(-26f * u, -6f * u, 26f * u, 6f * u)
        cv.drawOval(rf, pa)

        val sw = if (moving) sin(walk) else 0f

        if (cape) {
            pa.color = clothDark
            path.reset()
            path.moveTo(-6f * u, -94f * u)
            path.lineTo(-30f * u, -20f * u)
            path.lineTo(-6f * u, -30f * u)
            path.close()
            cv.drawPath(path, pa)
        }

        st.color = clothDark; st.strokeWidth = 13f * u
        cv.drawLine(-6f * u, -48f * u, -6f * u + sw * 16f * u, 0f, st)
        cv.drawLine(6f * u, -48f * u, 6f * u - sw * 16f * u, 0f, st)
        pa.color = metalDark
        cv.drawRect(-12f * u + sw * 16f * u, -6f * u, 2f * u + sw * 16f * u, 0f, pa)
        cv.drawRect(0f * u - sw * 16f * u, -6f * u, 14f * u - sw * 16f * u, 0f, pa)

        drawWeaponArm(u, atk, weapon, skin, metalDark, behind = true)

        pa.color = metal
        rf.set(-19f * u, -96f * u, 19f * u, -46f * u)
        cv.drawRoundRect(rf, 7f * u, 7f * u, pa)
        pa.color = accent
        cv.drawRect(-19f * u, -58f * u, 19f * u, -50f * u, pa)
        pa.color = metalDark
        var ry = -90f * u
        while (ry < -60f * u) {
            cv.drawCircle(-10f * u, ry, 1.6f * u, pa)
            cv.drawCircle(10f * u, ry, 1.6f * u, pa)
            ry += 10f * u
        }

        if (shield) {
            pa.color = metalDark
            cv.drawCircle(13f * u, -72f * u, 21f * u, pa)
            st.color = accent; st.strokeWidth = 3f * u
            cv.drawCircle(13f * u, -72f * u, 21f * u, st)
            pa.color = accent; cv.drawCircle(13f * u, -72f * u, 5f * u, pa)
            st.strokeWidth = 2.5f * u
            cv.drawLine(13f * u, -86f * u, 13f * u, -58f * u, st)
            cv.drawLine(0f * u, -72f * u, 26f * u, -72f * u, st)
        }

        st.color = skin; st.strokeWidth = 10f * u
        cv.drawLine(0f, -96f * u, 0f, -104f * u, st)
        pa.color = skin
        cv.drawCircle(2f * u, -116f * u, 14f * u, pa)
        drawHead(u, head, skin, metal, metalDark, accent)

        drawWeaponArm(u, atk, weapon, skin, metalDark, behind = false)

        if (dim) {
            pa.color = 0x66FFFFFF
            rf.set(-22f * u, -132f * u, 22f * u, 0f)
            cv.drawRoundRect(rf, 8f * u, 8f * u, pa)
        }
        cv.restore()
    }

    private fun drawHead(u: Float, head: Int, skin: Int, metal: Int, metalDark: Int, accent: Int) {
        val hx = 2f * u; val hy = -116f * u; val r = 14f * u
        when (head) {
            0 -> {
                pa.color = metal
                rf.set(hx - r, hy - r - 2f * u, hx + r, hy + 2f * u)
                cv.drawArc(rf, 180f, 180f, true, pa)
                path.reset()
                path.moveTo(hx - 3f * u, hy - r); path.lineTo(hx, hy - r - 14f * u); path.lineTo(hx + 3f * u, hy - r); path.close()
                cv.drawPath(path, pa)
                st.color = metalDark; st.strokeWidth = 3f * u
                cv.drawLine(hx + 6f * u, hy - r, hx + 6f * u, hy + 6f * u, st)
                pa.color = 0xFF9C3B32.toInt()
                cv.drawCircle(hx, hy - r - 16f * u, 4f * u, pa)
            }
            1 -> {
                pa.color = 0xFF4A3322.toInt()
                rf.set(hx - r - 2f * u, hy - r, hx + r + 2f * u, hy)
                cv.drawArc(rf, 180f, 180f, true, pa)
                cv.drawRect(hx - r - 2f * u, hy - 3f * u, hx + r + 2f * u, hy + 2f * u, pa)
            }
            2 -> {
                pa.color = metal
                rf.set(hx - r, hy - r, hx + r, hy + 3f * u)
                cv.drawArc(rf, 180f, 180f, true, pa)
                pa.color = 0xFFE8E0D0.toInt()
                path.reset(); path.moveTo(hx - r, hy - r + 2f * u)
                path.lineTo(hx - r - 8f * u, hy - r - 12f * u); path.lineTo(hx - r + 4f * u, hy - r); path.close()
                cv.drawPath(path, pa)
                path.reset(); path.moveTo(hx + r, hy - r + 2f * u)
                path.lineTo(hx + r + 8f * u, hy - r - 12f * u); path.lineTo(hx + r - 4f * u, hy - r); path.close()
                cv.drawPath(path, pa)
            }
            else -> {
                pa.color = metal
                rf.set(hx - r - 2f * u, hy - r - 2f * u, hx + r + 2f * u, hy + 2f * u)
                cv.drawArc(rf, 180f, 180f, true, pa)
                pa.color = accent
                cv.drawRect(hx - r - 2f * u, hy - 2f * u, hx + r + 2f * u, hy + 3f * u, pa)
                path.reset()
                path.moveTo(hx - 3f * u, hy - r - 2f * u); path.lineTo(hx, hy - r - 22f * u); path.lineTo(hx + 3f * u, hy - r - 2f * u); path.close()
                pa.color = metalDark; cv.drawPath(path, pa)
                pa.color = 0xFF9C2B3A.toInt()
                cv.drawCircle(hx, hy - r - 22f * u, 6f * u, pa)
                cv.drawCircle(hx + 2f * u, hy - r - 14f * u, 5f * u, pa)
            }
        }
    }

    private fun drawWeaponArm(u: Float, atk: Float, weapon: Int, skin: Int, metalDark: Int, behind: Boolean) {
        when (weapon) {
            0, 1, 3 -> {
                if (behind) return
                val ease = if (atk < 0f) 0f else 1f - (1f - atk) * (1f - atk)
                val angle = if (atk < 0f) -42f else lerp(-125f, 78f, ease)
                cv.save()
                cv.translate(8f * u, -90f * u)
                cv.rotate(angle)
                st.color = skin; st.strokeWidth = 10f * u
                cv.drawLine(0f, 0f, 0f, -26f * u, st)
                val len = if (weapon == 3) 78f * u else 60f * u
                val bw = if (weapon == 3) 5f * u else 3.4f * u
                pa.color = GOLD
                cv.drawRect(-9f * u, -30f * u, 9f * u, -26f * u, pa)
                cv.drawRect(-2f * u, -26f * u, 2f * u, -18f * u, pa)
                pa.color = BLADE
                cv.drawRect(-bw, -30f * u - len, bw, -30f * u, pa)
                path.reset()
                path.moveTo(-bw, -30f * u - len); path.lineTo(0f, -30f * u - len - 10f * u); path.lineTo(bw, -30f * u - len); path.close()
                cv.drawPath(path, pa)
                if (weapon == 1) {
                    pa.color = metalDark
                    path.reset()
                    path.moveTo(bw, -30f * u - len * 0.85f)
                    path.lineTo(bw + 22f * u, -30f * u - len * 0.95f)
                    path.lineTo(bw + 22f * u, -30f * u - len * 0.55f)
                    path.lineTo(bw, -30f * u - len * 0.65f)
                    path.close()
                    cv.drawPath(path, pa)
                }
                cv.restore()
            }
            2 -> {
                if (behind) return
                val hx = 18f * u; val hy = -80f * u
                st.color = 0xFF6E4A2A.toInt(); st.strokeWidth = 4f * u
                rf.set(hx - 6f * u, hy - 26f * u, hx + 14f * u, hy + 26f * u)
                cv.drawArc(rf, -70f, 140f, false, st)
                st.color = 0xFFE8E4DA.toInt(); st.strokeWidth = 1.8f * u
                val pull = if (atk in 0f..0.6f) 10f * u else 0f
                cv.drawLine(hx + 10f * u, hy - 26f * u, hx - pull, hy, st)
                cv.drawLine(hx + 10f * u, hy + 26f * u, hx - pull, hy, st)
                if (atk in 0f..0.55f) {
                    st.color = 0xFFCBB089.toInt(); st.strokeWidth = 2.5f * u
                    cv.drawLine(hx - pull, hy, hx + 22f * u, hy, st)
                }
                st.color = skin; st.strokeWidth = 9f * u
                cv.drawLine(2f * u, -90f * u, hx, hy, st)
            }
        }
    }

    private fun drawArrow(a: Arrow) {
        val ang = Math.toDegrees(Math.atan2(a.vy.toDouble(), a.vx.toDouble())).toFloat()
        cv.save(); cv.translate(a.x, a.y); cv.rotate(ang)
        st.color = 0xFFCBB089.toInt(); st.strokeWidth = 3f * s
        cv.drawLine(-16f * s, 0f, 8f * s, 0f, st)
        pa.color = 0xFFE8E4DA.toInt()
        path.reset(); path.moveTo(8f * s, 0f); path.lineTo(0f, -4f * s); path.lineTo(0f, 4f * s); path.close()
        cv.drawPath(path, pa)
        st.color = 0xFF9C3B32.toInt(); st.strokeWidth = 2.5f * s
        cv.drawLine(-16f * s, 0f, -20f * s, -4f * s, st)
        cv.drawLine(-16f * s, 0f, -20f * s, 4f * s, st)
        cv.restore()
    }

    private fun drawParticle(p: Particle) {
        val a = (p.life / p.maxLife).coerceIn(0f, 1f)
        pa.color = withAlpha(p.color, (a * 255).toInt())
        cv.drawRect(p.x - p.size, p.y - p.size, p.x + p.size, p.y + p.size, pa)
    }

    // ---------------- HUD ----------------

    private fun drawHud() {
        val pad = 18f * s
        val barW = 260f * s; val barH = 24f * s
        pa.color = 0xAA1A1F26.toInt()
        cv.drawRect(pad, pad, pad + barW, pad + barH, pa)
        pa.color = 0xFF8E2B22.toInt()
        val hpf = (g.player.hp / g.player.maxHp).coerceIn(0f, 1f)
        cv.drawRect(pad, pad, pad + barW * hpf, pad + barH, pa)
        st.color = GOLD; st.strokeWidth = 2.5f * s
        cv.drawRect(pad, pad, pad + barW, pad + barH, st)
        tp.color = Color.WHITE; tp.textSize = 15f * s; tp.textAlign = Paint.Align.LEFT
        cv.drawText("ВИТЯЗЬ", pad + 6f * s, pad + barH - 7f * s, tp)

        tp.textAlign = Paint.Align.RIGHT; tp.textSize = 22f * s; tp.color = Color.WHITE
        cv.drawText(g.score.toString(), g.w - pad, pad + 22f * s, tp)
        tp.textSize = 12f * s; tp.color = withAlpha(Color.WHITE, 180)
        cv.drawText("ОЧКИ", g.w - pad, pad + 38f * s, tp)

        tp.textAlign = Paint.Align.CENTER; tp.textSize = 16f * s; tp.color = withAlpha(Color.WHITE, 220)
        cv.drawText(g.level.name, g.w / 2f, pad + 20f * s, tp)

        if (g.combo > 1) {
            tp.textAlign = Paint.Align.LEFT; tp.textSize = 20f * s; tp.color = GOLD
            cv.drawText("КОМБО x${g.combo}", pad, pad + barH + 28f * s, tp)
        }

        if (g.isBossAlive()) {
            val bw = g.w * 0.5f; val bx = (g.w - bw) / 2f; val by = g.h - 36f * s
            pa.color = 0xAA1A1F26.toInt(); cv.drawRect(bx, by, bx + bw, by + 16f * s, pa)
            pa.color = 0xFFB02A2A.toInt(); cv.drawRect(bx, by, bx + bw * g.bossHpFraction(), by + 16f * s, pa)
            st.color = GOLD; st.strokeWidth = 2.5f * s; cv.drawRect(bx, by, bx + bw, by + 16f * s, st)
            tp.textAlign = Paint.Align.CENTER; tp.textSize = 13f * s; tp.color = Color.WHITE
            cv.drawText("ВОЕВОДА", g.w / 2f, by - 5f * s, tp)
        }
    }

    private fun drawControls() {
        val l = Controls.left(g)
        drawButtonBase(l)
        triangle(l.cx + 8f * s, l.cy, l.cx - 12f * s, l.cy - 14f * s, l.cx - 12f * s, l.cy + 14f * s)
        val r = Controls.right(g)
        drawButtonBase(r)
        triangle(r.cx - 8f * s, r.cy, r.cx + 12f * s, r.cy - 14f * s, r.cx + 12f * s, r.cy + 14f * s)
        val j = Controls.jump(g)
        drawButtonBase(j)
        triangle(j.cx, j.cy - 14f * s, j.cx - 14f * s, j.cy + 8f * s, j.cx + 14f * s, j.cy + 8f * s)

        val a = Controls.attack(g)
        pa.color = withAlpha(0xFF9C3B32.toInt(), 150); cv.drawCircle(a.cx, a.cy, a.r, pa)
        st.color = withAlpha(GOLD, 220); st.strokeWidth = 3f * s; cv.drawCircle(a.cx, a.cy, a.r, st)
        st.color = Color.WHITE; st.strokeWidth = 5f * s
        cv.drawLine(a.cx - 16f * s, a.cy + 16f * s, a.cx + 14f * s, a.cy - 16f * s, st)
        st.strokeWidth = 4f * s
        cv.drawLine(a.cx - 22f * s, a.cy + 6f * s, a.cx - 6f * s, a.cy + 22f * s, st)
    }

    private fun drawButtonBase(b: Btn) {
        pa.color = withAlpha(0xFF26303C.toInt(), 130); cv.drawCircle(b.cx, b.cy, b.r, pa)
        st.color = withAlpha(Color.WHITE, 150); st.strokeWidth = 2.5f * s; cv.drawCircle(b.cx, b.cy, b.r, st)
        pa.color = withAlpha(Color.WHITE, 230)
    }

    private fun triangle(x1: Float, y1: Float, x2: Float, y2: Float, x3: Float, y3: Float) {
        path.reset(); path.moveTo(x1, y1); path.lineTo(x2, y2); path.lineTo(x3, y3); path.close()
        cv.drawPath(path, pa)
    }

    // ---------------- OVERLAYS ----------------

    private fun drawOverlays() {
        when (g.phase) {
            Phase.MENU -> menuScreen()
            Phase.LEVELCARD -> levelCard()
            Phase.CLEARED -> centerCard("УРОВЕНЬ ПРОЙДЕН", "Очки: ${g.score}", "")
            Phase.GAMEOVER -> centerCard("НОВГОРОД ПАЛ", "Очки: ${g.score}", "Нажмите, чтобы повторить")
            Phase.WIN -> centerCard("ПОБЕДА!", "Новгород спасён · Очки: ${g.score}", "Нажмите, чтобы вернуться")
            else -> {}
        }
    }

    private fun dimScreen(alpha: Int) {
        pa.color = withAlpha(Color.BLACK, alpha); cv.drawRect(0f, 0f, g.w, g.h, pa)
    }

    private fun menuScreen() {
        dimScreen(150)
        val ex = g.w / 2f; val ey = g.h * 0.30f
        pa.color = 0xFFB07566.toInt()
        path.reset()
        path.moveTo(ex, ey - 40f * s); path.lineTo(ex + 42f * s, ey - 26f * s)
        path.lineTo(ex + 42f * s, ey + 18f * s)
        path.cubicTo(ex + 42f * s, ey + 44f * s, ex + 20f * s, ey + 58f * s, ex, ey + 66f * s)
        path.cubicTo(ex - 20f * s, ey + 58f * s, ex - 42f * s, ey + 44f * s, ex - 42f * s, ey + 18f * s)
        path.lineTo(ex - 42f * s, ey - 26f * s); path.close()
        cv.drawPath(path, pa)
        pa.color = BLADE; cv.drawRect(ex - 3f * s, ey - 30f * s, ex + 3f * s, ey + 40f * s, pa)
        pa.color = GOLD; cv.drawRect(ex - 16f * s, ey + 20f * s, ex + 16f * s, ey + 27f * s, pa)

        tp.textAlign = Paint.Align.CENTER
        tp.color = Color.WHITE; tp.textSize = 54f * s
        cv.drawText("ВИТЯЗИ", g.w / 2f, g.h * 0.52f, tp)
        tp.color = GOLD; tp.textSize = 40f * s
        cv.drawText("НОВГОРОДА", g.w / 2f, g.h * 0.62f, tp)
        tp.color = withAlpha(Color.WHITE, 230); tp.textSize = 20f * s
        cv.drawText("Нажмите, чтобы начать", g.w / 2f, g.h * 0.74f, tp)
        tp.color = withAlpha(Color.WHITE, 160); tp.textSize = 14f * s
        cv.drawText("◀ ▶ — движение    ⤒ — прыжок    ⚔ — удар", g.w / 2f, g.h * 0.83f, tp)
    }

    private fun levelCard() {
        val a = (g.phaseTimer / 2.2f).coerceIn(0f, 1f)
        pa.color = withAlpha(Color.BLACK, (a * 130).toInt()); cv.drawRect(0f, 0f, g.w, g.h, pa)
        tp.textAlign = Paint.Align.CENTER
        tp.color = withAlpha(GOLD, (a * 255).toInt()); tp.textSize = 22f * s
        cv.drawText("УРОВЕНЬ ${g.levelIndex + 1}", g.w / 2f, g.h * 0.40f, tp)
        tp.color = withAlpha(Color.WHITE, (a * 255).toInt()); tp.textSize = 40f * s
        cv.drawText(g.level.name, g.w / 2f, g.h * 0.50f, tp)
        tp.color = withAlpha(Color.WHITE, (a * 200).toInt()); tp.textSize = 18f * s
        cv.drawText(g.level.subtitle, g.w / 2f, g.h * 0.58f, tp)
    }

    private fun centerCard(title: String, sub: String, hint: String) {
        dimScreen(170)
        tp.textAlign = Paint.Align.CENTER
        tp.color = GOLD; tp.textSize = 48f * s
        cv.drawText(title, g.w / 2f, g.h * 0.44f, tp)
        tp.color = Color.WHITE; tp.textSize = 22f * s
        cv.drawText(sub, g.w / 2f, g.h * 0.55f, tp)
        if (hint.isNotEmpty()) {
            tp.color = withAlpha(Color.WHITE, 200); tp.textSize = 18f * s
            cv.drawText(hint, g.w / 2f, g.h * 0.66f, tp)
        }
    }

    // ---------------- helpers ----------------

    private fun now() = (System.nanoTime() / 1_000_000L) / 1000f

    private fun lerp(a: Float, b: Float, t: Float) = a + (b - a) * t

    private fun withAlpha(color: Int, alpha: Int): Int =
        (color and 0x00FFFFFF) or (alpha.coerceIn(0, 255) shl 24)

    private fun darker(color: Int): Int {
        val r = (Color.red(color) * 0.7f).toInt()
        val gg = (Color.green(color) * 0.7f).toInt()
        val b = (Color.blue(color) * 0.7f).toInt()
        return Color.rgb(r, gg, b)
    }
}
