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

// 📦 تأكيد طلبية الزبون بصورة آمنة مع خصم المخزن الذري ومنع التكرار (Idempotency)
exports.submitOrder = onCall(
  { region: "us-central1" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "يجب تسجيل الدخول لإرسال طلبية.");
    }

    const userId = request.auth.uid;
    const data = request.data || {};

    const orderId = String(data.orderId || Date.now());
    const customerName = String(data.customerName || "").trim();
    const customerPhone = String(data.customerPhone || "").trim();
    const rawItems = Array.isArray(data.items) ? data.items : [];
    const isSpecialPriceRequested = Boolean(data.isSpecialPrice);
    const paidAmount = Number(data.paidAmount) || 0;
    const address = data.address ? String(data.address).trim() : null;
    const latitude = data.latitude !== undefined && data.latitude !== null ? Number(data.latitude) : null;
    const longitude = data.longitude !== undefined && data.longitude !== null ? Number(data.longitude) : null;

    if (!customerName || !customerPhone) {
      throw new HttpsError("invalid-argument", "يرجى تقديم اسم ورقم هاتف الزبون.");
    }

    if (rawItems.length === 0) {
      throw new HttpsError("invalid-argument", "السلة فارغة، لا يمكن إرسال طلبية فارغة.");
    }

    const { db } = getAdmin();

    // 1. التحقق من حساب المستخدم ورتبته
    const userDoc = await db.collection("users").doc(userId).get();
    if (!userDoc.exists) {
      throw new HttpsError("not-found", "حساب المستخدم غير موجود.");
    }
    const userData = userDoc.data();
    const userRole = userData.role || "user_normal";
    const seesSpecial = userRole === "admin" || userRole === "user_special";
    const isSpecialPrice = isSpecialPriceRequested && seesSpecial;

    // 2. استخدام Firestore Transaction لمنع التعارض وخصم المخزن ذرياً وإطعام Idempotency
    return await db.runTransaction(async (transaction) => {
      // أ. التحقق من وجود الطلبية مسبقاً (Idempotency Check)
      const orderRef = db.collection("orders").doc(orderId);
      const existingOrderDoc = await transaction.get(orderRef);
      if (existingOrderDoc.exists) {
        console.log(`ℹ️ طلب مكرر تم معالجته مسبقاً: ${orderId}`);
        const existingData = existingOrderDoc.data();
        return {
          success: true,
          orderId: orderId,
          total: existingData.total || 0,
          duplicate: true,
          message: "تم استقبال الطلبية مسبقاً بنجاح.",
        };
      }

      // ب. قراءة جميع المستندات المطلوبة أولاً (قاعدة Firestore: Read before Write in Transaction)
      const productRefs = [];
      for (const item of rawItems) {
        const pid = String(item.productId || "").trim();
        if (!pid) {
          throw new HttpsError("invalid-argument", "يوجد عنصر غير صالح في السلة.");
        }
        productRefs.push(db.collection("products").doc(pid));
      }

      // جلب جميع منتجات السلة داخل Transaction
      const productDocs = [];
      for (const pRef of productRefs) {
        const pDoc = await transaction.get(pRef);
        if (!pDoc.exists) {
          throw new HttpsError("not-found", `المنتج (${pRef.id}) غير موجود في قاعدة البيانات.`);
        }
        productDocs.push(pDoc);
      }

      // ج. التحقق من توفر كل منتج ومخزونه وحساب الأسعار
      const validatedItems = [];
      const stockUpdates = [];
      let calculatedTotal = 0;

      for (let i = 0; i < rawItems.length; i++) {
        const item = rawItems[i];
        const pDoc = productDocs[i];
        const pData = pDoc.data();

        if (pData.isAvailable === false) {
          throw new HttpsError("failed-precondition", `المنتج "${pData.name || "عنصر"}" غير متاح حالياً.`);
        }

        const qty = Number(item.quantity) || 0;
        if (qty <= 0) {
          throw new HttpsError("invalid-argument", `الكمية غير صالحة للمنتج "${pData.name}".`);
        }

        const isCarton = Boolean(item.isCarton);
        const isWeighed = Boolean(pData.isWeighed);
        const unitsPerCarton = Number(pData.unitsPerCarton) > 0 ? Number(pData.unitsPerCarton) : 1;

        // حساب الكمية بالقطع/الوزن المقابلة للخصم
        let requiredPieces = qty;
        if (!isWeighed) {
          requiredPieces = isCarton ? qty * unitsPerCarton : qty;
        }

        const currentStock = Number(pData.stockQuantity) || 0;
        if (currentStock < requiredPieces) {
          throw new HttpsError(
            "failed-precondition",
            `المخزون غير كافٍ للمنتج "${pData.name || "المنتج"}". (المتوفر: ${currentStock}، المطلوب: ${requiredPieces})`
          );
        }

        // تحديد سعر الوحدة بناءً على نوع السعر والتخفيض
        let unitPrice = 0;
        if (item.priceOverridden === true && userRole === "admin" && item.unitPrice !== undefined) {
          unitPrice = Number(item.unitPrice) || 0;
        } else {
          if (isCarton) {
            unitPrice = isSpecialPrice ? Number(pData.priceCartonSpecial || 0) : Number(pData.priceCartonNormal || 0);
          } else {
            unitPrice = isSpecialPrice ? Number(pData.priceUnitSpecial || 0) : Number(pData.priceUnitNormal || 0);
          }
          const discount = Number(pData.discount) || 0;
          if (discount > 0) {
            unitPrice = unitPrice - (unitPrice * discount / 100);
          }
        }

        const lineTotal = unitPrice * qty;
        calculatedTotal += lineTotal;

        const purchasePrice = Number(pData.purchasePrice) || 0;
        const itemCost = isCarton ? purchasePrice * unitsPerCarton : purchasePrice;

        validatedItems.push({
          productId: pDoc.id,
          productName: String(pData.name || item.productName || ""),
          cost: itemCost,
          quantity: qty,
          price: unitPrice,
          unitPrice: unitPrice,
          isCarton: isCarton,
          typeLabel: isWeighed ? "KG" : (isCarton ? "كرتون" : "حبة"),
          flavor: item.flavor ? String(item.flavor) : "",
          priceOverridden: Boolean(item.priceOverridden),
          isWeighed: isWeighed,
        });

        stockUpdates.push({
          ref: pDoc.ref,
          newStock: currentStock - requiredPieces,
        });
      }

      // د. تنفيذ التعديلات (Writes after Reads inside Transaction)
      for (const update of stockUpdates) {
        transaction.update(update.ref, { stockQuantity: update.newStock });
      }

      const remainingBalance = calculatedTotal - paidAmount > 0 ? calculatedTotal - paidAmount : 0;
      const dateStr = data.date ? String(data.date) : new Date().toISOString();

      transaction.set(orderRef, {
        id: orderId,
        customerName: customerName,
        customerPhone: customerPhone,
        items: validatedItems,
        total: calculatedTotal,
        isSpecialPrice: isSpecialPrice,
        date: dateStr,
        userId: userId,
        status: "pending",
        paidAmount: paidAmount,
        remainingBalance: remainingBalance,
        latitude: latitude,
        longitude: longitude,
        address: address,
        createdAt: FieldValue.serverTimestamp(),
      });

      console.log(`✅ تم إنشاء الطلبية وتحديث المخزن بنجاح: ${orderId}`);

      return {
        success: true,
        orderId: orderId,
        total: calculatedTotal,
        message: "تم إرسال الطلبية بنجاح.",
      };
    });
  }
);

