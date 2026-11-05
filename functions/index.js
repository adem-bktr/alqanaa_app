const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { initializeApp, getApps } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

function getAdmin() {
  if (getApps().length === 0) {
    initializeApp();
  }
  return {
    db: getFirestore(),
    messaging: getMessaging(),
  };
}

/**
 * تنظيف التوكينات غير الصالحة من وثائق المستخدمين
 */
async function removeInvalidTokens(db, userTokenMap, responses) {
  const batch = db.batch();
  let count = 0;

  responses.forEach((resp, index) => {
    if (!resp.success && resp.error) {
      const code = resp.error.code;
      if (
        code === "messaging/invalid-registration-token" ||
        code === "messaging/registration-token-not-registered"
      ) {
        const userId = userTokenMap[index];
        if (userId) {
          const ref = db.collection("users").doc(userId);
          batch.update(ref, { fcmToken: FieldValue.delete() });
          count++;
        }
      }
    }
  });

  if (count > 0) {
    await batch.commit();
    console.log(`🧹 تم تنظيف ${count} توكين غير صالحة.`);
  }
}

// 📦 إشعار للأدمن عند طلب جديد
exports.notifyAdminNewOrder = onDocumentCreated(
  { document: "orders/{orderId}", region: "us-central1" },
  async (event) => {
    const order = event.data ? event.data.data() : null;
    if (!order) return null;

    const { db, messaging } = getAdmin();
    const adminsSnapshot = await db
      .collection("users")
      .where("role", "==", "admin")
      .get();

    const tokens = [];
    const userTokenMap = [];

    adminsSnapshot.docs.forEach((d) => {
      const data = d.data();
      if (data.fcmToken) {
        tokens.push(data.fcmToken);
        userTokenMap.push(d.id);
      }
    });

    if (tokens.length === 0) {
      console.log("ℹ️ لا يوجد توكينات للأدمن لإرسال إشعار طلب جديد.");
      return null;
    }

    try {
      const response = await messaging.sendEachForMulticast({
        tokens,
        notification: {
          title: "📦 طلب جديد!",
          body: `${order.customerName || "زبون"} - ${order.total || 0} DA`,
        },
        data: {
          type: "new_order",
          orderId: event.params.orderId,
          customerName: String(order.customerName || ""),
          total: String(order.total || 0),
        },
      });

      console.log(`✅ أُرسل إشعار الطلب الجديد بنجاح لـ ${response.successCount} أدمن.`);
      await removeInvalidTokens(db, userTokenMap, response.responses);
    } catch (error) {
      console.error("❌ خطأ في notifyAdminNewOrder:", error);
    }

    return null;
  }
);

// 🚚 إشعار للزبون عند تغيير حالة الطلب
exports.notifyUserOrderStatus = onDocumentUpdated(
  { document: "orders/{orderId}", region: "us-central1" },
  async (event) => {
    const before = event.data ? event.data.before.data() : null;
    const after = event.data ? event.data.after.data() : null;

    if (!before || !after || before.status === after.status) return null;
    if (!after.userId) return null;

    const { db, messaging } = getAdmin();
    const userDoc = await db.collection("users").doc(after.userId).get();

    if (!userDoc.exists) return null;

    const token = userDoc.data().fcmToken;
    if (!token) return null;

    const messages = {
      confirmed: { title: "✅ تم تأكيد طلبك", body: "طلبك قيد التجهيز الآن" },
      rejected:  { title: "❌ تم رفض الطلب",  body: "نعتذر، لا يمكننا تلبية طلبك حالياً" },
      delivered: { title: "🎉 تم توصيل طلبك", body: "استمتع بطلبك!" },
      shipping:  { title: "🚚 طلبك في الطريق", body: "جاري توصيل طلبك الآن" },
    };

    const msg = messages[after.status] || {
      title: "⏳ تحديث الطلب",
      body: `تم تحديث حالة طلبك إلى: ${after.status}`,
    };

    try {
      await messaging.send({
        token,
        notification: msg,
        data: {
          type: "order_status",
          orderId: event.params.orderId,
          status: String(after.status),
        },
      });
      console.log(`✅ أُرسل إشعار تغيير الحالة للزبون: ${after.userId}`);
    } catch (error) {
      console.error("❌ خطأ في notifyUserOrderStatus:", error);
      if (
        error.code === "messaging/invalid-registration-token" ||
        error.code === "messaging/registration-token-not-registered"
      ) {
        await db.collection("users").doc(after.userId).update({
          fcmToken: FieldValue.delete(),
        });
      }
    }

    return null;
  }
);

// 📢 إرسال إشعار تذكيري جماعي للزبائن عبر مشغّل الإعلانات
exports.onAnnouncementCreated = onDocumentCreated(
  { document: "announcements/{docId}", region: "us-central1" },
  async (event) => {
    const snap = event.data;
    if (!snap) return null;

    const data = snap.data();
    if (!data || data.processed === true) return null;

    const title = data.title || "🛒 عروض جديدة!";
    const body = data.message || data.body || "";
    if (!body) return null;

    const { db, messaging } = getAdmin();
    const usersSnapshot = await db.collection("users").get();

    const tokens = [];
    const userTokenMap = [];

    usersSnapshot.docs.forEach((doc) => {
      const uData = doc.data();
      if (uData.role !== "admin" && uData.fcmToken) {
        tokens.push(uData.fcmToken);
        userTokenMap.push(doc.id);
      }
    });

    if (tokens.length === 0) {
      console.log("ℹ️ لا يوجد زبائن ذوي توكينات صالحة للإرسال الجماعي.");
      await snap.ref.update({
        processed: true,
        sentCount: 0,
        failCount: 0,
        sentAt: FieldValue.serverTimestamp(),
      });
      return null;
    }

    let totalSuccess = 0;
    let totalFailure = 0;

    for (let i = 0; i < tokens.length; i += 500) {
      const batchTokens = tokens.slice(i, i + 500);
      const batchMap = userTokenMap.slice(i, i + 500);

      try {
        const response = await messaging.sendEachForMulticast({
          tokens: batchTokens,
          notification: { title, body },
          data: { type: "broadcast_reminder" },
        });

        totalSuccess += response.successCount;
        totalFailure += response.failureCount;

        await removeInvalidTokens(db, batchMap, response.responses);
      } catch (err) {
        console.error(`❌ خطأ في إرسال الدفعة ${i / 500}:`, err);
      }
    }

    await snap.ref.update({
      processed: true,
      sentCount: totalSuccess,
      failCount: totalFailure,
      sentAt: FieldValue.serverTimestamp(),
    });

    console.log(`🎉 تم إكتمال الإرسال الجماعي: نجح ${totalSuccess}، فشل ${totalFailure}.`);
    return null;
  }
);
