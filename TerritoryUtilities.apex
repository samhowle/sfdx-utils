// Territory utilities

// Account assignments
SELECT id, Object.name, object.type, ObjectId, territory2.name, Territory2Id FROM ObjectTerritory2Association ORDER BY territory2.name DESC

// User territory assignments
SELECT id, Territory2Id, Territory2.name, user.name, userid, RoleInTerritory2 FROM UserTerritory2Association



List<Account> terrAcccounts = [SELECT Id, Name, recordtype.name, FAM_Code__c, ShippingCountry, BillingCountry, Country__c, Country__r.Name from account]

SELECT Id, Name, recordtype.name, FAM_Code__c, ShippingCountry, BillingCountry, Country__c, Country__r.Name from account where name like '%NGM%' and recordtype.name = 'Prospect'

0MI7Q000000QL93WAG



List<ObjectTerritory2Association> assignList = new List<ObjectTerritory2Association>();


for (Account acc : [SELECT Id, Name, FAM_Code__c, ShippingCountry, BillingCountry, Country__c, Country__r.Name from account where name like '%NGM%' and recordtype.name = 'Prospect']) {
    system.debug('acc: ' + acc);

    ObjectTerritory2Association ota = new ObjectTerritory2Association();

    ota.territory2id = '0MI7Q000000QL93WAG';
    ota.objectid = acc.Id;

    system.debug('ota: ' + ota);
    assignList.add(ota);
}

    // insert assignList;


// Find unassigned Accounts (could be used for Leads)

//Map<Id, Account> accountMap = new Map<Id, Account>([SELECT Id, Name, Recordtype.Name, fam_code__c, Country__r.Name, BillingCountry FROM Account WHERE Fam_Code__c = 'ARO']);
Map<Id, Account> accountMap = new Map<Id, Account>([SELECT Id, Name, Recordtype.Name, fam_code__c, Country__r.Name, BillingCountry FROM Account WHERE Country__c = 'a0W7Q00000441TkUAI']);
Map<Id, Set<String>> assignmentMap = new Map<Id, Set<String>>();

for (ObjectTerritory2Association ota : [SELECT Id, Object.Name, ObjectId, Territory2.Name FROM ObjectTerritory2Association WHERE Object.Type = 'Account']) {
    if (!assignmentMap.containsKey(ota.ObjectId)) {
        assignmentMap.put(ota.ObjectId, new Set<String>{ota.Territory2.Name});
    } else {
        //System.debug('already in map: ' + assignmentMap.get(ota.ObjectId));
        //System.debug('account name and id - territory: ' + ota.Object.Name + ' - ' + ota.ObjectId + ' - ' + ota.Territory2.Name);
        assignmentMap.get(ota.ObjectId).add(ota.Territory2.Name);
        //System.debug('map updated: ' + assignmentMap.get(ota.ObjectId));
    }
}
//System.debug('final assignmentMap.size(): ' + assignmentMap.size());

List<ObjectTerritory2Association> territoriesToAssign = new List<ObjectTerritory2Association>();
Map<Id, Account> unassignedAccounts = new Map<Id, Account>();
for (Id accId : accountMap.keySet()) {
    if (!assignmentMap.containsKey(accId)) {
        Account acct = accountMap.get(accId);
        System.debug('unassigned acct: ' + acct.Recordtype.Name + ' - ' + acct.Name);
        unassignedAccounts.put(accId, acct);

        ObjectTerritory2Association ota = new ObjectTerritory2Association();
        ota.territory2id = '0MI7Q000000QL93WAG'; // "United States of America" territory
        ota.objectid = acct.Id;
        ota.AssociationCause = 'Territory2Manual';
        System.debug('ota: ' + ota);
        territoriesToAssign.add(ota);
    }
}

System.debug('# territoriesToAssign: ' + territoriesToAssign.size());

//insert territoriesToAssign;