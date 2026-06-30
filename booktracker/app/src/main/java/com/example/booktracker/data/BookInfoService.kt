package com.example.booktracker.data

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder

/** Context pulled from a book database for a title/author query. */
data class BookInfo(
    val title: String,
    val author: String,
    val description: String,
    val coverUrl: String?,
    val categories: String,
    val pageCount: Int,
    val infoLink: String
)

/** A handy link about the book's topic (opened in the browser). */
data class Material(val label: String, val url: String)

object BookInfoService {

    /**
     * Tries several queries against Google Books, then Open Library as a fallback.
     * Returns the first match, or null if nothing turns up / no network.
     */
    suspend fun search(title: String, author: String = ""): BookInfo? = withContext(Dispatchers.IO) {
        val t = title.trim()
        val a = author.trim()
        if (t.isBlank()) return@withContext null

        val attempts = mutableListOf<String>()
        if (a.isNotBlank()) attempts += "intitle:$t inauthor:$a"
        attempts += listOf(t, a).filter { it.isNotBlank() }.joinToString(" ")
        attempts += t

        for (q in attempts) {
            val r = googleBooks(q)
            if (r != null) return@withContext r
        }
        for (q in attempts) {
            val r = openLibrary(q)
            if (r != null) return@withContext r
        }
        null
    }

    private fun googleBooks(query: String): BookInfo? {
        val q = URLEncoder.encode(query, "UTF-8")
        val json = httpGet("https://www.googleapis.com/books/v1/volumes?q=$q&maxResults=3&country=RU")
            ?: httpGet("https://www.googleapis.com/books/v1/volumes?q=$q&maxResults=3")
            ?: return null
        return runCatching {
            val root = JSONObject(json)
            val items = root.optJSONArray("items") ?: return null
            if (items.length() == 0) return null
            val info = items.getJSONObject(0).optJSONObject("volumeInfo") ?: return null

            val authors = info.optJSONArray("authors")
            val authorStr = if (authors != null && authors.length() > 0)
                (0 until authors.length()).joinToString(", ") { authors.getString(it) } else ""

            val cats = info.optJSONArray("categories")
            val catStr = if (cats != null && cats.length() > 0)
                (0 until cats.length()).joinToString(", ") { cats.getString(it) } else ""

            var cover: String? = null
            info.optJSONObject("imageLinks")?.let { img ->
                val raw = img.optString("thumbnail", img.optString("smallThumbnail", ""))
                if (raw.isNotBlank()) cover = raw.replace("http://", "https://").replace("&edge=curl", "")
            }

            BookInfo(
                title = info.optString("title", query),
                author = authorStr,
                description = stripHtml(info.optString("description", "")),
                coverUrl = cover,
                categories = catStr,
                pageCount = info.optInt("pageCount", 0),
                infoLink = info.optString("infoLink", "")
            )
        }.getOrNull()
    }

    private fun openLibrary(query: String): BookInfo? {
        val q = URLEncoder.encode(query, "UTF-8")
        val json = httpGet("https://openlibrary.org/search.json?q=$q&limit=1&fields=title,author_name,cover_i,first_sentence,subject,number_of_pages_median,key")
            ?: return null
        return runCatching {
            val docs = JSONObject(json).optJSONArray("docs") ?: return null
            if (docs.length() == 0) return null
            val d = docs.getJSONObject(0)

            val authors = d.optJSONArray("author_name")
            val authorStr = if (authors != null && authors.length() > 0)
                (0 until authors.length()).joinToString(", ") { authors.getString(it) } else ""

            val subj = d.optJSONArray("subject")
            val catStr = if (subj != null && subj.length() > 0)
                (0 until minOf(3, subj.length())).joinToString(", ") { subj.getString(it) } else ""

            val coverId = d.optInt("cover_i", 0)
            val cover = if (coverId > 0) "https://covers.openlibrary.org/b/id/$coverId-L.jpg" else null

            var desc = ""
            val fs = d.opt("first_sentence")
            if (fs is org.json.JSONArray && fs.length() > 0) desc = fs.getString(0)
            else if (fs is String) desc = fs

            val key = d.optString("key", "")
            val link = if (key.isNotBlank()) "https://openlibrary.org$key" else ""

            BookInfo(
                title = d.optString("title", query),
                author = authorStr,
                description = stripHtml(desc),
                coverUrl = cover,
                categories = catStr,
                pageCount = d.optInt("number_of_pages_median", 0),
                infoLink = link
            )
        }.getOrNull()
    }

    /** Topic links — search deep-links, so no API keys are needed. */
    fun materialsFor(title: String, author: String, infoLink: String): List<Material> {
        val base = listOf(title, author).filter { it.isNotBlank() }.joinToString(" ")
        fun enc(s: String) = URLEncoder.encode(s, "UTF-8")
        val list = mutableListOf<Material>()
        list += Material("YouTube: обзор книги", "https://www.youtube.com/results?search_query=${enc("$base обзор книги")}")
        list += Material("Подкасты по теме", "https://www.google.com/search?q=${enc("$base подкаст")}")
        list += Material("Статьи и рецензии", "https://www.google.com/search?q=${enc("$base рецензия статья")}")
        list += Material("Цитаты и идеи", "https://www.google.com/search?q=${enc("$base краткое содержание идеи")}")
        if (infoLink.isNotBlank()) list += Material("Подробнее о книге", infoLink)
        return list
    }

    private fun httpGet(urlStr: String): String? {
        return runCatching {
            val conn = (URL(urlStr).openConnection() as HttpURLConnection).apply {
                requestMethod = "GET"
                connectTimeout = 9000
                readTimeout = 9000
                instanceFollowRedirects = true
                setRequestProperty("Accept", "application/json")
                setRequestProperty("User-Agent", "BookTracker/1.0 (Android)")
            }
            try {
                if (conn.responseCode != 200) return null
                conn.inputStream.bufferedReader().use { it.readText() }
            } finally {
                conn.disconnect()
            }
        }.getOrNull()
    }

    private fun stripHtml(s: String): String =
        s.replace(Regex("<[^>]*>"), "").replace("&nbsp;", " ").replace("&amp;", "&")
            .replace("&quot;", "\"").replace("&#39;", "'").trim()
}
