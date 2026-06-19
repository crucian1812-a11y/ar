package com.example.booktracker.data

import android.content.Context
import kotlinx.coroutines.flow.Flow
import java.time.LocalDate
import java.time.ZoneId

class Repository(
    private val bookDao: BookDao,
    private val quoteDao: QuoteDao,
    private val logDao: ReadingLogDao
) {
    val books: Flow<List<Book>> = bookDao.observeAll()
    val quotes: Flow<List<Quote>> = quoteDao.observeAll()
    val quoteCount: Flow<Int> = quoteDao.observeCount()
    val logs: Flow<List<ReadingLog>> = logDao.observeAll()

    fun book(id: Long): Flow<Book?> = bookDao.observeById(id)
    fun quotesForBook(bookId: Long): Flow<List<Quote>> = quoteDao.observeForBook(bookId)

    suspend fun getBook(id: Long): Book? = bookDao.getById(id)

    suspend fun saveBook(book: Book): Long = bookDao.upsert(book)

    suspend fun deleteBook(book: Book) = bookDao.delete(book)

    /** Updates reading progress, logs the delta, and flips status automatically. */
    suspend fun updateProgress(book: Book, newCurrentPage: Int) {
        val clamped = newCurrentPage.coerceAtLeast(0)
            .let { if (book.totalPages > 0) it.coerceAtMost(book.totalPages) else it }
        val delta = clamped - book.currentPage

        val now = System.currentTimeMillis()
        var updated = book.copy(currentPage = clamped)
        if (book.status == ReadingStatus.WANT_TO_READ && clamped > 0) {
            updated = updated.copy(status = ReadingStatus.READING, startedAt = book.startedAt ?: now)
        }
        if (book.totalPages > 0 && clamped >= book.totalPages) {
            updated = updated.copy(status = ReadingStatus.FINISHED, finishedAt = now)
        }
        bookDao.update(updated)

        if (delta > 0) {
            logDao.insert(
                ReadingLog(
                    bookId = book.id,
                    dateEpochDay = LocalDate.now().toEpochDay(),
                    pages = delta
                )
            )
        }
    }

    suspend fun setStatus(book: Book, status: ReadingStatus) {
        val now = System.currentTimeMillis()
        val updated = when (status) {
            ReadingStatus.READING -> book.copy(status = status, startedAt = book.startedAt ?: now)
            ReadingStatus.FINISHED -> book.copy(
                status = status,
                finishedAt = now,
                currentPage = if (book.totalPages > 0) book.totalPages else book.currentPage
            )
            ReadingStatus.WANT_TO_READ -> book.copy(status = status)
        }
        bookDao.update(updated)
    }

    suspend fun addQuote(quote: Quote): Long = quoteDao.upsert(quote)
    suspend fun updateQuote(quote: Quote) = quoteDao.update(quote)
    suspend fun deleteQuote(quote: Quote) = quoteDao.delete(quote)

    companion object {
        fun from(context: Context): Repository {
            val db = AppDatabase.get(context)
            return Repository(db.bookDao(), db.quoteDao(), db.readingLogDao())
        }

        fun epochDayToDate(day: Long): LocalDate = LocalDate.ofEpochDay(day)

        fun todayEpochDay(): Long =
            LocalDate.now(ZoneId.systemDefault()).toEpochDay()
    }
}
