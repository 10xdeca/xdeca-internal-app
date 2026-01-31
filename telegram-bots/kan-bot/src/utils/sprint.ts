// Sprint timing utilities
// Sprints are 2 weeks, starting on Monday

const SPRINT_LENGTH_DAYS = 14;

// Get a known sprint start date from env, or default to a Monday
// This can be any past sprint start - we'll calculate from there
function getSprintEpoch(): Date {
  const envDate = process.env.SPRINT_START_DATE;
  if (envDate) {
    const date = new Date(envDate);
    if (!isNaN(date.getTime())) {
      return date;
    }
  }
  // Default: Jan 6, 2025 (a Monday)
  return new Date("2025-01-06");
}

/**
 * Get the current day of the sprint (1-14)
 * Day 1 = Monday of sprint start
 * Day 6 = Saturday (mid-sprint touchpoint)
 * Day 14 = Sunday (retro day)
 */
export function getSprintDay(now: Date = new Date()): number {
  const epoch = getSprintEpoch();
  const msPerDay = 24 * 60 * 60 * 1000;

  // Calculate days since sprint epoch
  const daysSinceEpoch = Math.floor((now.getTime() - epoch.getTime()) / msPerDay);

  // Get day within current sprint (0-13), then convert to 1-14
  const dayInSprint = ((daysSinceEpoch % SPRINT_LENGTH_DAYS) + SPRINT_LENGTH_DAYS) % SPRINT_LENGTH_DAYS;
  return dayInSprint + 1;
}

/**
 * Check if we're in the sprint planning window (days 1-2)
 * This is when we should nag about vague tasks and missing due dates
 */
export function isSprintPlanningWindow(now: Date = new Date()): boolean {
  const day = getSprintDay(now);
  return day <= 2; // Monday and Tuesday of sprint start
}

/**
 * Check if it's the mid-sprint touchpoint day (Saturday, day 6)
 */
export function isMidSprintDay(now: Date = new Date()): boolean {
  return getSprintDay(now) === 6;
}

/**
 * Check if it's retro day (Sunday, day 14)
 */
export function isRetroDay(now: Date = new Date()): boolean {
  return getSprintDay(now) === 14;
}

/**
 * Get sprint info for debugging/display
 */
export function getSprintInfo(now: Date = new Date()): {
  day: number;
  isPlanningWindow: boolean;
  isMidSprint: boolean;
  isRetro: boolean;
} {
  const day = getSprintDay(now);
  return {
    day,
    isPlanningWindow: day <= 2,
    isMidSprint: day === 6,
    isRetro: day === 14,
  };
}
