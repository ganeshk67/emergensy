const assert = require('node:assert/strict');
const test = require('node:test');
const { parseArguments } = require('./set-doctor-claims');

test('parses all doctor claim grant arguments', () => {
  assert.deepEqual(
    parseArguments(['doctor-uid', 'clinic-123', 'North Clinic', 'Dr. Example']),
    {
      uid: 'doctor-uid',
      revoke: false,
      facilityId: 'clinic-123',
      facilityName: 'North Clinic',
      doctorName: 'Dr. Example',
    },
  );
});

test('parses doctor claim revocation', () => {
  assert.deepEqual(parseArguments(['--revoke', 'doctor-uid']), {
    uid: 'doctor-uid',
    revoke: true,
    facilityId: undefined,
    facilityName: undefined,
    doctorName: undefined,
  });
});
