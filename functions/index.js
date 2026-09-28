const { initializeApp } = require("firebase-admin/app");
const { getMessaging } = require("firebase-admin/messaging");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { onDocumentCreated, onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { logger } = require("firebase-functions");
const { recentShifts, SCHEDULE_TIME_ZONE } = require("./scheduleTime");

initializeApp();

// Mirrors MainBase/Models/NotificationType.swift. Keep both in sync.
const NOTIFICATION_TYPES = Object.freeze({
  CLOCK_EVENT: "clock_event",
  TASK_ASSIGNED: "task_assigned",
  SUBTASK_ASSIGNED: "subtask_assigned",
  ADDED_TO_PROJECT: "added_to_project",
  TASK_COMPLETED: "task_completed",
  SUBTASK_COMPLETED: "subtask_completed",
  CHAT_MESSAGE: "chat_message",
  REPORT_MESSAGE: "report_message",
  SCHEDULE_REMINDER: "schedule_reminder",
});

// Mirrors the ClockAction enum in MainBase/Models/NotificationType.swift.
const CLOCK_ACTIONS = Object.freeze({
  CLOCK_IN: "clock_in",
  CLOCK_OUT: "clock_out",
});

// Mirrors formattedDisplayName in MainBase/Utilities/PersonDisplayName.swift: "Sarah" + "Kim" -> "Sarah K.".
function formatDisplayName(name, surname) {
  const safeName = typeof name === "string" && name.trim().length > 0 ? name.trim() : "Someone";
  const trimmedSurname = typeof surname === "string" ? surname.trim() : "";
  if (!trimmedSurname) return safeName;
  return `${safeName} ${trimmedSurname.charAt(0)}.`;
}

function isExpoPushToken(token) {
  return (
    typeof token === "string" &&
    (token.startsWith("ExponentPushToken[") || token.startsWith("ExpoPushToken["))
  );
}

function chunkArray(items, size) {
  const chunks = [];
  for (let i = 0; i < items.length; i += size) {
    chunks.push(items.slice(i, i + size));
  }
  return chunks;
}

async function sendExpoPushNotifications(tokens, notificationPayload) {
  const chunks = chunkArray(tokens, 100); // Expo API max 100 messages/request.
  let successCount = 0;
  let failureCount = 0;
  const errors = [];

  for (const tokenChunk of chunks) {
    const messages = tokenChunk.map((token) => ({
      to: token,
      sound: "default",
      title: notificationPayload.title || "MainBase",
      body: notificationPayload.body || "You have a new notification.",
      data: notificationPayload.data || {},
    }));

    const response = await fetch("https://exp.host/--/api/v2/push/send", {
      method: "POST",
      headers: {
        Accept: "application/json",
        "Accept-encoding": "gzip, deflate",
        "Content-Type": "application/json",
      },
      body: JSON.stringify(messages),
    });

    if (!response.ok) {
      failureCount += tokenChunk.length;
      errors.push(`Expo API request failed with status ${response.status}`);
      continue;
    }

    const json = await response.json();
    const results = Array.isArray(json?.data) ? json.data : [];
    for (const result of results) {
      if (result?.status === "ok") {
        successCount += 1;
      } else {
        failureCount += 1;
        if (result?.message) {
          errors.push(result.message);
        }
      }
    }
  }

  return { successCount, failureCount, errors };
}

async function readRecipientTokens(recipientUserId) {
  const db = getFirestore();
  const fcmTokens = new Set();
  const expoPushTokens = new Set();

  const userSnap = await db.collection("users").doc(recipientUserId).get();
  if (userSnap.exists) {
    const userData = userSnap.data() || {};

    if (typeof userData.fcmToken === "string" && userData.fcmToken.trim().length > 0) {
      fcmTokens.add(userData.fcmToken);
    }

    if (Array.isArray(userData.fcmTokens)) {
      userData.fcmTokens
        .filter((token) => typeof token === "string" && token.trim().length > 0)
        .forEach((token) => fcmTokens.add(token));
    }

    if (typeof userData.expoPushToken === "string" && isExpoPushToken(userData.expoPushToken)) {
      expoPushTokens.add(userData.expoPushToken);
    }

    if (Array.isArray(userData.expoPushTokens)) {
      userData.expoPushTokens
        .filter((token) => isExpoPushToken(token))
        .forEach((token) => expoPushTokens.add(token));
    }
  }

  const tokenCollection = await db
    .collection("users")
    .doc(recipientUserId)
    .collection("fcmTokens")
    .get();

  tokenCollection.docs.forEach((doc) => {
    const data = doc.data() || {};
    if (typeof data.token === "string" && data.token.trim().length > 0) {
      fcmTokens.add(data.token);
    }
  });

  const expoTokenCollection = await db
    .collection("users")
    .doc(recipientUserId)
    .collection("expoPushTokens")
    .get();

  expoTokenCollection.docs.forEach((doc) => {
    const data = doc.data() || {};
    if (isExpoPushToken(data.token)) {
      expoPushTokens.add(data.token);
    }
  });

  return {
    fcmTokens: [...fcmTokens],
    expoPushTokens: [...expoPushTokens],
  };
}

// Looks up users by email (case-insensitive) in a single collection scan, so
// project-notification triggers can resolve an assigneeEmail/teamMembers entry
// to the uid + display name needed to write a notification. The user base is
// small enough that a full scan matches the pattern already used for the
// clock-event fan-out below.
async function lookupUsersByEmail(emails) {
  const wanted = new Set(
    emails.map((email) => (typeof email === "string" ? email.trim().toLowerCase() : "")).filter(Boolean)
  );
  const result = new Map();
  if (wanted.size === 0) return result;

  const db = getFirestore();
  const usersSnap = await db.collection("users").get();
  usersSnap.docs.forEach((doc) => {
    const data = doc.data() || {};
    const email = typeof data.email === "string" ? data.email.trim().toLowerCase() : "";
    if (email && wanted.has(email)) {
      result.set(email, {
        uid: doc.id,
        name: typeof data.name === "string" && data.name.trim().length > 0 ? formatDisplayName(data.name, data.surname) : email,
      });
    }
  });
  return result;
}

// All admin users, for the "admin sees every task action" notification rule.
async function getAdminUsers() {
  const db = getFirestore();
  const snap = await db.collection("users").where("admin", "==", true).get();
  return snap.docs.map((doc) => {
    const data = doc.data() || {};
    return { uid: doc.id, name: formatDisplayName(data.name, data.surname) };
  });
}

// Notifies every admin about a task/subtask action, skipping anyone in `excludeUids`
// (typically the actor and/or whoever already got the primary/personalized notification,
// so an admin doesn't get double-pinged for the same event).
async function notifyAdmins({ excludeUids, type, title, body, actorUserId, actorName, extra }) {
  const admins = await getAdminUsers();
  const exclude = new Set((excludeUids || []).filter(Boolean));
  await Promise.all(
    admins
      .filter((admin) => !exclude.has(admin.uid))
      .map((admin) => notifyUser({ recipientUserId: admin.uid, type, title, body, actorUserId, actorName, extra }))
  );
}

// Writes a notification doc for one recipient. The sendUserNotificationPush
// trigger below picks this up and delivers the push.
async function notifyUser({ recipientUserId, type, title, body, action, actorUserId, actorName, extra }) {
  const db = getFirestore();
  await db
    .collection("users")
    .doc(recipientUserId)
    .collection("notifications")
    .add({
      type,
      title,
      body,
      action: action || null,
      actorUserId: actorUserId || null,
      actorName: actorName || null,
      recipientUserId,
      createdAt: new Date(),
      read: false,
      ...(extra || {}),
    });
}

exports.sendUserNotificationPush = onDocumentCreated(
  "users/{recipientUserId}/notifications/{notificationId}",
  async (event) => {
    const recipientUserId = event.params.recipientUserId;

    const snapshot = event.data;
    if (!snapshot) {
      logger.warn("No notification snapshot data found.");
      return;
    }

    const notification = snapshot.data() || {};
    if (!Object.values(NOTIFICATION_TYPES).includes(notification.type)) {
      return;
    }

    const { fcmTokens, expoPushTokens } = await readRecipientTokens(recipientUserId);
    if (fcmTokens.length === 0 && expoPushTokens.length === 0) {
      logger.warn(`No push tokens found for recipient: ${recipientUserId}`);
      return;
    }

    const payload = {
      title: notification.title || "MainBase",
      body: notification.body || "You have a new notification.",
      data: {
        type: String(notification.type || ""),
        action: String(notification.action || ""),
        actorUserId: String(notification.actorUserId || ""),
        actorName: String(notification.actorName || ""),
        report: String(notification.report || ""),
        projectId: String(notification.projectId || ""),
        taskId: String(notification.taskId || ""),
        reportId: String(notification.reportId || ""),
        reportOwnerId: String(notification.reportOwnerId || ""),
      },
    };

    let fcmResponse = null;
    if (fcmTokens.length > 0) {
      const message = {
        tokens: fcmTokens,
        notification: {
          title: payload.title,
          body: payload.body,
        },
        data: payload.data,
        apns: {
          payload: {
            aps: {
              sound: "default",
            },
          },
        },
        android: {
          priority: "high",
          notification: {
            sound: "default",
            channelId: "default",
          },
        },
      };
      fcmResponse = await getMessaging().sendEachForMulticast(message);
    }

    let expoResponse = null;
    if (expoPushTokens.length > 0) {
      expoResponse = await sendExpoPushNotifications(expoPushTokens, payload);
    }

    logger.info("Notification push send result", {
      type: notification.type,
      fcmSuccessCount: fcmResponse?.successCount || 0,
      fcmFailureCount: fcmResponse?.failureCount || 0,
      expoSuccessCount: expoResponse?.successCount || 0,
      expoFailureCount: expoResponse?.failureCount || 0,
      expoErrors: expoResponse?.errors?.slice(0, 5) || [],
      fcmTokenCount: fcmTokens.length,
      expoTokenCount: expoPushTokens.length,
      recipientUserId,
      notificationId: event.params.notificationId,
    });
  }
);

exports.createClockEventNotification = onCall(async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }

  const { actorUserId, action, report } = request.data || {};
  if (typeof actorUserId !== "string" || actorUserId.trim().length === 0) {
    throw new HttpsError("invalid-argument", "actorUserId is required.");
  }

  if (request.auth.uid !== actorUserId) {
    throw new HttpsError("permission-denied", "You can only notify for your own clock events.");
  }

  if (action !== CLOCK_ACTIONS.CLOCK_IN && action !== CLOCK_ACTIONS.CLOCK_OUT) {
    throw new HttpsError("invalid-argument", "action must be clock_in or clock_out.");
  }

  const reportText = typeof report === "string" ? report.trim() : "";
  return fanOutClockEvent({ actorUserId, action, reportText });
});

// Writes a "Clock Update" notification to everyone who should hear about actorUserId's
// clock event. Shared by the client-called createClockEventNotification and the scheduled
// automatic clock-out in enforceClockSchedules.
async function fanOutClockEvent({ actorUserId, action, reportText }) {
  const db = getFirestore();
  const actorSnap = await db.collection("users").doc(actorUserId).get();
  const actorData = actorSnap.exists ? actorSnap.data() || {} : {};
  const actorName = formatDisplayName(actorData.name, actorData.surname);
  const actionLabel = action === CLOCK_ACTIONS.CLOCK_IN ? "clocked in" : "clocked out";
  const notificationBody =
    action === CLOCK_ACTIONS.CLOCK_OUT && reportText.length > 0
      ? `${actorName} clocked out: ${reportText}`
      : `${actorName} ${actionLabel}`;
  const allUsersSnap = await db.collection("users").get();

  // Non-admins only hear about a coworker's clock activity while clocked in themselves.
  // Admins instead pick an explicit preference (Profile > Clock Notifications): "all"
  // (every clock event regardless of their own status) or "none" (opt out entirely).
  const recipientDocs = allUsersSnap.docs.filter((doc) => {
    if (doc.id === actorUserId) return false;
    const data = doc.data() || {};
    if (data.admin === true) {
      return (data.clockNotificationPreference || "all") !== "none";
    }
    return data.isOnline === true;
  });

  if (recipientDocs.length === 0) {
    logger.warn("No users found to notify for clock event.", {
      actorUserId,
      action,
    });
    return { success: true, notificationCount: 0 };
  }

  const notificationWrites = recipientDocs.map((userDoc) =>
    db
      .collection("users")
      .doc(userDoc.id)
      .collection("notifications")
      .add({
        type: NOTIFICATION_TYPES.CLOCK_EVENT,
        title: "Clock Update",
        body: notificationBody,
        action,
        actorUserId,
        actorName,
        report: reportText,
        recipientUserId: userDoc.id,
        createdAt: new Date(),
        read: false,
      })
  );

  const notificationRefs = await Promise.all(notificationWrites);

  logger.info("Clock event notification created", {
    actorUserId,
    action,
    notificationCount: notificationRefs.length,
    recipientUserIds: recipientDocs.map((doc) => doc.id),
  });

  return {
    success: true,
    notificationCount: notificationRefs.length,
    notificationIds: notificationRefs.map((ref) => ref.id),
  };
}

exports.setEmployeeStatus = onCall(async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }

  const { targetUserId, isEmployed } = request.data || {};
  if (typeof targetUserId !== "string" || targetUserId.trim().length === 0) {
    throw new HttpsError("invalid-argument", "targetUserId is required.");
  }
  if (typeof isEmployed !== "boolean") {
    throw new HttpsError("invalid-argument", "isEmployed must be a boolean.");
  }

  const db = getFirestore();
  const callerSnap = await db.collection("users").doc(request.auth.uid).get();
  const callerData = callerSnap.exists ? callerSnap.data() || {} : {};

  if (callerData.admin !== true) {
    throw new HttpsError("permission-denied", "Only admins can update employment status.");
  }

  const targetSnap = await db.collection("users").doc(targetUserId).get();
  if (!targetSnap.exists) {
    throw new HttpsError("not-found", "Target user was not found.");
  }
  const targetData = targetSnap.data() || {};

  if (targetData.company !== callerData.company) {
    throw new HttpsError("permission-denied", "You can only update employees within your own company.");
  }

  await db.collection("users").doc(targetUserId).update({ isEmployed });

  logger.info("Employee status updated", {
    adminUserId: request.auth.uid,
    targetUserId,
    isEmployed,
  });

  return { success: true };
});

// ---------------- Gemini prompt ----------------
// The API key is read from functions/.env (GEMINI_API_KEY=...), which is gitignored and loaded by
// the Firebase CLI at deploy time, so it never ships inside the app binary or lands in git.
// Models are tried in order, moving to the next only when one answers 503 (overloaded). Flash-lite
// is first because it answers in ~2s and has stayed available while the full Flash models were
// frequently overloaded; "gemini-flash-latest" is the fallback. If Google retires a model, the
// error log names its replacement.
const GEMINI_MODELS = ["gemini-3.5-flash-lite", "gemini-flash-latest"];
const GEMINI_MAX_PROMPT_LENGTH = 8000;

// Cap on the clock-out reports text fed into one monthly summary, to bound cost and latency.
const SUMMARY_MAX_REPORTS_LENGTH = 30000;
const MAX_MONTH_RANGE_MS = 32 * 24 * 60 * 60 * 1000;

// Sends one prompt to Gemini and returns its text, trying GEMINI_MODELS in order. Throws an
// HttpsError the app can show as-is.
async function generateWithGemini(prompt, uid) {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    logger.error("GEMINI_API_KEY is not set. Add it to functions/.env and redeploy.");
    throw new HttpsError("failed-precondition", "Gemini is not configured.");
  }

  const callGemini = (model) =>
    fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-goog-api-key": apiKey,
      },
      body: JSON.stringify({ contents: [{ role: "user", parts: [{ text: prompt }] }] }),
    });

  let response;
  let model;
  for (model of GEMINI_MODELS) {
    response = await callGemini(model);
    if (response.status !== 503) break;
    logger.warn("Gemini model overloaded, trying next", { model });
  }

  if (!response.ok) {
    const errorText = await response.text();
    logger.error("Gemini request failed", { model, status: response.status, error: errorText.slice(0, 500), uid });
    if (response.status === 503) {
      throw new HttpsError("unavailable", "Gemini is busy right now. Please try again in a moment.");
    }
    if (response.status === 429) {
      throw new HttpsError("resource-exhausted", "Gemini usage limit reached. Please try again later.");
    }
    throw new HttpsError("internal", "Gemini could not answer right now.");
  }

  const json = await response.json();
  const text = (json?.candidates?.[0]?.content?.parts || [])
    .map((part) => part?.text || "")
    .join("")
    .trim();

  if (!text) {
    logger.warn("Gemini returned no text", { finishReason: json?.candidates?.[0]?.finishReason, uid });
    throw new HttpsError("internal", "Gemini returned an empty response.");
  }

  return text;
}

// Free-form prompt from the admin-only Gemini tab. Checked here too, since hiding the tab
// doesn't stop a signed-in client from calling the function.
exports.askGemini = onCall({ timeoutSeconds: 120 }, async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }

  const callerSnap = await getFirestore().collection("users").doc(request.auth.uid).get();
  if (callerSnap.data()?.admin !== true) {
    throw new HttpsError("permission-denied", "Only admins can use Gemini.");
  }

  const prompt = typeof request.data?.prompt === "string" ? request.data.prompt.trim() : "";
  if (!prompt) {
    throw new HttpsError("invalid-argument", "prompt is required.");
  }
  if (prompt.length > GEMINI_MAX_PROMPT_LENGTH) {
    throw new HttpsError("invalid-argument", `prompt must be ${GEMINI_MAX_PROMPT_LENGTH} characters or fewer.`);
  }

  return { text: await generateWithGemini(prompt, request.auth.uid) };
});

// "Summarize this month" in ReportsListView: a Gemini-written report of the caller's own month,
// built from their clock-out reports and history. Reads only the caller's data, so any
// signed-in user may call it. monthStart/monthEnd are epoch ms of the month as the app shows
// it (device calendar); monthTitle is its label, e.g. "September 2026".
exports.summarizeMonth = onCall({ timeoutSeconds: 120 }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }

  const { monthStart, monthEnd, monthTitle } = request.data || {};
  if (
    !Number.isFinite(monthStart) ||
    !Number.isFinite(monthEnd) ||
    monthEnd <= monthStart ||
    monthEnd - monthStart > MAX_MONTH_RANGE_MS
  ) {
    throw new HttpsError("invalid-argument", "monthStart and monthEnd must span one month.");
  }
  const title = typeof monthTitle === "string" && monthTitle.trim() ? monthTitle.trim() : "this month";
  const start = new Date(monthStart);
  const end = new Date(monthEnd);

  const db = getFirestore();
  const userRef = db.collection("users").doc(uid);
  const [userSnap, reportsSnap, historySnap] = await Promise.all([
    userRef.get(),
    userRef.collection("reports").where("timestamp", ">=", start).where("timestamp", "<", end).orderBy("timestamp").get(),
    userRef.collection("history").where("clockOut", ">=", start).where("clockOut", "<", end).get(),
  ]);

  const reports = reportsSnap.docs
    .map((doc) => doc.data() || {})
    .filter((data) => typeof data.reportText === "string" && data.reportText.trim().length > 0);
  if (reports.length === 0) {
    throw new HttpsError("failed-precondition", `You have no reports in ${title} to summarize.`);
  }

  const userData = userSnap.data() || {};
  const name = formatDisplayName(userData.name, userData.surname);
  const totalMs = historySnap.docs.reduce((sum, doc) => sum + (Number(doc.data()?.durationMs) || 0), 0);
  const shiftCount = historySnap.size;

  const reportLines = reports
    .map((data) => {
      const day =
        data.timestamp?.toDate?.().toLocaleDateString("en-US", {
          timeZone: SCHEDULE_TIME_ZONE,
          weekday: "short",
          month: "short",
          day: "numeric",
        }) || "unknown date";
      return `- ${day}: ${data.reportText.trim()}`;
    })
    .join("\n")
    .slice(0, SUMMARY_MAX_REPORTS_LENGTH);

  const prompt = [
    `You are writing a monthly work report for ${name}, an employee, covering ${title}.`,
    `They worked ${shiftCount} shift${shiftCount === 1 ? "" : "s"} totaling ${formatDuration(totalMs)} this month.`,
    "Below are their end-of-shift reports, one per line with the date.",
    "",
    "Write the report in the second person (\"you\") with these sections, each title in bold on its own line:",
    "**Overview** – two or three sentences on the month as a whole.",
    "**Key accomplishments** – bullet points (\"- \") of the most important work.",
    "**Recurring work** – bullet points of tasks or areas that came up repeatedly.",
    "**Hours** – one line with the shift count and total hours given above.",
    "Use only what the reports say; do not invent projects, numbers or outcomes. Do not use # headings.",
    "",
    "Reports:",
    reportLines,
  ].join("\n");

  return { text: await generateWithGemini(prompt, uid) };
});

// ---------------- scheduled clock enforcement ----------------
// Timing is measured from the admin-set schedule (users/{uid}/employment/terms), always in US
// Pacific time (SCHEDULE_TIME_ZONE in scheduleTime.js). The app
// separately snaps a clock-in made within 30 minutes of the scheduled start back to the
// start (TimeTrackerViewModel.clockIn).
const CLOCK_IN_REMINDER_DELAY_MS = 15 * 60 * 1000; // after scheduled start
const CLOCK_OUT_REMINDER_DELAY_MS = 30 * 60 * 1000; // after scheduled end
const AUTO_CLOCK_OUT_DELAY_MS = 90 * 60 * 1000; // after scheduled end (1h after the reminder)
// A session only counts toward a shift if it started no earlier than this before the shift's
// start, so an evening or stale session isn't credited up to the next shift's end. Mirrors
// EmploymentTerms.earlyClockInAllowance in the app, which leaves other sessions to the 8-hour cap.
const EARLY_CLOCK_IN_ALLOWANCE_MS = 4 * 60 * 60 * 1000;
const AUTO_CLOCK_OUT_REPORT = "Automatically clocked out at scheduled end time (no report written).";

function formatDuration(ms) {
  const totalMinutes = Math.floor(ms / 60000);
  return `${Math.floor(totalMinutes / 60)}h ${totalMinutes % 60}m`;
}

async function sendScheduleReminder(userId, action, body) {
  await notifyUser({
    recipientUserId: userId,
    type: NOTIFICATION_TYPES.SCHEDULE_REMINDER,
    title: "Clock Reminder",
    body,
    action,
  });
}

// Clocks the user out as of `clockOutAt`, mirroring TimeTrackerViewModel.clockOut. Runs in a
// transaction so it no-ops if the user clocked out (or back in) since we read their doc.
// Returns true if this call did the clock-out.
async function autoClockOut(userId, expectedClockIn, clockOutAt) {
  const db = getFirestore();
  const userRef = db.collection("users").doc(userId);

  const didClockOut = await db.runTransaction(async (tx) => {
    const snap = await tx.get(userRef);
    const data = snap.data() || {};
    const currentClockIn = data.clockInTime?.toDate?.();
    if (data.isOnline !== true || !currentClockIn || currentClockIn.getTime() !== expectedClockIn.getTime()) {
      return false;
    }

    const durationMs = clockOutAt.getTime() - expectedClockIn.getTime();
    tx.update(userRef, {
      isOnline: false,
      clockInTime: FieldValue.delete(),
      lastClockOut: clockOutAt,
    });
    tx.set(userRef.collection("history").doc(), {
      clockIn: expectedClockIn,
      clockOut: clockOutAt,
      durationMs,
      durationFormatted: formatDuration(durationMs),
      report: AUTO_CLOCK_OUT_REPORT,
      autoClockedOut: true,
      createdAt: new Date(),
    });
    tx.set(userRef.collection("reports").doc(), {
      reportText: AUTO_CLOCK_OUT_REPORT,
      timestamp: clockOutAt,
    });
    return true;
  });

  if (didClockOut) {
    await fanOutClockEvent({ actorUserId: userId, action: CLOCK_ACTIONS.CLOCK_OUT, reportText: AUTO_CLOCK_OUT_REPORT });
  }
  return didClockOut;
}

async function enforceScheduleForUser(userId, userData, terms, state, now) {
  const stateUpdate = {};
  const nowMs = now.getTime();
  const clockIn = userData.clockInTime?.toDate?.() || null;
  const lastClockOut = userData.lastClockOut?.toDate?.() || null;

  for (const shift of recentShifts(terms, now)) {
    const startMs = shift.start.getTime();
    const endMs = shift.end.getTime();

    // Still clocked in past the end of this shift.
    const sessionBelongsToShift =
      userData.isOnline === true &&
      clockIn &&
      clockIn.getTime() >= startMs - EARLY_CLOCK_IN_ALLOWANCE_MS &&
      clockIn.getTime() < endMs;
    if (sessionBelongsToShift) {
      if (nowMs >= endMs + AUTO_CLOCK_OUT_DELAY_MS) {
        const didClockOut = await autoClockOut(userId, clockIn, shift.end);
        if (didClockOut) logger.info("Auto clocked out at scheduled end", { userId, shift: shift.key });
        break; // The session is over; later shifts see stale userData.
      }
      if (nowMs >= endMs + CLOCK_OUT_REMINDER_DELAY_MS && state.clockOutReminderShift !== shift.key) {
        await sendScheduleReminder(userId, CLOCK_ACTIONS.CLOCK_OUT, "Did you forget to clock out and write your report?");
        stateUpdate.clockOutReminderShift = shift.key;
      }
    }

    // Not clocked in 15 minutes after the start, and hasn't already worked part of this shift.
    const workedThisShift = userData.isOnline === true || (lastClockOut && lastClockOut.getTime() >= startMs);
    if (
      !workedThisShift &&
      nowMs >= startMs + CLOCK_IN_REMINDER_DELAY_MS &&
      nowMs < endMs &&
      state.clockInReminderShift !== shift.key
    ) {
      await sendScheduleReminder(userId, CLOCK_ACTIONS.CLOCK_IN, "Did you forget to clock in?");
      stateUpdate.clockInReminderShift = shift.key;
    }
  }

  if (Object.keys(stateUpdate).length > 0) {
    await getFirestore()
      .collection("users")
      .doc(userId)
      .collection("employment")
      .doc("scheduleState")
      .set({ ...stateUpdate, updatedAt: now }, { merge: true });
  }
}

// Every 5 minutes: remind scheduled employees who haven't clocked in/out, and clock out anyone
// still clocked in 90 minutes past their scheduled end (recorded at the scheduled end time).
exports.enforceClockSchedules = onSchedule("every 5 minutes", async () => {
  const db = getFirestore();
  const now = new Date();
  const employmentSnap = await db.collectionGroup("employment").get();

  const termsByUser = new Map();
  const stateByUser = new Map();
  employmentSnap.docs.forEach((doc) => {
    const userId = doc.ref.parent.parent?.id;
    if (!userId) return;
    if (doc.id === "terms") termsByUser.set(userId, doc.data() || {});
    if (doc.id === "scheduleState") stateByUser.set(userId, doc.data() || {});
  });

  const userIds = [...termsByUser.keys()];
  if (userIds.length === 0) return;

  const userSnaps = await db.getAll(...userIds.map((userId) => db.collection("users").doc(userId)));
  for (const userSnap of userSnaps) {
    const userData = userSnap.data();
    if (!userData || userData.isEmployed !== true) continue;
    try {
      await enforceScheduleForUser(
        userSnap.id,
        userData,
        termsByUser.get(userSnap.id),
        stateByUser.get(userSnap.id) || {},
        now
      );
    } catch (error) {
      logger.error("Schedule enforcement failed for user", { userId: userSnap.id, error: error.message });
    }
  }
});

// Fires when a task's assigneeEmail is set or changed. Notifies only the
// (newly) assigned person, and skips the write entirely if they assigned the
// task to themselves.
exports.onProjectTaskAssigneeChanged = onDocumentWritten(
  "projects/{projectId}/tasks/{taskId}",
  async (event) => {
    const after = event.data?.after?.exists ? event.data.after.data() : null;
    if (!after) return; // deleted

    const before = event.data?.before?.exists ? event.data.before.data() : null;
    const newAssignee = (after.assigneeEmail || "").trim().toLowerCase();
    const oldAssignee = (before?.assigneeEmail || "").trim().toLowerCase();
    if (!newAssignee || newAssignee === oldAssignee) return;

    const assignedByEmail = (after.assignedByEmail || "").trim().toLowerCase();
    const isSelfAssign = Boolean(assignedByEmail) && assignedByEmail === newAssignee;

    const { projectId, taskId } = event.params;
    const db = getFirestore();
    const [usersByEmail, projectSnap] = await Promise.all([
      lookupUsersByEmail([newAssignee, assignedByEmail]),
      db.collection("projects").doc(projectId).get(),
    ]);

    const recipient = usersByEmail.get(newAssignee);
    const actor = assignedByEmail ? usersByEmail.get(assignedByEmail) : null;
    const actorName = actor?.name || "Someone";
    const projectTitle = projectSnap.exists ? projectSnap.data()?.projectTitle || "a project" : "a project";
    const taskTitle = after.title || "a task";

    if (recipient && !isSelfAssign) {
      await notifyUser({
        recipientUserId: recipient.uid,
        type: NOTIFICATION_TYPES.TASK_ASSIGNED,
        title: "New task assigned",
        body: `${actorName} assigned you "${taskTitle}" in ${projectTitle}`,
        actorUserId: actor?.uid,
        actorName,
        extra: { projectId, taskId },
      });
    } else if (!recipient) {
      logger.warn("No user found for assigned task email.", { projectId, taskId, newAssignee });
    }

    await notifyAdmins({
      excludeUids: [recipient?.uid, actor?.uid],
      type: NOTIFICATION_TYPES.TASK_ASSIGNED,
      title: "Task assignment",
      body: `${actorName} assigned "${taskTitle}" to ${recipient?.name || newAssignee} in ${projectTitle}`,
      actorUserId: actor?.uid,
      actorName,
      extra: { projectId, taskId },
    });
  }
);

// Same as onProjectTaskAssigneeChanged but for subtasks.
exports.onProjectSubtaskAssigneeChanged = onDocumentWritten(
  "projects/{projectId}/tasks/{taskId}/subtasks/{subtaskId}",
  async (event) => {
    const after = event.data?.after?.exists ? event.data.after.data() : null;
    if (!after) return; // deleted

    const before = event.data?.before?.exists ? event.data.before.data() : null;
    const newAssignee = (after.assigneeEmail || "").trim().toLowerCase();
    const oldAssignee = (before?.assigneeEmail || "").trim().toLowerCase();
    if (!newAssignee || newAssignee === oldAssignee) return;

    const assignedByEmail = (after.assignedByEmail || "").trim().toLowerCase();
    const isSelfAssign = Boolean(assignedByEmail) && assignedByEmail === newAssignee;

    const { projectId, taskId, subtaskId } = event.params;
    const db = getFirestore();
    const [usersByEmail, projectSnap, taskSnap] = await Promise.all([
      lookupUsersByEmail([newAssignee, assignedByEmail]),
      db.collection("projects").doc(projectId).get(),
      db.collection("projects").doc(projectId).collection("tasks").doc(taskId).get(),
    ]);

    const recipient = usersByEmail.get(newAssignee);
    const actor = assignedByEmail ? usersByEmail.get(assignedByEmail) : null;
    const actorName = actor?.name || "Someone";
    const projectTitle = projectSnap.exists ? projectSnap.data()?.projectTitle || "a project" : "a project";
    const parentTaskTitle = taskSnap.exists ? taskSnap.data()?.title || "a task" : "a task";
    const subtaskTitle = after.title || "a subtask";

    if (recipient && !isSelfAssign) {
      await notifyUser({
        recipientUserId: recipient.uid,
        type: NOTIFICATION_TYPES.SUBTASK_ASSIGNED,
        title: "New subtask assigned",
        body: `${actorName} assigned you "${subtaskTitle}" (${parentTaskTitle}) in ${projectTitle}`,
        actorUserId: actor?.uid,
        actorName,
        extra: { projectId, taskId, subtaskId },
      });
    } else if (!recipient) {
      logger.warn("No user found for assigned subtask email.", { projectId, taskId, subtaskId, newAssignee });
    }

    await notifyAdmins({
      excludeUids: [recipient?.uid, actor?.uid],
      type: NOTIFICATION_TYPES.SUBTASK_ASSIGNED,
      title: "Subtask assignment",
      body: `${actorName} assigned "${subtaskTitle}" (${parentTaskTitle}) to ${recipient?.name || newAssignee} in ${projectTitle}`,
      actorUserId: actor?.uid,
      actorName,
      extra: { projectId, taskId, subtaskId },
    });
  }
);

// Fires when a project is created or edited and teamMembers gains new
// entries. Notifies only the newly added members, not the whole roster.
exports.onProjectTeamMembersChanged = onDocumentWritten(
  "projects/{projectId}",
  async (event) => {
    const after = event.data?.after?.exists ? event.data.after.data() : null;
    if (!after) return; // deleted

    const before = event.data?.before?.exists ? event.data.before.data() : null;
    const beforeMembers = new Set(
      (before?.teamMembers || []).map((email) => (email || "").trim().toLowerCase())
    );
    const afterMembers = [...new Set((after.teamMembers || []).map((email) => (email || "").trim().toLowerCase()))];

    const addedByEmail = (after.lastEditedByEmail || after.projectLead || "").trim().toLowerCase();
    const newMembers = afterMembers.filter((email) => email && !beforeMembers.has(email) && email !== addedByEmail);
    if (newMembers.length === 0) return;

    const { projectId } = event.params;
    const usersByEmail = await lookupUsersByEmail([...newMembers, addedByEmail]);

    const actor = addedByEmail ? usersByEmail.get(addedByEmail) : null;
    const actorName = actor?.name || "Someone";
    const projectTitle = after.projectTitle || "a project";

    await Promise.all(
      newMembers.map((email) => {
        const recipient = usersByEmail.get(email);
        if (!recipient) {
          logger.warn("No user found for added team member email.", { projectId, email });
          return null;
        }
        return notifyUser({
          recipientUserId: recipient.uid,
          type: NOTIFICATION_TYPES.ADDED_TO_PROJECT,
          title: "Added to project",
          body: `${actorName} added you to ${projectTitle}`,
          actorUserId: actor?.uid,
          actorName,
          extra: { projectId },
        });
      })
    );
  }
);

// Notifies the rest of a project's team (teamMembers + lead, minus the sender)
// whenever someone posts a new chat message.
exports.onProjectChatMessageCreated = onDocumentCreated(
  "projects/{projectId}/chatMessages/{messageId}",
  async (event) => {
    const message = event.data?.data();
    if (!message) return;

    const { projectId } = event.params;
    const db = getFirestore();
    const projectSnap = await db.collection("projects").doc(projectId).get();
    const project = projectSnap.data();
    if (!project) return;

    const senderEmail = (message.senderEmail || "").trim().toLowerCase();
    const recipientEmails = [...new Set(
      [...(project.teamMembers || []), project.projectLead || ""]
        .map((email) => (email || "").trim().toLowerCase())
        .filter((email) => email && email !== senderEmail)
    )];
    if (recipientEmails.length === 0) return;

    const projectTitle = project.projectTitle || "a project";
    const usersByEmail = await lookupUsersByEmail([...recipientEmails, senderEmail]);
    const sender = usersByEmail.get(senderEmail);
    const senderName = sender?.name || "Someone";
    const text = (message.text || "").trim();
    const truncatedText = text.length > 80 ? `${text.slice(0, 80)}…` : text;

    await Promise.all(
      recipientEmails.map((email) => {
        const recipient = usersByEmail.get(email);
        if (!recipient) return null;
        return notifyUser({
          recipientUserId: recipient.uid,
          type: NOTIFICATION_TYPES.CHAT_MESSAGE,
          title: `New message in ${projectTitle}`,
          body: `${senderName}: ${truncatedText}`,
          actorUserId: sender?.uid,
          actorName: senderName,
          extra: { projectId },
        });
      })
    );
  }
);

// Fires on every message in a report's chat thread (users/{reportOwnerId}/reports/{reportId}/chatMessages).
// Recipients are everyone who has a stake in the thread so far — the report's owner plus
// anyone who has previously sent a message in it — minus whoever just sent this one. That
// covers both directions with one rule: the first message from someone other than the owner
// notifies just the owner (nobody else has spoken yet), and when the owner replies it notifies
// whoever opened the conversation.
exports.onReportChatMessageCreated = onDocumentCreated(
  "users/{reportOwnerId}/reports/{reportId}/chatMessages/{messageId}",
  async (event) => {
    const message = event.data?.data();
    if (!message) return;

    const senderId = typeof message.senderId === "string" ? message.senderId : "";
    if (!senderId) return;
    const senderName = message.senderName || "Someone";

    const { reportOwnerId, reportId } = event.params;
    const db = getFirestore();
    const reportRef = db.collection("users").doc(reportOwnerId).collection("reports").doc(reportId);

    // Running total so the reports list can show a message-count badge without each
    // report needing its own live subcollection listener.
    await reportRef.update({ messageCount: FieldValue.increment(1) }).catch((error) => {
      logger.warn("Failed to increment report messageCount.", { reportOwnerId, reportId, error: String(error) });
    });

    const chatSnap = await reportRef.collection("chatMessages").get();
    const participantIds = new Set();
    chatSnap.docs.forEach((doc) => {
      const id = doc.data()?.senderId;
      if (typeof id === "string" && id) participantIds.add(id);
    });
    participantIds.add(reportOwnerId);
    participantIds.delete(senderId);
    if (participantIds.size === 0) return;

    const text = (message.text || "").trim();
    const truncatedText = text.length > 80 ? `${text.slice(0, 80)}…` : text;

    await Promise.all(
      [...participantIds].map((recipientUserId) =>
        notifyUser({
          recipientUserId,
          type: NOTIFICATION_TYPES.REPORT_MESSAGE,
          title: "New report message",
          body: `${senderName}: ${truncatedText}`,
          actorUserId: senderId,
          actorName: senderName,
          extra: { reportOwnerId, reportId },
        })
      )
    );
  }
);

// Fires when a task's status transitions to completed (whether via the plain
// checkbox or via submitting a proof link). Notifies only the project lead,
// and only about the fact that the task was completed — not the proof-link
// content. Skips notifying the lead if they completed it themselves.
exports.onProjectTaskCompleted = onDocumentWritten(
  "projects/{projectId}/tasks/{taskId}",
  async (event) => {
    const after = event.data?.after?.exists ? event.data.after.data() : null;
    if (!after) return; // deleted

    const before = event.data?.before?.exists ? event.data.before.data() : null;
    const wasCompleted = before?.status === "completed";
    const isCompleted = after.status === "completed";
    if (!isCompleted || wasCompleted) return;

    const { projectId, taskId } = event.params;
    const db = getFirestore();
    const projectSnap = await db.collection("projects").doc(projectId).get();
    if (!projectSnap.exists) return;
    const projectData = projectSnap.data() || {};
    const leadEmail = (projectData.projectLead || "").trim().toLowerCase();
    const completedByEmail = (after.completedByEmail || "").trim().toLowerCase();

    const usersByEmail = await lookupUsersByEmail([leadEmail, completedByEmail]);
    const recipient = leadEmail ? usersByEmail.get(leadEmail) : null;
    const actor = completedByEmail ? usersByEmail.get(completedByEmail) : null;
    const actorName = actor?.name || "Someone";
    const projectTitle = projectData.projectTitle || "a project";
    const taskTitle = after.title || "a task";
    const body = `${actorName} completed "${taskTitle}" in ${projectTitle}`;

    if (recipient && leadEmail !== completedByEmail) {
      await notifyUser({
        recipientUserId: recipient.uid,
        type: NOTIFICATION_TYPES.TASK_COMPLETED,
        title: "Task completed",
        body,
        actorUserId: actor?.uid,
        actorName,
        extra: { projectId, taskId },
      });
    }

    await notifyAdmins({
      excludeUids: [recipient?.uid, actor?.uid],
      type: NOTIFICATION_TYPES.TASK_COMPLETED,
      title: "Task completed",
      body,
      actorUserId: actor?.uid,
      actorName,
      extra: { projectId, taskId },
    });
  }
);

// Same as onProjectTaskCompleted but for subtasks.
exports.onProjectSubtaskCompleted = onDocumentWritten(
  "projects/{projectId}/tasks/{taskId}/subtasks/{subtaskId}",
  async (event) => {
    const after = event.data?.after?.exists ? event.data.after.data() : null;
    if (!after) return; // deleted

    const before = event.data?.before?.exists ? event.data.before.data() : null;
    const wasCompleted = before?.status === "completed";
    const isCompleted = after.status === "completed";
    if (!isCompleted || wasCompleted) return;

    const { projectId, taskId, subtaskId } = event.params;
    const db = getFirestore();
    const [projectSnap, taskSnap] = await Promise.all([
      db.collection("projects").doc(projectId).get(),
      db.collection("projects").doc(projectId).collection("tasks").doc(taskId).get(),
    ]);
    if (!projectSnap.exists) return;
    const projectData = projectSnap.data() || {};
    const leadEmail = (projectData.projectLead || "").trim().toLowerCase();
    const completedByEmail = (after.completedByEmail || "").trim().toLowerCase();

    const usersByEmail = await lookupUsersByEmail([leadEmail, completedByEmail]);
    const recipient = leadEmail ? usersByEmail.get(leadEmail) : null;
    const actor = completedByEmail ? usersByEmail.get(completedByEmail) : null;
    const actorName = actor?.name || "Someone";
    const projectTitle = projectData.projectTitle || "a project";
    const parentTaskTitle = taskSnap.exists ? taskSnap.data()?.title || "a task" : "a task";
    const subtaskTitle = after.title || "a subtask";
    const body = `${actorName} completed "${subtaskTitle}" (${parentTaskTitle}) in ${projectTitle}`;

    if (recipient && leadEmail !== completedByEmail) {
      await notifyUser({
        recipientUserId: recipient.uid,
        type: NOTIFICATION_TYPES.SUBTASK_COMPLETED,
        title: "Subtask completed",
        body,
        actorUserId: actor?.uid,
        actorName,
        extra: { projectId, taskId, subtaskId },
      });
    }

    await notifyAdmins({
      excludeUids: [recipient?.uid, actor?.uid],
      type: NOTIFICATION_TYPES.SUBTASK_COMPLETED,
      title: "Subtask completed",
      body,
      actorUserId: actor?.uid,
      actorName,
      extra: { projectId, taskId, subtaskId },
    });
  }
);
