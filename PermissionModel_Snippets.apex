System.debug('***************************** Object CRUD Permissions by Permission Set *****************************');
List<String> permSetList = new List<String>{''};
List<String> profileList = new List<String>{'Media Sales Planner','AdWorks'};
// For each Permission Set, store a map of SObjects and CRUD access (Map<PermissionSet, Map<SObjectType, ObjectPermissions>>)
Map<String, Map<String, String>> crudMap = new Map<String, Map<String, String>>();
for (PermissionSet ps : [SELECT Id, Name, IsOwnedByProfile, Profile.Name,
		(SELECT ParentId, Parent.Name, SObjectType, PermissionsRead, PermissionsCreate, PermissionsEdit, PermissionsDelete, PermissionsViewAllRecords, PermissionsModifyAllRecords FROM ObjectPerms)
		FROM PermissionSet WHERE Name IN :permSetList OR (IsOwnedByProfile = true AND Profile.Name IN :profileList)]) {

	String parentName = (ps.IsOwnedByProfile) ? ps.Profile.Name : ps.Name;
	//System.debug(parentName + ' Object Permissions');
	Map<String, String> innerMap = new Map<String, String>();
	for (ObjectPermissions op : ps.ObjectPerms) {
		String crudAccess = (op.PermissionsRead) ? 'Read' : '';
		crudAccess += (op.PermissionsCreate) ? ', Create' : '';
		crudAccess += (op.PermissionsEdit) ? ', Edit' : '';
		crudAccess += (op.PermissionsDelete) ? ', Delete' : '';
		crudAccess += (op.PermissionsViewAllRecords) ? ', View All' : '';
		crudAccess += (op.PermissionsModifyAllRecords) ? ', Modify All' : '';
		innerMap.put(op.SObjectType, crudAccess);
		//System.debug(op.SObjectType + ' has CRUD Access: ' + crudAccess);
	}
	crudMap.put(parentName, innerMap);
}

Map<String, String> permMap1 = crudMap.get(profileList[0]);
Map<String, String> permMap2 = crudMap.get(profileList[1]);
Set<String> processedObjects = new Set<String>();
for (String obj : permMap1.keySet()) {
	String crudAccess1 = permMap1.get(obj);
	if (permMap2.containsKey(obj)) {
		String crudAccess2 = permMap2.get(obj);
		if (crudAccess2 != null && crudAccess1 != crudAccess2) {
			System.debug('Different access for ' + obj + '. ' + profileList[0] + ' = ' + crudAccess1 + ' ; ' + profileList[1] + ' = ' + crudAccess2);
		}
	} else {
		System.debug('Different access for ' + obj + '. ' + profileList[0] + ' = ' + crudAccess1 + ' ; ' + profileList[1] + ' = No Access');
	}
	processedObjects.add(obj);
}
for (String obj : permMap2.keySet()) {
	if (!processedObjects.contains(obj)) {
		String crudAccess2 = permMap2.get(obj);
		if (permMap1.containsKey(obj)) {
			String crudAccess1 = permMap1.get(obj);
			if (crudAccess1 != null && crudAccess2 != crudAccess1) {
				System.debug('Different access for ' + obj + '. ' + profileList[1] + ' = ' + crudAccess2 + ' ; ' + profileList[0] + ' = ' + crudAccess1);
			}
		} else {
			System.debug('Different access for ' + obj + '. ' + profileList[1] + ' = ' + crudAccess2 + ' ; ' + profileList[0] + ' = No Access');
		}
		processedObjects.add(obj);
	}
}


/*******  Analyze Permission Set Assignments --> Find out which Permission Sets aren't being used **********/

// Create Map to keep track of how many assignments each permission set has
// NOTE: This is configured for Permission Sets ONLY - remove the 'IsOwnedByProfile' filter to apply logic to Profiles
Map<String, Integer> assignmentMap = new Map<String, Integer>();
for (AggregateResult ar : [SELECT PermissionSet.Name, COUNT(Id) FROM PermissionSetAssignment WHERE PermissionSet.IsOwnedByProfile = false GROUP BY PermissionSet.Name ORDER BY Count(Id) DESC]) {
	String psName = String.valueOf(ar.get('Name'));
	Integer userCount = Integer.valueOf(ar.get('expr0'));
	assignmentMap.put(psName, userCount);
	// Query is sorted by # assignments high --> low for reference
	System.debug(psName + ' has ' + userCount + ' assignments');
}

// Lastly, query for ALL Permission Sets to identify which ones do not have any assignments (which would not be included in the PermissionSetAssignment query)
List<String> unusedPermSets = new List<String>();
for (PermissionSet ps : [SELECT Name FROM PermissionSet WHERE IsOwnedByProfile = false ORDER BY Name ASC]) {
	if (!assignmentMap.containsKey(ps.Name)) {
		unusedPermSets.add(ps.Name);
		System.debug(ps.Name + ' does NOT have any assigned users');
	}
}




/***************************************************** More Permission Model snippets and notes *****************************************/





// sObject types to describe
String[] types = new String[]{'Profile', 'PermissionSet', 'PermissionSetGroup','FieldPermissions',
							'ObjectPermissions','UserPermissionAccess'};
Schema.DescribeSobjectResult[] results = Schema.describeSObjects(types);

// For each returned result, get some info
for(Schema.DescribeSobjectResult res : results) {
	System.debug(res.getLabel() + ' = Num of fields: ' + res.fields.getMap().size());
	for (String fName : res.fields.getMap().keySet()) {
		System.debug(fName);
	}

	// Get child relationships
	Schema.ChildRelationship[] rels = res.getChildRelationships();
	if (rels.size() > 0) {
		System.debug(res.getName() + ' has ' + rels.size() + ' child relationships.');
		for (Schema.ChildRelationship cRel : rels) {
	   		System.debug('Child Object: ' + cRel.getChildSObject().getDescribe().getName());
   		}
	}
}


/*
	// Get all Permission Sets, including those owned by Profiles
	SELECT Id, Name, Profile.Name, Type, IsOwnedByProfile FROM PermissionSet ORDER BY IsOwnedByProfile ASC

	// Get User assignments (includes Perm Sets + Profiles)
	SELECT Id, Assignee.Name, PermissionSet.Name, PermissionSet.Profile.Name, PermissionSet.Type FROM PermissionSetAssignment

	// Get FLS for a Permission Set by Object
	SELECT ParentId, SObjectType, Field, PermissionsRead, PermissionsEdit
			FROM FieldPermissions WHERE SObjectType = 'Order' AND ParentId IN (SELECT Id FROM PermissionSet WHERE Name = 'Manage_Order_Data')

	// Object CRUD Access by PermissionSet
	SELECT ParentId, Parent.Name, SObjectType, PermissionsRead, PermissionsCreate, PermissionsEdit, PermissionsDelete, PermissionsViewAllRecords, PermissionsModifyAllRecords
			FROM ObjectPermissions WHERE SObjectType IN ('Order','Opportunity') AND ParentId IN (SELECT Id FROM PermissionSet)

	// Get PermissionSets with Object Permissions nested
	SELECT Id, Name , (SELECT ParentId, Parent.Name, SObjectType, PermissionsRead, PermissionsCreate, PermissionsEdit, PermissionsDelete, PermissionsViewAllRecords, PermissionsModifyAllRecords from ObjectPerms)
			FROM PermissionSet

	// Get PermissionSets with FieldPermissions (must iterate through query results due to size)
	for (PermissionSet ps : [SELECT Id,Name, (SELECT ParentId, SObjectType, Field, PermissionsRead, PermissionsEdit FROM FieldPerms) FROM PermissionSet]) {
		System.debug(ps);
		System.debug(ps.FieldPerms);
	}

	// Tooling API

	SELECT id, DeveloperName, sharingmodel from customobject

	SELECT Layout.Name, Layout.TableEnumOrId, RecordType.Name, Profile.Name FROM ProfileLayout WHERE Profile.Name IN ('Adworks', 'Campaign Manager', 'Media Sales Planner') AND Layout.TableEnumOrId IN ('01I2S0000006N90')
*/

/* SKH: Next Steps

	1) Create matrix that compares all permission sets and what they each have in common. Start with Object Permissions, then Field Permissions, then User Permissions.
	   Attempt to display how closely they related to each other, areas of overlap
	2) Based on those results, see the feasbility of combining them and/or using Permission Set Groups
	3) Create another matrix that shows user assignments. Bucket users into groups of who shares the same permission set assignments (which also includes profile assignment)

*/

// Map each Username to the set of Permission Sets that user has assigned (including their Profile)
List<User> activeUsers = [SELECT Id, Username, Name, ProfileId FROM User WHERE isActive = true AND UserType  = 'Standard'];
System.debug('# Active Users: ' + activeUsers.size());

/*
	Remove beginning of Debug statements in logs
	[0-9]{2}:[0-9]{2}:[0-9]{2}.[0-9]{1,4} \([0-9]{6,12}\)\|USER_DEBUG\|\[[0-9]{1,4}\]\|DEBUG\|
*/

Map<String, List<String>> assignmentMap = new Map<String, List<String>>();
for (PermissionSet ps : [SELECT Id, Name, ProfileId, Profile.Name, Type, IsOwnedByProfile,
						(SELECT Id, AssigneeId, Assignee.UserName, Assignee.Name, PermissionSetId FROM Assignments WHERE Assignee.isActive = true AND Assignee.UserType  = 'Standard')
				FROM PermissionSet ORDER BY IsOwnedByProfile DESC]) {
	String parentName = '';
	if (ps.IsOwnedByProfile) {
		parentName = ps.Profile.Name;
	} else {
		parentName = ps.Name;
	}
	for (PermissionSetAssignment psa : ps.Assignments) {
		if (!assignmentMap.containsKey(psa.Assignee.Name)) {
			// switch back to username when enforcing uniqueness
			assignmentMap.put(psa.Assignee.Name, new List<String>{parentName});
		} else {
			// switch back to username when enforcing uniqueness
			assignmentMap.get(psa.Assignee.Name).add(parentName);
		}
	}
}

// Unique groups of users based on their total permissions (profile + permission sets)
Map<String, List<String>> permGroupMap = new Map<String, List<String>>();
System.debug('******************************** Active Users with their Assigned Permissions ********************************');
System.debug('new line');
for (String userName : assignmentMap.keySet()) {
	String userAssignments = '';
	List<String> userList = new List<String>();
	String logText = userName + ': ';
	Integer psCounter = 0;

	for (String ps : assignmentMap.get(userName)) {
		userAssignments += ps + ';';
		logText += ps;
		if (psCounter < (assignmentMap.get(userName).size() - 1)) {
			logText += ', ';
		}
		psCounter += 1;
	}
	if (!permGroupMap.containsKey(userAssignments)) {
		permGroupMap.put(userAssignments, new List<String>{userName});
	} else {
		permGroupMap.get(userAssignments).add(userName);
	}
	System.debug(logText);
}

System.debug('******************* Total # of unique user groups based on permissions = ' + permGroupMap.size() + ' *******************');
System.debug('new line');

List<String> orderedList = new List<String>();
orderedList.addAll(permGroupMap.KeySet());
orderedList.sort();
for (String pGroup : orderedList) {
	System.debug(permGroupMap.get(pGroup).size() + ' users have the following assignments: ' + pGroup);
	for (String u : permGroupMap.get(pGroup)) {
		System.debug(u);
	}
	System.debug('new line');
}

// Number of assignment by Profile / Permission Set (including placeholder to sort)
for (PermissionSet ps : [SELECT Id, Name, ProfileId, Profile.Name, Type, IsOwnedByProfile,
						(SELECT Id, AssigneeId, Assignee.UserName, Assignee.Name, PermissionSetId FROM Assignments WHERE Assignee.isActive = true AND Assignee.UserType  = 'Standard')
				FROM PermissionSet ORDER BY IsOwnedByProfile DESC]) {
	String parentName = '';
	if (ps.IsOwnedByProfile) {
		parentName = ps.Profile.Name;
	} else {
		parentName = ps.Name;
	}
	if (ps.IsOwnedByProfile) {
		System.debug('Sort Order: ' + ps.Assignments.size() + '********* Profile: ' + parentName + ' is assigned to ' + ps.Assignments.size() + ' active users *********');
	} else {
		System.debug('Sort Order: ' + ps.Assignments.size() + '********* Permission Set: ' + parentName + ' is assigned to ' + ps.Assignments.size() + ' active users *********');
	}
}

System.debug('***************************** Object CRUD Permissions by Permission Set *****************************');
System.debug('new line');
// For each Permission Set, store a map of SObjects and CRUD access (Map<PermissionSet, Map<SObjectType, ObjectPermissions>>)
Map<String, Map<String, ObjectPermissions>> crudMap = new Map<String, Map<String, ObjectPermissions>>();
for (PermissionSet ps : [SELECT Id, Name, IsOwnedByProfile, Profile.Name,
		(SELECT ParentId, Parent.Name, SObjectType, PermissionsRead, PermissionsCreate, PermissionsEdit, PermissionsDelete, PermissionsViewAllRecords, PermissionsModifyAllRecords FROM ObjectPerms) FROM PermissionSet]) {

	String parentName = (ps.IsOwnedByProfile) ? ps.Profile.Name : ps.Name;
	Map<String, ObjectPermissions> innerMap = new Map<String, ObjectPermissions>();
	for (ObjectPermissions op : ps.ObjectPerms) {
		innerMap.put(op.SObjectType, op);
	}
	crudMap.put(parentName, innerMap);

	if (ps.IsOwnedByProfile) {
		System.debug('********* Profile Name: ' + parentName + ' grants Object CRUD access to ' + crudMap.get(parentName).size() + ' object(s) *********');
	} else {
		System.debug('********* Permission Set: ' + parentName + ' grants Object CRUD access to ' + crudMap.get(parentName).size() + ' object(s) *********');
	}

	for (String obj : crudMap.get(parentName).keySet()) {
		ObjectPermissions op = crudMap.get(parentName).get(obj);
		String crudAccess = (op.PermissionsRead) ? 'Read' : '';
		crudAccess += (op.PermissionsCreate) ? ', Create' : '';
		crudAccess += (op.PermissionsEdit) ? ', Edit' : '';
		crudAccess += (op.PermissionsDelete) ? ', Delete' : '';
		crudAccess += (op.PermissionsViewAllRecords) ? ', View All' : '';
		crudAccess += (op.PermissionsModifyAllRecords) ? ', Modify All' : '';
		System.debug(obj + ' has CRUD Access: ' + crudAccess);
	}
	System.debug('new line');
}

System.debug('***************************** Field Level Permissions by Permission Set, by Object *****************************');
System.debug('new line');
// For each Permission Set, and each Object, map out field level settings ((Map<PermissionSet, Map<SObjectType, Map<FieldName, FieldPermissions>>>))
Map<String, Map<String, Map<String, FieldPermissions>>> flsMap = new Map<String, Map<String, Map<String, FieldPermissions>>>();
for (PermissionSet ps : [SELECT Id, Name, IsOwnedByProfile, Profile.Name,
						(SELECT ParentId, SObjectType, Field, PermissionsRead, PermissionsEdit FROM FieldPerms) FROM PermissionSet]) {

	String parentName = (ps.IsOwnedByProfile) ? ps.Profile.Name : ps.Name;
	Map<String, Map<String, FieldPermissions>> middleMap = new Map<String, Map<String, FieldPermissions>>();
	for (FieldPermissions fp : ps.FieldPerms) {
		Map<String, FieldPermissions> insideMap = middleMap.containsKey(fp.SObjectType) ? middleMap.get(fp.SObjectType) : new Map<String, FieldPermissions>();
		insideMap.put(fp.Field, fp);
		middleMap.put(fp.SObjectType, insideMap);
	}
	flsMap.put(parentName, middleMap);

	if (ps.IsOwnedByProfile) {
		System.debug('********* Profile Name: ' + parentName + ' grants FLS access to ' + flsMap.get(parentName).size() + ' object(s) *********');
	} else {
		System.debug('********* Permission Set: ' + parentName + ' grants FLS access to ' + flsMap.get(parentName).size() + ' object(s) *********');
	}

	for (String obj : middleMap.keySet()) {
		System.debug('******************************  FLS for Object: ' + obj + ' (' + parentName + ') ******************************');
		for (String f : middleMap.get(obj).keySet()) {
			FieldPermissions fp = middleMap.get(obj).get(f);
			String fls = (fp.PermissionsRead && fp.PermissionsEdit) ? 'Editable' : (fp.PermissionsRead && !fp.PermissionsEdit) ? 'Read Only' : 'No Access';
			String fieldNameOnly = (fp.Field.split('\\.').size() > 1) ? fp.Field.split('\\.')[1] : fp.Field;
			System.debug(fieldNameOnly + ' --> ' + fls);
		}
		System.debug('new line');
	}
}

/*
List<String> allObjects = new List<String>();
for (Schema.SObjectType objTyp : Schema.getGlobalDescribe().values()) {
	String objName = objTyp.getDescribe().getName();
	if ((!objName.containsignorecase('history') && !objName.containsignorecase('share') && !objName.containsignorecase('feed')) || objName.toLowerCase().right(3) ==  '__c') {
		allObjects.add(objName);
	}
}
Schema.DescribeSobjectResult[] results = Schema.describeSObjects(allObjects);
*/
Set<String> fieldList = new Set<String>();
Map<String, Set<String>> fieldMap = new Map<String, Set<String>>();

String query = 'SELECT ';
String[] types = new String[]{'PermissionSet'};

Schema.DescribeSobjectResult[] results = Schema.describeSObjects(types);
for (Schema.DescribeSobjectResult res : results) {
	Integer numFields = res.fields.getMap().size();
	//Integer counter = 0;
	for (String fName : res.fields.getMap().keySet()) {
		fieldList.add(fName);
		query = query + fName;
		query = query + ', ';
	}
	fieldMap.put(res.getName(), fieldList);
}
query = query + ' Profile.Name FROM PermissionSet';

System.debug('***************************** Application Permissions granted by Permission Set *****************************');
System.debug('new line');
Map<String, List<String>> userPermMap = new Map<String, List<String>>();
for (PermissionSet ps : (List<PermissionSet>)Database.query(query)) {
	String parentName = (ps.IsOwnedByProfile) ? ps.Profile.Name : ps.Name;
	for (Schema.SObjectField soField : Schema.describeSObjects(new List<String>{'PermissionSet'})[0].fields.getMap().values()) {
		Schema.DescribeFieldResult fResult = soField.getDescribe();
		String fType = String.valueOf(fResult.getType());
		String fName = fResult.getName();
		// Only add to map if field name starts with Permission (checkbox fields), and the value for that field on the PermSet is true
		if (fName.startsWithIgnoreCase('permission') && ps.get(fName) != null) {
			if (String.valueOf(ps.get(fName)).equalsIgnoreCase('true')) {
				if (!userPermMap.containsKey(parentName)) {
					userPermMap.put(parentName, new List<String>{fName});
				} else {
					userPermMap.get(parentName).add(fName);
				}
			}
		}
	}

	if (userPermMap.containsKey(parentName)) {
		if (ps.IsOwnedByProfile) {
			System.debug('********* Profile Name: ' + parentName + ' grants ' + userPermMap.get(parentName).size() + ' User Permissions *********');
		} else {
			System.debug('********* Permission Set: ' + parentName + ' grants ' + userPermMap.get(parentName).size() + ' User Permissions *********');
		}

		for (String userPerm : userPermMap.get(parentName)) {
			System.debug(userPerm.split('Permissions')[1]);
		}
		System.debug('new line');
	}
}
System.debug('********************************** Summary: ' + userPermMap.size() + ' Permission Sets grant User Permissions **********************************');


System.debug('***************************** Object CRUD Permissions by Permission Set *****************************');
List<String> permSetList = new List<String>{''};
List<String> profileList = new List<String>{'Media Sales Planner','AdWorks'};

//List<String> objList = new List<String>{'add objects here to filter to only key objects'};

// For each Permission Set, store a map of SObjects and CRUD access (Map<PermissionSet, Map<SObjectType, ObjectPermissions>>)
Map<String, Map<String, String>> crudMap = new Map<String, Map<String, String>>();
for (PermissionSet ps : [SELECT Id, Name, IsOwnedByProfile, Profile.Name,
		(SELECT ParentId, Parent.Name, SObjectType, PermissionsRead, PermissionsCreate, PermissionsEdit, PermissionsDelete, PermissionsViewAllRecords, PermissionsModifyAllRecords FROM ObjectPerms)
		FROM PermissionSet WHERE Name IN :permSetList OR (IsOwnedByProfile = true AND Profile.Name IN :profileList)]) {

	String parentName = (ps.IsOwnedByProfile) ? ps.Profile.Name : ps.Name;
	//System.debug(parentName + ' Object Permissions');
	Map<String, String> innerMap = new Map<String, String>();
	for (ObjectPermissions op : ps.ObjectPerms) {
		String crudAccess = (op.PermissionsRead) ? 'Read' : '';
		crudAccess += (op.PermissionsCreate) ? ', Create' : '';
		crudAccess += (op.PermissionsEdit) ? ', Edit' : '';
		crudAccess += (op.PermissionsDelete) ? ', Delete' : '';
		crudAccess += (op.PermissionsViewAllRecords) ? ', View All' : '';
		crudAccess += (op.PermissionsModifyAllRecords) ? ', Modify All' : '';
		innerMap.put(op.SObjectType, crudAccess);
		//System.debug(op.SObjectType + ' has CRUD Access: ' + crudAccess);
	}
	crudMap.put(parentName, innerMap);
}

Map<String, String> permMap1 = crudMap.get(profileList[0]);
Map<String, String> permMap2 = crudMap.get(profileList[1]);
Set<String> processedObjects = new Set<String>();
for (String obj : permMap1.keySet()) {
	String crudAccess1 = permMap1.get(obj);
	if (permMap2.containsKey(obj)) {
		String crudAccess2 = permMap2.get(obj);
		if (crudAccess2 != null && crudAccess1 != crudAccess2) {
			System.debug('Different access for ' + obj + '. ' + profileList[0] + ' = ' + crudAccess1 + ' ; ' + profileList[1] + ' = ' + crudAccess2);
		}
	} else {
		System.debug('Different access for ' + obj + '. ' + profileList[0] + ' = ' + crudAccess1 + ' ; ' + profileList[1] + ' = No Access');
	}
	processedObjects.add(obj);
}
for (String obj : permMap2.keySet()) {
	if (!processedObjects.contains(obj)) {
		String crudAccess2 = permMap2.get(obj);
		if (permMap1.containsKey(obj)) {
			String crudAccess1 = permMap1.get(obj);
			if (crudAccess1 != null && crudAccess2 != crudAccess1) {
				System.debug('Different access for ' + obj + '. ' + profileList[1] + ' = ' + crudAccess2 + ' ; ' + profileList[0] + ' = ' + crudAccess1);
			}
		} else {
			System.debug('Different access for ' + obj + '. ' + profileList[1] + ' = ' + crudAccess2 + ' ; ' + profileList[0] + ' = No Access');
		}
		processedObjects.add(obj);
	}
}