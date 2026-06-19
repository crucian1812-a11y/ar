package com.example.booktracker.ui.screens

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
import androidx.compose.material3.Card
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.example.booktracker.ui.MainViewModel
import com.example.booktracker.ui.components.BarChart
import com.example.booktracker.ui.components.StatCard

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DashboardScreen(vm: MainViewModel) {
    val stats by vm.dashboard.collectAsStateWithLifecycle()

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

            SectionCard("Страниц за 14 дней") {
                BarChart(
                    bars = stats.pagesLast14Days.map { it.date.dayOfMonth.toString() to it.pages },
                    modifier = Modifier.fillMaxWidth()
                )
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
            Spacer(Modifier.height(8.dp))
        }
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
