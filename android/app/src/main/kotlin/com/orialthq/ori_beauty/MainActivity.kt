package com.orialthq.ori_beauty

import android.content.Intent
import android.os.Bundle
import com.orialthq.ori_beauty.share.IncomingShareIngestor
import com.orialthq.ori_beauty.share.IncomingShareRoutePolicy
import com.orialthq.ori_beauty.share.IncomingShareStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var incomingChannel: MethodChannel? = null
    private val incomingStore: IncomingShareStore by lazy {
        IncomingShareStore(applicationContext)
    }
    private val incomingShareIngestor: IncomingShareIngestor by lazy {
        IncomingShareIngestor(applicationContext)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        incomingChannel =
            MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                INCOMING_SHARE_CHANNEL,
            ).also { channel ->
                channel.setMethodCallHandler { call, result ->
                    when (call.method) {
                        "drainPendingShares" -> result.success(incomingStore.pending())
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
                        else -> result.notImplemented()
                    }
                }
            }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        val incomingIntent = intent
        setIntent(intentForFlutter(incomingIntent))
        super.onCreate(savedInstanceState)
        stageIncomingShare(incomingIntent)
    }

    override fun onNewIntent(intent: Intent) {
        val incomingIntent = intent
        val flutterIntent = intentForFlutter(incomingIntent)
        super.onNewIntent(flutterIntent)
        setIntent(flutterIntent)
        stageIncomingShare(incomingIntent)
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
        incomingChannel?.invokeMethod("pendingSharesChanged", null)
    }

    companion object {
        private const val INCOMING_SHARE_CHANNEL =
            "com.orialthq.ori_beauty/incoming_share/v1"
    }
}
