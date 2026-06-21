package com.example.booktracker.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil.compose.AsyncImage
import com.example.booktracker.data.Book
import com.example.booktracker.data.progress
import com.example.booktracker.ui.MainViewModel
import com.example.booktracker.ui.components.ProgressBarLine
import com.example.booktracker.ui.components.RatingStars
import java.io.File

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LibraryScreen(
    vm: MainViewModel,
    onOpenBook: (Long) -> Unit,
    onAddBook: () -> Unit
) {
    val books by vm.books.collectAsStateWithLifecycle()

    Scaffold(
        topBar = { TopAppBar(title = { Text("Моя библиотека") }) },
        floatingActionButton = {
            FloatingActionButton(onClick = onAddBook) {
                Icon(Icons.Filled.Add, contentDescription = "Добавить книгу")
            }
        }
    ) { padding ->
        if (books.isEmpty()) {
            Box(
                Modifier.fillMaxSize().padding(padding).padding(32.dp),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    "Пока нет книг.\nНажмите + чтобы добавить первую.",
                    style = MaterialTheme.typography.bodyLarge
                )
            }
        } else {
            LazyColumn(
                modifier = Modifier.fillMaxSize().padding(padding),
                contentPadding = androidx.compose.foundation.layout.PaddingValues(12.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                items(books, key = { it.id }) { book ->
                    BookRow(book, onClick = { onOpenBook(book.id) })
                }
            }
        }
    }
}

@Composable
private fun BookRow(book: Book, onClick: () -> Unit) {
    Card(
        Modifier.fillMaxWidth().clickable(onClick = onClick)
    ) {
        Row(Modifier.padding(12.dp)) {
            BookCover(book, width = 56, height = 80)
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                Text(
                    book.title,
                    fontWeight = FontWeight.SemiBold,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                    style = MaterialTheme.typography.titleMedium
                )
                if (book.author.isNotBlank()) {
                    Text(
                        book.author,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                Spacer(Modifier.height(6.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    StatusChip(book)
                    if (book.rating > 0) {
                        Spacer(Modifier.width(8.dp))
                        RatingStars(book.rating, starSize = 14)
                    }
                }
                if (book.totalPages > 0) {
                    Spacer(Modifier.height(8.dp))
                    ProgressBarLine(book.progress, Modifier.fillMaxWidth())
                    Text(
                        "${book.currentPage} / ${book.totalPages} стр.",
                        fontSize = 11.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(top = 2.dp)
                    )
                }
            }
        }
    }
}

@Composable
fun StatusChip(book: Book) {
    val color = MaterialTheme.colorScheme.secondaryContainer
    Box(
        Modifier
            .background(color)
            .padding(horizontal = 10.dp, vertical = 4.dp)
    ) {
        Text(book.status.label, fontSize = 11.sp, color = MaterialTheme.colorScheme.onSecondaryContainer)
    }
}

@Composable
fun BookCover(book: Book, width: Int, height: Int) {
    val shape = RectangleShape
    if (book.coverPath != null) {
        AsyncImage(
            model = File(book.coverPath),
            contentDescription = book.title,
            modifier = Modifier.size(width.dp, height.dp).clip(shape)
        )
    } else {
        Box(
            Modifier
                .size(width.dp, height.dp)
                .clip(shape)
                .background(MaterialTheme.colorScheme.primaryContainer),
            contentAlignment = Alignment.Center
        ) {
            Text(
                book.title.firstOrNull()?.uppercase() ?: "?",
                fontSize = 24.sp,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onPrimaryContainer
            )
        }
    }
}
