# Emergensy

An emergency-help Flutter app with a premium midnight-navy interface, electric
cyan highlights, and focused emergency-red actions. Rounded cards, expressive
icons, and lightweight transitions keep emergency and health information clear.
Motion respects the device's reduced-animation setting. Shared theme tokens and
centered page layouts keep the experience consistent and comfortable on phones
and tablets, while feature icons use shared-element transitions between the
home and destination pages. A light appearance is available in Profile.
Features include emergency assistance, a real-time voice assistant, first-aid
guidance, doctor appointments, lab booking and results, health news, an emergency
QR profile, a health timeline, and consent-led family profiles.

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
3. Grant the Cloud Functions runtime service account the Firebase
   Authentication Admin role so it can issue doctor custom claims. Deploy
   updated checked-in rules and Cloud Functions with
   `firebase.cmd deploy --only firestore:rules,functions --project emergensy-ca0f3`.
   The doctor, AI-summary, and push workflows require deployment; Cloud
   Functions deployment requires a billing-enabled Firebase project.

Firebase's client `apiKey` is project identification/configuration, not a
database password. Firestore access must be protected by Firebase Authentication
and Security Rules; never put service-account credentials in the Flutter app.
The rules scope SOS alerts and lab data to each signed-in user's UID. Lab
results are readable by that user but can only be written by a trusted
server/admin integration. Clinic queue access is scoped to the facility ID in a doctor custom claim.

The app does not currently use Firebase Cloud Storage. `storage.rules`
therefore denies all reads and writes until an explicit authenticated upload
workflow is added.

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

## Voice assistant setup

The real-time voice assistant uses Firebase AI Logic's Gemini Live API directly
from Flutter on Android, iOS, and supported web browsers. Web voice requires
HTTPS and user-granted microphone access. It does not use a separate agent
data-collection endpoint. Before using it:

1. Confirm the active Firebase project is `emergensy-ca0f3`, then run this from
   the project root to provision Firebase AI Logic:

   ```sh
   npx -y firebase-tools@latest init ailogic
   ```

2. Set up Firebase App Check for Android with Play Integrity, iOS with
   DeviceCheck, and web with reCAPTCHA Enterprise. Debug builds use App Check's
   debug provider; register the generated debug token in Firebase Console >
   App Check > Apps before testing Gemini requests. Never ship a debug token
   or debug build.
3. Before release, enforce App Check for Firebase AI Logic and configure the
   production providers in Firebase Console. Production web builds also need
   a reCAPTCHA Enterprise site key, supplied as
   `--dart-define=APP_CHECK_RECAPTCHA_ENTERPRISE_SITE_KEY=<site-key>`.

The voice screen asks for consent before enabling the microphone. Audio is
streamed to Google Gemini for responses; the app does not save the conversation.
The assistant provides general information, not diagnosis or emergency dispatch.
For emergencies in India, call 112. Gemini Live API is a Preview feature and may
change.

## Deploy Flutter web to Render

Render serves the Flutter web app from the Docker image; Firebase remains the
backend for Auth, Firestore, and Cloud Functions. Android and iOS app binaries
are not deployed through Render.

1. Push the repository to GitHub and connect it in Render with **New > Blueprint**.
   Render reads the root `render.yaml`.
2. Set `APP_CHECK_RECAPTCHA_ENTERPRISE_SITE_KEY` to the public reCAPTCHA
   Enterprise site key configured for the Firebase web app. The Docker build
   embeds this value into the Flutter web bundle; do not put a private secret
   in this variable.
3. Add the assigned `*.onrender.com` hostname to the allowed domains for the
   reCAPTCHA Enterprise key and to Firebase Authentication's authorized
   domains. Then deploy.
4. Deploy Firestore rules and Cloud Functions to Firebase separately if they
   have not already been deployed. Render does not run Firebase Functions.

Live voice is available from supported mobile browsers when the app is served
over HTTPS and microphone access is allowed. Some browser or device
configurations may not support live recording; the Android and iOS apps remain
available as alternatives.

## Current scope

- Emergency flow collects an emergency type and device location or a manually
  entered address, then presents relevant immediate safety steps and buttons
  to call 112 (India) or the emergency contact saved in the user's profile.
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
- The voice assistant streams microphone audio to Firebase AI Logic/Gemini only
  after the user consents. It does not persist conversation audio or transcripts
  and is not a substitute for emergency services or professional care.
- Each hospital gets one unique, private invite code tied to its facility ID.
  The hospital can give that code to its doctors, who self-register and are
  automatically linked to the hospital. A trusted administrator creates or
  rotates the hospital's single active code; the backend stores only its
  SHA-256 hash and grants facility-scoped claims only after a signed-in user
  redeems it. Keep the code private and share it only with that hospital's
  clinicians. To create or
  rotate a code, authenticate the Firebase Admin SDK with trusted
  application-default credentials, then run:

  ```powershell
  gcloud auth application-default login
  $env:GOOGLE_CLOUD_PROJECT = "emergensy-ca0f3"
  cd .\functions
  node .\scripts\manage-doctor-invite.js node-123 "North Clinic"
  ```

  The command prints the code once; securely share it with the clinic. Rerun
  the command to rotate it, or use
  `node .\scripts\manage-doctor-invite.js --revoke node-123` to revoke it.
  Never commit service-account credentials or put invite codes in client code.
  Replace `node-123` with the exact OpenStreetMap place ID used by patient
  bookings (for example `way-456`); otherwise the doctor queue will not match
  those appointments. Doctors sign in with their clinic code to enroll; their
  ID token is refreshed after the backend grants the claim. Administrators can
  still grant or revoke claims directly with `scripts/set-doctor-claims.js`
  when needed.
- Doctors can publish facility availability and approve or decline requests
  for their assigned facility. In-person requests require selecting a nearby
  OpenStreetMap-listed location; its name/address is saved with the request and
  displayed to both patient and clinic. A map listing is not proof that a
  clinic is connected: only a verified doctor whose claim matches that
  facility ID can see and review its request. Online requests remain private.
  Approval is not an emergency dispatch service.
- Family guardian profiles require an explicit authorization toggle. Authorized
  profiles can be selected when booking appointments and lab tests; the
  guardian account owns those records and can view results tagged with the
  member ID/name. A connected lab integration must preserve those member
  fields when it publishes a result for the correct guardian account.
- Lab test booking includes sample test selection, collection preference, and
  a results screen. Requests are persisted privately in Firestore; no lab
  receives them. Real reports are shown only when added by a trusted
  integration.
- Profile settings include an emergency QR code with individually selectable
  fields, including height, weight, allergies, and conditions. Doctor accounts
  can scan that code; the scanner allowlists supported fields and displays
  them only in memory without saving or transmitting them. QR data is not
  access-controlled, so only include fields the patient is comfortable
  disclosing. The health timeline is manually maintained and does not extract
  uploaded reports.
- Patients can explicitly consent to send structured result fields (test name,
  value, units, reference range, and status; not name/contact details) to
  Google Vertex AI for a plain-language explanation. The result remains in
  Firestore, and the explanation is not a diagnosis. To enable this workflow,
  deploy the Functions, enable the Vertex AI API, and grant the Functions
  service account the Vertex AI User role in the configured region.
- Lab-result push notifications contain no medical details. The app requests
  OS notification permission and registers an FCM token on Android/iOS; configure
  Apple Push Notification service credentials in Firebase for iOS. In-app
  foreground notices link to the reports screen. Web push is not configured.
- The default appearance is midnight navy with cyan and emergency-red accents.
  A light appearance is available in Profile and is saved to the signed-in
  user's settings.
- The shop has a local catalog and cart for basic first-aid supplies and an
  over-the-counter medicine example. The cart is a demo: checkout does not
  submit a real order, process payments, or connect to a pharmacy.
- News articles link to their original publisher.

Real appointments, lab collection/results, and ordering require authorized
provider backends and appropriate privacy/security controls. Real ordering
also requires delivery handling and a payment integration.
