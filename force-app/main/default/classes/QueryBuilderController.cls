public with sharing class QueryBuilderController {

    public class OptionWrapper {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String value { get; set; }

        public OptionWrapper(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }

    public class QueryResultWrapper {
        @AuraEnabled public List<String> fields { get; set; }
        @AuraEnabled public List<Map<String, Object>> records { get; set; }

        public QueryResultWrapper() {
            fields = new List<String>();
            records = new List<Map<String, Object>>();
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<OptionWrapper> getObjects() {
        List<OptionWrapper> options = new List<OptionWrapper>();

        Map<String, Schema.SObjectType> objectMap =
            Schema.getGlobalDescribe();

        List<String> objectNames = new List<String>();

        for (String objectName : objectMap.keySet()) {
            Schema.DescribeSObjectResult objDescribe =
                objectMap.get(objectName).getDescribe();

            if (objDescribe.isQueryable() &&
                objDescribe.isAccessible() &&
                !objDescribe.isDeprecatedAndHidden()) {

                objectNames.add(objectName);
            }
        }

        objectNames.sort();

        for (String objectName : objectNames) {
            options.add(new OptionWrapper(objectName, objectName));
        }

        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<OptionWrapper> getFields(String objectName) {
        if (String.isBlank(objectName)) {
            throw new AuraHandledException('Please select an object.');
        }

        Map<String, Schema.SObjectType> objectMap =
            Schema.getGlobalDescribe();

        if (!objectMap.containsKey(objectName)) {
            throw new AuraHandledException('Invalid object selected.');
        }

        Schema.DescribeSObjectResult objDescribe =
            objectMap.get(objectName).getDescribe();

        if (!objDescribe.isQueryable() || !objDescribe.isAccessible()) {
            throw new AuraHandledException(
                'You do not have permission to query this object.'
            );
        }

        Map<String, Schema.SObjectField> fieldMap =
            objDescribe.fields.getMap();

        List<String> fieldNames = new List<String>();

        for (String fieldName : fieldMap.keySet()) {
            Schema.DescribeFieldResult fieldDescribe =
                fieldMap.get(fieldName).getDescribe();

           if (fieldDescribe.isAccessible()) {
    fieldNames.add(fieldName);
}
        }

        fieldNames.sort();

        List<OptionWrapper> options = new List<OptionWrapper>();

        for (String fieldName : fieldNames) {
            options.add(new OptionWrapper(fieldName, fieldName));
        }

        return options;
    }

    @AuraEnabled
    public static QueryResultWrapper executeQuery(
        String soql,
        Integer recordLimit
    ) {
        if (String.isBlank(soql)) {
            throw new AuraHandledException(
                'Please enter a SOQL query.'
            );
        }

        if (recordLimit == null ||
            !new Set<Integer>{500, 1000, 5000, 50000}
                .contains(recordLimit)) {

            throw new AuraHandledException('Invalid record limit.');
        }

        String queryText = soql.trim();

        if (!queryText.toUpperCase().startsWith('SELECT ')) {
            throw new AuraHandledException(
                'Only SELECT queries are allowed.'
            );
        }

        if (queryText.contains(';')) {
            throw new AuraHandledException(
                'Multiple statements are not allowed.'
            );
        }

        // Keep the user's query editable, but enforce the selected maximum.
        // Remove a trailing semicolon before executing; semicolons are
        // otherwise rejected above.
        String upperQuery = queryText.toUpperCase();

        // Reject unsupported query constructs for this query builder.
        if (upperQuery.contains(' FOR UPDATE') ||
            upperQuery.contains(' OFFSET ')) {
            throw new AuraHandledException(
                'FOR UPDATE and OFFSET are not supported.'
            );
        }

        // Apply the selected maximum to the final query.
        // If the user has already supplied a LIMIT, use the smaller limit.
        Integer effectiveLimit = recordLimit;
        Integer limitPosition = upperQuery.lastIndexOf(' LIMIT ');

        if (limitPosition >= 0) {
            String suppliedLimit = queryText.substring(
                limitPosition + 7
            ).trim();

            if (!Pattern.matches('[0-9]+', suppliedLimit)) {
                throw new AuraHandledException(
                    'Use a numeric LIMIT at the end of the query.'
                );
            }

            Integer userLimit = Integer.valueOf(suppliedLimit);

            if (userLimit < 1) {
                throw new AuraHandledException(
                    'LIMIT must be greater than zero.'
                );
            }

            effectiveLimit = Math.min(recordLimit, userLimit);

            queryText = queryText.substring(0, limitPosition).trim();
        }

        // Remove trailing whitespace and add our enforced limit.
        queryText += ' LIMIT ' + effectiveLimit;

        try {
            List<SObject> queriedRecords =
                Database.query(queryText, AccessLevel.USER_MODE);

            QueryResultWrapper result = new QueryResultWrapper();

            for (SObject recordItem : queriedRecords) {
                Map<String, Object> row =
                    new Map<String, Object>();

                Map<String, Object> rawFields =
                    recordItem.getPopulatedFieldsAsMap();

                for (String fieldName : rawFields.keySet()) {
                    row.put(fieldName, rawFields.get(fieldName));

                    if (!result.fields.contains(fieldName)) {
                        result.fields.add(fieldName);
                    }
                }

                Id recordId = (Id) recordItem.get('Id');

                row.put('RecordUrl', '/' + recordId);

                String recordLabel = String.valueOf(recordId);

                if (rawFields.containsKey('Name') &&
                    rawFields.get('Name') != null) {
                    recordLabel = String.valueOf(rawFields.get('Name'));
                }

                row.put('RecordLabel', recordLabel);
                result.records.add(row);
            }

            result.fields.sort();
            return result;

        } catch (Exception e) {
            throw new AuraHandledException(
                'Invalid SOQL query: ' + e.getMessage()
            );
        }
    }
}