/* eslint-disable */
const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

// Trigger เมื่อมี report ใหม่
exports.sendReportNotificationToAdmin = functions.firestore
    .document("reports/{reportId}")
    .onCreate(async (snap, context) => {
        const report = snap.data();
        if (!report) return;

        // ดึง admin ทั้งหมด
        const adminSnapshot = await admin.firestore().collection("users")
            .where("role", "==", "admin")
            .get();

        const tokens = [];
        adminSnapshot.forEach(doc => {
            const token = doc.data().fcmToken;
            if (token) tokens.push(token);
        });

        if (tokens.length === 0) return;

        const message = {
            notification: {
                title: "มีรายงานใหม่",
                body: report.detail || "มีรายละเอียดเพิ่มเติม",
            },
            tokens: tokens,
        };

        await admin.messaging().sendMulticast(message);
        console.log("✅ Notification sent to admin");
    });
