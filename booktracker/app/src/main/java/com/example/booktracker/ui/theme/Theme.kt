package com.example.booktracker.ui.theme

import android.app.Activity
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Shapes
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.view.WindowCompat

// --- Calm Suprematist palette ---
private val Terracotta = Color(0xFFB07566)
private val DustyBlue = Color(0xFF5E7E92)
private val Ochre = Color(0xFFCBA85C)
private val Charcoal = Color(0xFF3A3A38)
private val Cream = Color(0xFFF4F1E8)
private val SandVariant = Color(0xFFE4DFD3)

private val LightColors = lightColorScheme(
    primary = Terracotta,
    onPrimary = Color(0xFFFFFFFF),
    primaryContainer = Color(0xFFDDB9AE),
    onPrimaryContainer = Color(0xFF3A241D),

    secondary = DustyBlue,
    onSecondary = Color(0xFFFFFFFF),
    secondaryContainer = Color(0xFFC6D3DB),
    onSecondaryContainer = Color(0xFF1E2C34),

    tertiary = Ochre,
    onTertiary = Charcoal,
    tertiaryContainer = Color(0xFFE7D6AB),
    onTertiaryContainer = Color(0xFF3A3320),

    background = Cream,
    onBackground = Charcoal,
    surface = Cream,
    onSurface = Charcoal,
    surfaceVariant = SandVariant,
    onSurfaceVariant = Color(0xFF5C584E),
    outline = Color(0xFF8A8578),

    error = Color(0xFF9C4A3C),
    onError = Color(0xFFFFFFFF)
)

private val DarkColors = darkColorScheme(
    primary = Color(0xFFC98B7C),
    onPrimary = Color(0xFF2A1A14),
    primaryContainer = Color(0xFF6E4A3F),
    onPrimaryContainer = Color(0xFFEFD7CF),

    secondary = Color(0xFF8FAAB9),
    onSecondary = Color(0xFF14242C),
    secondaryContainer = Color(0xFF3E5563),
    onSecondaryContainer = Color(0xFFD4E2EA),

    tertiary = Color(0xFFD9BC76),
    onTertiary = Color(0xFF2C2410),
    tertiaryContainer = Color(0xFF5A4D2C),
    onTertiaryContainer = Color(0xFFF0E2BC),

    background = Color(0xFF26251F),
    onBackground = Color(0xFFEDE8DC),
    surface = Color(0xFF26251F),
    onSurface = Color(0xFFEDE8DC),
    surfaceVariant = Color(0xFF433F36),
    onSurfaceVariant = Color(0xFFCBC5B6),
    outline = Color(0xFF938D7E),

    error = Color(0xFFE39286),
    onError = Color(0xFF2A1410)
)

// Suprematist look: sharp, blocky corners everywhere.
private val AppShapes = Shapes(
    extraSmall = RoundedCornerShape(0.dp),
    small = RoundedCornerShape(0.dp),
    medium = RoundedCornerShape(0.dp),
    large = RoundedCornerShape(0.dp),
    extraLarge = RoundedCornerShape(0.dp)
)

private val base = Typography()
val AppTypography = base.copy(
    titleLarge = base.titleLarge.copy(fontWeight = FontWeight.ExtraBold, letterSpacing = 0.5.sp),
    titleMedium = base.titleMedium.copy(fontWeight = FontWeight.Bold),
    labelLarge = base.labelLarge.copy(fontWeight = FontWeight.Bold, letterSpacing = 0.5.sp),
    headlineSmall = base.headlineSmall.copy(fontWeight = FontWeight.ExtraBold)
)

@Composable
fun BookTrackerTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    val colors = if (darkTheme) DarkColors else LightColors

    val view = LocalView.current
    if (!view.isInEditMode) {
        SideEffect {
            val window = (view.context as Activity).window
            window.statusBarColor = colors.primary.toArgb()
            WindowCompat.getInsetsController(window, view).isAppearanceLightStatusBars = false
        }
    }

    MaterialTheme(
        colorScheme = colors,
        typography = AppTypography,
        shapes = AppShapes,
        content = content
    )
}
