
public class LeadCollectionQueueable implements Queueable {

    public void execute(QueueableContext context) {

        List<Lead> leads = [
            SELECT Id, OwnerId, Name
            FROM Lead
            WHERE Status = 'Working - Contacted'
        ];

        if (!leads.isEmpty()) {
            System.enqueueJob(
                new LeadTaskQueueable(leads)
            );
        }
    }
}
