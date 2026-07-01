package com.example.booktracker.data

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.TypeConverters

@Database(
    entities = [Book::class, Quote::class, Impression::class, ReadingLog::class],
    version = 3,
    exportSchema = false
)
@TypeConverters(Converters::class)
abstract class AppDatabase : RoomDatabase() {
    abstract fun bookDao(): BookDao
    abstract fun quoteDao(): QuoteDao
    abstract fun impressionDao(): ImpressionDao
    abstract fun readingLogDao(): ReadingLogDao

    companion object {
        @Volatile
        private var instance: AppDatabase? = null

        fun get(context: Context): AppDatabase =
            instance ?: synchronized(this) {
                instance ?: Room.databaseBuilder(
                    context.applicationContext,
                    AppDatabase::class.java,
                    "booktracker.db"
                ).fallbackToDestructiveMigration().build().also { instance = it }
            }
    }
}
