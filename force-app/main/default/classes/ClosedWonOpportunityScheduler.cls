global class ClosedWonOpportunityScheduler
    implements Schedulable {

    global void execute(
        SchedulableContext sc
    ) {

        ClosedWonOpportunityBatch batch =
            new ClosedWonOpportunityBatch();

        Database.executeBatch(
            batch,
            200
        );
    }
}



System.schedule(
    'Daily Closed Won Opportunity Job',
    '0 0 0 * * ?',
    new ClosedWonOpportunityScheduler()
);
