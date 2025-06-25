const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

exports.sendCallNotification = functions.https.onRequest(async (req, res) => {
  if (req.method !== 'POST') {
    return res.status(405).send('Method Not Allowed');
  }

  // ✅ Extract callkitId from the request body sent by the Flutter app
  const { fcmToken, callerId, channelId, callkitId } = req.body;

  if (!fcmToken || !callerId || !channelId) {
    console.error("Missing essential parameters: fcmToken, callerId, or channelId.");
    return res.status(400).send("Missing essential parameters for call notification (fcmToken, callerId, channelId)");
  }

  const message = {
    token: fcmToken,
    data: { // ONLY the 'data' field should be present for CallKit
        callerId: callerId,
        channelId: channelId,
        callkitId: callkitId || 'unknown_callkit_id', // ✅ Pass callkitId to FCM data payload
    },
    android: {
        priority: "high", // Ensures timely delivery
    },
    // DO NOT include a 'notification' field here; it would cause duplicate system notifications.
    // notification: { ... }
  };

  try {
    const response = await admin.messaging().send(message);
    console.log("Successfully sent FCM message:", response);
    return res.status(200).send("Notification sent successfully");
  } catch (error) {
    console.error("Error sending FCM:", error);
    return res.status(500).send(`Failed to send notification: ${error.message}`);
  }
});