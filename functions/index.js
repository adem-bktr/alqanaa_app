const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { getAuth } = require("firebase-admin/auth");

function getAdmin() {
  try {
    return {
      db: getFirestore(),
      messaging: getMessaging(),
    };
  } catch (e) {
    initializeApp();
    return {
      db: getFirestore(),
      messaging: getMessaging(),
    };
  }
}

/**
 * تنظيف التوكينات غير الصالحة من وثائق المستخدمين
 */
async function removeInvalidTokens(db, tokenMapping, responses) {
  const batch = db.batch();
  let count = 0;

  responses.forEach((resp, index) => {
    if (!resp.success && resp.error) {
      const code = resp.error.code;
      if (
        code === "messaging/invalid-registration-token" ||
        code === "messaging/registration-token-not-registered"
      ) {
        const item = tokenMapping[index];
        if (item && item.userId && item.token) {
          const ref = db.collection("users").doc(item.userId);
          batch.update(ref, {
            fcmTokens: FieldValue.arrayRemove(item.token),
            fcmToken: FieldValue.delete(),
          });
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

/**
 * استخراج التوكينات لمستخدم مع دعم التوافق مع الأجهزة المتعددة
 */
function extractUserTokens(userData) {
  const tokens = new Set();
  if (Array.isArray(userData.fcmTokens)) {
    userData.fcmTokens.forEach((t) => {
      if (t && typeof t === "string") tokens.add(t.trim());
    });
  }
  if (userData.fcmToken && typeof userData.fcmToken === "string") {
    tokens.add(userData.fcmToken.trim());
  }
  return Array.from(tokens);
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
    const tokenMapping = [];

    adminsSnapshot.docs.forEach((d) => {
      const userTokens = extractUserTokens(d.data());
      userTokens.forEach((token) => {
        tokens.push(token);
        tokenMapping.push({ userId: d.id, token });
      });
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

      console.log(`✅ أُرسل إشعار الطلب الجديد بنجاح لـ ${response.successCount} جهاز أدمن.`);
      await removeInvalidTokens(db, tokenMapping, response.responses);
    } catch (error) {
      console.error("❌ خطأ في notifyAdminNewOrder:", error);
    }

    return null;
  }
);

// 🚚 إشعار للزبون عند تغيير حالة الطلب (لجميع أجهزته)
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

    const tokens = extractUserTokens(userDoc.data());
    if (tokens.length === 0) return null;

    const tokenMapping = tokens.map((token) => ({ userId: after.userId, token }));

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
      const response = await messaging.sendEachForMulticast({
        tokens,
        notification: msg,
        data: {
          type: "order_status",
          orderId: event.params.orderId,
          status: String(after.status),
        },
      });

      console.log(`✅ أُرسل إشعار تغيير الحالة للزبون: ${after.userId} (نجح ${response.successCount}/${tokens.length})`);
      await removeInvalidTokens(db, tokenMapping, response.responses);
    } catch (error) {
      console.error("❌ خطأ في notifyUserOrderStatus:", error);
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
    const tokenMapping = [];

    usersSnapshot.docs.forEach((doc) => {
      const uData = doc.data();
      if (uData.role !== "admin") {
        const uTokens = extractUserTokens(uData);
        uTokens.forEach((token) => {
          tokens.push(token);
          tokenMapping.push({ userId: doc.id, token });
        });
      }
    });

    if (tokens.length === 0) {
      console.log("ℹ️ لا يوجد زبائن ذوي توكينات صالحة للإرسال الجماعي.");
      await snap.ref.update({
        processed: true,
        targetedCount: 0,
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
      const batchMap = tokenMapping.slice(i, i + 500);

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
      targetedCount: tokens.length,
      sentCount: totalSuccess,
      failCount: totalFailure,
      sentAt: FieldValue.serverTimestamp(),
    });

    console.log(`🎉 تم إكتمال الإرسال الجماعي: استهدف ${tokens.length} جهاز (نجح ${totalSuccess}، فشل ${totalFailure}).`);
    return null;
  }
);

// 🗑️ حذف حساب المستخدم كلياً (Authentication + Firestore) للأدمن فقط
exports.deleteUserAccount = onCall(
  { region: "us-central1" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "يجب تسجيل الدخول كأدمن لصلحية الحذف.");
    }

    const callerUid = request.auth.uid;
    const targetUid = request.data ? request.data.targetUid : null;

    if (!targetUid || typeof targetUid !== "string") {
      throw new HttpsError("invalid-argument", "معرّف المستخدم المطلوب حذفه غير صحيح.");
    }

    if (callerUid === targetUid) {
      throw new HttpsError("permission-denied", "لا يمكنك حذف حساب الأدمن الخاص بك.");
    }

    const { db } = getAdmin();

    const callerDoc = await db.collection("users").doc(callerUid).get();
    if (!callerDoc.exists || callerDoc.data().role !== "admin") {
      throw new HttpsError("permission-denied", "غير مصرح لك بحذف المستخدمين. يجب أن تكون أدمن.");
    }

    const targetDoc = await db.collection("users").doc(targetUid).get();
    if (targetDoc.exists && targetDoc.data().role === "admin") {
      throw new HttpsError("permission-denied", "لا يمكن حذف حساب أدمن من هذه الواجهة.");
    }

    try {
      try {
        await getAuth().deleteUser(targetUid);
        console.log(`✅ تم حذف الحساب من Firebase Auth: ${targetUid}`);
      } catch (authErr) {
        if (authErr.code !== "auth/user-not-found") {
          console.error(`⚠️ خطأ أثناء حذف الحساب من Auth:`, authErr);
        }
      }

      if (targetDoc.exists) {
        await db.collection("users").doc(targetUid).delete();
        console.log(`✅ تم حذف وثيقة المستخدم من Firestore: ${targetUid}`);
      }

      await db.collection("audit_logs").add({
        action: "delete_user",
        deletedUid: targetUid,
        deletedName: targetDoc.exists ? (targetDoc.data().name || "") : "",
        deletedEmail: targetDoc.exists ? (targetDoc.data().email || "") : "",
        performedBy: callerUid,
        timestamp: FieldValue.serverTimestamp(),
      });

      return { success: true, message: "تم حذف المستخدم كلياً بنجاح." };
    } catch (err) {
      console.error("❌ خطأ أثناء تنفيذ deleteUserAccount:", err);
      throw new HttpsError("internal", "فشلت عملية الحذف: " + err.message);
    }
  }
);
