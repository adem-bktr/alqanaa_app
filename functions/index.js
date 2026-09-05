const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

// إشعار للأدمن عند طلب جديد
exports.notifyAdminNewOrder = onDocumentCreated(
  { document: "orders/{orderId}", region: "us-central1" },
  async (event) => {
    const order = event.data.data();
    if (!order) return null;

    const db = getFirestore();
    const adminsSnapshot = await db
      .collection("users")
      .where("role", "==", "admin")
      .get();

    const tokens = adminsSnapshot.docs
      .map((d) => d.data().fcmToken)
      .filter((t) => t);

    if (tokens.length === 0) return null;

    await getMessaging().sendEachForMulticast({
      tokens,
      notification: {
        title: "📦 طلب جديد!",
        body: `${order.customerName} - ${order.total} DA`,
      },
      data: {
        type: "new_order",
        orderId: event.params.orderId,
      },
    });

    return null;
  }
);

// إشعار للزبون عند تغيير حالة الطلب
exports.notifyUserOrderStatus = onDocumentUpdated(
  { document: "orders/{orderId}", region: "us-central1" },
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();

    if (before.status === after.status) return null;
    if (!after.userId) return null;

    const db = getFirestore();
    const userDoc = await db.collection("users").doc(after.userId).get();

    if (!userDoc.exists) return null;

    const token = userDoc.data().fcmToken;
    if (!token) return null;

    const messages = {
      confirmed: { title: "✅ تم تأكيد طلبك", body: "طلبك قيد التجهيز" },
      rejected:  { title: "❌ تم رفض الطلب",  body: "نعتذر، لا يمكننا تلبية طلبك" },
      delivered: { title: "🎉 تم توصيل طلبك", body: "استمتع بطلبك!" },
      shipping:  { title: "🚚 طلبك في الطريق", body: "جاري توصيل طلبك الآن" },
    };

    const msg = messages[after.status] || {
      title: "⏳ تحديث الطلب",
      body: "تم تحديث حالة طلبك",
    };

    await getMessaging().send({
      token,
      notification: msg,
      data: {
        type: "order_status",
        orderId: event.params.orderId,
        status: after.status,
      },
    });

    return null;
  }
);