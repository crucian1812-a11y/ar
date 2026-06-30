package com.example.booktracker.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.OpenInNew
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.example.booktracker.data.ReadingStatus
import com.example.booktracker.data.progress
import com.example.booktracker.ui.MainViewModel
import com.example.booktracker.ui.components.ProgressBarLine
import com.example.booktracker.ui.components.RatingStars

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun BookDetailScreen(
    vm: MainViewModel,
    bookId: Long,
    onBack: () -> Unit,
    onEdit: () -> Unit,
    onScan: () -> Unit
) {
    val bookFlow = remember(bookId) { vm.book(bookId) }
    val quotesFlow = remember(bookId) { vm.quotesForBook(bookId) }
    val book by bookFlow.collectAsStateWithLifecycle(initialValue = null)
    val quotes by quotesFlow.collectAsStateWithLifecycle(initialValue = emptyList())
    val b = book

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(b?.title ?: "Книга", maxLines = 1) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Назад")
                    }
                },
                actions = {
                    IconButton(onClick = onEdit) { Icon(Icons.Filled.Edit, "Редактировать") }
                    if (b != null) {
                        IconButton(onClick = { vm.deleteBook(b); onBack() }) {
                            Icon(Icons.Filled.Delete, "Удалить", tint = MaterialTheme.colorScheme.error)
                        }
                    }
                }
            )
        },
        floatingActionButton = {
            ExtendedFloatingActionButton(
                onClick = onScan,
                icon = { Icon(Icons.Filled.CameraAlt, contentDescription = null) },
                text = { Text("Сфотографировать цитату") }
            )
        }
    ) { padding ->
        if (b == null) {
            Box(Modifier.fillMaxSize().padding(padding), Alignment.Center) { Text("Загрузка…") }
            return@Scaffold
        }

        LazyColumn(
            Modifier.fillMaxSize().padding(padding),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            item {
                Row {
                    BookCover(b, width = 96, height = 140)
                    Spacer(Modifier.width(16.dp))
                    Column {
                        Text(b.title, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                        if (b.author.isNotBlank()) {
                            Text(b.author, style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                        Spacer(Modifier.height(8.dp))
                        RatingStars(b.rating, starSize = 22,
                            onRatingChange = { vm.saveBook(b.copy(rating = it)) })
                    }
                }
            }

            item {
                Card(Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(16.dp)) {
                        Text("Статус", style = MaterialTheme.typography.labelLarge)
                        Spacer(Modifier.height(8.dp))
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            ReadingStatus.entries.forEach { s ->
                                FilterChip(
                                    selected = b.status == s,
                                    onClick = { vm.setStatus(b, s) },
                                    label = { Text(s.label, maxLines = 1) }
                                )
                            }
                        }
                    }
                }
            }

            item { ProgressEditor(vm, b) }

            if (b.description.isNotBlank()) {
                item {
                    Card(Modifier.fillMaxWidth()) {
                        Column(Modifier.padding(16.dp)) {
                            Text("Описание", style = MaterialTheme.typography.labelLarge)
                            Spacer(Modifier.height(8.dp))
                            Text(b.description, style = MaterialTheme.typography.bodyMedium)
                            if (b.categories.isNotBlank()) {
                                Spacer(Modifier.height(8.dp))
                                Text("Тема: ${b.categories}",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                        }
                    }
                }
            }

            item { MaterialsSection(b) }

            item {
                Text("Цитаты (${quotes.size})",
                    style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
            }

            if (quotes.isEmpty()) {
                item {
                    Text(
                        "Нажмите «Сфотографировать цитату», чтобы добавить первую — текст со страницы распознается автоматически.",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            } else {
                items(quotes, key = { it.id }) { quote ->
                    QuoteCard(
                        quote = quote,
                        bookTitle = "",
                        onOpenBook = {},
                        onDelete = { vm.deleteQuote(quote) }
                    )
                }
            }
            item { Spacer(Modifier.height(72.dp)) }
        }
    }
}

@OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
@Composable
private fun MaterialsSection(book: com.example.booktracker.data.Book) {
    val context = androidx.compose.ui.platform.LocalContext.current
    val materials = com.example.booktracker.data.BookInfoService
        .materialsFor(book.title, book.author, book.infoLink)
    Card(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp)) {
            Text("Материалы по теме", style = MaterialTheme.typography.labelLarge)
            Spacer(Modifier.height(4.dp))
            Text("Видео, подкасты и статьи о книге",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant)
            Spacer(Modifier.height(8.dp))
            androidx.compose.foundation.layout.FlowRow(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                materials.forEach { m ->
                    androidx.compose.material3.AssistChip(
                        onClick = {
                            runCatching {
                                context.startActivity(
                                    android.content.Intent(
                                        android.content.Intent.ACTION_VIEW,
                                        android.net.Uri.parse(m.url)
                                    )
                                )
                            }
                        },
                        label = { Text(m.label) },
                        leadingIcon = {
                            Icon(Icons.Filled.OpenInNew, contentDescription = null,
                                modifier = Modifier.size(18.dp))
                        }
                    )
                }
            }
        }
    }
}

@Composable
private fun ProgressEditor(vm: MainViewModel, book: com.example.booktracker.data.Book) {
    var pageText by remember(book.currentPage) { mutableStateOf(book.currentPage.toString()) }

    Card(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp)) {
            Text("Прогресс чтения", style = MaterialTheme.typography.labelLarge)
            Spacer(Modifier.height(8.dp))
            if (book.totalPages > 0) {
                ProgressBarLine(book.progress, Modifier.fillMaxWidth())
                Text(
                    "${book.currentPage} / ${book.totalPages} стр. · ${(book.progress * 100).toInt()}%",
                    style = MaterialTheme.typography.bodySmall,
                    modifier = Modifier.padding(top = 4.dp)
                )
            } else {
                Text("Текущая страница: ${book.currentPage}",
                    style = MaterialTheme.typography.bodySmall)
            }
            Spacer(Modifier.height(12.dp))
            Row(verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(
                    value = pageText,
                    onValueChange = { v -> pageText = v.filter { it.isDigit() } },
                    label = { Text("Стр.") },
                    keyboardOptions = KeyboardOptions(keyboardType = androidx.compose.ui.text.input.KeyboardType.Number),
                    singleLine = true,
                    modifier = Modifier.width(120.dp)
                )
                Button(onClick = {
                    vm.updateProgress(book, pageText.toIntOrNull() ?: book.currentPage)
                }) { Text("Обновить") }
                OutlinedButton(onClick = {
                    val next = book.currentPage + 10
                    pageText = next.toString()
                    vm.updateProgress(book, next)
                }) { Text("+10") }
            }
        }
    }
}
