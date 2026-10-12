
public class LeadTaskQueueable implements Queueable {

    private List<Lead> leads;

    public LeadTaskQueueable(List<Lead> leads) {
        this.leads = leads;
    }

    public void execute(QueueableContext context) {

        List<Task> tasksToInsert = new List<Task>();

        for (Lead leadRecord : leads) {

            Task newTask = new Task();

            newTask.Subject = 'Follow-up on Lead';
            newTask.Priority = 'Normal';
            newTask.Status = 'Not Started';
            newTask.WhoId = leadRecord.Id;
            newTask.OwnerId = leadRecord.OwnerId;

            tasksToInsert.add(newTask);
        }

        if (!tasksToInsert.isEmpty()) {
            insert tasksToInsert;
        }
    }
}
