package com.example.booktracker.data

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import androidx.room.TypeConverter

enum class ReadingStatus {
    WANT_TO_READ,
    READING,
    FINISHED;

    val label: String
        get() = when (this) {
            WANT_TO_READ -> "Хочу прочитать"
            READING -> "Читаю"
            FINISHED -> "Прочитано"
        }
}

class Converters {
    @TypeConverter
    fun statusToString(status: ReadingStatus): String = status.name

    @TypeConverter
    fun stringToStatus(value: String): ReadingStatus =
        runCatching { ReadingStatus.valueOf(value) }.getOrDefault(ReadingStatus.WANT_TO_READ)
}

@Entity(tableName = "books")
data class Book(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val title: String,
    val author: String = "",
    val coverPath: String? = null,
    val coverUrl: String? = null,
    val description: String = "",
    val categories: String = "",
    val infoLink: String = "",
    val status: ReadingStatus = ReadingStatus.WANT_TO_READ,
    val rating: Int = 0,
    val totalPages: Int = 0,
    val currentPage: Int = 0,
    val startedAt: Long? = null,
    val finishedAt: Long? = null,
    val notes: String = "",
    val createdAt: Long = System.currentTimeMillis()
)

/** Computed (not persisted) — kept as an extension so Room doesn't treat it as a column. */
val Book.progress: Float
    get() = if (totalPages > 0) (currentPage.toFloat() / totalPages).coerceIn(0f, 1f) else 0f

@Entity(
    tableName = "quotes",
    foreignKeys = [
        ForeignKey(
            entity = Book::class,
            parentColumns = ["id"],
            childColumns = ["bookId"],
            onDelete = ForeignKey.CASCADE
        )
    ],
    indices = [Index("bookId")]
)
data class Quote(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val bookId: Long,
    val text: String,
    val page: Int? = null,
    val photoPath: String? = null,
    val createdAt: Long = System.currentTimeMillis()
)

/** One entry per progress update — powers the dashboard charts and reading streak. */
@Entity(
    tableName = "reading_logs",
    foreignKeys = [
        ForeignKey(
            entity = Book::class,
            parentColumns = ["id"],
            childColumns = ["bookId"],
            onDelete = ForeignKey.CASCADE
        )
    ],
    indices = [Index("bookId")]
)
data class ReadingLog(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val bookId: Long,
    val dateEpochDay: Long,
    val pages: Int,
    val createdAt: Long = System.currentTimeMillis()
)
