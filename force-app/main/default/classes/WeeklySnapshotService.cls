
public with sharing class WeeklySnapshotService {

    private static final List<String> MONTH_NAMES = new List<String>{
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
    };

    public class WeekSegment {
        public Integer weekNumber;
        public Date weekStart;
        public Date weekEnd;
    }


    public static void generateForCurrentMonth() {
        Date today = Date.today();
        generateForMonth(today.year(), today.month());
    }


    public static void generateForMonth(Integer year, Integer month) {
        if (year == null || month == null || month < 1 || month > 12) {
            return;
        }

        String monthName = getMonthName(month);
        Date monthStart = Date.newInstance(year, month, 1);
        Date monthEnd = monthStart.toStartOfMonth().addMonths(1).addDays(-1);

        List<WeekSegment> weeks = buildWeekSegments(monthStart, monthEnd);
        if (weeks.isEmpty()) {
            return;
        }

        Set<String> existingKeys = loadExistingSnapshotKeys(year, monthName);
        List<Task> tasks = queryTasksForMonth(monthStart, monthEnd);

        List<WeeklySnapshot__c> snapshotsToInsert = new List<WeeklySnapshot__c>();

        for (WeekSegment week : weeks) {
            String duplicateKey = buildDuplicateKey(
                week.weekStart, week.weekEnd, monthName, year
            );
            if (existingKeys.contains(duplicateKey)) {
                continue;
            }

            Decimal estimatedTotal = 0;
            Decimal billableTotal = 0;
            Decimal nonBillableTotal = 0;
            Integer taskCount = 0;

            for (Task t : tasks) {
                if (t.ActivityDate >= week.weekStart && t.ActivityDate <= week.weekEnd) {
                    taskCount++;
                    estimatedTotal += safeDecimal(t.Estimated_Hours__c);
                    billableTotal += safeDecimal(t.Billable_Hours__c);
                    nonBillableTotal += safeDecimal(t.Non_Billable_Hours__c);
                }
            }

            WeeklySnapshot__c snapshot = new WeeklySnapshot__c();
            snapshot.Name = 'WS-' + monthName + '-W' + week.weekNumber;
            snapshot.Week_Start_Date__c = week.weekStart;
            snapshot.Week_End_Date__c = week.weekEnd;
            snapshot.Week_Number__c = week.weekNumber;
            snapshot.Month__c = monthName;
            snapshot.Year__c = year;
            snapshot.Estimated_Hours__c = estimatedTotal;
            snapshot.Billable_Hours__c = billableTotal;
            snapshot.Non_Billable_Hours__c = nonBillableTotal;
            snapshot.Summary__c = buildSummary(
                week.weekNumber,
                monthName,
                week.weekStart,
                week.weekEnd,
                taskCount,
                estimatedTotal,
                billableTotal,
                nonBillableTotal
            );

            snapshotsToInsert.add(snapshot);
        }

        if (!snapshotsToInsert.isEmpty()) {
            insert snapshotsToInsert;
        }
    }

    @TestVisible
    private static List<WeekSegment> buildWeekSegments(Date monthStart, Date monthEnd) {
        List<WeekSegment> weeks = new List<WeekSegment>();
        Date weekStart = monthStart;
        Integer weekNumber = 1;

        while (weekStart <= monthEnd) {
            Date weekEnd;

            if (weekNumber == 1) {
                Date firstSunday = firstSundayOnOrAfter(monthStart);
                weekEnd = firstSunday <= monthEnd ? firstSunday : monthEnd;
            } else {
                Date sundayEnd = weekStart.addDays(6);
                weekEnd = sundayEnd <= monthEnd ? sundayEnd : monthEnd;
            }

            WeekSegment segment = new WeekSegment();
            segment.weekNumber = weekNumber;
            segment.weekStart = weekStart;
            segment.weekEnd = weekEnd;
            weeks.add(segment);

            weekStart = weekEnd.addDays(1);
            weekNumber++;
        }

        return weeks;
    }

    private static Date firstSundayOnOrAfter(Date startDate) {
        Date current = startDate;
        while (!isSunday(current)) {
            current = current.addDays(1);
        }
        return current;
    }

    private static Boolean isSunday(Date d) {
        Datetime dt = Datetime.newInstance(d, Time.newInstance(12, 0, 0, 0));
        return dt.format('u') == '7';
    }

    private static List<Task> queryTasksForMonth(Date monthStart, Date monthEnd) {
        return [
            SELECT ActivityDate, Estimated_Hours__c, Billable_Hours__c, Non_Billable_Hours__c
            FROM Task
            WHERE ActivityDate >= :monthStart
              AND ActivityDate <= :monthEnd
        ];
    }

    private static Set<String> loadExistingSnapshotKeys(Integer year, String monthName) {
        Set<String> keys = new Set<String>();
        for (WeeklySnapshot__c existing : [
            SELECT Week_Start_Date__c, Week_End_Date__c, Month__c, Year__c
            FROM WeeklySnapshot__c
            WHERE Year__c = :year
              AND Month__c = :monthName
        ]) {
            keys.add(
                buildDuplicateKey(
                    existing.Week_Start_Date__c,
                    existing.Week_End_Date__c,
                    existing.Month__c,
                    Integer.valueOf(existing.Year__c)
                )
            );
        }
        return keys;
    }

    private static String buildDuplicateKey(
        Date weekStart,
        Date weekEnd,
        String monthName,
        Integer year
    ) {
        return String.valueOf(weekStart) + '|' + String.valueOf(weekEnd) + '|' + monthName + '|' + year;
    }

    private static String getMonthName(Integer month) {
        return MONTH_NAMES[month - 1];
    }

    private static Decimal safeDecimal(Decimal value) {
        return value == null ? 0 : value;
    }

    private static String buildSummary(
        Integer weekNumber,
        String monthName,
        Date weekStart,
        Date weekEnd,
        Integer taskCount,
        Decimal estimated,
        Decimal billable,
        Decimal nonBillable
    ) {
        return 'Week: ' + weekNumber + '\n'
            + 'Period: ' + formatDisplayDate(weekStart) + ' - ' + formatDisplayDate(weekEnd) + '\n'
            + 'Total Tasks: ' + taskCount + '\n'
            + 'Estimated Hours: ' + estimated.stripTrailingZeros().toPlainString() + '\n'
            + 'Billable Hours: ' + billable.stripTrailingZeros().toPlainString() + '\n'
            + 'Non-Billable Hours: ' + nonBillable.stripTrailingZeros().toPlainString();
    }

    private static String formatDisplayDate(Date d) {
        return getMonthName(d.month()) + ' ' + d.day() + ', ' + d.year();
    }
}
