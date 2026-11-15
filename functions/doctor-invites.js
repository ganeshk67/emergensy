const { createHash, randomBytes } = require('node:crypto');

function createDoctorInviteCode() {
  return randomBytes(32).toString('base64url');
}

function hashDoctorInviteCode(code) {
  const normalized = typeof code === 'string' ? code.trim() : '';
  if (!/^[A-Za-z0-9_-]{20,128}$/.test(normalized)) {
    throw new TypeError('Invalid clinic invite code.');
  }
  return createHash('sha256').update(normalized).digest('hex');
}

function buildDoctorClaims(currentClaims, invite, doctorName) {
  if (
    currentClaims.role &&
    (currentClaims.role !== 'doctor' ||
      currentClaims.facilityId !== invite.facilityId)
  ) {
    return null;
  }
  return {
    ...currentClaims,
    role: 'doctor',
    facilityId: invite.facilityId,
    facilityName: invite.facilityName,
    doctorName,
  };
}

function parseDoctorInviteArguments(args) {
  if (args[0] === '--revoke') {
    const facilityId = args[1];
    if (!facilityId || args.length !== 2) {
      throw new Error(
        'Usage: node scripts/manage-doctor-invite.js --revoke <facilityId>',
      );
    }
    return { revoke: true, facilityId };
  }

  const [facilityId, facilityName] = args;
  if (
    !facilityId ||
    !/^[A-Za-z0-9_-]{1,128}$/.test(facilityId) ||
    !facilityName ||
    facilityName.trim().length < 2 ||
    facilityName.trim().length > 120 ||
    args.length !== 2
  ) {
    throw new Error(
      'Usage: node scripts/manage-doctor-invite.js <facilityId> "<facilityName>"',
    );
  }
  return { revoke: false, facilityId, facilityName: facilityName.trim() };
}

module.exports = {
  createDoctorInviteCode,
  hashDoctorInviteCode,
  buildDoctorClaims,
  parseDoctorInviteArguments,
};
