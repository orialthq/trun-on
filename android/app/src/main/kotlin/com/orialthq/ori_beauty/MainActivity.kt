package com.orialthq.ori_beauty

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.MediaStore
import com.orialthq.ori_beauty.share.IncomingShareIngestor
import com.orialthq.ori_beauty.share.IncomingShareRoutePolicy
import com.orialthq.ori_beauty.share.IncomingShareStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var incomingChannel: MethodChannel? = null
    private var placeReminderChannel: MethodChannel? = null
    private var appNavigationChannel: MethodChannel? = null
    private val incomingStore: IncomingShareStore by lazy {
        IncomingShareStore(applicationContext)
    }
    private val incomingShareIngestor: IncomingShareIngestor by lazy {
        IncomingShareIngestor(applicationContext)
    }
    private val captureNotifications: CaptureNotificationManager by lazy {
        CaptureNotificationManager(applicationContext)
    }
    private val placeReminderManager: PlaceReminderManager by lazy {
        PlaceReminderManager(applicationContext)
    }
    private val sharedMediaDeletionManager: SharedMediaDeletionManager by lazy {
        SharedMediaDeletionManager(applicationContext)
    }
    private var pendingCaptureNotificationId: String? = null
    private var pendingLocationPermissionResult: MethodChannel.Result? = null
    private var pendingSourceDeletionResult: MethodChannel.Result? = null
    private var pendingSourceDeletionTransportId: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        incomingChannel =
            MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                INCOMING_SHARE_CHANNEL,
            ).also { channel ->
                channel.setMethodCallHandler { call, result ->
                    when (call.method) {
                        "drainPendingShares" -> {
                            val pending =
                                incomingStore.pending().map { payload ->
                                    val transportId = payload["id"] as? String
                                    payload +
                                        ("sourceDeletionAvailable" to
                                            (transportId != null &&
                                                sharedMediaDeletionManager.isAvailable(
                                                    transportId,
                                                )))
                                }
                            result.success(pending)
                        }
                        "loadAppSnapshot" -> result.success(incomingStore.loadAppSnapshot())
                        "saveAppSnapshot" -> {
                            val snapshot = call.arguments as? String
                            if (snapshot.isNullOrBlank()) {
                                result.error(
                                    "invalid_snapshot",
                                    "App snapshot must be a non-empty string.",
                                    null,
                                )
                            } else if (incomingStore.saveAppSnapshot(snapshot)) {
                                result.success(true)
                            } else {
                                result.error(
                                    "snapshot_save_failed",
                                    "App snapshot could not be committed to durable storage.",
                                    null,
                                )
                            }
                        }
                        "acknowledgeShares" -> {
                            val arguments = call.arguments as? Map<*, *>
                            val ids =
                                (arguments?.get("ids") as? List<*>)
                                    ?.filterIsInstance<String>()
                                    .orEmpty()
                            if (incomingStore.acknowledge(ids)) {
                                result.success(null)
                            } else {
                                result.error(
                                    "share_acknowledge_failed",
                                    "Pending shares could not be committed to durable storage.",
                                    null,
                                )
                            }
                        }
                        "deleteSharedSource" ->
                            requestSharedSourceDeletion(call.arguments, result)
                        "keepSharedSource" -> {
                            val transportId =
                                (call.arguments as? Map<*, *>)?.get("transportId") as? String
                            if (transportId.isNullOrBlank()) {
                                result.error(
                                    "invalid_transport",
                                    "Transport id is required.",
                                    null,
                                )
                            } else {
                                sharedMediaDeletionManager.forget(transportId)
                                result.success(null)
                            }
                        }
                        else -> result.notImplemented()
                    }
                }
            }

        placeReminderChannel =
            MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                PLACE_REMINDER_CHANNEL,
            ).also { channel ->
                channel.setMethodCallHandler { call, result ->
                    when (call.method) {
                        "getPlaceReminder" -> {
                            val id = (call.arguments as? Map<*, *>)?.get("id") as? String
                            if (id.isNullOrBlank()) {
                                result.error("invalid_place", "Place id is required.", null)
                            } else {
                                result.success(
                                    placeReminderManager.state(id) + locationPermissionState(),
                                )
                            }
                        }
                        "requestForegroundLocationPermission" ->
                            requestForegroundLocationPermission(result)
                        "openBackgroundLocationSettings" -> {
                            if (openBackgroundLocationSettings()) {
                                result.success(null)
                            } else {
                                result.error(
                                    "settings_unavailable",
                                    "Location permission settings are unavailable.",
                                    null,
                                )
                            }
                        }
                        "enablePlaceReminder" -> enablePlaceReminder(call.arguments, result)
                        "disablePlaceReminder" -> disablePlaceReminder(call.arguments, result)
                        "openMap" -> openMap(call.arguments, result)
                        else -> result.notImplemented()
                    }
                }
            }

        appNavigationChannel =
            MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                APP_NAVIGATION_CHANNEL,
            ).also { channel ->
                channel.setMethodCallHandler { call, result ->
                    when (call.method) {
                        "returnToPreviousApp" -> returnToPreviousApp(result)
                        else -> result.notImplemented()
                    }
                }
            }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        val incomingIntent = intent
        setIntent(intentForFlutter(incomingIntent))
        super.onCreate(savedInstanceState)
        captureNotifications.createChannel()
        handleIncomingIntent(incomingIntent)
    }

    override fun onNewIntent(intent: Intent) {
        val incomingIntent = intent
        val flutterIntent = intentForFlutter(incomingIntent)
        super.onNewIntent(flutterIntent)
        setIntent(flutterIntent)
        handleIncomingIntent(incomingIntent)
    }

    override fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?,
    ) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == SOURCE_DELETE_REQUEST_CODE) {
            val transportId = pendingSourceDeletionTransportId
            if (transportId != null) {
                sharedMediaDeletionManager.forget(transportId)
            }
            pendingSourceDeletionResult?.success(
                if (resultCode == RESULT_OK) "deleted" else "kept",
            )
            pendingSourceDeletionResult = null
            pendingSourceDeletionTransportId = null
            return
        }
        if (requestCode != PICK_CAPTURE_REQUEST_CODE || resultCode != RESULT_OK) {
            return
        }
        val selectedUri = data?.data ?: return
        val mimeType = contentResolver.getType(selectedUri) ?: "image/*"
        stageIncomingShare(
            Intent(Intent.ACTION_VIEW, selectedUri).apply {
                type = mimeType
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            },
        )
    }

    private fun handleIncomingIntent(intent: Intent?) {
        if (intent?.action == ACTION_PICK_CAPTURE) {
            launchCapturePicker()
            return
        }
        stageIncomingShare(intent)
    }

    private fun launchCapturePicker() {
        val pickerIntent =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                Intent(MediaStore.ACTION_PICK_IMAGES).apply {
                    type = "image/*"
                }
            } else {
                Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = "image/*"
                }
            }
        startActivityForResult(pickerIntent, PICK_CAPTURE_REQUEST_CODE)
    }

    private fun locationPermissionState(): Map<String, Any> {
        val foregroundGranted =
            checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) ==
                PackageManager.PERMISSION_GRANTED
        val backgroundGranted =
            Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
                checkSelfPermission(Manifest.permission.ACCESS_BACKGROUND_LOCATION) ==
                PackageManager.PERMISSION_GRANTED
        val backgroundLabel =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                packageManager.backgroundPermissionOptionLabel.toString()
            } else {
                "항상 허용"
            }
        return mapOf(
            "foregroundGranted" to foregroundGranted,
            "backgroundGranted" to backgroundGranted,
            "backgroundPermissionLabel" to backgroundLabel,
        )
    }

    private fun requestForegroundLocationPermission(result: MethodChannel.Result) {
        if (
            checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        if (pendingLocationPermissionResult != null) {
            result.error(
                "permission_request_in_progress",
                "A location permission request is already in progress.",
                null,
            )
            return
        }
        pendingLocationPermissionResult = result
        requestPermissions(
            arrayOf(
                Manifest.permission.ACCESS_FINE_LOCATION,
                Manifest.permission.ACCESS_COARSE_LOCATION,
            ),
            LOCATION_PERMISSION_REQUEST_CODE,
        )
    }

    private fun openBackgroundLocationSettings(): Boolean {
        return LocationPermissionSettingsNavigator.open(this)
    }

    private fun returnToPreviousApp(result: MethodChannel.Result) {
        // Let Flutter receive the method result before this activity is paused or
        // finished. If a share target was added on top of the source app's task,
        // finishing reveals that source activity. Otherwise, moving Trun On's own
        // task behind reveals whichever app was foreground before the share.
        result.success(true)
        window.decorView.post {
            if (isFinishing || isDestroyed) {
                return@post
            }
            if (!isTaskRoot) {
                finish()
            } else if (!moveTaskToBack(true)) {
                finish()
            }
        }
    }

    private fun enablePlaceReminder(arguments: Any?, result: MethodChannel.Result) {
        val values = arguments as? Map<*, *>
        val id = values?.get("id") as? String
        val title = values?.get("title") as? String
        val address = values?.get("address") as? String
        val radius = (values?.get("radiusMeters") as? Number)?.toFloat()
        if (
            id.isNullOrBlank() ||
                title.isNullOrBlank() ||
                address.isNullOrBlank() ||
                radius == null
        ) {
            result.error("invalid_place", "Place reminder fields are invalid.", null)
            return
        }
        val permission = locationPermissionState()
        if (permission["foregroundGranted"] != true) {
            result.success(mapOf("status" to "needs_foreground_permission"))
            return
        }
        if (permission["backgroundGranted"] != true) {
            result.success(
                mapOf(
                    "status" to "needs_background_permission",
                    "backgroundPermissionLabel" to
                        (permission["backgroundPermissionLabel"] as? String ?: "항상 허용"),
                ),
            )
            return
        }
        placeReminderManager.enable(id, title, address, radius) { outcome ->
            runOnUiThread {
                outcome.fold(
                    onSuccess = { reminder ->
                        result.success(
                            mapOf(
                                "status" to "enabled",
                                "radiusMeters" to reminder.radiusMeters.toDouble(),
                            ),
                        )
                    },
                    onFailure = { error ->
                        result.success(
                            mapOf(
                                "status" to
                                    if (error.message == "address_not_found") {
                                        "address_not_found"
                                    } else {
                                        "failed"
                                    },
                            ),
                        )
                    },
                )
            }
        }
    }

    private fun disablePlaceReminder(arguments: Any?, result: MethodChannel.Result) {
        val id = (arguments as? Map<*, *>)?.get("id") as? String
        if (id.isNullOrBlank()) {
            result.error("invalid_place", "Place id is required.", null)
            return
        }
        placeReminderManager.disable(id) { removed ->
            runOnUiThread { result.success(removed) }
        }
    }

    private fun openMap(arguments: Any?, result: MethodChannel.Result) {
        val values = arguments as? Map<*, *>
        val name = values?.get("name") as? String
        val address = values?.get("address") as? String
        val query = listOfNotNull(name, address).joinToString(" ").trim()
        if (query.isEmpty()) {
            result.error("invalid_place", "A map query is required.", null)
            return
        }
        val uri =
            Uri.parse(
                "https://www.google.com/maps/search/?api=1&query=${Uri.encode(query)}",
            )
        startActivity(Intent(Intent.ACTION_VIEW, uri))
        result.success(null)
    }

    private fun requestSharedSourceDeletion(
        arguments: Any?,
        result: MethodChannel.Result,
    ) {
        val transportId =
            (arguments as? Map<*, *>)?.get("transportId") as? String
        if (transportId.isNullOrBlank()) {
            result.error("invalid_transport", "Transport id is required.", null)
            return
        }
        if (pendingSourceDeletionResult != null) {
            result.error(
                "deletion_request_in_progress",
                "A source deletion request is already in progress.",
                null,
            )
            return
        }
        val deleteRequest =
            sharedMediaDeletionManager.createDeleteRequest(transportId)
        if (deleteRequest == null) {
            sharedMediaDeletionManager.forget(transportId)
            result.success("unavailable")
            return
        }
        pendingSourceDeletionResult = result
        pendingSourceDeletionTransportId = transportId
        try {
            startIntentSenderForResult(
                deleteRequest.intentSender,
                SOURCE_DELETE_REQUEST_CODE,
                null,
                0,
                0,
                0,
            )
        } catch (_: Exception) {
            pendingSourceDeletionResult = null
            pendingSourceDeletionTransportId = null
            sharedMediaDeletionManager.forget(transportId)
            result.success("failed")
        }
    }

    private fun intentForFlutter(intent: Intent): Intent {
        if (!IncomingShareRoutePolicy.shouldStripData(intent.action)) {
            return intent
        }
        return Intent(intent).apply {
            data = null
        }
    }

    private fun stageIncomingShare(intent: Intent?) {
        val sourcePackage = referrer?.host
        val payload =
            incomingShareIngestor.ingest(
                intent = intent,
                sourcePackage = sourcePackage,
            ) ?: return
        if (!incomingStore.append(payload)) {
            incomingShareIngestor.deleteAttachments(payload.attachments)
            return
        }
        if (payload.sourceImageUris.isNotEmpty()) {
            sharedMediaDeletionManager.remember(payload.id, payload.sourceImageUris)
        }
        if (payload.attachments.isNotEmpty()) {
            notifyCaptureReceived(payload.id)
        }
        incomingChannel?.invokeMethod("pendingSharesChanged", null)
    }

    private fun notifyCaptureReceived(transportId: String) {
        if (
            Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
                checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
                PackageManager.PERMISSION_GRANTED
        ) {
            captureNotifications.showReceived(transportId)
            pendingCaptureNotificationId = null
            return
        }

        pendingCaptureNotificationId = transportId
        val preferences =
            getSharedPreferences(NOTIFICATION_PREFERENCES_NAME, MODE_PRIVATE)
        if (preferences.getBoolean(KEY_NOTIFICATION_PERMISSION_REQUESTED, false)) {
            return
        }
        preferences
            .edit()
            .putBoolean(KEY_NOTIFICATION_PERMISSION_REQUESTED, true)
            .apply()
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATION_PERMISSION_REQUEST_CODE,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        when (requestCode) {
            NOTIFICATION_PERMISSION_REQUEST_CODE -> {
                if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
                    pendingCaptureNotificationId?.let(captureNotifications::showReceived)
                }
                pendingCaptureNotificationId = null
            }
            LOCATION_PERMISSION_REQUEST_CODE -> {
                val granted =
                    checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) ==
                        PackageManager.PERMISSION_GRANTED
                pendingLocationPermissionResult?.success(granted)
                pendingLocationPermissionResult = null
            }
        }
    }

    companion object {
        const val ACTION_PICK_CAPTURE =
            "com.orialthq.ori_beauty.action.PICK_CAPTURE"
        private const val INCOMING_SHARE_CHANNEL =
            "com.orialthq.ori_beauty/incoming_share/v1"
        private const val PLACE_REMINDER_CHANNEL =
            "com.orialthq.ori_beauty/place_reminders/v1"
        private const val APP_NAVIGATION_CHANNEL =
            "com.orialthq.ori_beauty/app_navigation/v1"
        private const val PICK_CAPTURE_REQUEST_CODE = 4109
        private const val NOTIFICATION_PERMISSION_REQUEST_CODE = 4107
        private const val LOCATION_PERMISSION_REQUEST_CODE = 4111
        private const val SOURCE_DELETE_REQUEST_CODE = 4112
        private const val NOTIFICATION_PREFERENCES_NAME = "capture_notifications"
        private const val KEY_NOTIFICATION_PERMISSION_REQUESTED = "permission_requested"
    }
}
