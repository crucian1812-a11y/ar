package com.example.booktracker.ui.screens

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.example.booktracker.ui.BackupState
import com.example.booktracker.ui.MainViewModel
import com.example.booktracker.ui.components.BarChart
import com.example.booktracker.ui.components.StatCard

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DashboardScreen(vm: MainViewModel) {
    val stats by vm.dashboard.collectAsStateWithLifecycle()
    val backup by vm.backup.collectAsStateWithLifecycle()

    LaunchedEffect(Unit) { vm.resetBackup() }

    val exportLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.CreateDocument("application/json")
    ) { uri -> if (uri != null) vm.exportBackup(uri) }
    val importLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenDocument()
    ) { uri -> if (uri != null) vm.importBackup(uri) }

    Scaffold(topBar = { TopAppBar(title = { Text("Дашборд") }) }) { padding ->
        Column(
            Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(12.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                StatCard("${stats.finished}", "Прочитано", Modifier.weight(1f))
                StatCard("${stats.reading}", "Читаю сейчас", Modifier.weight(1f),
                    MaterialTheme.colorScheme.secondaryContainer)
            }
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                StatCard("${stats.totalQuotes}", "Цитат", Modifier.weight(1f),
                    MaterialTheme.colorScheme.tertiaryContainer)
                StatCard("${stats.currentStreak} дн.", "Серия чтения", Modifier.weight(1f),
                    MaterialTheme.colorScheme.surfaceVariant)
            }

            SectionCard("Статистика чтения") {
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    StatCard("${stats.pagesToday}", "Сегодня", Modifier.weight(1f),
                        MaterialTheme.colorScheme.primaryContainer)
                    StatCard("${stats.pagesThisWeek}", "За неделю", Modifier.weight(1f),
                        MaterialTheme.colorScheme.secondaryContainer)
                    StatCard("${stats.pagesThisMonth}", "За месяц", Modifier.weight(1f),
                        MaterialTheme.colorScheme.tertiaryContainer)
                }
                Spacer(Modifier.height(12.dp))
                StatLine("Всего прочитано страниц", "${stats.totalPagesRead}")
                StatLine("В среднем за активный день", "${stats.avgPagesPerActiveDay} стр.")
                StatLine("Дней с чтением", "${stats.activeDays}")
                StatLine("Лучший день", stats.bestDay?.let {
                    "${it.pages} стр. · ${it.date.dayOfMonth}.${it.date.monthValue}"
                } ?: "—")
                StatLine("Самая длинная серия", "${stats.longestStreak} дн.")
                StatLine("Заметок и впечатлений", "${stats.totalImpressions}")
            }

            SectionCard("Страниц за 14 дней") {
                BarChart(
                    bars = stats.pagesLast14Days.map { it.date.dayOfMonth.toString() to it.pages },
                    modifier = Modifier.fillMaxWidth()
                )
            }

            if (stats.recentDays.isNotEmpty()) {
                SectionCard("Страницы по дням") {
                    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        stats.recentDays.forEach { day ->
                            StatLine(
                                "${day.date.dayOfMonth}.${day.date.monthValue}.${day.date.year}",
                                "${day.pages} стр."
                            )
                        }
                    }
                }
            }

            SectionCard("Прочитано книг по месяцам") {
                BarChart(
                    bars = stats.finishedByMonth.map { it.label to it.count },
                    modifier = Modifier.fillMaxWidth(),
                    barColor = MaterialTheme.colorScheme.secondary
                )
            }

            SectionCard("Распределение оценок") {
                BarChart(
                    bars = stats.ratingDistribution.mapIndexed { i, c -> "${i + 1}★" to c },
                    modifier = Modifier.fillMaxWidth(),
                    barColor = MaterialTheme.colorScheme.tertiary
                )
            }

            Card(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(16.dp)) {
                    Text("Всего книг: ${stats.totalBooks}", fontWeight = FontWeight.Medium)
                    Text("В планах: ${stats.wantToRead}",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }

            SectionCard("Резервная копия") {
                Text(
                    "Сохрани все книги, цитаты и заметки в файл JSON — на случай " +
                        "переустановки или обновления. Файл можно восстановить обратно.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Spacer(Modifier.height(12.dp))
                val working = backup is BackupState.Working
                Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                    Button(
                        onClick = { exportLauncher.launch(vm.suggestedBackupName()) },
                        enabled = !working,
                        modifier = Modifier.weight(1f)
                    ) { Text("Экспорт") }
                    OutlinedButton(
                        onClick = { importLauncher.launch(arrayOf("application/json", "text/*", "*/*")) },
                        enabled = !working,
                        modifier = Modifier.weight(1f)
                    ) { Text("Импорт") }
                }
                when (val st = backup) {
                    is BackupState.Working -> {
                        Spacer(Modifier.height(8.dp))
                        Text("Обработка…", style = MaterialTheme.typography.bodySmall)
                    }
                    is BackupState.Done -> {
                        Spacer(Modifier.height(8.dp))
                        Text(st.message, style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.primary)
                    }
                    is BackupState.Error -> {
                        Spacer(Modifier.height(8.dp))
                        Text(st.message, style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.error)
                    }
                    else -> {}
                }
            }
            Spacer(Modifier.height(8.dp))
        }
    }
}

@Composable
private fun StatLine(label: String, value: String) {
    Row(
        Modifier.fillMaxWidth().padding(vertical = 2.dp),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(label, style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(value, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.SemiBold)
    }
}

@Composable
private fun SectionCard(title: String, content: @Composable () -> Unit) {
    Card(Modifier.fillMaxWidth()) {
        Column(Modifier.padding(16.dp)) {
            Text(title, fontWeight = FontWeight.SemiBold, style = MaterialTheme.typography.titleMedium)
            Spacer(Modifier.height(12.dp))
            content()
        }
    }
}
