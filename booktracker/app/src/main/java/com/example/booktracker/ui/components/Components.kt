package com.example.booktracker.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.outlined.StarBorder
import androidx.compose.material3.Card
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
fun StatCard(
    value: String,
    label: String,
    modifier: Modifier = Modifier,
    container: Color = MaterialTheme.colorScheme.primaryContainer
) {
    Card(modifier = modifier) {
        Column(Modifier.background(container).fillMaxWidth().padding(16.dp)) {
            Text(value, fontSize = 28.sp, fontWeight = FontWeight.Bold)
            Text(label, style = MaterialTheme.typography.labelMedium)
        }
    }
}

/** Simple vertical bar chart. [bars] = label to value. */
@Composable
fun BarChart(
    bars: List<Pair<String, Int>>,
    modifier: Modifier = Modifier,
    barColor: Color = MaterialTheme.colorScheme.primary
) {
    val max = (bars.maxOfOrNull { it.second } ?: 0).coerceAtLeast(1)
    Row(
        modifier = modifier.height(140.dp),
        verticalAlignment = Alignment.Bottom,
        horizontalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        bars.forEach { (label, value) ->
            Column(
                modifier = Modifier.weight(1f),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Bottom
            ) {
                if (value > 0) {
                    Text(value.toString(), fontSize = 10.sp)
                }
                val fraction = value.toFloat() / max
                Box(
                    Modifier
                        .padding(top = 2.dp)
                        .fillMaxWidth()
                        .height((4 + 96 * fraction).dp)
                        .clip(RoundedCornerShape(topStart = 4.dp, topEnd = 4.dp))
                        .background(if (value > 0) barColor else barColor.copy(alpha = 0.18f))
                )
                Spacer(Modifier.height(4.dp))
                Text(label, fontSize = 9.sp, maxLines = 1)
            }
        }
    }
}

@Composable
fun RatingStars(
    rating: Int,
    modifier: Modifier = Modifier,
    starSize: Int = 24,
    onRatingChange: ((Int) -> Unit)? = null
) {
    Row(modifier) {
        (1..5).forEach { i ->
            val filled = i <= rating
            Icon(
                imageVector = if (filled) Icons.Filled.Star else Icons.Outlined.StarBorder,
                contentDescription = "Оценка $i",
                tint = if (filled) Color(0xFFFFC107) else MaterialTheme.colorScheme.outline,
                modifier = Modifier
                    .size(starSize.dp)
                    .then(
                        if (onRatingChange != null) {
                            Modifier.clickable { onRatingChange(if (rating == i) 0 else i) }
                        } else Modifier
                    )
            )
        }
    }
}

@Composable
fun ProgressBarLine(progress: Float, modifier: Modifier = Modifier) {
    Box(
        modifier
            .clip(RoundedCornerShape(50))
            .background(MaterialTheme.colorScheme.surfaceVariant)
            .height(8.dp)
    ) {
        Box(
            Modifier
                .fillMaxWidth(progress.coerceIn(0f, 1f))
                .height(8.dp)
                .clip(RoundedCornerShape(50))
                .background(MaterialTheme.colorScheme.primary)
        )
    }
}
