import { LightningElement } from 'lwc';

import getObjects from '@salesforce/apex/QueryBuilderController.getObjects';
import getFields from '@salesforce/apex/QueryBuilderController.getFields';
import executeQuery from '@salesforce/apex/QueryBuilderController.executeQuery';

export default class QueryBuilder extends LightningElement {

    objectOptions = [];
    fieldOptions = [];
    selectedObject = '';
    selectedFields = [];
    recordLimit = '500';
    soql = '';
    records = [];
    columns = [];
    errorMessage = '';
    isLoading = false;

    limitOptions = [
        { label: '500', value: '500' },
        { label: '1000', value: '1000' },
        { label: '5000', value: '5000' },
        { label: '50000', value: '50000' }
    ];

    connectedCallback() {
        this.loadObjects();
    }

    async loadObjects() {
        try {
            this.objectOptions = await getObjects();
        } catch (error) {
            this.showError(error);
        }
    }

    async handleObjectChange(event) {
        this.selectedObject = event.detail.value;
        this.selectedFields = [];
        this.fieldOptions = [];
        this.records = [];
        this.columns = [];
        this.errorMessage = '';

        try {
            this.fieldOptions = await getFields({
                objectName: this.selectedObject
            });

            this.generateQuery();
        } catch (error) {
            this.showError(error);
        }
    }

    handleFieldsChange(event) {
        this.selectedFields = [...event.detail.value];
        this.generateQuery();
    }

    handleLimitChange(event) {
        this.recordLimit = event.detail.value;
        this.generateQuery();
    }

    handleQueryChange(event) {
        this.soql = event.detail.value;
    }

    generateQuery() {
        if (!this.selectedObject) {
            this.soql = '';
            return;
        }

        // Id is required to identify and link each result.
        const fields = [...new Set([
            'Id',
            ...this.selectedFields
        ])].sort();

        this.soql =
            `SELECT ${fields.join(', ')} ` +
            `FROM ${this.selectedObject} ` +
            `LIMIT ${this.recordLimit}`;
    }

    async handleExecute() {
        this.isLoading = true;
        this.errorMessage = '';
        this.records = [];
        this.columns = [];

        try {
            const result = await executeQuery({
                soql: this.soql,
                recordLimit: Number(this.recordLimit)
            });

            this.records = result.records || [];

            // Show a clickable record name, even when the object
            // does not have a Name field.
            this.columns = [
                {
                    label: 'Record',
                    fieldName: 'RecordUrl',
                    type: 'url',
                    typeAttributes: {
                        label: { fieldName: 'RecordLabel' },
                        target: '_self'
                    }
                },
                ...this.selectedFields
                    .filter(field => field !== 'Id')
                    .map(field => ({
                        label: field,
                        fieldName: field,
                        type: 'text'
                    }))
            ];

            // Handle an edited query containing fields not selected
            // in the original field picker.
            const displayedFields = new Set(
                this.columns.map(column => column.fieldName)
            );

            (result.fields || []).forEach(field => {
                if (
                    field !== 'Id' &&
                    field !== 'Name' &&
                    field !== 'RecordUrl' &&
                    field !== 'RecordLabel' &&
                    !displayedFields.has(field)
                ) {
                    this.columns.push({
                        label: field,
                        fieldName: field,
                        type: 'text'
                    });
                }
            });

        } catch (error) {
            this.showError(error);
        } finally {
            this.isLoading = false;
        }
    }

    get hasResults() {
        return this.records.length > 0;
    }

    get resultCount() {
        return this.records.length;
    }

    showError(error) {
        this.errorMessage =
            error?.body?.message ||
            error?.message ||
            'Something went wrong.';
    }
}