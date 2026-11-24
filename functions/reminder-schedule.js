function asDate(value) {
  if (value && typeof value.toDate === 'function') return value.toDate();
  if (value instanceof Date) return value;
  if (typeof value === 'string') {
    const parsed = new Date(value);
    if (!Number.isNaN(parsed.getTime())) return parsed;
  }
  return null;
}

function localParts(date, offsetMinutes) {
  return new Date(date.getTime() + offsetMinutes * 60_000);
}

function appointmentInstant(appointment, offsetMinutes) {
  const date = asDate(appointment.date);
  const slot = typeof appointment.slot === 'string' ? appointment.slot : '';
  const match = slot.match(/^\s*(\d{1,2}):(\d{2})\s*(AM|PM)\s*$/i);
  if (!date || !match) return null;
  const rawHour = Number(match[1]);
  const minute = Number(match[2]);
  if (rawHour < 1 || rawHour > 12 || minute > 59) return null;
  let hour = rawHour % 12;
  if (match[3].toUpperCase() === 'PM') hour += 12;
  const localDate = localParts(date, offsetMinutes);
  return new Date(
    Date.UTC(
      localDate.getUTCFullYear(),
      localDate.getUTCMonth(),
      localDate.getUTCDate(),
      hour,
      minute,
    ) -
      offsetMinutes * 60_000,
  );
}

function dueMedicationTimes(medication, now, offsetMinutes, graceMinutes = 9) {
  if (!medication || medication.active === false) return [];
  const localNow = localParts(now, offsetMinutes);
  const weekday = localNow.getUTCDay() === 0 ? 7 : localNow.getUTCDay();
  const days = Array.isArray(medication.days) ? medication.days : [];
  if (!days.includes(weekday)) return [];
  const minuteOfDay = localNow.getUTCHours() * 60 + localNow.getUTCMinutes();
  return [...new Set(Array.isArray(medication.times) ? medication.times : [])]
    .filter((time) => {
      if (typeof time !== 'string' || !/^([01]\d|2[0-3]):[0-5]\d$/.test(time)) {
        return false;
      }
      const [hour, minute] = time.split(':').map(Number);
      const lateness = minuteOfDay - hour * 60 - minute;
      return lateness >= 0 && lateness <= graceMinutes;
    })
    .sort();
}

module.exports = { asDate, localParts, appointmentInstant, dueMedicationTimes };
