package com.example.flutter_application_1


import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import android.app.AlarmManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.engine.FlutterEngine


class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.app/permissions"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Flutter 엔진 초기화
        val flutterEngine = flutterEngine ?: return

        // MethodChannel 초기화
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "checkExactAlarmPermission") {
                if (!canScheduleExactAlarms()) {
                    val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                    startActivity(intent)
                    result.success(false)
                } else {
                    result.success(true)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun canScheduleExactAlarms(): Boolean {
        val alarmManager = getSystemService(ALARM_SERVICE) as AlarmManager
        return alarmManager.canScheduleExactAlarms()
    }
}
