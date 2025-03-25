# BlueNotify - Post Notifications for Bluesky

BlueNotify is a post notification app for bluesky, filling a current feature gap that Twitter has but Bluesky has not yet added. Users can connect to their bluesky account and subscribe to push notifications when user's they follow post.

The app can be downloaded on [Google Play](https://play.google.com/store/apps/details?id=com.austinwitherspoon.bluenotify&hl=en_US) and the [Apple App Store](https://apps.apple.com/us/app/bluenotify/id6738239349).

This is the main Flutter app for BlueNotify. Backend services can be found at https://github.com/austinwitherspoon/bluenotify-backend.

Currently in-use by over 5000 users!

<img src="https://github.com/user-attachments/assets/2113a773-6165-4f46-a07d-a7eff5ab037c" width="300">
<img src="https://github.com/user-attachments/assets/496dd215-f8ea-4036-a80a-c281301770e4" width="300">

The app uses Firebase Cloud Notifications to receive push notifications. Notification settings are currently stored in Firestore using the user's FCM token. We use that token as each user's unique ID associated with their notification settings in the backend. No login to bluesky is required (although the app does prompt you to enter your bluesky handle in order for certain features to work!)

This app is only tested with IOS, Android, and Web.

This is a personal project that I run for free, and for _the most part_ I want to work on this alone, if you're very eager to add in a feature and help out, feel free to reach out or open an issue!

You can find me on Bluesky at either [@austinwitherspoon.com](https://bsky.app/profile/austinwitherspoon.com) or [@bluenotify.app](https://bsky.app/profile/bluenotify.app)
