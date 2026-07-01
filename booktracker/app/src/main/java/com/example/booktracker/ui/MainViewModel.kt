package com.example.booktracker.ui

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.example.booktracker.BookTrackerApp
import com.example.booktracker.data.Book
import com.example.booktracker.data.Quote
import com.example.booktracker.data.ReadingLog
import com.example.booktracker.data.ReadingStatus
import com.example.booktracker.data.Repository
import com.example.booktracker.util.ImageUtils
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.YearMonth
import java.time.format.TextStyle
import java.util.Locale

data class DashboardStats(
    val totalBooks: Int = 0,
    val reading: Int = 0,
    val finished: Int = 0,
    val wantToRead: Int = 0,
    val totalQuotes: Int = 0,
    val totalImpressions: Int = 0,
    val currentStreak: Int = 0,
    val longestStreak: Int = 0,
    val totalPagesRead: Int = 0,
    val pagesToday: Int = 0,
    val pagesThisWeek: Int = 0,
    val pagesThisMonth: Int = 0,
    val avgPagesPerActiveDay: Int = 0,
    val activeDays: Int = 0,
    val bestDay: DayPages? = null,
    val pagesLast14Days: List<DayPages> = emptyList(),
    val recentDays: List<DayPages> = emptyList(),
    val finishedByMonth: List<MonthCount> = emptyList(),
    val ratingDistribution: List<Int> = List(5) { 0 }
)

data class DayPages(val date: LocalDate, val pages: Int)
data class MonthCount(val label: String, val count: Int)

sealed interface ScanState {
    data object Idle : ScanState
    data class Preparing(val message: String) : ScanState
    data object Recognizing : ScanState
    data class Result(val text: String, val photoPath: String) : ScanState
    data class Error(val message: String) : ScanState
}

sealed interface LookupState {
    data object Idle : LookupState
    data object Loading : LookupState
    data class Found(val info: com.example.booktracker.data.BookInfo) : LookupState
    data object NotFound : LookupState
}

class MainViewModel(app: Application) : AndroidViewModel(app) {

    private val repo: Repository = (app as BookTrackerApp).repository
    private val ocr = (app as BookTrackerApp).ocrManager

    val books: StateFlow<List<Book>> =
        repo.books.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    val quotes: StateFlow<List<Quote>> =
        repo.quotes.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), emptyList())

    val dashboard: StateFlow<DashboardStats> =
        combine(repo.books, repo.logs, repo.quoteCount, repo.impressionCount) { books, logs, quoteCount, imprCount ->
            buildStats(books, logs, quoteCount, imprCount)
        }.stateIn(viewModelScope, SharingStarted.WhileSubscribed(5000), DashboardStats())

    private val _scanState = MutableStateFlow<ScanState>(ScanState.Idle)
    val scanState: StateFlow<ScanState> = _scanState.asStateFlow()

    private val _lookup = MutableStateFlow<LookupState>(LookupState.Idle)
    val lookup: StateFlow<LookupState> = _lookup.asStateFlow()

    fun lookupBook(title: String, author: String = "") = viewModelScope.launch {
        if (title.isBlank()) return@launch
        _lookup.value = LookupState.Loading
        val info = repo.lookupBookInfo(title, author)
        _lookup.value = if (info != null) LookupState.Found(info) else LookupState.NotFound
    }

    fun resetLookup() { _lookup.value = LookupState.Idle }

    fun book(id: Long): Flow<Book?> = repo.book(id)
    fun quotesForBook(id: Long): Flow<List<Quote>> = repo.quotesForBook(id)
    fun impressionsForBook(id: Long): Flow<List<com.example.booktracker.data.Impression>> =
        repo.impressionsForBook(id)

    fun addImpression(impression: com.example.booktracker.data.Impression, onDone: () -> Unit = {}) =
        viewModelScope.launch {
            repo.addImpression(impression)
            onDone()
        }

    fun deleteImpression(impression: com.example.booktracker.data.Impression) =
        viewModelScope.launch { repo.deleteImpression(impression) }

    fun saveBook(book: Book, onSaved: (Long) -> Unit = {}) = viewModelScope.launch {
        onSaved(repo.saveBook(book))
    }

    fun deleteBook(book: Book) = viewModelScope.launch { repo.deleteBook(book) }

    fun updateProgress(book: Book, newPage: Int) = viewModelScope.launch {
        repo.updateProgress(book, newPage)
    }

    fun setStatus(book: Book, status: ReadingStatus) = viewModelScope.launch {
        repo.setStatus(book, status)
    }

    fun addQuote(quote: Quote, onDone: () -> Unit = {}) = viewModelScope.launch {
        repo.addQuote(quote)
        onDone()
    }

    fun updateQuote(quote: Quote) = viewModelScope.launch { repo.updateQuote(quote) }
    fun deleteQuote(quote: Quote) = viewModelScope.launch { repo.deleteQuote(quote) }

    // ---- OCR ----

    fun newPhotoFile() = ImageUtils.newPhotoFile(getApplication())

    fun resetScan() { _scanState.value = ScanState.Idle }

    fun recognize(photoPath: String) = viewModelScope.launch {
        if (!ocr.isReady()) {
            _scanState.value = ScanState.Preparing("Подготовка распознавания…")
            val prep = ocr.ensureLanguages { msg -> _scanState.value = ScanState.Preparing(msg) }
            if (prep.isFailure) {
                _scanState.value = ScanState.Error(
                    "Не удалось загрузить языковые данные. Проверьте интернет и попробуйте снова."
                )
                return@launch
            }
        }
        _scanState.value = ScanState.Recognizing
        val bitmap = ImageUtils.decodeForOcr(photoPath)
        if (bitmap == null) {
            _scanState.value = ScanState.Error("Не удалось открыть фото.")
            return@launch
        }
        val result = ocr.recognize(bitmap)
        _scanState.value = result.fold(
            onSuccess = { text ->
                if (text.isBlank()) {
                    ScanState.Error("Текст не распознан. Попробуйте сфотографировать чётче.")
                } else {
                    ScanState.Result(normalize(text), photoPath)
                }
            },
            onFailure = { ScanState.Error(it.message ?: "Ошибка распознавания") }
        )
    }

    private fun normalize(raw: String): String =
        raw.replace("\r", "")
            .split("\n")
            .joinToString("\n") { it.trim() }
            .replace(Regex("\n{3,}"), "\n\n")
            .trim()

    private fun buildStats(
        books: List<Book>,
        logs: List<ReadingLog>,
        quoteCount: Int,
        impressionCount: Int
    ): DashboardStats {
        val today = LocalDate.now()
        val todayEpoch = today.toEpochDay()

        val pagesByDay = logs.groupBy { it.dateEpochDay }
            .mapValues { (_, list) -> list.sumOf { it.pages } }
        val last14 = (13 downTo 0).map { offset ->
            val date = today.minusDays(offset.toLong())
            DayPages(date, pagesByDay[date.toEpochDay()] ?: 0)
        }
        // A longer daily breakdown for detailed page-per-day tracking (newest first, only active days).
        val recentDays = pagesByDay.entries
            .filter { it.value > 0 }
            .sortedByDescending { it.key }
            .take(30)
            .map { DayPages(LocalDate.ofEpochDay(it.key), it.value) }

        val totalPagesRead = logs.sumOf { it.pages }
        val activeDays = pagesByDay.count { it.value > 0 }
        val pagesToday = pagesByDay[todayEpoch] ?: 0
        val pagesThisWeek = (0 until 7).sumOf { pagesByDay[todayEpoch - it] ?: 0 }
        val pagesThisMonth = (0 until 30).sumOf { pagesByDay[todayEpoch - it] ?: 0 }
        val avgPerActiveDay = if (activeDays > 0) totalPagesRead / activeDays else 0
        val bestDay = pagesByDay.filter { it.value > 0 }.maxByOrNull { it.value }
            ?.let { DayPages(LocalDate.ofEpochDay(it.key), it.value) }

        val finishedBooks = books.filter { it.status == ReadingStatus.FINISHED && it.finishedAt != null }
        val byMonth = (5 downTo 0).map { offset ->
            val ym = YearMonth.from(today).minusMonths(offset.toLong())
            val count = finishedBooks.count { b ->
                val d = java.time.Instant.ofEpochMilli(b.finishedAt!!)
                    .atZone(java.time.ZoneId.systemDefault()).toLocalDate()
                YearMonth.from(d) == ym
            }
            MonthCount(ym.month.getDisplayName(TextStyle.SHORT, Locale("ru")), count)
        }

        val ratingDist = MutableList(5) { 0 }
        books.filter { it.rating in 1..5 }.forEach { ratingDist[it.rating - 1]++ }

        val activeDaySet = pagesByDay.filter { it.value > 0 }.keys

        return DashboardStats(
            totalBooks = books.size,
            reading = books.count { it.status == ReadingStatus.READING },
            finished = books.count { it.status == ReadingStatus.FINISHED },
            wantToRead = books.count { it.status == ReadingStatus.WANT_TO_READ },
            totalQuotes = quoteCount,
            totalImpressions = impressionCount,
            currentStreak = computeStreak(activeDaySet),
            longestStreak = computeLongestStreak(activeDaySet),
            totalPagesRead = totalPagesRead,
            pagesToday = pagesToday,
            pagesThisWeek = pagesThisWeek,
            pagesThisMonth = pagesThisMonth,
            avgPagesPerActiveDay = avgPerActiveDay,
            activeDays = activeDays,
            bestDay = bestDay,
            pagesLast14Days = last14,
            recentDays = recentDays,
            finishedByMonth = byMonth,
            ratingDistribution = ratingDist
        )
    }

    private fun computeLongestStreak(daysWithReading: Set<Long>): Int {
        if (daysWithReading.isEmpty()) return 0
        val sorted = daysWithReading.sorted()
        var best = 1
        var run = 1
        for (i in 1 until sorted.size) {
            run = if (sorted[i] == sorted[i - 1] + 1) run + 1 else 1
            if (run > best) best = run
        }
        return best
    }

    private fun computeStreak(daysWithReading: Set<Long>): Int {
        if (daysWithReading.isEmpty()) return 0
        val today = LocalDate.now().toEpochDay()
        // Streak counts back from today or yesterday so a not-yet-read today doesn't break it.
        var cursor = when {
            daysWithReading.contains(today) -> today
            daysWithReading.contains(today - 1) -> today - 1
            else -> return 0
        }
        var streak = 0
        while (daysWithReading.contains(cursor)) {
            streak++
            cursor--
        }
        return streak
    }
}
