
@IsTest
private class QueryBuilderControllerTest {

    @IsTest
    static void testGetObjects() {
        Test.startTest();
        List<QueryBuilderController.OptionWrapper> results =
            QueryBuilderController.getObjects();
        Test.stopTest();

        System.assertNotEquals(null, results);
        System.assert(!results.isEmpty());

        Boolean foundAccount = false;

        for (QueryBuilderController.OptionWrapper option : results) {
            if (option.value == 'Account') {
                foundAccount = true;
                break;
            }
        }

        System.assert(foundAccount, 'Account should be available.');
    }

    @IsTest
    static void testGetFields() {
        Test.startTest();
        List<QueryBuilderController.OptionWrapper> results =
            QueryBuilderController.getFields('Account');
        Test.stopTest();

        System.assertNotEquals(null, results);
        System.assert(!results.isEmpty());

        Boolean foundName = false;

        for (QueryBuilderController.OptionWrapper option : results) {
            if (option.value == 'Name') {
                foundName = true;
                break;
            }
        }

        System.assert(foundName, 'Account Name should be available.');
    }

    @IsTest
    static void testExecuteQuery() {
        Account testAccount = new Account(Name = 'Query Builder Test');
        insert testAccount;

        Test.startTest();

        QueryBuilderController.QueryResultWrapper result =
            QueryBuilderController.executeQuery(
                'SELECT Id, Name FROM Account WHERE Name = \'Query Builder Test\'',
                500
            );

        Test.stopTest();

        System.assertEquals(1, result.records.size());
        System.assertEquals(
            testAccount.Id,
            (Id) result.records[0].get('Id')
        );
        System.assertEquals(
            'Query Builder Test',
            result.records[0].get('Name')
        );
        System.assertEquals(
            '/' + testAccount.Id,
            result.records[0].get('RecordUrl')
        );
    }

    @IsTest
    static void testBlankQuery() {
        Boolean exceptionThrown = false;

        Test.startTest();

        try {
            QueryBuilderController.executeQuery('', 500);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }

        Test.stopTest();

        System.assert(exceptionThrown);
    }

    @IsTest
    static void testInvalidQueryType() {
        Boolean exceptionThrown = false;

        try {
            QueryBuilderController.executeQuery(
                'DELETE FROM Account',
                500
            );
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }

        System.assert(exceptionThrown);
    }

    @IsTest
    static void testInvalidLimit() {
        Boolean exceptionThrown = false;

        try {
            QueryBuilderController.executeQuery(
                'SELECT Id FROM Account',
                100
            );
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }

        System.assert(exceptionThrown);
    }

    @IsTest
    static void testInvalidObject() {
        Boolean exceptionThrown = false;

        try {
            QueryBuilderController.getFields('Invalid_Object__c');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }

        System.assert(exceptionThrown);
    }
}
