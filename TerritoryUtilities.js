// Territory utilities

// Account assignments
SELECT id, Object.name, object.type, ObjectId, territory2.name, Territory2Id FROM ObjectTerritory2Association order by territory2.name desc

// User territory assignments
SELECT id, Territory2Id, Territory2.name, user.name, userid, RoleInTerritory2 FROM UserTerritory2Association