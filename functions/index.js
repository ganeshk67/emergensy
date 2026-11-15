const admin = require('firebase-admin');
const { VertexAI } = require('@google-cloud/vertexai');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { HttpsError, onCall } = require('firebase-functions/v2/https');
const {
  buildDoctorClaims,
  hashDoctorInviteCode,
} = require('./doctor-invites');

admin.initializeApp();

const db = admin.firestore();
const region = 'asia-south1';
const vertexAI = new VertexAI({
  project: process.env.GCLOUD_PROJECT,
  location: region,
});

function requireDoctor(request) {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Sign in to continue.');
  }
  const { role, facilityId } = request.auth.token;
  if (role !== 'doctor' || typeof facilityId !== 'string' || !facilityId) {
    throw new HttpsError(
      'permission-denied',
      'A verified doctor account is required.',
    );
  }
  return { uid: request.auth.uid, facilityId };
}

async function findActiveDoctorInvite(inviteCode) {
  let inviteHash;
  try {
    inviteHash = hashDoctorInviteCode(inviteCode);
  } catch (_) {
    throw new HttpsError(
      'permission-denied',
      'The clinic invite code is invalid or inactive.',
    );
  }

  const invite = await db.collection('doctorInvites').doc(inviteHash).get();
  const data = invite.data();
  if (
    !invite.exists ||
    data?.active !== true ||
    typeof data.facilityId !== 'string' ||
    !data.facilityId ||
    typeof data.facilityName !== 'string' ||
    !data.facilityName
  ) {
    throw new HttpsError(
      'permission-denied',
      'The clinic invite code is invalid or inactive.',
    );
  }
  return data;
}

exports.validateDoctorInvite = onCall({ region }, async (request) => {
  await findActiveDoctorInvite(request.data?.inviteCode);
  return { valid: true };
});

exports.redeemDoctorInvite = onCall({ region }, async (request) => {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'Sign in to continue.');
  }
  const doctorName = request.data?.doctorName;
  if (
    typeof doctorName !== 'string' ||
    doctorName.trim().length < 2 ||
    doctorName.trim().length > 100
  ) {
    throw new HttpsError(
      'invalid-argument',
      'Enter a valid doctor name to enroll.',
    );
  }

  const invite = await findActiveDoctorInvite(request.data?.inviteCode);
  const auth = admin.auth();
  const user = await auth.getUser(request.auth.uid);
  const currentClaims = user.customClaims || {};
  const updatedClaims = buildDoctorClaims(
    currentClaims,
    invite,
    doctorName.trim(),
  );
  if (!updatedClaims) {
    throw new HttpsError(
      'failed-precondition',
      'This account is already assigned to another role or facility.',
    );
  }

  await auth.setCustomUserClaims(request.auth.uid, updatedClaims);
  return {
    facilityId: invite.facilityId,
    facilityName: invite.facilityName,
  };
});

exports.reviewAppointment = onCall({ region }, async (request) => {
  const doctor = requireDoctor(request);
  const appointmentId = request.data?.appointmentId;
  const status = request.data?.status;
  if (
    typeof appointmentId !== 'string' ||
    !/^[A-Za-z0-9_-]{1,128}$/.test(appointmentId) ||
    !['approved', 'declined'].includes(status)
  ) {
    throw new HttpsError('invalid-argument', 'Invalid appointment review.');
  }

  const appointmentRef = db.collection('appointments').doc(appointmentId);
  await db.runTransaction(async (transaction) => {
    const appointment = await transaction.get(appointmentRef);
    if (!appointment.exists) {
      throw new HttpsError('not-found', 'Appointment was not found.');
    }
    const data = appointment.data();
    if (data.facilityId !== doctor.facilityId) {
      throw new HttpsError(
        'permission-denied',
        'This appointment belongs to another facility.',
      );
    }
    if (data.status !== 'requested' || typeof data.patientUid !== 'string') {
      throw new HttpsError(
        'failed-precondition',
        'This request is no longer waiting for review.',
      );
    }

    let availabilityRef;
    if (status === 'approved' && typeof data.availabilityId === 'string') {
      availabilityRef = db
        .collection('facilities')
        .doc(doctor.facilityId)
        .collection('availability')
        .doc(data.availabilityId);
      const availability = await transaction.get(availabilityRef);
      if (!availability.exists || availability.data()?.status !== 'available') {
        throw new HttpsError(
          'failed-precondition',
          'This appointment time is no longer available.',
        );
      }
    }

    const review = {
      status,
      reviewedBy: doctor.uid,
      reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    transaction.update(appointmentRef, review);
    transaction.set(
      db
        .collection('users')
        .doc(data.patientUid)
        .collection('appointments')
        .doc(appointmentId),
      review,
      { merge: true },
    );
    if (availabilityRef) {
      transaction.update(availabilityRef, { status: 'booked' });
    }
  });

  return { status };
});

exports.summarizeLabResult = onCall(
  { region, timeoutSeconds: 60, memory: '512MiB' },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Sign in to continue.');
    }
    if (request.data?.consent !== true) {
      throw new HttpsError(
        'failed-precondition',
        'Explicit consent is required before AI processing.',
      );
    }
    const resultId = request.data?.resultId;
    if (typeof resultId !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(resultId)) {
      throw new HttpsError('invalid-argument', 'Invalid lab result.');
    }

    const userRef = db.collection('users').doc(request.auth.uid);
    const resultRef = userRef.collection('labResults').doc(resultId);
    const consentRef = userRef.collection('aiSummaryConsents').doc(resultId);
    const [resultSnapshot, consentSnapshot] = await Promise.all([
      resultRef.get(),
      consentRef.get(),
    ]);
    if (!consentSnapshot.exists || consentSnapshot.data()?.accepted !== true) {
      throw new HttpsError(
        'failed-precondition',
        'Record consent before requesting a summary.',
      );
    }
    if (!resultSnapshot.exists) {
      throw new HttpsError('not-found', 'Lab result was not found.');
    }

    const result = resultSnapshot.data();
    if (typeof result.aiSummary === 'string' && result.aiSummary.trim()) {
      return { summary: result.aiSummary };
    }

    const fields = ['testName', 'value', 'unit', 'referenceRange', 'status'];
    const values = Object.fromEntries(
      fields
        .filter((field) => result[field] != null)
        .map((field) => [field, String(result[field]).slice(0, 500)]),
    );
    if (!values.testName || !values.value) {
      throw new HttpsError(
        'failed-precondition',
        'This report has no structured result value to explain.',
      );
    }

    const model = vertexAI.getGenerativeModel({
      model: 'gemini-2.5-flash',
      generationConfig: { temperature: 0.1, maxOutputTokens: 400 },
    });
    const prompt = [
      'Explain this single laboratory result in plain, calm language for a patient.',
      'Use only the supplied fields. Do not diagnose, recommend treatment, or infer missing facts.',
      'Explain the reference range only if one is supplied. If a value is outside that range, say it deserves discussion with a qualified clinician; do not imply an emergency.',
      'Keep the explanation to 3 short sentences and end with: This explanation is not a diagnosis or a substitute for your clinician.',
      `Result fields: ${JSON.stringify(values)}`,
    ].join('\n');

    let response;
    try {
      response = await model.generateContent({
        contents: [{ role: 'user', parts: [{ text: prompt }] }],
      });
    } catch (error) {
      console.error('Vertex AI result explanation failed.', error);
      throw new HttpsError(
        'unavailable',
        'The explanation service is temporarily unavailable. Try again later.',
      );
    }

    const summary = response.response.candidates?.[0]?.content?.parts
      ?.map((part) => part.text || '')
      .join('')
      .trim();
    if (!summary) {
      throw new HttpsError(
        'unavailable',
        'The explanation service returned no summary.',
      );
    }

    await resultRef.update({
      aiSummary: summary.slice(0, 4000),
      aiSummaryAt: admin.firestore.FieldValue.serverTimestamp(),
      aiSummaryModel: 'gemini-2.5-flash',
    });
    return { summary: summary.slice(0, 4000) };
  },
);

exports.notifyNewLabResult = onDocumentCreated(
  {
    document: 'users/{userId}/labResults/{resultId}',
    region,
  },
  async (event) => {
    const userSnapshot = await db
      .collection('users')
      .doc(event.params.userId)
      .get();
    const token = userSnapshot.data()?.fcmToken;
    if (typeof token !== 'string' || !token) return;

    try {
      await admin.messaging().send({
        token,
        notification: {
          title: 'A new lab result is ready',
          body: 'Open EM3RGENSY to review the verified result.',
        },
        data: { type: 'lab_result' },
      });
    } catch (error) {
      console.error('Could not send lab result notification.', error);
    }
  },
);
