package com.example.vityazi

import android.content.Context
import android.graphics.Canvas
import android.view.MotionEvent
import android.view.SurfaceHolder
import android.view.SurfaceView

class GameView(context: Context) : SurfaceView(context), SurfaceHolder.Callback {

    val game = Game()
    val renderer = Renderer()
    private var thread: GameThread? = null

    init {
        holder.addCallback(this)
        isFocusable = true
    }

    override fun surfaceCreated(h: SurfaceHolder) {
        if (thread == null || thread?.isAlive != true) {
            thread = GameThread(holder, this).also {
                it.running = true
                it.start()
            }
        }
    }

    override fun surfaceChanged(h: SurfaceHolder, format: Int, width: Int, height: Int) {
        game.resize(width, height)
    }

    override fun surfaceDestroyed(h: SurfaceHolder) {
        thread?.let {
            it.running = false
            var retry = true
            while (retry) {
                try { it.join(); retry = false } catch (_: InterruptedException) {}
            }
        }
        thread = null
    }

    override fun onTouchEvent(e: MotionEvent): Boolean {
        val action = e.actionMasked

        if (game.phase != Phase.PLAY) {
            if (action == MotionEvent.ACTION_DOWN) game.onTap()
            return true
        }

        if (action == MotionEvent.ACTION_DOWN || action == MotionEvent.ACTION_POINTER_DOWN) {
            val i = e.actionIndex
            val x = e.getX(i); val y = e.getY(i)
            if (Controls.jump(game).contains(x, y)) game.queueJump()
            if (Controls.attack(game).contains(x, y)) game.queueAttack()
        }

        // Recompute movement from all currently-down pointers.
        var l = false; var r = false
        val upIndex = if (action == MotionEvent.ACTION_POINTER_UP || action == MotionEvent.ACTION_UP)
            e.actionIndex else -1
        for (i in 0 until e.pointerCount) {
            if (i == upIndex) continue
            val x = e.getX(i); val y = e.getY(i)
            if (Controls.left(game).contains(x, y)) l = true
            if (Controls.right(game).contains(x, y)) r = true
        }
        game.moveLeft = l
        game.moveRight = r
        return true
    }
}

class GameThread(
    private val surfaceHolder: SurfaceHolder,
    private val view: GameView
) : Thread() {

    @Volatile
    var running = false

    override fun run() {
        var last = System.nanoTime()
        while (running) {
            val now = System.nanoTime()
            val dt = ((now - last) / 1_000_000_000f)
            last = now

            view.game.update(dt)

            var canvas: Canvas? = null
            try {
                canvas = surfaceHolder.lockCanvas()
                if (canvas != null) {
                    synchronized(surfaceHolder) { view.renderer.draw(canvas, view.game) }
                }
            } finally {
                if (canvas != null) {
                    try { surfaceHolder.unlockCanvasAndPost(canvas) } catch (_: Exception) {}
                }
            }

            val frameMs = (System.nanoTime() - now) / 1_000_000f
            val sleepMs = (16L - frameMs.toLong())
            if (sleepMs > 0) {
                try { sleep(sleepMs) } catch (_: InterruptedException) {}
            }
        }
    }
}
