@isTest
private class UtilTest {

	@testSetup
	public static void setup(){
		//Account acc = TestDataFactory.createAccount();
	}

	@isTest
	static void testUtilMethods() {
		System.assertEquals(true, fieldSetList.size() > 0);

		// Returns the name of the current sandbox; If production, returns null
		Boolean currentlyInSandbox = (System.DomainParser.parse(URL.getOrgDomainUrl()).getSandboxName() == null) ? false : true;
		System.assert(currentlyInSandbox == Util.isSandbox());

		Boolean hasDeliverability = Util.checkEmailDeliverability();
	}

	@isTest
	static void testCreateDebugLog() {
		Exception_Logs__c debugLogInsert = Util.createDebugLog('UtilTest', 'Test create log with insert', true);
		Exception_Logs__c debugLogNoInsert = Util.createDebugLog('UtilTest', 'Test create log without insert', false);
		System.assertEquals(1, [SELECT COUNT(Id) logCount FROM Exception_Logs__c][0].get('logCount'), 'Only 1 Exception Log should be inserted');
	}

	@isTest
	static void testGetStandardPricebookId() {
		Id stdPb = Util.getStdPriceBookId();
		System.assert(stdPb != null);
	}

	@isTest
	static void testGetFieldSet() {
		Set<String> fieldSetList = Util.getFieldSetList('User', 'PersonalInfo_EPIM');
		Assert.areEqual(true, fieldSetList.size() > 0);
	}

	@isTest
	static void testIsChanged() {
		// Basic tests to confirm that methods can detect differences between same field on two different records (in practice used to see if Trigger.new is different than Trigger.old SObject)
		List<Account> testAccts = TestDataFactory.createAccounts(2, 'SAP', 'SCU', null);
		Assert.areEqual(true, Util.isChanged(testAccts[0], testAccts[1], 'Name'), 'Should have returned true since Account Name did change');
		Assert.areEqual(false, Util.isChanged(testAccts[0], testAccts[1], 'FAM_Code__c'), 'Should have returned false since FAM_Code__c did NOT change (same value on both records)');
		Assert.areEqual(true, Util.isChanged(testAccts[0], testAccts[1], new Set<String>{'Name', 'FAM_Code__c'}), 'Should return true since one field did change (Name)');
		Assert.areEqual(false, Util.isChanged(testAccts[0], testAccts[1], new Set<String>{'FAM_Code__c', 'Country__c'}), 'Should return false since neither field changed');

		Assert.areEqual(true, Util.isChangedNotNull(testAccts[0], testAccts[1], new Set<String>{'Name', 'FAM_Code__c'}), 'Should have returned true since Name did change and neither are null');
		testAccts[1].Name = null;
		Assert.areEqual(false, Util.isChangedNotNull(testAccts[0], testAccts[1], new Set<String>{'Name', 'FAM_Code__c'}), 'Should have returned false since Name is null on 2nd record');
	}

	public class TestException extends Exception {}
}