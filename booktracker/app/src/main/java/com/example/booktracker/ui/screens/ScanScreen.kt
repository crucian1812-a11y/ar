package com.example.booktracker.ui.screens

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.PhotoLibrary
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.core.content.FileProvider
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.example.booktracker.data.Quote
import com.example.booktracker.ui.MainViewModel
import com.example.booktracker.ui.ScanState
import java.io.File

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ScanScreen(
    vm: MainViewModel,
    bookId: Long,
    onDone: () -> Unit
) {
    val context = LocalContext.current
    val books by vm.books.collectAsStateWithLifecycle()
    val scanState by vm.scanState.collectAsStateWithLifecycle()

    var selectedBookId by remember { mutableStateOf(bookId) }
    var pendingPhoto by remember { mutableStateOf<File?>(null) }

    LaunchedEffect(Unit) { vm.resetScan() }

    val takePicture = rememberLauncherForActivityResult(
        ActivityResultContracts.TakePicture()
    ) { success ->
        val file = pendingPhoto
        if (success && file != null) vm.recognize(file.absolutePath)
    }

    val pickImage = rememberLauncherForActivityResult(
        ActivityResultContracts.GetContent()
    ) { uri: Uri? ->
        if (uri != null) {
            val dest = vm.newPhotoFile()
            runCatching {
                context.contentResolver.openInputStream(uri)?.use { input ->
                    dest.outputStream().use { output -> input.copyTo(output) }
                }
            }
            if (dest.exists()) vm.recognize(dest.absolutePath)
        }
    }

    fun launchCamera() {
        val file = vm.newPhotoFile()
        pendingPhoto = file
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
        takePicture.launch(uri)
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Новая цитата") },
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
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            if (selectedBookId <= 0L) {
                BookSelector(
                    books = books.map { it.id to it.title },
                    selectedId = selectedBookId,
                    onSelect = { selectedBookId = it }
                )
            }

            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                Button(onClick = { launchCamera() }, modifier = Modifier.weight(1f)) {
                    Icon(Icons.Filled.CameraAlt, contentDescription = null)
                    Spacer(Modifier.height(0.dp)); Text("  Камера")
                }
                OutlinedButton(onClick = { pickImage.launch("image/*") }, modifier = Modifier.weight(1f)) {
                    Icon(Icons.Filled.PhotoLibrary, contentDescription = null)
                    Text("  Галерея")
                }
            }

            when (val s = scanState) {
                is ScanState.Idle -> {
                    Text(
                        "Сфотографируйте страницу книги — текст будет распознан (русский и английский) и сохранён как цитата.",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                is ScanState.Preparing -> StatusBlock(s.message)
                is ScanState.Recognizing -> StatusBlock("Распознавание текста…")
                is ScanState.Error -> {
                    Text(s.message, color = MaterialTheme.colorScheme.error)
                }
                is ScanState.Result -> {
                    QuoteEditor(
                        initialText = s.text,
                        photoPath = s.photoPath,
                        canSave = selectedBookId > 0L,
                        onSave = { text, page ->
                            vm.addQuote(
                                Quote(
                                    bookId = selectedBookId,
                                    text = text,
                                    page = page,
                                    photoPath = s.photoPath
                                )
                            ) { onDone() }
                        }
                    )
                }
            }
        }
    }
}

@Composable
private fun StatusBlock(message: String) {
    Row(verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        CircularProgressIndicator()
        Text(message)
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun BookSelector(
    books: List<Pair<Long, String>>,
    selectedId: Long,
    onSelect: (Long) -> Unit
) {
    var expanded by remember { mutableStateOf(false) }
    val selectedTitle = books.firstOrNull { it.first == selectedId }?.second ?: "Выберите книгу"

    ExposedDropdownMenuBox(expanded = expanded, onExpandedChange = { expanded = it }) {
        OutlinedTextField(
            value = selectedTitle,
            onValueChange = {},
            readOnly = true,
            label = { Text("Книга") },
            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
            modifier = Modifier.fillMaxWidth().menuAnchor()
        )
        androidx.compose.material3.ExposedDropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false }
        ) {
            books.forEach { (id, title) ->
                DropdownMenuItem(
                    text = { Text(title) },
                    onClick = { onSelect(id); expanded = false }
                )
            }
        }
    }
}

@Composable
private fun QuoteEditor(
    initialText: String,
    photoPath: String,
    canSave: Boolean,
    onSave: (String, Int?) -> Unit
) {
    var text by remember(initialText) { mutableStateOf(initialText) }
    var pageText by remember { mutableStateOf("") }

    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Text("Распознанный текст (можно отредактировать):",
            style = MaterialTheme.typography.labelLarge)
        TextField(
            value = text,
            onValueChange = { text = it },
            modifier = Modifier.fillMaxWidth().height(220.dp)
        )
        OutlinedTextField(
            value = pageText,
            onValueChange = { v -> pageText = v.filter { it.isDigit() } },
            label = { Text("Страница (необязательно)") },
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
            singleLine = true
        )
        Button(
            onClick = { onSave(text.trim(), pageText.toIntOrNull()) },
            enabled = canSave && text.isNotBlank(),
            modifier = Modifier.fillMaxWidth()
        ) {
            Text(if (canSave) "Сохранить цитату" else "Сначала выберите книгу")
        }
    }
}
