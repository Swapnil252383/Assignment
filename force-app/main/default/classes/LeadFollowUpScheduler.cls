
global class LeadFollowUpScheduler implements Schedulable {

    global void execute(SchedulableContext context) {

        System.enqueueJob(
            new LeadCollectionQueueable()
        );
    }
}




System.schedule(
    'Daily Lead Follow Up Job',
    '0 37 10 * * ?',
    new LeadFollowUpScheduler()
);
