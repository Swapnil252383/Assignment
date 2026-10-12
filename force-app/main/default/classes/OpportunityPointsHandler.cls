public class OpportunityPointsHandler {

    public static void updateAccountPoints(
        Set<Id> accountIds
    ) {

        if (accountIds == null || accountIds.isEmpty()) {
            return;
        }

        List<Opportunity> opportunities = [
            SELECT Id,
                   AccountId,
                   StageName
            FROM Opportunity
            WHERE AccountId IN :accountIds
        ];


        // Number of Closed Won Opportunities
        Map<Id, Integer> closedWonCount =
            new Map<Id, Integer>();


        // First calculate Closed Won count
        for (Opportunity opp : opportunities) {

            if (opp.AccountId == null) {
                continue;
            }

            if (opp.StageName == 'Closed Won') {

                if (!closedWonCount.containsKey(opp.AccountId)) {

                    closedWonCount.put(
                        opp.AccountId,
                        0
                    );
                }

                closedWonCount.put(
                    opp.AccountId,
                    closedWonCount.get(opp.AccountId) + 1
                );
            }
        }


        // Calculate points
        Map<Id, Integer> accountPoints =
            new Map<Id, Integer>();


        for (Opportunity opp : opportunities) {

            if (opp.AccountId == null) {
                continue;
            }


            // Closed Lost = 0 points
            if (opp.StageName == 'Closed Lost') {
                continue;
            }


            Integer pointsForOpportunity = 1;


            // Closed Won with more than 5
            // Closed Won Opportunities
            if (opp.StageName == 'Closed Won') {

                Integer wonCount =
                    closedWonCount.get(opp.AccountId);

                if (wonCount > 5) {

                    pointsForOpportunity = 2;
                }
            }


            if (!accountPoints.containsKey(opp.AccountId)) {

                accountPoints.put(
                    opp.AccountId,
                    0
                );
            }


            accountPoints.put(
                opp.AccountId,
                accountPoints.get(opp.AccountId)
                + pointsForOpportunity
            );
        }


        List<Account> accountsToUpdate =
            new List<Account>();


        for (Id accountId : accountIds) {

            Integer points = 0;

            if (accountPoints.containsKey(accountId)) {

                points = accountPoints.get(accountId);
            }


            Account acc = new Account();

            acc.Id = accountId;
            acc.Points__c = points;

            accountsToUpdate.add(acc);
        }


        if (!accountsToUpdate.isEmpty()) {

            update accountsToUpdate;
        }
    }
}
