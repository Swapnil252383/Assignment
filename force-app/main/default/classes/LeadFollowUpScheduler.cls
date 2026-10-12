
global class LeadFollowUpScheduler implements Schedulable {

    global void execute(SchedulableContext context) {

        System.enqueueJob(
            new LeadCollectionQueueable()
        );
    }
}
