package com.example.booktracker.ui.screens

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.AddAPhoto
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.RectangleShape
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import coil.compose.AsyncImage
import com.example.booktracker.data.Book
import com.example.booktracker.data.ReadingStatus
import com.example.booktracker.ui.MainViewModel
import com.example.booktracker.ui.components.RatingStars
import com.example.booktracker.util.ImageUtils
import java.io.File

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddEditBookScreen(
    vm: MainViewModel,
    bookId: Long,
    onDone: () -> Unit
) {
    val context = LocalContext.current
    val isNew = bookId <= 0L
    val existingFlow = remember(bookId) {
        if (isNew) kotlinx.coroutines.flow.flowOf<Book?>(null) else vm.book(bookId)
    }
    val existing by existingFlow.collectAsStateWithLifecycle(initialValue = null)

    var loaded by remember { mutableStateOf(false) }
    var title by remember { mutableStateOf("") }
    var author by remember { mutableStateOf("") }
    var totalPages by remember { mutableStateOf("") }
    var status by remember { mutableStateOf(ReadingStatus.WANT_TO_READ) }
    var rating by remember { mutableStateOf(0) }
    var notes by remember { mutableStateOf("") }
    var coverPath by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(existing) {
        val b = existing
        if (b != null && !loaded) {
            title = b.title
            author = b.author
            totalPages = if (b.totalPages > 0) b.totalPages.toString() else ""
            status = b.status
            rating = b.rating
            notes = b.notes
            coverPath = b.coverPath
            loaded = true
        }
    }

    val pickCover = rememberLauncherForActivityResult(
        ActivityResultContracts.GetContent()
    ) { uri: Uri? ->
        if (uri != null) {
            val dest = ImageUtils.newPhotoFile(context).let { File(it.parentFile, "cover_${System.currentTimeMillis()}.jpg") }
            runCatching {
                context.contentResolver.openInputStream(uri)?.use { input ->
                    dest.outputStream().use { output -> input.copyTo(output) }
                }
            }
            if (dest.exists()) coverPath = dest.absolutePath
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(if (isNew) "Новая книга" else "Редактировать") },
                navigationIcon = {
                    IconButton(onClick = onDone) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Назад")
                    }
                }
            )
        }
    ) { padding ->
        Column(
            Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Row {
                Card {
                    Box(
                        Modifier
                            .size(90.dp, 130.dp)
                            .clickable { pickCover.launch("image/*") },
                        contentAlignment = Alignment.Center
                    ) {
                        if (coverPath != null) {
                            AsyncImage(
                                model = File(coverPath!!),
                                contentDescription = "Обложка",
                                modifier = Modifier.size(90.dp, 130.dp).clip(RectangleShape)
                            )
                        } else {
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                Icon(Icons.Filled.AddAPhoto, contentDescription = null)
                                Text("Обложка", style = MaterialTheme.typography.labelSmall)
                            }
                        }
                    }
                }
                Spacer(Modifier.width(16.dp))
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                    OutlinedTextField(
                        value = title, onValueChange = { title = it },
                        label = { Text("Название") }, modifier = Modifier.fillMaxWidth(), singleLine = true
                    )
                    OutlinedTextField(
                        value = author, onValueChange = { author = it },
                        label = { Text("Автор") }, modifier = Modifier.fillMaxWidth(), singleLine = true
                    )
                }
            }

            OutlinedTextField(
                value = totalPages,
                onValueChange = { v -> totalPages = v.filter { it.isDigit() } },
                label = { Text("Всего страниц") },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                modifier = Modifier.fillMaxWidth(), singleLine = true
            )

            Text("Статус", style = MaterialTheme.typography.labelLarge)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                ReadingStatus.entries.forEach { s ->
                    FilterChip(
                        selected = status == s,
                        onClick = { status = s },
                        label = { Text(s.label, maxLines = 1) }
                    )
                }
            }

            Text("Оценка", style = MaterialTheme.typography.labelLarge)
            RatingStars(rating = rating, starSize = 32, onRatingChange = { rating = it })

            OutlinedTextField(
                value = notes, onValueChange = { notes = it },
                label = { Text("Заметки") },
                modifier = Modifier.fillMaxWidth().height(120.dp)
            )

            Button(
                onClick = {
                    if (title.isBlank()) return@Button
                    val base = existing ?: Book(title = title)
                    val updated = base.copy(
                        title = title.trim(),
                        author = author.trim(),
                        totalPages = totalPages.toIntOrNull() ?: 0,
                        status = status,
                        rating = rating,
                        notes = notes,
                        coverPath = coverPath
                    )
                    vm.saveBook(updated) { onDone() }
                },
                enabled = title.isNotBlank(),
                modifier = Modifier.fillMaxWidth()
            ) {
                Text("Сохранить")
            }
        }
    }
}
