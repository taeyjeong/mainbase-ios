const { initializeApp } = require("firebase-admin/app");
const { getMessaging } = require("firebase-admin/messaging");
const { getFirestore } = require("firebase-admin/firestore");
const { onDocumentCreated, onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions");

initializeApp();

// Mirrors MainBase/Models/NotificationType.swift. Keep both in sync.
const NOTIFICATION_TYPES = Object.freeze({
  CLOCK_EVENT: "clock_event",
  TASK_ASSIGNED: "task_assigned",
  SUBTASK_ASSIGNED: "subtask_assigned",
  ADDED_TO_PROJECT: "added_to_project",
  TASK_COMPLETED: "task_completed",
  SUBTASK_COMPLETED: "subtask_completed",
});

// Mirrors the ClockAction enum in MainBase/Models/NotificationType.swift.
const CLOCK_ACTIONS = Object.freeze({
  CLOCK_IN: "clock_in",
  CLOCK_OUT: "clock_out",
});

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
        name: typeof data.name === "string" && data.name.trim().length > 0 ? data.name : email,
      });
    }
  });
  return result;
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

  const db = getFirestore();
  const actorSnap = await db.collection("users").doc(actorUserId).get();
  const actorData = actorSnap.exists ? actorSnap.data() || {} : {};
  const actorName = typeof actorData.name === "string" ? actorData.name : "Someone";
  const actionLabel = action === CLOCK_ACTIONS.CLOCK_IN ? "clocked in" : "clocked out";
  const notificationBody =
    action === CLOCK_ACTIONS.CLOCK_OUT && reportText.length > 0
      ? `${actorName} clocked out: ${reportText}`
      : `${actorName} ${actionLabel}`;
  const allUsersSnap = await db.collection("users").get();

  const recipientDocs = allUsersSnap.docs.filter((doc) => doc.id !== actorUserId);

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
});

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
    if (assignedByEmail && assignedByEmail === newAssignee) return; // self-assign

    const { projectId, taskId } = event.params;
    const db = getFirestore();
    const [usersByEmail, projectSnap] = await Promise.all([
      lookupUsersByEmail([newAssignee, assignedByEmail]),
      db.collection("projects").doc(projectId).get(),
    ]);

    const recipient = usersByEmail.get(newAssignee);
    if (!recipient) {
      logger.warn("No user found for assigned task email.", { projectId, taskId, newAssignee });
      return;
    }

    const actor = assignedByEmail ? usersByEmail.get(assignedByEmail) : null;
    const actorName = actor?.name || "Someone";
    const projectTitle = projectSnap.exists ? projectSnap.data()?.projectTitle || "a project" : "a project";
    const taskTitle = after.title || "a task";

    await notifyUser({
      recipientUserId: recipient.uid,
      type: NOTIFICATION_TYPES.TASK_ASSIGNED,
      title: "New task assigned",
      body: `${actorName} assigned you "${taskTitle}" in ${projectTitle}`,
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
    if (assignedByEmail && assignedByEmail === newAssignee) return; // self-assign

    const { projectId, taskId, subtaskId } = event.params;
    const db = getFirestore();
    const [usersByEmail, projectSnap, taskSnap] = await Promise.all([
      lookupUsersByEmail([newAssignee, assignedByEmail]),
      db.collection("projects").doc(projectId).get(),
      db.collection("projects").doc(projectId).collection("tasks").doc(taskId).get(),
    ]);

    const recipient = usersByEmail.get(newAssignee);
    if (!recipient) {
      logger.warn("No user found for assigned subtask email.", { projectId, taskId, subtaskId, newAssignee });
      return;
    }

    const actor = assignedByEmail ? usersByEmail.get(assignedByEmail) : null;
    const actorName = actor?.name || "Someone";
    const projectTitle = projectSnap.exists ? projectSnap.data()?.projectTitle || "a project" : "a project";
    const parentTaskTitle = taskSnap.exists ? taskSnap.data()?.title || "a task" : "a task";
    const subtaskTitle = after.title || "a subtask";

    await notifyUser({
      recipientUserId: recipient.uid,
      type: NOTIFICATION_TYPES.SUBTASK_ASSIGNED,
      title: "New subtask assigned",
      body: `${actorName} assigned you "${subtaskTitle}" (${parentTaskTitle}) in ${projectTitle}`,
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
    if (!leadEmail || leadEmail === completedByEmail) return; // lead completed it themselves

    const usersByEmail = await lookupUsersByEmail([leadEmail, completedByEmail]);
    const recipient = usersByEmail.get(leadEmail);
    if (!recipient) {
      logger.warn("No user found for project lead email.", { projectId, taskId, leadEmail });
      return;
    }

    const actor = completedByEmail ? usersByEmail.get(completedByEmail) : null;
    const actorName = actor?.name || "Someone";
    const projectTitle = projectData.projectTitle || "a project";
    const taskTitle = after.title || "a task";

    await notifyUser({
      recipientUserId: recipient.uid,
      type: NOTIFICATION_TYPES.TASK_COMPLETED,
      title: "Task completed",
      body: `${actorName} completed "${taskTitle}" in ${projectTitle}`,
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
    if (!leadEmail || leadEmail === completedByEmail) return; // lead completed it themselves

    const usersByEmail = await lookupUsersByEmail([leadEmail, completedByEmail]);
    const recipient = usersByEmail.get(leadEmail);
    if (!recipient) {
      logger.warn("No user found for project lead email.", { projectId, taskId, subtaskId, leadEmail });
      return;
    }

    const actor = completedByEmail ? usersByEmail.get(completedByEmail) : null;
    const actorName = actor?.name || "Someone";
    const projectTitle = projectData.projectTitle || "a project";
    const parentTaskTitle = taskSnap.exists ? taskSnap.data()?.title || "a task" : "a task";
    const subtaskTitle = after.title || "a subtask";

    await notifyUser({
      recipientUserId: recipient.uid,
      type: NOTIFICATION_TYPES.SUBTASK_COMPLETED,
      title: "Subtask completed",
      body: `${actorName} completed "${subtaskTitle}" (${parentTaskTitle}) in ${projectTitle}`,
      actorUserId: actor?.uid,
      actorName,
      extra: { projectId, taskId, subtaskId },
    });
  }
);
