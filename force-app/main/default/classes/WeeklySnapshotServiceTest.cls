@IsTest
private class WeeklySnapshotServiceTest {

    private static void grantWeeklySnapshotAccess() {
        PermissionSet ps = [
            SELECT Id
            FROM PermissionSet
            WHERE Name = 'Weekly_Snapshot_User'
            LIMIT 1
        ];
        List<PermissionSetAssignment> existing = [
            SELECT Id
            FROM PermissionSetAssignment
            WHERE AssigneeId = :UserInfo.getUserId()
              AND PermissionSetId = :ps.Id
            LIMIT 1
        ];
        if (existing.isEmpty()) {
            insert new PermissionSetAssignment(
                AssigneeId = UserInfo.getUserId(),
                PermissionSetId = ps.Id
            );
        }
    }

    @IsTest
    static void testApril2021WeeklySnapshots() {
        grantWeeklySnapshotAccess();
        insertApril2021Tasks();

        Test.startTest();
        WeeklySnapshotService.generateForMonth(2021, 4);
        Test.stopTest();

        List<WeeklySnapshot__c> snapshots = [
            SELECT Name, Week_Start_Date__c, Week_End_Date__c, Week_Number__c,
                   Month__c, Year__c, Estimated_Hours__c, Billable_Hours__c,
                   Non_Billable_Hours__c, Summary__c
            FROM WeeklySnapshot__c
            WHERE Year__c = 2021 AND Month__c = 'April'
            ORDER BY Week_Number__c
        ];

        System.assertEquals(5, snapshots.size(), 'April 2021 should have 5 weekly snapshots');

        assertWeek(
            snapshots[0], 'WS-April-W1',
            Date.newInstance(2021, 4, 1), Date.newInstance(2021, 4, 4),
            1, 23, 22, 9, 3
        );
        assertWeek(
            snapshots[1], 'WS-April-W2',
            Date.newInstance(2021, 4, 5), Date.newInstance(2021, 4, 11),
            2, 40, 40, 9, 5
        );
        assertWeek(
            snapshots[2], 'WS-April-W3',
            Date.newInstance(2021, 4, 12), Date.newInstance(2021, 4, 18),
            3, 31, 31, 3, 4
        );
        assertWeek(
            snapshots[3], 'WS-April-W4',
            Date.newInstance(2021, 4, 19), Date.newInstance(2021, 4, 25),
            4, 53, 53, 6, 7
        );
        assertWeek(
            snapshots[4], 'WS-April-W5',
            Date.newInstance(2021, 4, 26), Date.newInstance(2021, 4, 30),
            5, 1, 1, 1, 1
        );
    }

    @IsTest
    static void testDuplicatePrevention() {
        grantWeeklySnapshotAccess();
        insertApril2021Tasks();

        WeeklySnapshotService.generateForMonth(2021, 4);
        WeeklySnapshotService.generateForMonth(2021, 4);

        Integer count = [
            SELECT COUNT()
            FROM WeeklySnapshot__c
            WHERE Year__c = 2021 AND Month__c = 'April'
        ];
        System.assertEquals(5, count, 'Duplicate snapshots must not be created');
    }

    @IsTest
    static void testMonthWithNoTasks() {
        grantWeeklySnapshotAccess();
        Test.startTest();
        WeeklySnapshotService.generateForMonth(2020, 2);
        Test.stopTest();

        List<WeeklySnapshot__c> snapshots = [
            SELECT Estimated_Hours__c, Billable_Hours__c, Non_Billable_Hours__c, Summary__c
            FROM WeeklySnapshot__c
            WHERE Year__c = 2020 AND Month__c = 'February'
        ];

        System.assert(snapshots.size() >= 4, 'Week segments should still be created');
        for (WeeklySnapshot__c snap : snapshots) {
            System.assertEquals(0, snap.Estimated_Hours__c);
            System.assertEquals(0, snap.Billable_Hours__c);
            System.assertEquals(0, snap.Non_Billable_Hours__c);
            System.assert(snap.Summary__c.contains('Total Tasks: 0'));
        }
    }

    @IsTest
    static void testMultipleTasksOnSameDate() {
        grantWeeklySnapshotAccess();
        List<Task> tasks = new List<Task>();
        Date sameDay = Date.newInstance(2021, 4, 19);
        tasks.add(buildTask(sameDay, 8, 8, 2));
        tasks.add(buildTask(sameDay, 8, 8, 1));
        tasks.add(buildTask(sameDay, 5, 5, 1));
        insert tasks;

        WeeklySnapshotService.generateForMonth(2021, 4);

        WeeklySnapshot__c week4 = [
            SELECT Estimated_Hours__c, Billable_Hours__c, Non_Billable_Hours__c, Summary__c
            FROM WeeklySnapshot__c
            WHERE Year__c = 2021 AND Month__c = 'April' AND Week_Number__c = 4
            LIMIT 1
        ];

        System.assertEquals(21, week4.Estimated_Hours__c);
        System.assertEquals(21, week4.Billable_Hours__c);
        System.assertEquals(4, week4.Non_Billable_Hours__c);
        System.assert(week4.Summary__c.contains('Total Tasks: 3'));
    }

    @IsTest
    static void testWeekSegmentBuilderApril2021() {
        Date monthStart = Date.newInstance(2021, 4, 1);
        Date monthEnd = Date.newInstance(2021, 4, 30);

        List<WeeklySnapshotService.WeekSegment> weeks =
            WeeklySnapshotService.buildWeekSegments(monthStart, monthEnd);

        System.assertEquals(5, weeks.size());
        System.assertEquals(Date.newInstance(2021, 4, 1), weeks[0].weekStart);
        System.assertEquals(Date.newInstance(2021, 4, 4), weeks[0].weekEnd);
        System.assertEquals(Date.newInstance(2021, 4, 26), weeks[4].weekStart);
        System.assertEquals(Date.newInstance(2021, 4, 30), weeks[4].weekEnd);
    }

    @IsTest
    static void testSchedulerCreatesSnapshots() {
        grantWeeklySnapshotAccess();
        Date today = Date.today();
        List<Task> tasks = new List<Task>();
        tasks.add(buildTask(today, 4, 3, 1));
        insert tasks;

        Test.startTest();
        System.schedule(
            'Test Weekly Snapshot Scheduler',
            WeeklySnapshotScheduler.getCronExpression(),
            new WeeklySnapshotScheduler()
        );
        Test.stopTest();

        List<WeeklySnapshot__c> snapshots = [
            SELECT Id
            FROM WeeklySnapshot__c
            WHERE Year__c = :today.year()
              AND Month__c = :getMonthName(today.month())
        ];
        System.assert(!snapshots.isEmpty(), 'Scheduler should create weekly snapshots');
    }

    private static void insertApril2021Tasks() {
        List<Task> tasks = new List<Task>();
        tasks.add(buildTask(Date.newInstance(2021, 4, 1), 8, 8, 2));
        tasks.add(buildTask(Date.newInstance(2021, 4, 2), 8, 7, 3));
        tasks.add(buildTask(Date.newInstance(2021, 4, 3), 7, 7, 4));
        tasks.add(buildTask(Date.newInstance(2021, 4, 6), 8, 8, 1));
        tasks.add(buildTask(Date.newInstance(2021, 4, 7), 8, 8, 2));
        tasks.add(buildTask(Date.newInstance(2021, 4, 8), 8, 8, 3));
        tasks.add(buildTask(Date.newInstance(2021, 4, 9), 8, 8, 2));
        tasks.add(buildTask(Date.newInstance(2021, 4, 9), 8, 8, 1));
        tasks.add(buildTask(Date.newInstance(2021, 4, 13), 8, 8, 0));
        tasks.add(buildTask(Date.newInstance(2021, 4, 14), 7, 7, 0));
        tasks.add(buildTask(Date.newInstance(2021, 4, 15), 8, 8, 1));
        tasks.add(buildTask(Date.newInstance(2021, 4, 16), 8, 8, 2));
        tasks.add(buildTask(Date.newInstance(2021, 4, 19), 8, 8, 2));
        tasks.add(buildTask(Date.newInstance(2021, 4, 19), 8, 8, 1));
        tasks.add(buildTask(Date.newInstance(2021, 4, 19), 5, 5, 1));
        tasks.add(buildTask(Date.newInstance(2021, 4, 20), 8, 8, 1));
        tasks.add(buildTask(Date.newInstance(2021, 4, 21), 8, 8, 0));
        tasks.add(buildTask(Date.newInstance(2021, 4, 22), 8, 8, 0));
        tasks.add(buildTask(Date.newInstance(2021, 4, 23), 8, 8, 1));
        tasks.add(buildTask(Date.newInstance(2021, 4, 26), 1, 1, 1));
        insert tasks;
    }

    private static Task buildTask(Date activityDate, Decimal estimated, Decimal billable, Decimal nonBillable) {
        return new Task(
            Subject = 'Test Task',
            Status = 'Completed',
            Priority = 'Normal',
            ActivityDate = activityDate,
            Estimated_Hours__c = estimated,
            Billable_Hours__c = billable,
            Non_Billable_Hours__c = nonBillable
        );
    }

    private static void assertWeek(
        WeeklySnapshot__c snap,
        String expectedName,
        Date expectedStart,
        Date expectedEnd,
        Integer expectedWeekNumber,
        Decimal expectedEstimated,
        Decimal expectedBillable,
        Decimal expectedNonBillable,
        Integer expectedTaskCount
    ) {
        System.assertEquals(expectedName, snap.Name);
        System.assertEquals(expectedStart, snap.Week_Start_Date__c);
        System.assertEquals(expectedEnd, snap.Week_End_Date__c);
        System.assertEquals(expectedWeekNumber, snap.Week_Number__c.intValue());
        System.assertEquals('April', snap.Month__c);
        System.assertEquals(2021, snap.Year__c.intValue());
        System.assertEquals(expectedEstimated, snap.Estimated_Hours__c);
        System.assertEquals(expectedBillable, snap.Billable_Hours__c);
        System.assertEquals(expectedNonBillable, snap.Non_Billable_Hours__c);
        System.assert(snap.Summary__c.contains('Week: ' + expectedWeekNumber));
        System.assert(snap.Summary__c.contains('Total Tasks: ' + expectedTaskCount));
    }

    private static String getMonthName(Integer month) {
        List<String> names = new List<String>{
            'January', 'February', 'March', 'April', 'May', 'June',
            'July', 'August', 'September', 'October', 'November', 'December'
        };
        return names[month - 1];
    }
}
