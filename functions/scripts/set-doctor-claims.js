const admin = require('firebase-admin');
const { getAuth } = require('firebase-admin/auth');

function parseArguments(args) {
  const revoke = args[0] === '--revoke';
  const uid = revoke ? args[1] : args[0];
  const facilityId = revoke ? undefined : args[1];
  const facilityName = revoke ? undefined : args[2];
  const doctorName = revoke ? undefined : args[3];
  if (!uid || (!revoke && (!facilityId || !facilityName || !doctorName))) {
    throw new Error(
      'Usage: node scripts/set-doctor-claims.js <uid> <facilityId> <facilityName> <doctorName>\n' +
        '   or: node scripts/set-doctor-claims.js --revoke <uid>',
    );
  }
  return { uid, revoke, facilityId, facilityName, doctorName };
}

async function main(args = process.argv.slice(2)) {
  const { uid, revoke, facilityId, facilityName, doctorName } =
    parseArguments(args);
  admin.initializeApp();
  const auth = getAuth();
  const user = await auth.getUser(uid);
  const current = user.customClaims || {};
  const claims =
    revoke
      ? Object.fromEntries(
          Object.entries(current).filter(
            ([key]) =>
              !['role', 'facilityId', 'facilityName', 'doctorName'].includes(
                key,
              ),
          ),
        )
      : {
          ...current,
          role: 'doctor',
          facilityId,
          facilityName,
          doctorName,
        };
  await auth.setCustomUserClaims(uid, claims);
  console.log(
    revoke
      ? `Doctor access revoked for ${uid}. Ask the user to sign out and back in.`
      : `Doctor access granted for ${uid} at ${facilityName}. Ask the user to sign out and back in.`,
  );
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error.message || error);
    process.exitCode = 1;
  });
}

module.exports = { parseArguments };
