package com.orialthq.ori_beauty.trigger

import android.Manifest
import android.annotation.SuppressLint
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import com.google.android.gms.location.Geofence
import com.google.android.gms.location.GeofencingRequest
import com.google.android.gms.location.LocationServices

enum class TriggerRegistrationStatus {
    REGISTERED,
    SAVED_DISABLED,
    LOCATION_PERMISSION_REQUIRED,
    REGISTRATION_FAILED,
    STORAGE_FAILED,
    GEOFENCE_LIMIT_EXCEEDED,
}

data class TriggerRegistrationOutcome(
    val status: TriggerRegistrationStatus,
    val error: Throwable? = null,
)

data class TriggerRestoreReport(
    val status: TriggerRegistrationStatus,
    val restoredGeofenceCount: Int,
    val restoredTimeAlarmCount: Int,
    val restoredSnoozeCount: Int,
    val error: Throwable? = null,
)

data class TriggerSyncReport(
    val status: TriggerRegistrationStatus,
    val storedRuleCount: Int,
    val restoredGeofenceCount: Int,
    val restoredTimeAlarmCount: Int,
    val restoredSnoozeCount: Int,
    val error: Throwable? = null,
)

class NativeTriggerScheduler(context: Context) {
    private val applicationContext = context.applicationContext
    private val store = TriggerRuleStore(applicationContext)
    private val presenter = TriggerNotificationPresenter(applicationContext)
    private val alarms = TriggerAlarmScheduler(applicationContext)
    private val interactions = TriggerInteractionStore(applicationContext)
    private val geofencingClient = LocationServices.getGeofencingClient(applicationContext)

    fun rules(): List<TriggerRule> = store.allRules()

    fun state(ruleId: String): TriggerRuntimeState? = store.runtimeState(ruleId)

    fun notificationPermissionGranted(): Boolean = presenter.canNotify()

    fun upsert(
        rule: TriggerRule,
        resetRuntimeState: Boolean = false,
        callback: (TriggerRegistrationOutcome) -> Unit = {},
    ) {
        val previousRule = store.findRule(rule.id)
        val previousState = store.runtimeState(rule.id)
        if (!store.upsertRule(rule, resetRuntimeState)) {
            callback(TriggerRegistrationOutcome(TriggerRegistrationStatus.STORAGE_FAILED))
            return
        }
        val scheduleChanged =
            resetRuntimeState ||
                previousRule?.alarmSchedule != rule.alarmSchedule ||
                previousRule?.recurrence != rule.recurrence
        if (scheduleChanged) {
            alarms.cancelTime(rule.id, previousState?.nextAlarmAtMillis)
            store.setNextAlarm(rule.id, null)
        }
        if (!rule.enabled) {
            unregisterGeofence(rule.id) {
                val state = store.runtimeState(rule.id)
                state?.snoozedUntilMillis?.let { alarms.cancel(rule.id, it) }
                alarms.cancelTime(rule.id, state?.nextAlarmAtMillis)
                callback(TriggerRegistrationOutcome(TriggerRegistrationStatus.SAVED_DISABLED))
            }
            return
        }
        if (rule.alarmSchedule != null) {
            unregisterGeofence(rule.id) {
                armTimeRule(rule, System.currentTimeMillis())
                callback(TriggerRegistrationOutcome(TriggerRegistrationStatus.REGISTERED))
            }
            return
        }
        if (!hasLocationPermission()) {
            callback(
                TriggerRegistrationOutcome(TriggerRegistrationStatus.LOCATION_PERMISSION_REQUIRED),
            )
            return
        }
        register(listOf(rule)) { error ->
            callback(
                if (error == null) {
                    TriggerRegistrationOutcome(TriggerRegistrationStatus.REGISTERED)
                } else {
                    TriggerRegistrationOutcome(
                        TriggerRegistrationStatus.REGISTRATION_FAILED,
                        error,
                    )
                },
            )
        }
    }

    fun remove(
        ruleId: String,
        callback: (Boolean) -> Unit = {},
    ) {
        val snoozedUntil = store.runtimeState(ruleId)?.snoozedUntilMillis
        val nextAlarmAt = store.runtimeState(ruleId)?.nextAlarmAtMillis
        val removed = store.removeRule(ruleId)
        presenter.cancel(ruleId)
        alarms.cancel(ruleId, snoozedUntil)
        alarms.cancelTime(ruleId, nextAlarmAt)
        unregisterGeofence(ruleId) { callback(removed) }
    }

    fun reset(
        ruleId: String,
        callback: (TriggerRegistrationOutcome) -> Unit = {},
    ) {
        val rule = store.findRule(ruleId)
        val previousState = store.runtimeState(ruleId)
        if (rule == null || !store.resetRuntimeState(ruleId)) {
            callback(TriggerRegistrationOutcome(TriggerRegistrationStatus.STORAGE_FAILED))
            return
        }
        alarms.cancel(ruleId, previousState?.snoozedUntilMillis)
        alarms.cancelTime(ruleId, previousState?.nextAlarmAtMillis)
        upsert(rule.copy(updatedAtMillis = System.currentTimeMillis()), callback = callback)
    }

    /** Makes the provided generic rules canonical without touching legacy place reminders. */
    fun sync(
        rules: List<TriggerRule>,
        resetRuntimeStateIds: Set<String> = emptySet(),
        callback: (TriggerSyncReport) -> Unit = {},
    ) {
        if (
            rules.count { it.location != null } > MAX_GEOFENCES ||
                rules.map(TriggerRule::id).distinct().size != rules.size
        ) {
            callback(
                TriggerSyncReport(
                    status = TriggerRegistrationStatus.GEOFENCE_LIMIT_EXCEEDED,
                    storedRuleCount = 0,
                    restoredGeofenceCount = 0,
                    restoredTimeAlarmCount = 0,
                    restoredSnoozeCount = 0,
                ),
            )
            return
        }
        val previousRules = store.allRules()
        val previousRulesById = previousRules.associateBy(TriggerRule::id)
        val previousStates = store.allRuntimeStates().associateBy(TriggerRuntimeState::ruleId)
        val scheduleChangedIds =
            rules.mapNotNullTo(mutableSetOf()) { rule ->
                val previous = previousRulesById[rule.id] ?: return@mapNotNullTo null
                rule.id.takeIf {
                    previous.alarmSchedule != rule.alarmSchedule ||
                        previous.recurrence != rule.recurrence
                }
            }
        if (!store.replaceRules(rules, resetRuntimeStateIds + scheduleChangedIds)) {
            callback(
                TriggerSyncReport(
                    status = TriggerRegistrationStatus.STORAGE_FAILED,
                    storedRuleCount = 0,
                    restoredGeofenceCount = 0,
                    restoredTimeAlarmCount = 0,
                    restoredSnoozeCount = 0,
                ),
            )
            return
        }
        val incomingIds = rules.mapTo(mutableSetOf(), TriggerRule::id)
        previousRules.forEach { previous ->
            val state = previousStates[previous.id]
            if (previous.id !in incomingIds) presenter.cancel(previous.id)
            alarms.cancel(previous.id, state?.snoozedUntilMillis)
            alarms.cancelTime(previous.id, state?.nextAlarmAtMillis)
        }
        val allRegistrationIds = (previousRules + rules).map(TriggerRule::id).distinct()
        unregisterGeofences(allRegistrationIds) {
            restore { report ->
                callback(
                    TriggerSyncReport(
                        status = report.status,
                        storedRuleCount = rules.size,
                        restoredGeofenceCount = report.restoredGeofenceCount,
                        restoredTimeAlarmCount = report.restoredTimeAlarmCount,
                        restoredSnoozeCount = report.restoredSnoozeCount,
                        error = report.error,
                    ),
                )
            }
        }
    }

    fun handleGeofenceEntry(
        geofenceRequestId: String,
        occurredAtMillis: Long = System.currentTimeMillis(),
    ): TriggerDecision {
        if (!presenter.canNotify()) {
            return TriggerDecision.Suppress(TriggerSuppressionReason.NOTIFICATION_PERMISSION_REQUIRED)
        }
        val rule =
            store.allRules().firstOrNull {
                TriggerRegistrationIds.geofenceRequestId(it.id) == geofenceRequestId
            } ?: return TriggerDecision.Suppress(TriggerSuppressionReason.RULE_NOT_FOUND)
        val claim = store.claimGeofenceNotification(rule.id, occurredAtMillis)
        if (claim.decision == TriggerDecision.Notify) {
            if (presenter.show(rule)) enqueueFired(rule, claim.event)
            if (rule.recurrence == TriggerRecurrence.ONCE) unregisterGeofence(rule.id)
        }
        return claim.decision
    }

    fun complete(
        ruleId: String,
        completedAtMillis: Long = System.currentTimeMillis(),
        callback: (Boolean) -> Unit = {},
    ) {
        val snoozedUntil = store.runtimeState(ruleId)?.snoozedUntilMillis
        val nextAlarmAt = store.runtimeState(ruleId)?.nextAlarmAtMillis
        val saved = store.markCompleted(ruleId, completedAtMillis)
        presenter.cancel(ruleId)
        alarms.cancel(ruleId, snoozedUntil)
        alarms.cancelTime(ruleId, nextAlarmAt)
        unregisterGeofence(ruleId) { callback(saved) }
    }

    fun snooze(
        ruleId: String,
        requestedAtMillis: Long = System.currentTimeMillis(),
    ): Boolean {
        val rule = store.findRule(ruleId) ?: return false
        val previousDue = store.runtimeState(ruleId)?.snoozedUntilMillis
        val dueAt = saturatedAdd(requestedAtMillis, rule.laterDelayMillis)
        if (!store.markSnoozed(ruleId, dueAt)) return false
        presenter.cancel(ruleId)
        alarms.cancel(ruleId, previousDue)
        alarms.schedule(ruleId, scheduledAtMillis = dueAt)
        return true
    }

    fun handleSnoozeDue(
        ruleId: String,
        scheduledAtMillis: Long,
        occurredAtMillis: Long = System.currentTimeMillis(),
    ): TriggerDecision {
        if (!presenter.canNotify()) {
            return TriggerDecision.Suppress(TriggerSuppressionReason.NOTIFICATION_PERMISSION_REQUIRED)
        }
        val claim =
            store.claimSnoozedNotification(
                ruleId = ruleId,
                scheduledAtMillis = scheduledAtMillis,
                occurredAtMillis = occurredAtMillis,
            )
        if (claim.decision == TriggerDecision.Notify) {
            claim.rule?.let { rule ->
                if (presenter.show(rule)) enqueueFired(rule, claim.event)
            }
        }
        return claim.decision
    }

    fun handleTimeDue(
        ruleId: String,
        scheduledAtMillis: Long,
        occurredAtMillis: Long = System.currentTimeMillis(),
    ): TriggerDecision {
        if (!presenter.canNotify()) {
            alarms.scheduleTime(
                ruleId = ruleId,
                scheduledAtMillis = scheduledAtMillis,
                fireAtMillis = saturatedAdd(occurredAtMillis, NOTIFICATION_RETRY_MILLIS),
            )
            return TriggerDecision.Suppress(TriggerSuppressionReason.NOTIFICATION_PERMISSION_REQUIRED)
        }
        val claim =
            store.claimScheduledNotification(
                ruleId = ruleId,
                scheduledAtMillis = scheduledAtMillis,
                occurredAtMillis = occurredAtMillis,
            )
        val rule = claim.rule
        if (
            rule != null &&
                claim.decision != TriggerDecision.Suppress(TriggerSuppressionReason.STALE_ALARM)
        ) {
            val next = nextScheduledAfter(rule, scheduledAtMillis, occurredAtMillis)
            store.setNextAlarm(ruleId, next)
            if (next != null) {
                alarms.scheduleTime(ruleId, scheduledAtMillis = next)
            }
        }
        if (claim.decision == TriggerDecision.Notify) {
            rule?.let { if (presenter.show(it)) enqueueFired(it, claim.event) }
        }
        return claim.decision
    }

    /** Re-registers durable geofences and re-arms time/snooze alarms after reboot/update. */
    fun restore(callback: (TriggerRestoreReport) -> Unit = {}) {
        val now = System.currentTimeMillis()
        val states = store.allRuntimeStates().associateBy(TriggerRuntimeState::ruleId)
        val rules = store.allRules()
        var restoredSnoozes = 0
        var restoredTimeAlarms = 0
        rules.forEach { rule ->
            val state = states[rule.id]
            val dueAt = state?.snoozedUntilMillis
            if (rule.enabled && state?.completedAtMillis == null && dueAt != null) {
                alarms.schedule(
                    ruleId = rule.id,
                    scheduledAtMillis = dueAt,
                    fireAtMillis = maxOf(dueAt, now + RESTORED_ALARM_GRACE_MILLIS),
                )
                restoredSnoozes += 1
            }
            if (rule.alarmSchedule != null && armTimeRule(rule, now)) {
                restoredTimeAlarms += 1
            }
        }
        val eligibleLocations =
            rules.filter { rule ->
                val state = states[rule.id]
                rule.location != null &&
                    rule.enabled &&
                    state?.completedAtMillis == null &&
                    !(rule.recurrence == TriggerRecurrence.ONCE &&
                        state?.firstNotifiedAtMillis != null)
            }
        if (eligibleLocations.isEmpty()) {
            callback(
                TriggerRestoreReport(
                    status = TriggerRegistrationStatus.REGISTERED,
                    restoredGeofenceCount = 0,
                    restoredTimeAlarmCount = restoredTimeAlarms,
                    restoredSnoozeCount = restoredSnoozes,
                ),
            )
            return
        }
        if (eligibleLocations.size > MAX_GEOFENCES) {
            callback(
                TriggerRestoreReport(
                    status = TriggerRegistrationStatus.GEOFENCE_LIMIT_EXCEEDED,
                    restoredGeofenceCount = 0,
                    restoredTimeAlarmCount = restoredTimeAlarms,
                    restoredSnoozeCount = restoredSnoozes,
                ),
            )
            return
        }
        if (!hasLocationPermission()) {
            callback(
                TriggerRestoreReport(
                    status = TriggerRegistrationStatus.LOCATION_PERMISSION_REQUIRED,
                    restoredGeofenceCount = 0,
                    restoredTimeAlarmCount = restoredTimeAlarms,
                    restoredSnoozeCount = restoredSnoozes,
                ),
            )
            return
        }
        register(eligibleLocations) { error ->
            callback(
                TriggerRestoreReport(
                    status =
                        if (error == null) {
                            TriggerRegistrationStatus.REGISTERED
                        } else {
                            TriggerRegistrationStatus.REGISTRATION_FAILED
                        },
                    restoredGeofenceCount = if (error == null) eligibleLocations.size else 0,
                    restoredTimeAlarmCount = restoredTimeAlarms,
                    restoredSnoozeCount = restoredSnoozes,
                    error = error,
                ),
            )
        }
    }

    @SuppressLint("MissingPermission")
    private fun register(
        rules: List<TriggerRule>,
        callback: (Throwable?) -> Unit,
    ) {
        val geofences =
            rules.map { rule ->
                val location = requireNotNull(rule.location)
                Geofence.Builder()
                    .setRequestId(TriggerRegistrationIds.geofenceRequestId(rule.id))
                    .setCircularRegion(
                        location.latitude,
                        location.longitude,
                        location.radiusMeters,
                    )
                    .setTransitionTypes(Geofence.GEOFENCE_TRANSITION_ENTER)
                    .setExpirationDuration(Geofence.NEVER_EXPIRE)
                    .build()
            }
        runCatching {
            geofencingClient.addGeofences(
                GeofencingRequest.Builder()
                    .setInitialTrigger(0)
                    .addGeofences(geofences)
                    .build(),
                geofencePendingIntent(),
            )
        }.fold(
            onSuccess = { task ->
                task.addOnSuccessListener { callback(null) }
                    .addOnFailureListener(callback)
            },
            onFailure = callback,
        )
    }

    private fun unregisterGeofence(
        ruleId: String,
        callback: () -> Unit = {},
    ) {
        runCatching {
            geofencingClient.removeGeofences(
                listOf(TriggerRegistrationIds.geofenceRequestId(ruleId)),
            )
        }.fold(
            onSuccess = { task -> task.addOnCompleteListener { callback() } },
            onFailure = { callback() },
        )
    }

    private fun unregisterGeofences(
        ruleIds: List<String>,
        callback: () -> Unit,
    ) {
        if (ruleIds.isEmpty()) {
            callback()
            return
        }
        runCatching {
            geofencingClient.removeGeofences(ruleIds.map(TriggerRegistrationIds::geofenceRequestId))
        }.fold(
            onSuccess = { task -> task.addOnCompleteListener { callback() } },
            onFailure = { callback() },
        )
    }

    private fun armTimeRule(
        rule: TriggerRule,
        nowMillis: Long,
    ): Boolean {
        val schedule = rule.alarmSchedule ?: return false
        val state = store.runtimeState(rule.id)
        if (
            !rule.enabled ||
                state?.completedAtMillis != null ||
                (rule.recurrence == TriggerRecurrence.ONCE &&
                    state?.firstNotifiedAtMillis != null)
        ) {
            alarms.cancelTime(rule.id, state?.nextAlarmAtMillis)
            store.setNextAlarm(rule.id, null)
            return false
        }
        val dueAt =
            state?.nextAlarmAtMillis
                ?: firstScheduledAtOrAfter(rule, schedule.firstFireAtMillis, nowMillis)
                ?: return false
        if (rule.activeUntilMillis != null && dueAt >= rule.activeUntilMillis) {
            store.setNextAlarm(rule.id, null)
            return false
        }
        if (!store.setNextAlarm(rule.id, dueAt)) return false
        alarms.scheduleTime(
            ruleId = rule.id,
            scheduledAtMillis = dueAt,
            fireAtMillis = maxOf(dueAt, nowMillis + RESTORED_ALARM_GRACE_MILLIS),
        )
        return true
    }

    private fun enqueueFired(
        rule: TriggerRule,
        event: TriggerEvent?,
    ) {
        interactions.enqueueOutcome(
            ruleId = rule.id,
            kind = TriggerOutcomeKind.FIRED,
            occurredAtMillis = event?.occurredAtMillis ?: System.currentTimeMillis(),
            eventKey = event?.eventKey,
        )
    }

    private fun firstScheduledAtOrAfter(
        rule: TriggerRule,
        firstFireAtMillis: Long,
        thresholdMillis: Long,
    ): Long? {
        val threshold = maxOf(thresholdMillis, rule.activeFromMillis ?: Long.MIN_VALUE)
        val candidate =
            TriggerAlarmRecurrence.firstAtOrAfter(
                recurrence = rule.recurrence,
                firstFireAtMillis = firstFireAtMillis,
                thresholdMillis = threshold,
                timeZoneId = rule.alarmSchedule?.timeZoneId,
            ) ?: return null
        return candidate.takeIf { rule.activeUntilMillis == null || it < rule.activeUntilMillis }
    }

    private fun nextScheduledAfter(
        rule: TriggerRule,
        scheduledAtMillis: Long,
        nowMillis: Long,
    ): Long? {
        var candidate =
            TriggerAlarmRecurrence.next(
                recurrence = rule.recurrence,
                scheduledAtMillis = scheduledAtMillis,
                timeZoneId = rule.alarmSchedule?.timeZoneId,
            ) ?: return null
        val threshold = maxOf(nowMillis, rule.activeFromMillis ?: Long.MIN_VALUE)
        while (candidate < threshold) {
            candidate =
                TriggerAlarmRecurrence.next(
                    recurrence = rule.recurrence,
                    scheduledAtMillis = candidate,
                    timeZoneId = rule.alarmSchedule?.timeZoneId,
                ) ?: return null
        }
        return candidate.takeIf { rule.activeUntilMillis == null || it < rule.activeUntilMillis }
    }

    private fun hasLocationPermission(): Boolean {
        val foreground =
            applicationContext.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) ==
                PackageManager.PERMISSION_GRANTED
        val background =
            Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
                applicationContext.checkSelfPermission(
                    Manifest.permission.ACCESS_BACKGROUND_LOCATION,
                ) == PackageManager.PERMISSION_GRANTED
        return foreground && background
    }

    private fun geofencePendingIntent(): PendingIntent =
        PendingIntent.getBroadcast(
            applicationContext,
            GEOFENCE_REQUEST_CODE,
            Intent(applicationContext, TriggerGeofenceReceiver::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
        )

    private fun saturatedAdd(
        left: Long,
        right: Long,
    ): Long = if (right > Long.MAX_VALUE - left) Long.MAX_VALUE else left + right

    companion object {
        private const val GEOFENCE_REQUEST_CODE = 4210
        private const val MAX_GEOFENCES = 100
        private const val RESTORED_ALARM_GRACE_MILLIS = 1_000L
        private const val NOTIFICATION_RETRY_MILLIS = 60 * 60 * 1_000L
    }
}
