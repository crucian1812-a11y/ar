package com.example.booktracker.ui

import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.FormatQuote
import androidx.compose.material.icons.automirrored.filled.MenuBook
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.NavType
import androidx.navigation.navArgument
import com.example.booktracker.ui.screens.AddEditBookScreen
import com.example.booktracker.ui.screens.BookDetailScreen
import com.example.booktracker.ui.screens.DashboardScreen
import com.example.booktracker.ui.screens.LibraryScreen
import com.example.booktracker.ui.screens.QuotesScreen
import com.example.booktracker.ui.screens.ScanScreen

private data class TopTab(val route: String, val label: String, val icon: ImageVector)

private val tabs = listOf(
    TopTab("library", "Книги", Icons.AutoMirrored.Filled.MenuBook),
    TopTab("dashboard", "Дашборд", Icons.Filled.BarChart),
    TopTab("quotes", "Цитаты", Icons.Filled.FormatQuote)
)

@Composable
fun AppRoot() {
    val nav = rememberNavController()
    val vm: MainViewModel = viewModel()

    val backStack by nav.currentBackStackEntryAsState()
    val currentRoute = backStack?.destination?.route
    val showBottomBar = currentRoute in tabs.map { it.route }

    Scaffold(
        bottomBar = {
            if (showBottomBar) {
                NavigationBar {
                    val dest = backStack?.destination
                    tabs.forEach { tab ->
                        val selected = dest?.hierarchy?.any { it.route == tab.route } == true
                        NavigationBarItem(
                            selected = selected,
                            onClick = {
                                nav.navigate(tab.route) {
                                    popUpTo(nav.graph.findStartDestination().id) { saveState = true }
                                    launchSingleTop = true
                                    restoreState = true
                                }
                            },
                            icon = { Icon(tab.icon, contentDescription = tab.label) },
                            label = { Text(tab.label) }
                        )
                    }
                }
            }
        }
    ) { padding ->
        NavHost(
            navController = nav,
            startDestination = "library",
            modifier = Modifier.padding(padding)
        ) {
            composable("library") {
                LibraryScreen(
                    vm = vm,
                    onOpenBook = { id -> nav.navigate("book/$id") },
                    onAddBook = { nav.navigate("edit?bookId=-1") }
                )
            }
            composable("dashboard") { DashboardScreen(vm) }
            composable("quotes") {
                QuotesScreen(vm = vm, onOpenBook = { id -> nav.navigate("book/$id") })
            }
            composable(
                route = "book/{bookId}",
                arguments = listOf(navArgument("bookId") { type = NavType.LongType })
            ) { entry ->
                val bookId = entry.arguments?.getLong("bookId") ?: -1L
                BookDetailScreen(
                    vm = vm,
                    bookId = bookId,
                    onBack = { nav.popBackStack() },
                    onEdit = { nav.navigate("edit?bookId=$bookId") },
                    onScan = { nav.navigate("scan?bookId=$bookId") }
                )
            }
            composable(
                route = "edit?bookId={bookId}",
                arguments = listOf(navArgument("bookId") { type = NavType.LongType; defaultValue = -1L })
            ) { entry ->
                val bookId = entry.arguments?.getLong("bookId") ?: -1L
                AddEditBookScreen(
                    vm = vm,
                    bookId = bookId,
                    onDone = { nav.popBackStack() }
                )
            }
            composable(
                route = "scan?bookId={bookId}",
                arguments = listOf(navArgument("bookId") { type = NavType.LongType; defaultValue = -1L })
            ) { entry ->
                val bookId = entry.arguments?.getLong("bookId") ?: -1L
                ScanScreen(
                    vm = vm,
                    bookId = bookId,
                    onDone = { nav.popBackStack() }
                )
            }
        }
    }
}
