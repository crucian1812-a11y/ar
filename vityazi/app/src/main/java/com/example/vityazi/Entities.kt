package com.example.vityazi

enum class EnemyType { RAIDER, ARCHER, BRUTE, BOSS }

class Player {
    var x = 0f
    var y = 0f            // feet (ground line)
    var vy = 0f
    var onGround = true
    var facing = 1        // +1 right, -1 left
    var hp = 100f
    var maxHp = 100f
    var walk = 0f         // walk-cycle phase
    var moving = false
    var attackTimer = 0f  // > 0 while a swing is in progress
    var attackDuration = 0.30f
    var attackCooldown = 0f
    var swing = 0L        // unique id per swing (so each enemy is hit once)
    var invuln = 0f
    var flash = 0f        // hurt flash
}

class Enemy(val type: EnemyType) {
    var x = 0f
    var y = 0f
    var vy = 0f
    var onGround = true
    var facing = -1
    var hp = 0f
    var maxHp = 0f
    var walk = 0f
    var attackTimer = 0f
    var actCd = 0.6f      // cooldown between actions (swing / shot)
    var hitSwing = -1L    // last player swing id that already damaged this enemy
    var stagger = 0f      // knockback / hit-stun timer
    var hurt = 0f         // hurt flash
    var dead = false
    var spawnIn = 0.35f   // brief "rise" animation timer
}

class Arrow {
    var x = 0f
    var y = 0f
    var vx = 0f
    var vy = 0f
    var fromEnemy = true
    var dmg = 8f
    var life = 5f
    var dead = false
}

class Particle {
    var x = 0f
    var y = 0f
    var vx = 0f
    var vy = 0f
    var life = 0f
    var maxLife = 0f
    var size = 0f
    var color = 0
    var gravity = 1f
}
