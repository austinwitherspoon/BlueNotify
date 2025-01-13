self.addEventListener('notificationclick', (event) => {
    const clickedNotification = event.notification;

    console.log('Notification Click.', event.notification);

    const url = clickedNotification.data?.FCM_MSG?.data?.url || "/";
    console.log('Notification url:', url);
    const promiseChain = clients.openWindow(url);
    event.waitUntil(promiseChain);
});


importScripts("https://www.gstatic.com/firebasejs/9.10.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/9.10.0/firebase-messaging-compat.js");

firebase.initializeApp({
    apiKey: 'AIzaSyB7wZb2tO1-Fs6GbDADUSTs2Qs3w08Hovw',
    projectId: 'bluenotify-b1700',
    authDomain: 'bluenotify-b1700.firebaseapp.com',
    storageBucket: 'bluenotify-b1700.appspot.com',
    messagingSenderId: '496531737502',
    appId: '1:496531737502:web:9195d217e8cfe66fa3a48f',

});
// Necessary to receive background messages:
const messaging = firebase.messaging();

// Optional:
messaging.onBackgroundMessage((message) => {
    console.log("onBackgroundMessage", message);
});
