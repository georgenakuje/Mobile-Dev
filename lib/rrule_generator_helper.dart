/// Utility function to format a DateTime object into the iCalendar UTC format:
/// YYYYMMDDTHHMMSSZ. This format is mandatory for the UNTIL parameter.
String _formatDateToIcsUtc(DateTime date) {
  // Convert to UTC, which is required for the UNTIL date in RRULE.
  final utcDate = date.toUtc();

  // Format components, ensuring two digits for month, day, hour, minute, second.
  return [
    utcDate.year.toString().padLeft(4, '0'),
    utcDate.month.toString().padLeft(2, '0'),
    utcDate.day.toString().padLeft(2, '0'),
    'T',
    utcDate.hour.toString().padLeft(2, '0'),
    utcDate.minute.toString().padLeft(2, '0'),
    utcDate.second.toString().padLeft(2, '0'),
    'Z', // Indicates UTC time
  ].join();
}

/// Generates an iCalendar (ICS) Recurrence Rule (RRULE) string
/// based on the selected recurrence option and an optional end date.
///
/// Parameters:
/// - `option`: The desired recurrence frequency (e.g., Weekly, Monthly).
/// - `endDate`: The date when the recurrence should stop. If provided,
///   it is formatted and appended as the UNTIL parameter in the RRULE.
///
/// Returns:
/// A valid RRULE string (e.g., "FREQ=WEEKLY;INTERVAL=2;UNTIL=20240101T000000Z")
/// or an empty string if the option is RecurrenceOption.Never.
String generateIcsRrule({required String option, DateTime? endDate}) {
  String rrule = '';

  switch (option) {
    case "Never":
      return ''; // No recurrence rule

    case "Daily":
      rrule = 'RRULE:FREQ=DAILY';
      break;

    case "Weekly":
      rrule = 'RRULE:FREQ=WEEKLY';
      break;

    case "BiWeekly":
      rrule =
          'RRULE:FREQ=WEEKLY;INTERVAL=2'; // Bi-Weekly is WEEKLY with INTERVAL=2
      break;

    case "Monthly":
      // Note: By default, FREQ=MONTHLY repeats on the same day of the month
      // (e.g., if the start day is the 15th, it repeats on the 15th of every month).
      rrule = 'RRULE:FREQ=MONTHLY';
      break;

    case "Yearly":
      rrule = 'RRULE:FREQ=YEARLY';
      break;
    default:
      return '';
  }

  // If an end date is provided, append the UNTIL parameter.
  if (endDate != null) {
    final untilString = _formatDateToIcsUtc(endDate);
    rrule = '$rrule;UNTIL=$untilString';
  }

  return rrule;
}
