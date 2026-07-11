const { initializeApp } = require("firebase-admin/app");
const { getMessaging } = require("firebase-admin/messaging");
const { getFirestore } = require("firebase-admin/firestore");
const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { logger } = require("firebase-functions");

initializeApp();

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
      title: notificationPayload.title || "Clock Update",
      body: notificationPayload.body || "A clock event was recorded.",
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

exports.sendClockEventPush = onDocumentCreated(
  "users/{recipientUserId}/notifications/{notificationId}",
  async (event) => {
    const recipientUserId = event.params.recipientUserId;

    const snapshot = event.data;
    if (!snapshot) {
      logger.warn("No notification snapshot data found.");
      return;
    }

    const notification = snapshot.data() || {};
    if (notification.type !== "clock_event") {
      return;
    }

    const { fcmTokens, expoPushTokens } = await readRecipientTokens(recipientUserId);
    if (fcmTokens.length === 0 && expoPushTokens.length === 0) {
      logger.warn(`No push tokens found for recipient: ${recipientUserId}`);
      return;
    }

    const payload = {
      title: notification.title || "Clock Update",
      body: notification.body || "A clock event was recorded.",
      data: {
        type: "clock_event",
        action: String(notification.action || ""),
        actorUserId: String(notification.actorUserId || ""),
        actorName: String(notification.actorName || ""),
        report: String(notification.report || ""),
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

    logger.info("Clock event push send result", {
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

  if (action !== "clock_in" && action !== "clock_out") {
    throw new HttpsError("invalid-argument", "action must be clock_in or clock_out.");
  }

  const reportText = typeof report === "string" ? report.trim() : "";

  const db = getFirestore();
  const actorSnap = await db.collection("users").doc(actorUserId).get();
  const actorData = actorSnap.exists ? actorSnap.data() || {} : {};
  const actorName = typeof actorData.name === "string" ? actorData.name : "Someone";
  const actionLabel = action === "clock_in" ? "clocked in" : "clocked out";
  const notificationBody =
    action === "clock_out" && reportText.length > 0
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
        type: "clock_event",
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

