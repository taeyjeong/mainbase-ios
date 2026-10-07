// Time zone helpers for the scheduled clock enforcement in index.js. Schedules are stored
// as minutes since midnight in their own zone, the terms doc's `timeZone`
// (MainBase/Models/EmploymentTerms.swift), and enforced in that zone.

// The zone of a schedule saved without one (all schedules from before per-employee zones).
// Mirrors EmploymentTerms.defaultTimeZone in the app. Pay months stay Pacific, so this is
// also the zone for pay-related dates (e.g. monthly summaries).
const DEFAULT_SCHEDULE_TIME_ZONE = "America/Los_Angeles";

// The terms doc's time zone if it's a valid IANA zone, else the default.
function scheduleTimeZone(terms) {
  const timeZone = terms?.timeZone;
  if (typeof timeZone !== "string" || !timeZone) return DEFAULT_SCHEDULE_TIME_ZONE;
  try {
    new Intl.DateTimeFormat("en-US", { timeZone });
    return timeZone;
  } catch (error) {
    return DEFAULT_SCHEDULE_TIME_ZONE;
  }
}

const WEEKDAYS = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"];

// Wall-clock date/time parts of `date` as seen in `timeZone`.
function zonedParts(date, timeZone) {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone,
    hourCycle: "h23",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  }).formatToParts(date);
  const get = (type) => Number(parts.find((part) => part.type === type).value);
  return {
    year: get("year"),
    month: get("month"),
    day: get("day"),
    hour: get("hour"),
    minute: get("minute"),
    second: get("second"),
  };
}

// Offset (ms) of `timeZone` from UTC at instant `utcMs`.
function offsetAt(utcMs, timeZone) {
  const p = zonedParts(new Date(utcMs), timeZone);
  return Date.UTC(p.year, p.month - 1, p.day, p.hour, p.minute, p.second) - utcMs;
}

// The instant when the wall clock in `timeZone` reads `minutes` past midnight on year/month/day.
// Re-checks the offset once so times on a DST-change day land correctly.
function zonedTimeToDate(year, month, day, minutes, timeZone) {
  const wallMs = Date.UTC(year, month - 1, day, 0, minutes);
  let result = wallMs - offsetAt(wallMs, timeZone);
  const corrected = wallMs - offsetAt(result, timeZone);
  if (corrected !== result) result = corrected;
  return new Date(result);
}

// Scheduled shifts for yesterday and today in the schedule's zone (yesterday first), so a
// shift ending late at night is still handled after midnight. Shifts never cross midnight:
// the app requires end > start.
function recentShifts(terms, now) {
  const timeZone = scheduleTimeZone(terms);
  const schedule = terms.schedule || {};
  const today = zonedParts(now, timeZone);
  const shifts = [];

  for (const daysAgo of [1, 0]) {
    const local = new Date(Date.UTC(today.year, today.month - 1, today.day - daysAgo));
    const year = local.getUTCFullYear();
    const month = local.getUTCMonth() + 1;
    const day = local.getUTCDate();
    const workDay = schedule[WEEKDAYS[local.getUTCDay()]];
    if (!workDay || workDay.isWorking !== true) continue;
    if (!Number.isInteger(workDay.startMinutes) || !Number.isInteger(workDay.endMinutes)) continue;
    if (workDay.endMinutes <= workDay.startMinutes) continue;

    shifts.push({
      key: `${year}-${String(month).padStart(2, "0")}-${String(day).padStart(2, "0")}`,
      start: zonedTimeToDate(year, month, day, workDay.startMinutes, timeZone),
      end: zonedTimeToDate(year, month, day, workDay.endMinutes, timeZone),
    });
  }
  return shifts;
}

module.exports = { recentShifts, zonedTimeToDate, scheduleTimeZone, DEFAULT_SCHEDULE_TIME_ZONE };
