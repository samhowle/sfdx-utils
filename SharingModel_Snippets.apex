/******************************** Apex Snippets for User Role Analysis ******************************************************************/

// Build maps of Active and Inactive users (Role Name to Count of Users for each map)
Map<String, Integer> activeRoleMap = new Map<String, Integer>();
for (AggregateResult ar : [SELECT UserRole.Name, COUNT(Id) FROM User WHERE IsActive = true AND UserRole.PortalType = 'None' GROUP BY UserRole.Name ORDER BY COUNT(Id) DESC]) {
	activeRoleMap.put(String.valueOf(ar.get('Name')), Integer.valueOf(ar.get('expr0')));
}
Map<String, Integer> inactiveRoleMap = new Map<String, Integer>();
for (AggregateResult ar : [SELECT UserRole.Name, COUNT(Id) FROM User WHERE IsActive = false AND UserRole.PortalType = 'None' GROUP BY UserRole.Name ORDER BY COUNT(Id) DESC]) {
	inactiveRoleMap.put(String.valueOf(ar.get('Name')), Integer.valueOf(ar.get('expr0')));
}

// List out how many active users each role currently has; Semi-colon delimited to easily transfer into Excel columns
Map<Id, UserRole> parentMap = new Map<Id, UserRole>([SELECT Id, Name FROM UserRole WHERE PortalType = 'None']);
for (UserRole ur : [SELECT id, Name, ParentRoleId FROM UserRole WHERE PortalType = 'None']) {
	Integer numActive = (activeRoleMap.containsKey(ur.Name)) ? activeRoleMap.get(ur.Name) : 0;
	Integer numInactive = (inactiveRoleMap.containsKey(ur.Name)) ? inactiveRoleMap.get(ur.Name) : 0;
	String parentRole = (ur.ParentRoleId != null) ? parentMap.get(ur.ParentRoleId).Name : 'No Parent Role';
	Integer numActiveParent = (activeRoleMap.containsKey(parentRole)) ? activeRoleMap.get(parentRole) : 0;
	Integer numInactiveParent = (inactiveRoleMap.containsKey(parentRole)) ? inactiveRoleMap.get(parentRole) : 0;
	System.debug(ur.Name + ';active=;' + numActive + ';inactive=;' + numInactive + ';Parent Role=;' + parentRole + ';num active parent=;' + numActiveParent + ';num inactive parent=;' + numInactiveParent);
}

// List out Users with their Role assignment
for (User u : [SELECT id, Name, UserName, Profile.Name, UserRole.Name FROM User WHERE IsActive = true AND UserType = 'Standard']) {
	String roleName = (u.UserRole.Name != null) ? u.UserRole.Name : 'None';
	System.debug(u.Name + ';' + u.UserName + ';' + roleName + ';' + u.Profile.Name);
}

// User info to map Department to Role
for (User u : [SELECT Id, Name, Username, Department, isActive, UserRoleId, UserRole.Name, UserRole.ParentRoleId FROM User WHERE UserRole.PortalType = 'None']) {
	System.debug(u.Id + ';' + u.Name + ';' + u.Username + ';' + u.isActive + ';' + u.Department + ';' + u.UserRoleId + ';' + u.UserRole.Name + ';' + u.UserRole.ParentRoleId);
}

/******************************** Useful SOQL Queries for Role Analysis ******************************************************************/
// Role Assignments by User
SELECT id, name, profile.name, userrole.name FROM User WHERE isactive = true AND userrole.portaltype = 'None'

//# of Assignments by Role
SELECT UserRole.name, COUNT(Id) FROM user WHERE isactive = true AND UserRole.PortalType = 'None' GROUP BY userrole.name ORDER BY COUNT(Id) DESC

//List of Roles (Internal)
SELECT Id, name, DeveloperName FROM UserRole WHERE PortalType = 'None'

// Account Owners by Role (break out Active vs Inactive users)
SELECT Owner.UserRole.Name, Owner.IsActive, Count(id) FROM Account GROUP BY Owner.UserRole.Name, Owner.IsActive ORDER BY Owner.UserRole.Name ASC


/******************************** Metadata references to Roles (reports) ******************************************************************/
/*
<roleHierarchyFilter>Role Name</roleHierarchyFilter>

<filter>
	<criteriaItems>
		<column>ROLLUP_DESCRIPTION</column>
		<columnToColumn>false</columnToColumn>
		<isUnlocked>true</isUnlocked>
		<operator>equals</operator>
		<value>Role Name</value>
	</criteriaItems>
</filter>

<scope>salesteamteam</scope>
<scope>salesteam</scope>
<scope>team</scope>
*/
