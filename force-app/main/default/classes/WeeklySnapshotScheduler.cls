
public with sharing class WeeklySnapshotScheduler implements Schedulable {

    public void execute(SchedulableContext context) {
        WeeklySnapshotService.generateForCurrentMonth();
    }

    public static String getCronExpression() {
        return '0 0 0 1 * ?';
    }

    public static Id scheduleMonthlyJob() {
        return System.schedule(
            'Weekly Snapshot Monthly Job',
            getCronExpression(),
            new WeeklySnapshotScheduler()
        );
    }
}
