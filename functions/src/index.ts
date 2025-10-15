import { onCall } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

admin.initializeApp();
const db = admin.firestore();

// 🪙 دالة لشراء الكوينز
export const creditCoinsAfterPurchase = onCall(async (request) => {
  const uid = request.auth?.uid;
  const coins = request.data?.coins;

  if (!uid) {
    throw new Error("يجب تسجيل الدخول أولاً.");
  }

  if (!coins || typeof coins !== "number" || coins <= 0) {
    throw new Error("عدد الكوينز غير صالح.");
  }

  const userRef = db.collection("users").doc(uid);
  await db.runTransaction(async (transaction) => {
    const doc = await transaction.get(userRef);
    const currentCoins = doc.exists ? doc.data()?.coins || 0 : 0;
    transaction.set(userRef, { coins: currentCoins + coins }, { merge: true });
  });

  return { success: true, message: `تمت إضافة ${coins} كوينز بنجاح.` };
});

// 🎁 دالة لدعم فيديو أو منشور
export const tipPost = onCall(async (request) => {
  const uid = request.auth?.uid;
  const postId = request.data?.postId;
  const coins = request.data?.coins;

  if (!uid) {
    throw new Error("يجب تسجيل الدخول أولاً.");
  }

  if (!postId || !coins || typeof coins !== "number" || coins <= 0) {
    throw new Error("بيانات غير صالحة.");
  }

  const userRef = db.collection("users").doc(uid);
  const postRef = db.collection("posts").doc(postId);

  await db.runTransaction(async (transaction) => {
    const userDoc = await transaction.get(userRef);
    const userCoins = userDoc.data()?.coins || 0;

    if (userCoins < coins) {
      throw new Error("ليس لديك كوينز كافية.");
    }

    transaction.update(userRef, { coins: userCoins - coins });

    const postDoc = await transaction.get(postRef);
    const currentTips = postDoc.exists ? postDoc.data()?.tips || 0 : 0;
    transaction.set(postRef, { tips: currentTips + coins }, { merge: true });
  });

  return { success: true, message: `تم دعم الفيديو بـ ${coins} كوينز.` };
});
