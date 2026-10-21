#import <XCTest/XCTest.h>
@interface ArbeitsKlarUITests : XCTestCase
@end
@implementation ArbeitsKlarUITests
- (void)capture:(NSString *)name {
 XCTAttachment *a=[XCTAttachment attachmentWithScreenshot:XCUIScreen.mainScreen.screenshot];a.name=name;a.lifetime=XCTAttachmentLifetimeKeepAlways;[self addAttachment:a];
}
- (void)testNativeRosterFlow {
 self.continueAfterFailure=NO;
 XCUIApplication *app=[[XCUIApplication alloc]initWithBundleIdentifier:@"de.kamilunavo.arbeitsklar"];
 app.launchArguments=@[@"-has_completed_onboarding_v1",@"YES",@"-AppleLanguages",@"(de)",@"-AppleLocale",@"de_DE"];
 [app launch];
 XCTAssertTrue([app.tabBars.buttons[@"Planer"] waitForExistenceWithTimeout:20]);
 [app.tabBars.buttons[@"Planer"] tap];
 XCUIElement *cycles=app.buttons[@"Schichtfolgen"];
 XCTAssertTrue([cycles waitForExistenceWithTimeout:10]);[cycles tap];
 XCTAssertTrue([app.buttons[@"Schichtfolge anlegen"] waitForExistenceWithTimeout:5]);
 [app.buttons[@"Schichtfolge anlegen"] tap];
 XCTAssertTrue([app.navigationBars[@"Schichtfolge planen"] waitForExistenceWithTimeout:5]);
 XCUIElement *name=app.textFields.firstMatch;XCTAssertTrue(name.exists);[[name coordinateWithNormalizedOffset:CGVectorMake(0.12,0.5)] tap];
 NSString *old=(NSString *)name.value;NSMutableString *replacement=[NSMutableString string];
 for(NSUInteger i=0;i<old.length;i++)[replacement appendString:XCUIKeyboardKeyDelete];
 [replacement appendString:@"Native Folge"];[name typeText:replacement];
 [self capture:@"01-native-cycle-editor"];
 XCUIElement *preview=app.buttons[@"Datierte Vorschau"];
 for(int i=0;i<7&&!preview.hittable;i++)[app swipeUp];
 XCTAssertTrue(preview.hittable);[preview tap];
 XCTAssertTrue([app.staticTexts[@"Geplante Termine"] waitForExistenceWithTimeout:5]);
 [self capture:@"02-native-dated-preview"];
 XCUIElement *apply=app.navigationBars.buttons[@"Anwenden"];
 XCTAssertTrue(apply.hittable);XCTAssertTrue(apply.enabled);[apply tap];
 XCUIElementQuery *savedQuery=[app.buttons matchingPredicate:[NSPredicate predicateWithFormat:@"label CONTAINS %@",@"Native Folge"]];
 XCTAssertTrue([savedQuery.firstMatch waitForExistenceWithTimeout:5]);
 [self capture:@"03-native-saved-cycle"];
 [app terminate];[app launch];
 XCTAssertTrue([app.tabBars.buttons[@"Planer"] waitForExistenceWithTimeout:15]);[app.tabBars.buttons[@"Planer"] tap];
 XCTAssertTrue([app.buttons[@"Schichtfolgen"] waitForExistenceWithTimeout:5]);[app.buttons[@"Schichtfolgen"] tap];
 XCUIElement *saved=[app.buttons matchingPredicate:[NSPredicate predicateWithFormat:@"label CONTAINS %@",@"Native Folge"]].firstMatch;
 XCTAssertTrue([saved waitForExistenceWithTimeout:5]);
 [saved tap];XCTAssertTrue([app.navigationBars[@"Schichtfolge planen"] waitForExistenceWithTimeout:5]);
 XCUIElement *previewAgain=app.buttons[@"Datierte Vorschau"];
 for(int i=0;i<7&&!previewAgain.hittable;i++)[app swipeUp];[previewAgain tap];
 XCTAssertTrue(app.navigationBars.buttons[@"Anwenden"].enabled);[app.navigationBars.buttons[@"Anwenden"] tap];
 XCTAssertEqual(savedQuery.count,1);
 [self capture:@"04-native-reopened-cycle"];
 [savedQuery.firstMatch swipeLeft];
 XCUIElement *end=app.buttons[@"Schichtfolge beenden"];
 XCTAssertTrue([end waitForExistenceWithTimeout:5]);[end tap];
 XCUIElement *confirm=app.sheets.buttons[@"Schichtfolge beenden"];
 if([confirm waitForExistenceWithTimeout:3]) [confirm tap];
 else { XCUIElement *last=[app.buttons matchingIdentifier:@"Schichtfolge beenden"].allElementsBoundByIndex.lastObject;[last tap]; }
 XCTAssertTrue([app.staticTexts[@"Noch keine Schichtfolge angelegt."] waitForExistenceWithTimeout:5]);
 [self capture:@"05-native-ended-cycle"];
}
@end
