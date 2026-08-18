package com.orialthq.ori_beauty.trigger

import android.content.Context
import android.content.Intent
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Flutter bridge kept outside MainActivity so integration is limited to lifecycle forwarding. */
class TriggerSchedulerChannel(context: Context) : MethodChannel.MethodCallHandler {
    private val scheduler = NativeTriggerScheduler(context.applicationContext)
    private val interactions = TriggerInteractionStore(context.applicationContext)
    private val locationResolver = TriggerLocationResolver(context.applicationContext)
    private var channel: MethodChannel? = null

    fun attach(messenger: BinaryMessenger) {
        channel?.setMethodCallHandler(null)
        channel = MethodChannel(messenger, CHANNEL_NAME).also { it.setMethodCallHandler(this) }
    }

    fun detach() {
        channel?.setMethodCallHandler(null)
        channel = null
        locationResolver.close()
    }

    /** Returns true only for this bridge's explicit notification-open contract. */
    fun handleIntent(intent: Intent?): Boolean {
        if (intent?.action != TriggerNotificationPresenter.ACTION_OPEN_NATIVE_TRIGGER) return false
        val ruleId =
            intent.getStringExtra(TriggerNotificationPresenter.EXTRA_TRIGGER_RULE_ID)?.trim().orEmpty()
        val destinationId =
            intent
                .getStringExtra(TriggerNotificationPresenter.EXTRA_TRIGGER_DESTINATION_ID)
                ?.trim()
                .orEmpty()
        val event =
            interactions.enqueueOpen(
                ruleId = ruleId,
                destinationId = destinationId,
                occurredAtMillis = System.currentTimeMillis(),
            ) ?: return true
        channel?.invokeMethod(EVENT_TRIGGER_OPENED, TriggerRuleWireCodec.encodeOpen(event))
        return true
    }

    /** Call from Activity.onResume; Flutter still acks the durable queue after applying it. */
    fun emitPendingInteractions() {
        val outcomes = interactions.pendingOutcomes().map(TriggerRuleWireCodec::encodeOutcome)
        if (outcomes.isNotEmpty()) channel?.invokeMethod(EVENT_OUTCOMES_CHANGED, outcomes)
        val opens = interactions.pendingOpens().map(TriggerRuleWireCodec::encodeOpen)
        if (opens.isNotEmpty()) channel?.invokeMethod(EVENT_OPENS_CHANGED, opens)
    }

    override fun onMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        runCatching {
            when (call.method) {
                METHOD_SCHEDULE -> schedule(call.arguments, result)
                METHOD_CANCEL -> cancel(call.arguments, result)
                METHOD_SYNC -> sync(call.arguments, result)
                METHOD_LIST -> list(result)
                METHOD_RESET -> reset(call.arguments, result)
                METHOD_RESTORE -> restore(result)
                METHOD_RESOLVE_LOCATION -> resolveLocation(call.arguments, result)
                METHOD_PENDING_OUTCOMES ->
                    result.success(
                        interactions.pendingOutcomes().map(TriggerRuleWireCodec::encodeOutcome),
                    )
                METHOD_ACKNOWLEDGE_OUTCOMES ->
                    result.success(interactions.acknowledgeOutcomes(argumentIds(call.arguments)))
                METHOD_PENDING_OPENS ->
                    result.success(interactions.pendingOpens().map(TriggerRuleWireCodec::encodeOpen))
                METHOD_ACKNOWLEDGE_OPENS ->
                    result.success(interactions.acknowledgeOpens(argumentIds(call.arguments)))
                else -> result.notImplemented()
            }
        }.onFailure { error ->
            result.error("invalid_native_trigger", error.message ?: "Invalid trigger request.", null)
        }
    }

    private fun schedule(
        arguments: Any?,
        result: MethodChannel.Result,
    ) {
        val values = arguments as? Map<*, *> ?: emptyMap<Any?, Any?>()
        val rule = TriggerRuleWireCodec.decodeRule(values["rule"])
        val resetState = values["resetState"] as? Boolean ?: false
        scheduler.upsert(rule, resetRuntimeState = resetState) { outcome ->
            result.success(
                mapOf(
                    "status" to outcome.status.name.lowercase(),
                    "persisted" to (outcome.status != TriggerRegistrationStatus.STORAGE_FAILED),
                    "notificationPermissionGranted" to
                        scheduler.notificationPermissionGranted(),
                    "rule" to TriggerRuleWireCodec.encodeRule(rule),
                ),
            )
        }
    }

    private fun cancel(
        arguments: Any?,
        result: MethodChannel.Result,
    ) {
        val id = argumentId(arguments)
        scheduler.remove(id) { removed -> result.success(mapOf("removed" to removed, "id" to id)) }
    }

    private fun sync(
        arguments: Any?,
        result: MethodChannel.Result,
    ) {
        val values = arguments as? Map<*, *> ?: emptyMap<Any?, Any?>()
        val rawRules = values["rules"] as? List<*> ?: emptyList<Any?>()
        val now = System.currentTimeMillis()
        val rules = rawRules.map { TriggerRuleWireCodec.decodeRule(it, now) }
        val resetIds =
            (values["resetStateIds"] as? List<*>)
                ?.filterIsInstance<String>()
                ?.toSet()
                .orEmpty()
        scheduler.sync(rules, resetIds) { report ->
            result.success(
                mapOf(
                    "status" to report.status.name.lowercase(),
                    "storedRuleCount" to report.storedRuleCount,
                    "restoredGeofenceCount" to report.restoredGeofenceCount,
                    "restoredTimeAlarmCount" to report.restoredTimeAlarmCount,
                    "restoredSnoozeCount" to report.restoredSnoozeCount,
                    "notificationPermissionGranted" to
                        scheduler.notificationPermissionGranted(),
                ),
            )
        }
    }

    private fun list(result: MethodChannel.Result) {
        result.success(
            scheduler.rules().map { rule ->
                mapOf(
                    "rule" to TriggerRuleWireCodec.encodeRule(rule),
                    "state" to TriggerRuleWireCodec.encodeState(scheduler.state(rule.id)),
                )
            },
        )
    }

    private fun reset(
        arguments: Any?,
        result: MethodChannel.Result,
    ) {
        val id = argumentId(arguments)
        scheduler.reset(id) { outcome ->
            result.success(mapOf("id" to id, "status" to outcome.status.name.lowercase()))
        }
    }

    private fun restore(result: MethodChannel.Result) {
        scheduler.restore { report ->
            result.success(
                mapOf(
                    "status" to report.status.name.lowercase(),
                    "restoredGeofenceCount" to report.restoredGeofenceCount,
                    "restoredTimeAlarmCount" to report.restoredTimeAlarmCount,
                    "restoredSnoozeCount" to report.restoredSnoozeCount,
                    "notificationPermissionGranted" to
                        scheduler.notificationPermissionGranted(),
                ),
            )
        }
    }

    private fun resolveLocation(
        arguments: Any?,
        result: MethodChannel.Result,
    ) {
        val query = (arguments as? Map<*, *>)?.get("query") as? String
        if (query.isNullOrBlank()) throw IllegalArgumentException("query is required")
        locationResolver.resolve(query) { resolved ->
            if (resolved == null) {
                result.success(mapOf("status" to "address_not_found"))
            } else {
                result.success(
                    mapOf(
                        "status" to "resolved",
                        "latitude" to resolved.latitude,
                        "longitude" to resolved.longitude,
                        "formattedAddress" to resolved.formattedAddress,
                    ),
                )
            }
        }
    }

    private fun argumentId(arguments: Any?): String {
        val id = (arguments as? Map<*, *>)?.get("id") as? String
        return id?.trim()?.takeIf(String::isNotEmpty)
            ?: throw IllegalArgumentException("id is required")
    }

    private fun argumentIds(arguments: Any?): List<String> =
        ((arguments as? Map<*, *>)?.get("eventIds") as? List<*>)
            ?.filterIsInstance<String>()
            .orEmpty()

    companion object {
        const val CHANNEL_NAME = "com.orialthq.ori_beauty/native_triggers/v1"
        const val EVENT_TRIGGER_OPENED = "triggerOpened"
        const val EVENT_OUTCOMES_CHANGED = "triggerOutcomesChanged"
        const val EVENT_OPENS_CHANGED = "triggerOpensChanged"

        private const val METHOD_SCHEDULE = "schedule"
        private const val METHOD_CANCEL = "cancel"
        private const val METHOD_SYNC = "sync"
        private const val METHOD_LIST = "list"
        private const val METHOD_RESET = "reset"
        private const val METHOD_RESTORE = "restore"
        private const val METHOD_RESOLVE_LOCATION = "resolveLocation"
        private const val METHOD_PENDING_OUTCOMES = "pendingOutcomes"
        private const val METHOD_ACKNOWLEDGE_OUTCOMES = "acknowledgeOutcomes"
        private const val METHOD_PENDING_OPENS = "pendingOpens"
        private const val METHOD_ACKNOWLEDGE_OPENS = "acknowledgeOpens"
    }
}
