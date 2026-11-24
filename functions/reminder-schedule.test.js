const assert = require('node:assert/strict');
const test = require('node:test');
const {
  appointmentInstant,
  dueMedicationTimes,
} = require('./reminder-schedule');

test('appointment slots use the saved local calendar day and timezone', () => {
  const savedLocalMidnight = new Date('2026-11-30T18:30:00.000Z');
  const instant = appointmentInstant(
    { date: savedLocalMidnight, slot: '10:00 AM' },
    330,
  );

  assert.equal(instant.toISOString(), '2026-12-01T04:30:00.000Z');
});

test('appointment slot parsing rejects invalid clock values', () => {
  const appointment = { date: new Date('2026-12-01T00:00:00.000Z') };

  assert.equal(appointmentInstant({ ...appointment, slot: '13:00 PM' }, 0), null);
  assert.equal(appointmentInstant({ ...appointment, slot: '10:75 AM' }, 0), null);
});

test('medicine reminders match local weekday and due-time window', () => {
  const now = new Date('2026-11-24T02:35:00.000Z'); // 08:05 Tuesday in India
  const medication = {
    active: true,
    days: [2],
    times: ['08:00', '08:00', '08:15', 'not-a-time'],
  };

  assert.deepEqual(dueMedicationTimes(medication, now, 330), ['08:00']);
  assert.deepEqual(
    dueMedicationTimes({ ...medication, days: [1] }, now, 330),
    [],
  );
  assert.deepEqual(
    dueMedicationTimes({ ...medication, active: false }, now, 330),
    [],
  );
});
