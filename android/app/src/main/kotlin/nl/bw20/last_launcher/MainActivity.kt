package nl.bw20.last_launcher

import android.content.Intent
import android.content.pm.ResolveInfo
import android.graphics.Color
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.View
import android.view.WindowInsets
import android.view.WindowManager
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "nl.bw20.last_launcher/apps"
    private var methodChannel: MethodChannel? = null
    private var pendingOpenSettings = false
    private var fullscreenEnabled = false

    // ------------------------------------------------------------------
    // Lifecycle
    // ------------------------------------------------------------------

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Window theme already sets windowTranslucentStatus / windowTranslucentNavigation.
        // Combined with FLAG_LAYOUT_NO_LIMITS the window owns the bar regions visually,
        // so there is no transient reveal or contrast scrim when bars are hidden.
        @Suppress("DEPRECATION")
        window.addFlags(WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isStatusBarContrastEnforced = false
            window.isNavigationBarContrastEnforced = false
        }
        @Suppress("DEPRECATION")
        window.statusBarColor = Color.TRANSPARENT
        @Suppress("DEPRECATION")
        window.navigationBarColor = Color.TRANSPARENT
        // Re-hide system bars whenever they reappear (soft IME dismiss, OEM
        // overlays, etc). Predictive back is disabled at the manifest level
        // so the back gesture never reveals bars to begin with.
        ViewCompat.setOnApplyWindowInsetsListener(window.decorView) { v, insets ->
            if (fullscreenEnabled &&
                !isFinishing &&
                insets.isVisible(WindowInsetsCompat.Type.systemBars())
            ) {
                v.post { if (!isFinishing) applyFullscreen() }
            }
            insets
        }
    }

    override fun onResume() {
        super.onResume()
        applyFullscreen()
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) applyFullscreen()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (intent.action == Intent.ACTION_APPLICATION_PREFERENCES) {
            // Set a fallback flag in case Flutter's handler isn't attached yet;
            // clear it once Dart acknowledges the direct invoke.
            pendingOpenSettings = true
            methodChannel?.invokeMethod(
                "openSettings",
                null,
                object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        pendingOpenSettings = false
                    }
                    override fun error(code: String, msg: String?, details: Any?) {}
                    override fun notImplemented() {}
                },
            )
        }
    }

    // ------------------------------------------------------------------
    // Flutter MethodChannel
    // ------------------------------------------------------------------

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getInstalledApps" -> result.success(getInstalledApps())
                "launchApp" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        launchApp(packageName)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENT", "packageName is required", null)
                    }
                }
                "openAppInfo" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        try {
                            openAppInfo(packageName)
                            result.success(null)
                        } catch (e: Exception) {
                            result.error(
                                "OPEN_APP_INFO_FAILED",
                                e.message ?: "Unable to open app info",
                                null,
                            )
                        }
                    } else {
                        result.error("INVALID_ARGUMENT", "packageName is required", null)
                    }
                }
                "expandQuickSettings" -> {
                    expandQuickSettings()
                    result.success(null)
                }
                "consumePendingOpenSettings" -> {
                    val consumed = pendingOpenSettings
                    pendingOpenSettings = false
                    result.success(consumed)
                }
                "setFullscreen" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    setFullscreen(enabled)
                    result.success(null)
                }
                "lockScreen" -> {
                    val locked = LockAccessibilityService.instance?.lockScreen() ?: false
                    result.success(locked)
                }
                "openAccessibilitySettings" -> {
                    if (LockAccessibilityService.instance == null) {
                        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)
                        startActivity(intent)
                    }
                    result.success(null)
                }
                "isDefaultLauncher" -> result.success(isDefaultLauncher())
                "requestDefaultLauncher" -> {
                    requestDefaultLauncher()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // Capture any cold-start pending action for Flutter to consume.
        if (intent?.action == Intent.ACTION_APPLICATION_PREFERENCES) {
            pendingOpenSettings = true
        }
    }

    // ------------------------------------------------------------------
    // Fullscreen
    // ------------------------------------------------------------------

    private fun setFullscreen(enabled: Boolean) {
        fullscreenEnabled = enabled
        runOnUiThread { applyFullscreen() }
    }

    private fun applyFullscreen() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val controller = window.insetsController ?: return
            if (fullscreenEnabled) {
                controller.hide(WindowInsets.Type.systemBars())
            } else {
                controller.show(WindowInsets.Type.systemBars())
            }
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = if (fullscreenEnabled) {
                View.SYSTEM_UI_FLAG_IMMERSIVE or
                    View.SYSTEM_UI_FLAG_FULLSCREEN or
                    View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
            } else {
                0
            }
        }
    }

    // ------------------------------------------------------------------
    // App listing / launching
    // ------------------------------------------------------------------

    private fun getInstalledApps(): List<Map<String, String>> {
        val intent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }
        val activities: List<ResolveInfo> =
            packageManager.queryIntentActivities(intent, 0)

        return activities
            .filter { it.activityInfo.packageName != packageName }
            .map { resolveInfo ->
                mapOf(
                    "packageName" to resolveInfo.activityInfo.packageName,
                    "label" to resolveInfo.loadLabel(packageManager).toString(),
                )
            }
    }

    private fun launchApp(targetPackageName: String) {
        val intent = packageManager.getLaunchIntentForPackage(targetPackageName)
        if (intent != null) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            @Suppress("DEPRECATION")
            overridePendingTransition(0, 0)
        }
    }

    private fun openAppInfo(targetPackageName: String) {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.fromParts("package", targetPackageName, null)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }

    // ------------------------------------------------------------------
    // Default-launcher role
    // ------------------------------------------------------------------

    private fun isDefaultLauncher(): Boolean {
        val intent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
        }
        val resolved = packageManager.resolveActivity(intent, 0) ?: return false
        return resolved.activityInfo.packageName == packageName
    }

    private fun requestDefaultLauncher() {
        // ROLE_HOME is declared requestable=false in the platform role config,
        // so RoleManager.createRequestRoleIntent(ROLE_HOME) opens an activity
        // that finishes immediately. ACTION_HOME_SETTINGS reliably opens the
        // system "Default home app" picker on every Android version.
        val intent = Intent(Settings.ACTION_HOME_SETTINGS)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            startActivity(intent)
        } catch (_: Exception) {
            // No-op if the device exposes no home-app settings screen.
        }
    }

    // ------------------------------------------------------------------
    // Quick settings (notification panel)
    // ------------------------------------------------------------------

    @Suppress("WrongConstant")
    private fun expandQuickSettings() {
        val statusBarService = getSystemService("statusbar") ?: return
        val clazz = statusBarService.javaClass

        try {
            clazz.getMethod("expandNotificationsPanel").invoke(statusBarService)
        } catch (_: Exception) {
            // Silently fail
        }
    }
}
