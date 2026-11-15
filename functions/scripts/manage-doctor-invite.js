const admin = require('firebase-admin');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const {
  createDoctorInviteCode,
  hashDoctorInviteCode,
  parseDoctorInviteArguments,
} = require('../doctor-invites');

async function main(args = process.argv.slice(2)) {
  const { revoke, facilityId, facilityName } =
    parseDoctorInviteArguments(args);
  const projectId =
    process.env.GOOGLE_CLOUD_PROJECT ||
    process.env.GCLOUD_PROJECT ||
    'emergensy-ca0f3';
  admin.initializeApp({ projectId });
  const db = getFirestore();
  const invites = db.collection('doctorInvites');
  const existing = await invites.where('facilityId', '==', facilityId).get();
  const batch = db.batch();
  let activeCount = 0;

  for (const document of existing.docs) {
    if (document.data().active === true) {
      batch.update(document.ref, {
        active: false,
        revokedAt: FieldValue.serverTimestamp(),
      });
      activeCount++;
    }
  }

  if (revoke) {
    if (activeCount > 0) await batch.commit();
    console.log(
      activeCount > 0
        ? `Revoked the active doctor invite for ${facilityId}.`
        : `No active doctor invite exists for ${facilityId}.`,
    );
    return;
  }

  const code = createDoctorInviteCode();
  batch.set(invites.doc(hashDoctorInviteCode(code)), {
    facilityId,
    facilityName,
    active: true,
    createdAt: FieldValue.serverTimestamp(),
  });
  await batch.commit();
  console.log(`Created an invite code for ${facilityName}. Share securely:`);
  console.log(code);
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error.message || error);
    process.exitCode = 1;
  });
}

module.exports = { main };
