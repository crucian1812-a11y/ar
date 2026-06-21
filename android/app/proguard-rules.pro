# Оставляем JS-интерфейсы WebView нетронутыми (на будущее)
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
