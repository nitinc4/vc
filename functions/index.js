const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

exports.sendCallNotification = functions.https.onRequest(async (req, res) => {
  if (req.method !== 'POST') {
    return res.status(405).send('Method Not Allowed');
  }

  const { fcmToken, callerId, channelId } = req.body;

  if (!fcmToken || !callerId || !channelId) {
    console.error("Missing essential parameters: fcmToken, callerId, or channelId.");
    return res.status(400).send("Missing essential parameters for call notification (fcmToken, callerId, channelId)");
  }

 // Your Firebase Cloud Function (index.js)
const message = {
    token: fcmToken,
    data: { // ONLY the 'data' field should be present for CallKit
        callerId: callerId,
        channelId: channelId,
    },
    android: {
        priority: "high",
    },
    // DO NOT include a 'notification' field here:
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