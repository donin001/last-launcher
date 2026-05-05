# Reflective lookup in MainActivity for the hidden quick-settings expansion API.
# Without this rule a future R8/proguard pass — combined with hypothetical name
# changes — could mask the method even though the system class itself is not
# obfuscated by R8.
-keepclassmembers class android.app.StatusBarManager {
    void expandNotificationsPanel();
}
