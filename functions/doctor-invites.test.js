const assert = require('node:assert/strict');
const test = require('node:test');
const {
  createDoctorInviteCode,
  hashDoctorInviteCode,
  buildDoctorClaims,
  parseDoctorInviteArguments,
} = require('./doctor-invites');

test('doctor invite codes are high-entropy URL-safe strings', () => {
  const code = createDoctorInviteCode();

  assert.match(code, /^[A-Za-z0-9_-]{43}$/);
});

test('doctor invite codes are hashed deterministically', () => {
  const code = 'a-valid-but-not-real-clinic-code';

  assert.equal(hashDoctorInviteCode(code), hashDoctorInviteCode(code));
  assert.notEqual(hashDoctorInviteCode(code), hashDoctorInviteCode(`${code}x`));
  assert.throws(() => hashDoctorInviteCode('short'), /Invalid clinic invite/);
});

test('doctor claims are facility-scoped and preserve unrelated claims', () => {
  const currentClaims = { locale: 'en', role: 'doctor', facilityId: 'clinic-123' };
  const invite = {
    facilityId: 'clinic-123',
    facilityName: 'North Clinic',
  };

  assert.deepEqual(
    buildDoctorClaims(currentClaims, invite, 'Dr. Example'),
    {
      locale: 'en',
      role: 'doctor',
      facilityId: 'clinic-123',
      facilityName: 'North Clinic',
      doctorName: 'Dr. Example',
    },
  );
  assert.equal(
    buildDoctorClaims(
      { role: 'doctor', facilityId: 'another-clinic' },
      invite,
      'Dr. Example',
    ),
    null,
  );
  assert.equal(
    buildDoctorClaims({ role: 'admin' }, invite, 'Dr. Example'),
    null,
  );
});

test('facility invite management supports creation and revocation', () => {
  assert.deepEqual(
    parseDoctorInviteArguments(['clinic-123', 'North Clinic']),
    {
      revoke: false,
      facilityId: 'clinic-123',
      facilityName: 'North Clinic',
    },
  );
  assert.deepEqual(parseDoctorInviteArguments(['--revoke', 'clinic-123']), {
    revoke: true,
    facilityId: 'clinic-123',
  });
});
