package com.example.booktracker.data

import org.json.JSONArray
import org.json.JSONObject

/** All app data collected for a backup file. */
data class BackupData(
    val books: List<Book>,
    val quotes: List<Quote>,
    val impressions: List<Impression>,
    val logs: List<ReadingLog>
)

/**
 * Serializes the whole library (books, quotes, impressions, reading logs) to a
 * plain JSON string and reads it back. IDs are preserved so a restore keeps the
 * links between a book and its quotes/impressions/logs intact.
 */
object BackupService {

    const val VERSION = 1

    fun toJson(data: BackupData): String {
        val root = JSONObject()
        root.put("version", VERSION)
        root.put("exportedAt", System.currentTimeMillis())

        root.put("books", JSONArray().apply {
            data.books.forEach { b ->
                put(JSONObject().apply {
                    put("id", b.id)
                    put("title", b.title)
                    put("author", b.author)
                    put("coverPath", b.coverPath ?: JSONObject.NULL)
                    put("coverUrl", b.coverUrl ?: JSONObject.NULL)
                    put("description", b.description)
                    put("categories", b.categories)
                    put("infoLink", b.infoLink)
                    put("status", b.status.name)
                    put("rating", b.rating)
                    put("totalPages", b.totalPages)
                    put("currentPage", b.currentPage)
                    put("startedAt", b.startedAt ?: JSONObject.NULL)
                    put("finishedAt", b.finishedAt ?: JSONObject.NULL)
                    put("notes", b.notes)
                    put("music", b.music)
                    put("createdAt", b.createdAt)
                })
            }
        })

        root.put("quotes", JSONArray().apply {
            data.quotes.forEach { q ->
                put(JSONObject().apply {
                    put("id", q.id)
                    put("bookId", q.bookId)
                    put("text", q.text)
                    put("page", q.page ?: JSONObject.NULL)
                    put("photoPath", q.photoPath ?: JSONObject.NULL)
                    put("createdAt", q.createdAt)
                })
            }
        })

        root.put("impressions", JSONArray().apply {
            data.impressions.forEach { i ->
                put(JSONObject().apply {
                    put("id", i.id)
                    put("bookId", i.bookId)
                    put("text", i.text)
                    put("music", i.music)
                    put("mood", i.mood)
                    put("page", i.page ?: JSONObject.NULL)
                    put("createdAt", i.createdAt)
                })
            }
        })

        root.put("logs", JSONArray().apply {
            data.logs.forEach { l ->
                put(JSONObject().apply {
                    put("id", l.id)
                    put("bookId", l.bookId)
                    put("dateEpochDay", l.dateEpochDay)
                    put("pages", l.pages)
                    put("createdAt", l.createdAt)
                })
            }
        })

        return root.toString(2)
    }

    fun parse(json: String): BackupData {
        val root = JSONObject(json)

        val books = root.optJSONArray("books").mapObjects { o ->
            Book(
                id = o.optLong("id"),
                title = o.optString("title"),
                author = o.optString("author"),
                coverPath = o.optStringOrNull("coverPath"),
                coverUrl = o.optStringOrNull("coverUrl"),
                description = o.optString("description"),
                categories = o.optString("categories"),
                infoLink = o.optString("infoLink"),
                status = runCatching { ReadingStatus.valueOf(o.optString("status")) }
                    .getOrDefault(ReadingStatus.WANT_TO_READ),
                rating = o.optInt("rating"),
                totalPages = o.optInt("totalPages"),
                currentPage = o.optInt("currentPage"),
                startedAt = o.optLongOrNull("startedAt"),
                finishedAt = o.optLongOrNull("finishedAt"),
                notes = o.optString("notes"),
                music = o.optString("music"),
                createdAt = o.optLong("createdAt", System.currentTimeMillis())
            )
        }

        val quotes = root.optJSONArray("quotes").mapObjects { o ->
            Quote(
                id = o.optLong("id"),
                bookId = o.optLong("bookId"),
                text = o.optString("text"),
                page = o.optIntOrNull("page"),
                photoPath = o.optStringOrNull("photoPath"),
                createdAt = o.optLong("createdAt", System.currentTimeMillis())
            )
        }

        val impressions = root.optJSONArray("impressions").mapObjects { o ->
            Impression(
                id = o.optLong("id"),
                bookId = o.optLong("bookId"),
                text = o.optString("text"),
                music = o.optString("music"),
                mood = o.optInt("mood"),
                page = o.optIntOrNull("page"),
                createdAt = o.optLong("createdAt", System.currentTimeMillis())
            )
        }

        val logs = root.optJSONArray("logs").mapObjects { o ->
            ReadingLog(
                id = o.optLong("id"),
                bookId = o.optLong("bookId"),
                dateEpochDay = o.optLong("dateEpochDay"),
                pages = o.optInt("pages"),
                createdAt = o.optLong("createdAt", System.currentTimeMillis())
            )
        }

        return BackupData(books, quotes, impressions, logs)
    }

    private inline fun <T> JSONArray?.mapObjects(transform: (JSONObject) -> T): List<T> {
        if (this == null) return emptyList()
        val out = ArrayList<T>(length())
        for (idx in 0 until length()) {
            optJSONObject(idx)?.let { out.add(transform(it)) }
        }
        return out
    }

    private fun JSONObject.optStringOrNull(key: String): String? =
        if (isNull(key) || !has(key)) null else optString(key)

    private fun JSONObject.optLongOrNull(key: String): Long? =
        if (isNull(key) || !has(key)) null else optLong(key)

    private fun JSONObject.optIntOrNull(key: String): Int? =
        if (isNull(key) || !has(key)) null else optInt(key)
}
