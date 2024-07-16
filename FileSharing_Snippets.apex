Map<String, String> financialDocumentMap = new Map<String, String>(); // ContentDocumentId to Financial Record ID

// Get all ContentVersions (version of a File, usually only one of them) that are related to a Financial Record via the custom lookup field
for (ContentVersion cv : [SELECT Id, PathOnClient, LastModifiedDate, ContentDocumentId, SharingPrivacy, SharingOption, Financial_Record__c, FirstPublishLocationId, 
	Financial_Record__r.Account__c, Financial_Record__r.Account__r.Name FROM ContentVersion WHERE Financial_Record__c != '' AND Financial_Record__r.Type__c != 'Credit Limit']) {
	financialDocumentMap.put(cv.ContentDocumentId, cv.Financial_Record__c);
	//System.debug(cv);
	//System.debug('Account: ' + cv.Financial_Record__r.Account__c + ' : ' + cv.Financial_Record__r.account__r.name);
}

// Map each File (ContentDocument) to the records/users/groups it's already shared to
Map<String, List<String>> linkMap = new Map<String, List<String>>();
for (ContentDocumentLink cdl : [SELECT Id, ContentDocumentId, LinkedEntityId FROM ContentDocumentLink WHERE ContentDocumentId IN :financialDocumentMap.keySet()]) {
	if (!linkMap.containsKey(cdl.ContentDocumentId)) {
		linkMap.put(cdl.ContentDocumentId, new List<String>{cdl.LinkedEntityId});
	} else {
		linkMap.get(cdl.ContentDocumentId).add(cdl.LinkedEntityId);
	}
}

Integer noLinkCount = 0;
Integer hasLinkCount = 0;
List<ContentDocumentLink> linksToInsert = new List<ContentDocumentLink>();

for (String contentId : linkMap.keySet()) {
	List<String> linkedIds = linkMap.get(contentId);
	String financeRecId = financialDocumentMap.get(contentId);
	//System.debug('Doc: ' + contentId + ' FinanceRec: ' + financeRecId + ' - has ' + linkedIds.size() + ' links --> ' + linkedIds);

	Boolean hasFinanceLink = false;
	for (String link : linkedIds) {
		if (link == financeRecId) {
			hasFinanceLink = true;
			break;
		}
	}
	if (hasFinanceLink) {
		hasLinkCount += 1;
		//System.debug('File already shared with Financial Record. Do nothing.');
	} else {
		noLinkCount += 1;
		System.debug(contentId + ' File is NOT shared to the Financial Record ' + financeRecId + ' --> Create link.');
		
		ContentDocumentLink cdl = new ContentDocumentLink(
			ContentDocumentId = contentId, 
			linkedentityid = financeRecId, 
			Visibility = 'InternalUsers',
			ShareType = 'V'
		);
		linksToInsert.add(cdl);
	}
	
}
System.debug('Files already shared: ' + hasLinkCount);
System.debug('Files not shared to their Financial Record: ' + noLinkCount);


System.debug('CDLs to insert: ' + linksToInsert.size());

// Break up into smaller lists due to CPU limits
List<ContentDocumentLink> batch1 = new List<ContentDocumentLink>();
List<ContentDocumentLink> batch2 = new List<ContentDocumentLink>();
List<ContentDocumentLink> batch3 = new List<ContentDocumentLink>();


if(linksToInsert.size() < 3000) {
	insert linksToInsert;
} else {
	// High volume; break up into chunks
    Integer counter = 0;
    for (Integer i = 0; i< linksToInsert.size(); i++) {
		//Switch on Math.mod(counter, 3){
        Switch on Math.mod(counter, 2){
            when 0{
                batch1.add(linksToInsert[i]);
            }
            when 1{
                batch2.add(linksToInsert[i]);
            }
            when 2{
            //    batch3.add(linksToInsert[i]);
            }
        }
		counter += 1;
    }
	System.debug('Batch 1 size: ' + batch1.size());
	System.debug('Batch 2 size: ' + batch2.size());
	System.debug('Batch 3 size: ' + batch3.size());
	//insert batch1;
}
