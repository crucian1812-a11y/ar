package com.example.booktracker.data

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.TypeConverters
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase

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

        /** v1 → v2: book context columns (cover url, description, topic, info link). */
        private val MIGRATION_1_2 = object : Migration(1, 2) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("ALTER TABLE books ADD COLUMN coverUrl TEXT")
                db.execSQL("ALTER TABLE books ADD COLUMN description TEXT NOT NULL DEFAULT ''")
                db.execSQL("ALTER TABLE books ADD COLUMN categories TEXT NOT NULL DEFAULT ''")
                db.execSQL("ALTER TABLE books ADD COLUMN infoLink TEXT NOT NULL DEFAULT ''")
            }
        }

        /** v2 → v3: reading music on a book + the impressions (reading journal) table. */
        private val MIGRATION_2_3 = object : Migration(2, 3) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("ALTER TABLE books ADD COLUMN music TEXT NOT NULL DEFAULT ''")
                db.execSQL(
                    "CREATE TABLE IF NOT EXISTS `impressions` (" +
                        "`id` INTEGER NOT NULL, " +
                        "`bookId` INTEGER NOT NULL, " +
                        "`text` TEXT NOT NULL, " +
                        "`music` TEXT NOT NULL, " +
                        "`mood` INTEGER NOT NULL, " +
                        "`page` INTEGER, " +
                        "`createdAt` INTEGER NOT NULL, " +
                        "PRIMARY KEY(`id`), " +
                        "FOREIGN KEY(`bookId`) REFERENCES `books`(`id`) " +
                        "ON UPDATE NO ACTION ON DELETE CASCADE )"
                )
                db.execSQL(
                    "CREATE INDEX IF NOT EXISTS `index_impressions_bookId` " +
                        "ON `impressions` (`bookId`)"
                )
            }
        }

        fun get(context: Context): AppDatabase =
            instance ?: synchronized(this) {
                instance ?: Room.databaseBuilder(
                    context.applicationContext,
                    AppDatabase::class.java,
                    "booktracker.db"
                )
                    .addMigrations(MIGRATION_1_2, MIGRATION_2_3)
                    // Migrations preserve data across upgrades; only fall back on a downgrade.
                    .fallbackToDestructiveMigrationOnDowngrade()
                    .build()
                    .also { instance = it }
            }
    }
}
