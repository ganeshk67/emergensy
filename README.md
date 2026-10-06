<<<<<<< HEAD
# emergensy
=======
# Emergensy

An emergency-help Flutter app with a dark, action-first interface, emergency
details and location capture, first-aid guidance, an essentials shop, doctor
appointment requests, lab test booking/results screens, and a separate
health-news feed.

## Run

```sh
flutter pub get
flutter run
```

## Firebase setup

This app is configured for the Firebase project `emergensy-ca0f3` on Android,
iOS, and web. The project-specific `lib/firebase_options.dart` was generated
with FlutterFire. Firebase Auth sign-in/registration and Firestore-backed
SOS alert, appointment, and lab booking flows are wired in the app.

Before using the live backend:

1. In [Firebase Console](https://console.firebase.google.com/), enable
   **Email/Password** under Authentication → Sign-in method.
2. The default Firestore database has been created in `asia-south1` (Mumbai).
   The Cloud Firestore API is enabled.
3. Deploy updated checked-in rules with
   `firebase.cmd deploy --only firestore:rules --project emergensy-ca0f3`
   (or `firebase deploy` where the Firebase CLI is available). The current
   rules have been deployed.

Firebase's client `apiKey` is project identification/configuration, not a
database password. Firestore access must be protected by Firebase Authentication
and Security Rules; never put service-account credentials in the Flutter app.
The rules scope SOS alerts, appointments, and lab data to each signed-in user's
UID. Lab results are readable by that user but can only be written by a trusted
server/admin integration.

Firestore results are read-only to app users; only a trusted lab integration
or administrator can add them. Appointment and test requests are saved to
Firestore, but they are not sent to real clinics or labs until provider
integrations are connected.

The news section reads Google's public Indian health-news RSS feed through
RSS2JSON's public JSON conversion endpoint. It needs no NewsAPI key, Firebase
Functions, or paid Firebase plan. The conversion service is a third-party
dependency and may apply usage limits; articles link to their original
publishers. Google News RSS terms limit the feed to personal, non-commercial
feed-reader use; verify licensing before distributing this feed in a
commercial/public service.

## Current scope

- Emergency flow collects an emergency type and device location or a manually
  entered address, then presents relevant immediate safety steps and a button
  to call 112 (India).
- The app does not dispatch or notify an ambulance/hospital and does not send
  location to 112. The caller must share the displayed details with the
  emergency operator. Direct dispatch requires an authorized emergency-service
  integration/backend.
- After the user reviews the emergency details and continues to the guidance
  screen, an SOS record containing the emergency type, reason, location, and
  prepared status is saved to `users/{uid}/alerts`. The app displays save errors
  and offers retry; saving the record does not notify responders.
- Location permission is requested only when the user taps "Use my location";
  a manual address can be used if location is unavailable or denied. Location
  permission declarations are configured for Android, iOS, and macOS.
- First-aid content is general information, not medical advice. Follow the
  emergency operator's instructions first.
- Doctor appointments include a sample doctor directory, online/in-person
  selection, dates/time slots, and an area field for in-person visits.
  Requests are persisted privately in Firestore; no provider receives them and
  availability is not live.
- Lab test booking includes sample test selection, collection preference, and
  a results screen. Requests are persisted privately in Firestore; no lab
  receives them. Real reports are shown only when added by a trusted
  integration.
- The shop has a local catalog and cart for basic first-aid supplies and an
  over-the-counter medicine example. The cart is a demo: checkout does not
  submit a real order, process payments, or connect to a pharmacy.
- News articles link to their original publisher.

Real appointments, lab collection/results, and ordering require authorized
provider backends and appropriate privacy/security controls. Real ordering
also requires delivery handling and a payment integration.
>>>>>>> c477b9a (first push)
