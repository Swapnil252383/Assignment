global class ClosedWonOpportunityBatch
    implements Database.Batchable<SObject> {

    private Date processingDate;

  
    global ClosedWonOpportunityBatch() {
        processingDate = Date.today().addDays(-1);
    }

    // Constructor for testing / manual execution
    global ClosedWonOpportunityBatch(Date processingDate) {
        this.processingDate = processingDate;
    }

    global Database.QueryLocator start(
        Database.BatchableContext bc
    ) {

        return Database.getQueryLocator([
            SELECT Id,
                   Name,
                   Primary_Email__c,
                   (
                       SELECT Id,
                              Name,
                              Amount
                       FROM Opportunities
                       WHERE StageName = 'Closed Won'
                       AND CloseDate = :processingDate
                       ORDER BY Name
                   )
            FROM Account
            WHERE Id IN (
                SELECT AccountId
                FROM Opportunity
                WHERE StageName = 'Closed Won'
                AND CloseDate = :processingDate
                AND AccountId != null
            )
        ]);
    }

    global void execute(
        Database.BatchableContext bc,
        List<Account> accounts
    ) {

        List<Messaging.SingleEmailMessage> emails =
            new List<Messaging.SingleEmailMessage>();

        for (Account acc : accounts) {

            // Skip Account if Primary Email is blank
            if (String.isBlank(acc.Primary_Email__c)) {
                continue;
            }

            // Skip if no Opportunities
            if (acc.Opportunities == null ||
                acc.Opportunities.isEmpty()) {
                continue;
            }

            Decimal totalAmount = 0;

            String emailBody = '';

            emailBody += '<html><body>';

            emailBody += '<h2>Daily Closed Won Opportunities</h2>';

            emailBody += '<p>Hello,</p>';

            emailBody +=
                '<p>Below are the Closed Won Opportunities ' +
                'for your account for ' +
                String.valueOf(processingDate) +
                '.</p>';

            emailBody +=
                '<table border="1" cellpadding="5" ' +
                'cellspacing="0">';

            emailBody +=
                '<tr>' +
                '<th>Opportunity Name</th>' +
                '<th>Amount</th>' +
                '</tr>';

            Integer opportunityCount = 0;

            for (Opportunity opp : acc.Opportunities) {

                Decimal amount = 0;

                if (opp.Amount != null) {
                    amount = opp.Amount;
                }

                totalAmount += amount;

                opportunityCount++;

                emailBody +=
                    '<tr>' +
                    '<td>' + escapeHtml(opp.Name) + '</td>' +
                    '<td>' + String.valueOf(amount) + '</td>' +
                    '</tr>';
            }

            emailBody += '</table>';

            emailBody += '<br/>';

            emailBody +=
                '<b>Total Opportunities: </b>' +
                String.valueOf(opportunityCount);

            emailBody += '<br/>';

            emailBody +=
                '<b>Total Amount: </b>' +
                String.valueOf(totalAmount);

            emailBody += '<br/><br/>';

            emailBody +=
                '<p>Regards,<br/>Salesforce System</p>';

            emailBody += '</body></html>';

            Messaging.SingleEmailMessage email =
                new Messaging.SingleEmailMessage();

            email.setToAddresses(
                new List<String>{
                    acc.Primary_Email__c
                }
            );

            email.setSubject(
                'Daily Closed Won Opportunities - ' +
                acc.Name
            );

            email.setHtmlBody(emailBody);

            emails.add(email);
        }

        // Send all emails in one call
        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails);
        }
    }

    global void finish(
        Database.BatchableContext bc
    ) {
        // No additional processing required.
    }


    private static String escapeHtml(String value) {

        if (value == null) {
            return '';
        }

        String result = value;

        result = result.replace('&', '&amp;');
        result = result.replace('<', '&lt;');
        result = result.replace('>', '&gt;');
        result = result.replace('"', '&quot;');
        result = result.replace('\'', '&#39;');

        return result;
    }
}
