@IsTest
private class OpportunityPointsHandlerTest {

    @IsTest
    static void testNormalOpportunities() {

        Account acc = new Account(
            Name = 'Test Account'
        );

        insert acc;


        List<Opportunity> opportunities =
            new List<Opportunity>();


        // Normal Opportunity
        opportunities.add(
            new Opportunity(
                Name = 'Prospecting Opp',
                AccountId = acc.Id,
                StageName = 'Prospecting',
                CloseDate = Date.today(),
                Amount = 1000
            )
        );


        // Closed Won
        opportunities.add(
            new Opportunity(
                Name = 'Closed Won Opp',
                AccountId = acc.Id,
                StageName = 'Closed Won',
                CloseDate = Date.today(),
                Amount = 2000
            )
        );


        // Closed Lost
        opportunities.add(
            new Opportunity(
                Name = 'Closed Lost Opp',
                AccountId = acc.Id,
                StageName = 'Closed Lost',
                CloseDate = Date.today(),
                Amount = 3000
            )
        );


        Test.startTest();

        insert opportunities;

        Test.stopTest();


        Account result = [
            SELECT Id,
                   Points__c
            FROM Account
            WHERE Id = :acc.Id
        ];


        /*
         * Prospecting = 1
         * Closed Won = 1
         * Closed Lost = 0
         *
         * Total = 2
         */

        System.assertEquals(
            2,
            result.Points__c
        );
    }


    @IsTest
    static void testMoreThanFiveClosedWon() {

        Account acc = new Account(
            Name = 'Six Won Account'
        );

        insert acc;


        List<Opportunity> opportunities =
            new List<Opportunity>();


        for (Integer i = 1; i <= 6; i++) {

            opportunities.add(
                new Opportunity(
                    Name = 'Closed Won ' + i,
                    AccountId = acc.Id,
                    StageName = 'Closed Won',
                    CloseDate = Date.today(),
                    Amount = 1000
                )
            );
        }


        Test.startTest();

        insert opportunities;

        Test.stopTest();


        Account result = [
            SELECT Id,
                   Points__c
            FROM Account
            WHERE Id = :acc.Id
        ];


        /*
         * 6 Closed Won
         *
         * 6 × 2 = 12 points
         */

        System.assertEquals(
            12,
            result.Points__c
        );
    }


    @IsTest
    static void testDeleteOpportunity() {

        Account acc = new Account(
            Name = 'Delete Test Account'
        );

        insert acc;


        Opportunity opp1 = new Opportunity(
            Name = 'Opportunity 1',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today(),
            Amount = 1000
        );


        Opportunity opp2 = new Opportunity(
            Name = 'Opportunity 2',
            AccountId = acc.Id,
            StageName = 'Closed Won',
            CloseDate = Date.today(),
            Amount = 2000
        );


        insert new List<Opportunity>{
            opp1,
            opp2
        };


        Account beforeDelete = [
            SELECT Points__c
            FROM Account
            WHERE Id = :acc.Id
        ];


        System.assertEquals(
            2,
            beforeDelete.Points__c
        );


        Test.startTest();

        delete opp1;

        Test.stopTest();


        Account afterDelete = [
            SELECT Points__c
            FROM Account
            WHERE Id = :acc.Id
        ];


        /*
         * Prospecting deleted
         *
         * Remaining:
         * Closed Won = 1
         *
         * Total = 1
         */

        System.assertEquals(
            1,
            afterDelete.Points__c
        );
    }


    @IsTest
    static void testUpdateOpportunity() {

        Account acc = new Account(
            Name = 'Update Test Account'
        );

        insert acc;


        Opportunity opp = new Opportunity(
            Name = 'Update Opportunity',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today(),
            Amount = 1000
        );

        insert opp;


        Account beforeUpdate = [
            SELECT Points__c
            FROM Account
            WHERE Id = :acc.Id
        ];


        System.assertEquals(
            1,
            beforeUpdate.Points__c
        );


        Test.startTest();

        opp.StageName = 'Closed Lost';

        update opp;

        Test.stopTest();


        Account afterUpdate = [
            SELECT Points__c
            FROM Account
            WHERE Id = :acc.Id
        ];


        /*
         * Closed Lost = 0
         */

        System.assertEquals(
            0,
            afterUpdate.Points__c
        );
    }


    @IsTest
    static void testAccountChange() {

        Account acc1 = new Account(
            Name = 'Account 1'
        );

        Account acc2 = new Account(
            Name = 'Account 2'
        );

        insert new List<Account>{
            acc1,
            acc2
        };


        Opportunity opp = new Opportunity(
            Name = 'Moving Opportunity',
            AccountId = acc1.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today(),
            Amount = 1000
        );

        insert opp;


        Test.startTest();

        opp.AccountId = acc2.Id;

        update opp;

        Test.stopTest();


        Account firstAccount = [
            SELECT Points__c
            FROM Account
            WHERE Id = :acc1.Id
        ];


        Account secondAccount = [
            SELECT Points__c
            FROM Account
            WHERE Id = :acc2.Id
        ];


        System.assertEquals(
            0,
            firstAccount.Points__c
        );


        System.assertEquals(
            1,
            secondAccount.Points__c
        );
    }
}
