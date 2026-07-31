package com.orialthq.ori_beauty

import android.content.Intent
import android.os.Bundle
import com.orialthq.ori_beauty.share.IncomingShareIntentParser
import com.orialthq.ori_beauty.share.IncomingShareStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var incomingChannel: MethodChannel? = null
    private val incomingStore: IncomingShareStore by lazy {
        IncomingShareStore(applicationContext)
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
                            incomingStore.acknowledge(ids)
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                }
            }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        stageIncomingShare(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        stageIncomingShare(intent)
    }

    private fun stageIncomingShare(intent: Intent?) {
        val sourcePackage = referrer?.host
        val payload =
            IncomingShareIntentParser.parse(
                intent = intent,
                sourcePackage = sourcePackage,
            ) ?: return
        incomingStore.append(payload)
        incomingChannel?.invokeMethod("pendingSharesChanged", null)
    }

    companion object {
        private const val INCOMING_SHARE_CHANNEL =
            "com.orialthq.ori_beauty/incoming_share/v1"
    }
}
