package com.example.booktracker.data

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder

/** Context pulled from the Google Books API for a title/author query. */
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

    /** Looks up the first matching volume. Returns null on no result / network error. */
    suspend fun search(query: String): BookInfo? = withContext(Dispatchers.IO) {
        if (query.isBlank()) return@withContext null
        val q = URLEncoder.encode(query.trim(), "UTF-8")
        val url = "https://www.googleapis.com/books/v1/volumes?q=$q&maxResults=1&country=RU"
        val json = httpGet(url) ?: return@withContext null
        runCatching {
            val items = JSONObject(json).optJSONArray("items") ?: return@withContext null
            if (items.length() == 0) return@withContext null
            val info = items.getJSONObject(0).optJSONObject("volumeInfo") ?: return@withContext null

            val authors = info.optJSONArray("authors")
            val authorStr = if (authors != null && authors.length() > 0)
                (0 until authors.length()).joinToString(", ") { authors.getString(it) }
            else ""

            val cats = info.optJSONArray("categories")
            val catStr = if (cats != null && cats.length() > 0)
                (0 until cats.length()).joinToString(", ") { cats.getString(it) }
            else ""

            var cover: String? = null
            val img = info.optJSONObject("imageLinks")
            if (img != null) {
                val raw = img.optString("thumbnail", img.optString("smallThumbnail", ""))
                if (raw.isNotBlank()) cover = raw.replace("http://", "https://").replace("&edge=curl", "")
            }

            BookInfo(
                title = info.optString("title", query),
                author = authorStr,
                description = info.optString("description", "").let { stripHtml(it) },
                coverUrl = cover,
                categories = catStr,
                pageCount = info.optInt("pageCount", 0),
                infoLink = info.optString("infoLink", "")
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
        if (infoLink.isNotBlank()) list += Material("Google Books", infoLink)
        return list
    }

    private fun httpGet(urlStr: String): String? {
        return runCatching {
            val conn = (URL(urlStr).openConnection() as HttpURLConnection).apply {
                requestMethod = "GET"
                connectTimeout = 8000
                readTimeout = 8000
                setRequestProperty("Accept", "application/json")
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
