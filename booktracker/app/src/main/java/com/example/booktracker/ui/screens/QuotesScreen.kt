package com.example.booktracker.ui.screens

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil.compose.AsyncImage
import com.example.booktracker.data.Quote
import com.example.booktracker.ui.MainViewModel
import java.io.File

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun QuotesScreen(vm: MainViewModel, onOpenBook: (Long) -> Unit) {
    val quotes by vm.quotes.collectAsStateWithLifecycle()
    val books by vm.books.collectAsStateWithLifecycle()
    val titles = books.associate { it.id to it.title }

    Scaffold(topBar = { TopAppBar(title = { Text("Цитаты") }) }) { padding ->
        if (quotes.isEmpty()) {
            Box(Modifier.fillMaxSize().padding(padding).padding(32.dp), Alignment.Center) {
                Text(
                    "Цитат пока нет.\nОткройте книгу и сфотографируйте страницу — текст распознается автоматически.",
                    style = MaterialTheme.typography.bodyLarge
                )
            }
        } else {
            LazyColumn(
                Modifier.fillMaxSize().padding(padding),
                contentPadding = androidx.compose.foundation.layout.PaddingValues(12.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                items(quotes, key = { it.id }) { quote ->
                    QuoteCard(
                        quote = quote,
                        bookTitle = titles[quote.bookId] ?: "",
                        onOpenBook = { onOpenBook(quote.bookId) },
                        onDelete = { vm.deleteQuote(quote) }
                    )
                }
            }
        }
    }
}

@Composable
fun QuoteCard(
    quote: Quote,
    bookTitle: String,
    onOpenBook: () -> Unit,
    onDelete: () -> Unit
) {
    Card(Modifier.fillMaxWidth().clickable(onClick = onOpenBook)) {
        Row(Modifier.padding(12.dp)) {
            if (quote.photoPath != null) {
                AsyncImage(
                    model = File(quote.photoPath),
                    contentDescription = null,
                    modifier = Modifier.size(56.dp).clip(RoundedCornerShape(6.dp))
                )
                Spacer(Modifier.width(12.dp))
            }
            Column(Modifier.weight(1f)) {
                Text(
                    "«${quote.text}»",
                    style = MaterialTheme.typography.bodyMedium,
                    fontStyle = FontStyle.Italic
                )
                Spacer(Modifier.size(4.dp))
                val meta = buildString {
                    if (bookTitle.isNotBlank()) append(bookTitle)
                    if (quote.page != null) append("  · стр. ${quote.page}")
                }
                if (meta.isNotBlank()) {
                    Text(
                        meta,
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
            IconButton(onClick = onDelete) {
                Icon(Icons.Filled.Delete, contentDescription = "Удалить", tint = MaterialTheme.colorScheme.error)
            }
        }
    }
}
