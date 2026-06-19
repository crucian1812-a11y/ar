package com.example.booktracker

import android.app.Application
import com.example.booktracker.data.Repository
import com.example.booktracker.ocr.OcrManager

class BookTrackerApp : Application() {
    val repository: Repository by lazy { Repository.from(this) }
    val ocrManager: OcrManager by lazy { OcrManager(this) }

    companion object {
        lateinit var instance: BookTrackerApp
            private set
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
    }
}
