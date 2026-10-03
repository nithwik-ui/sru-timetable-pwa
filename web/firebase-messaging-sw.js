importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyD9_WzJsEJSi-0ke0rdZVdA6ohgX_yib-Q",
  authDomain: "timetable-77a7d.firebaseapp.com",
  projectId: "timetable-77a7d",
  storageBucket: "timetable-77a7d.firebasestorage.app",
  messagingSenderId: "712842876134",
  appId: "1:712842876134:web:6a81c13779ec2828949727",
  measurementId: "G-WRP2DM4ZRL"
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  const notificationTitle = payload.notification.title || 'SRU Update';
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/icons/Icon-192.png'
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
