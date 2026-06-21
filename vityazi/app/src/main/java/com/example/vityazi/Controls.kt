package com.example.vityazi

class Btn(val cx: Float, val cy: Float, val r: Float) {
    fun contains(x: Float, y: Float): Boolean {
        val dx = x - cx; val dy = y - cy
        // generous square-ish hit area for comfort
        return dx * dx + dy * dy <= (r * 1.25f) * (r * 1.25f)
    }
}

object Controls {
    fun left(g: Game) = Btn(95f * g.s, g.h - 90f * g.s, 58f * g.s)
    fun right(g: Game) = Btn(235f * g.s, g.h - 90f * g.s, 58f * g.s)
    fun jump(g: Game) = Btn(g.w - 215f * g.s, g.h - 75f * g.s, 56f * g.s)
    fun attack(g: Game) = Btn(g.w - 95f * g.s, g.h - 100f * g.s, 72f * g.s)
}
