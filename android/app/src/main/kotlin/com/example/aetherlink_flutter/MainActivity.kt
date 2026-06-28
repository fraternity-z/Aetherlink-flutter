package com.example.aetherlink_flutter

import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // Termux one-tap setup (设计文档 §10.5 / Termux-A): the Dart side
    // (core/platform/impl/termux_impl.dart) asks whether Termux is installed and
    // from where, so it can warn about the deprecated Play build. Requires the
    // <package android:name="com.termux"> <queries> entry in the manifest to be
    // visible on Android 11+.
    private val termuxChannel = "aetherlink/termux"
    private val termuxPackage = "com.termux"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, termuxChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "detect" -> result.success(detectTermux())
                    else -> result.notImplemented()
                }
            }
    }

    private fun detectTermux(): Map<String, Any?> {
        val pm = packageManager
        val installed = try {
            pm.getPackageInfo(termuxPackage, 0)
            true
        } catch (e: PackageManager.NameNotFoundException) {
            false
        }
        var installer: String? = null
        if (installed) {
            installer = try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    pm.getInstallSourceInfo(termuxPackage).installingPackageName
                } else {
                    @Suppress("DEPRECATION")
                    pm.getInstallerPackageName(termuxPackage)
                }
            } catch (e: Exception) {
                null
            }
        }
        return mapOf(
            "installed" to installed,
            "installer" to installer,
        )
    }
}
