const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

exports.sendCallNotification = functions.https.onRequest(async (req, res) => {
  const { fcmToken, title, body, data } = req.body;

  if (!fcmToken || !title || !body) {
    return res.status(400).send("Missing parameters");
  }

  const message = {
    token: fcmToken,
    notification: {
      title,
      body,
    },
    data: data || {}, // Optional call metadata
    android: {
      priority: "high",
      notification: {
        sound: "default",
        channelId: "call_channel",
        visibility: "public",
        clickAction: "FLUTTER_NOTIFICATION_CLICK",
      },
    },
  };

  try {
    await admin.messaging().send(message);
    return res.status(200).send("Notification sent");
  } catch (error) {
    console.error("Error sending FCM:", error);
    return res.status(500).send("FCM send error");
  }
});
