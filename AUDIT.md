# EM3RGENSY repository audit

Audit date: 2026-11-16  
Scope: checked-in Flutter, Firebase, Functions, platform, and Render configuration. No production Firebase or Render credentials were available, so live behavior and deployed configuration were not verified.

## Summary

The repository contains a working Flutter app with Firebase Auth and Firestore adapters, server-side doctor invitation and appointment-review functions, a direct Gemini Live voice service, and a static Flutter web deployment. Several key flows are implemented and covered by widget or Node tests. The app is not yet a complete emergency-response platform: SOS saves a `prepared` record to the user's account and opens 112 calling guidance; it does not notify responders. Appointment and lab requests are stored, but are not provider integrations. Hospital discovery uses community OpenStreetMap data and is not a verified directory.

No confirmed critical vulnerability was found in the checked-in rules or Functions. Production readiness is blocked by unverified live configuration and missing provider integrations. The highest-impact repository risks are platform compatibility ambiguity in the voice implementation, browser/device-dependent speech recognition, and limited validation of profile/appointment data at the client-write boundary.

## Implemented during this pass

- Added a direct **Call 112 now** action to the signed-in home emergency card and the unauthenticated sign-in screen. It opens the phone app with `tel:112`; the existing emergency-details flow remains a separate action and is no longer required before calling.
- Added widget coverage for the signed-out screen and updated the home emergency-card expectation in `test/widget_test.dart`. At the time of the initial audit, Flutter tests were not run because the SDK lockfile was inaccessible; follow-up validation is recorded below.
- Began the patient foundation milestone: added an Emergency Passport screen backed by the owner-only `users/{uid}/passport/current` Firestore document, legacy profile read fallback, synchronized legacy fields for existing SOS/QR flows, bounded Firestore rules, and edit/load/save/retry/error states. Linked it from both the dashboard and Profile. The health and QR controls now share one screen and source document. The first schema is explicitly patient-reported and stores one emergency contact; document upload, multiple contacts, and offline cache remain future work.
- After finding that the Flutter SDK lockfile was read-only in the workspace sandbox, ran Flutter commands with the required SDK access: `flutter analyze` passed with no issues, `flutter test test/widget_test.dart` passed all 24 tests, and `flutter build web --release` completed. These widget tests use a fake repository; Firestore Emulator and live Firebase writes were not exercised.

## Findings by severity

### Critical

- None confirmed from the repository inspection. This is not a live penetration test or Firebase emulator rules test.

### High

- **Voice platform behavior and failure paths need real-device verification.** `lib/services/voice_agent_service.dart` uses Firebase AI Logic Live on mobile (`gemini-3.1-flash-live-preview`) but a separate text model plus browser speech recognition and speech synthesis on web. These are materially different implementations and have distinct browser support, permission, network, and App Check failure modes. The code has explicit phases and cleanup, but repository inspection cannot establish that microphone capture, Live connection, or audio output succeeds on supported devices. Confirm Firebase AI Logic provisioning and App Check enforcement in the live project before release.
- **Firebase setup is tied to a placeholder-style application identifier.** `lib/firebase_options.dart`, `android/app/build.gradle.kts`, and iOS project settings use `com.example.emergensy`. Firebase options currently match that identifier, so this may be intentional for the registered apps; it is a release blocker if the shipped package/bundle identifiers differ. Verify all store identifiers and Firebase app registrations before publishing.
- **Appointment requests are not real bookings.** `lib/services/app_backend.dart` saves user requests; `functions/index.js` allows a doctor with a facility claim to approve or decline. This is a request workflow, not an external clinic integration. Lab requests likewise remain private requests; there is no lab provider delivery path. The UI and README correctly disclose this limitation.
- **SOS does not contact emergency responders or trusted contacts.** SOS persistence is limited to `users/{uid}/alerts` with `status: prepared`; the app gives the user an option to call 112. No responder dispatch or automatic location sharing exists. This is accurately disclosed in `README.md` and `lib/main.dart` and must remain clear in any release materials.

### Medium

- **Profile document writes are broad.** Firestore rules restrict `/users/{uid}` ownership and protect role/facility fields, but otherwise let the owner write arbitrary profile fields. That is adequate for basic same-user privacy, but not a strict schema or consent boundary. Add field allowlists and type/size checks as profile fields and integrations expand. Keep trusted result and role fields server-only.
- **Appointment create validation is partial.** `/appointments/{appointmentId}` checks UID, status, timestamp, allowed keys, and in-person facility linkage, but does not validate field types, lengths, date/slot formats, or bounds for coordinates. Harden the schema before connecting external providers or enabling broader reads.
- **Availability reads are public.** `firestore.rules` permits unauthenticated reads of facility availability. This may be intentional for discovery; confirm the documents contain only public scheduling data and never private clinic or patient details.
- **Emergency QR contents are readable by anyone who scans the code.** `lib/screens/profile_pages.dart` makes sharing opt-in per field and tells the user that selected details are public. The QR is static JSON without expiry or revocation, so anyone who photographs it can retain the contents after consent is disabled. Avoid including contact details unless the user accepts that exposure.
- **Hospital discovery depends on public community endpoints.** `lib/services/hospital_search_service.dart` uses Nominatim and Overpass/OpenStreetMap, without a service SLA or verified facility status. Rate limits, missing data, or endpoint outages can break discovery. The UI must keep this distinct from verified EM3RGENSY partners.
- **No offline emergency content is implemented.** Essential first-aid information is embedded in the app, but there is no dedicated offline mode, local emergency-contact coordination, or medication notification system.
- **Language support is not an app-wide localization system.** The voice prompt asks Gemini to respond in the user's language, but navigation, emergency instructions, and notifications are predominantly English. Kannada and Hindi translations are not established across the product.
- **Cloud Storage is intentionally unavailable.** `storage.rules` denies all reads and writes. This protects data while no upload flow exists, but health document management cannot work until authenticated uploads and strict per-user access controls are added.
- **Deployment could not be exercised against Render.** `Dockerfile` requires `APP_CHECK_RECAPTCHA_ENTERPRISE_SITE_KEY`; `render.yaml` marks it as a Render-supplied environment variable. HTTPS hostname authorization and Firebase Auth authorized domains must be configured in the consoles. Container build and deployed browser behavior were not verified here.

### Low

- `pubspec.yaml` still has the starter description and has no localization, offline storage, or scheduled notification dependencies. Avoid adding packages until the corresponding feature is scoped.
- Nominatim uses a static User-Agent (`Emergensy/1.0 (com.example.emergensy)`). A production identity and operational contact should be used if the public geocoder remains in use.
- `README.md` describes many feature limitations well, but should be kept aligned with the actual released build and the supported device/browser matrix.

## Functionality traced

| Flow | Frontend | Backend/persistence | Current boundary |
|---|---|---|---|
| Sign-in / registration | `lib/main.dart`, `lib/services/app_backend.dart` | Firebase Auth | Firebase project configuration and authorized domains need live verification. |
| SOS | `lib/main.dart` | User-owned Firestore alert, create-only `prepared` state | Does not alert 112, an ambulance, hospital, or contacts. |
| Appointments | `lib/main.dart`, `lib/services/app_backend.dart`, `lib/screens/doctor_dashboard.dart` | Patient request in root and per-user collections; callable doctor review | Only in-person facility requests with claims appear in doctor review; provider confirmation is manual. |
| Lab bookings/results | `lib/main.dart`, `lib/services/app_backend.dart` | User-owned booking; lab results server/admin write-only; AI explainer in `functions/index.js` | No lab integration. AI summary requires explicit consent and sends structured test fields to Vertex AI. |
| Doctor enrollment | `lib/main.dart`, `lib/services/app_backend.dart` | `validateDoctorInvite` and `redeemDoctorInvite`; custom claims assigned server-side | Invite generation/revocation is an operator CLI task. Claim grant script is privileged and must stay out of the client. |
| Voice | `lib/screens/voice_assistant_page.dart`, `lib/services/voice_agent_service.dart` | Firebase AI Logic from client; web uses browser speech APIs | User consent is shown; requires working App Check and model access. Not a medical or dispatch service. |
| Hospital discovery | `lib/screens/hospital_map_page.dart`, `lib/services/hospital_search_service.dart` | Nominatim / Overpass public endpoints | Community listings, not verified partners; no booking integration. |
| Passport / QR / family / timeline | `lib/screens/emergency_passport_page.dart`, `lib/screens/profile_pages.dart` | Passport details and QR consent share owner-scoped `/users/{uid}/passport/current`; legacy profile fields are mirrored during migration | The QR is still static and readable/copyable by scanners; family profiles remain owner-managed records, not delegated accounts or notifications. |

## Security review

- `firestore.rules` scopes user subcollections by UID, prevents clients from changing doctor role/facility fields, makes lab results server-write-only, limits alert creation to `Critical` and `prepared`, and does not let patients update trusted appointment review decisions.
- Doctor appointment review checks the authenticated custom claim, facility match, request status, and availability inside a transaction (`functions/index.js`). Doctor claims are issued by callable invite redemption or a privileged local script, not by profile writes.
- `storage.rules` denies all access by default. No user file upload path exists.
- The Firebase client API keys in `lib/firebase_options.dart` identify Firebase apps and are not service-account credentials. No service-account private key was found in the inspected tracked configuration. Client keys still require appropriate API restrictions and Firebase rules.
- The AI report function checks auth and explicit consent, loads the result only under the caller UID, sends a limited set of result fields to Vertex AI, and avoids logging report content. Production IAM, App Check enforcement, consent retention, and model region configuration require console-level verification.
- Rules have not been run through the Firestore emulator or an automated rules test suite in this audit. Security conclusions are based on source inspection only.

## Verification performed

- `npm.cmd test` in `functions/`: **passed**, 6 tests.
- `npm.cmd run lint` in `functions/`: **passed** (`node --check` across function and admin script sources).
- Flutter checks (`flutter pub get`, `flutter analyze`, `flutter test`, `flutter build web --release`): **not completed**. The local `flutter.bat --version` command stalled without output and left Dart subprocesses; Flutter package/build validation could not be established in this environment.
- Render deployment, Firebase console configuration, live auth, Firestore rules execution, Gemini Live sessions, microphone permissions, Android/iOS hardware, and browser console: **not verified**; these require an available toolchain and/or live project access.

## Remaining production blockers and next work

1. Run Flutter dependency resolution, analyzer, widget tests, and release web build in a functioning Flutter environment; fix any resulting failures.
2. Test Firebase Auth, App Check, Gemini Live, and callable functions in staging on Android, iOS, and supported browsers, including denied permissions and network loss.
3. Emulator-test Firestore rules with cross-user access, forged doctor claims, invalid appointment payloads, and public availability reads; tighten profile and appointment schemas.
4. Confirm Firebase Auth domains, AI Logic enablement, App Check enforcement/providers, Functions IAM/billing, deployed rules, and the actual Render secret/public key and HTTPS hostname.
5. Obtain authorized integrations before representing dispatch, lab delivery, clinic booking, or family notifications as operational.
6. Implement app-wide English/Kannada/Hindi localization and offline emergency instructions only with medically reviewed content and a release process.
