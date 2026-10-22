import importlib.util, pathlib, tempfile, unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
NAMES=['legacyStorageApplyReopenAndEndPreserveIndividualShifts','nativeCycleEditorPreviewApplyAndReopen']
class NativeResultsTests(unittest.TestCase):
 def setUp(self):
  p=ROOT/'verify-native-results.py';self.assertTrue(p.is_file(),'Native result verifier is missing')
  spec=importlib.util.spec_from_file_location('native_results',p);self.module=importlib.util.module_from_spec(spec);spec.loader.exec_module(self.module)
 def check(self,text):
  with tempfile.TemporaryDirectory() as d:
   p=pathlib.Path(d);(p/'TEST-roster.xml').write_text(text);return self.module.verify_reports(p)
 def xml(self,names=NAMES,extra='',attrs=''):
  return '<testsuite tests="2" failures="0" errors="0" '+attrs+'>'+''.join('<testcase classname="de.kamilunavo.arbeitsklar.RosterNativeTest" name="'+n+'">'+extra+'</testcase>' for n in names)+'</testsuite>'
 def full_xml(self):
  onboarding=''.join('<testcase classname="de.kamilunavo.arbeitsklar.OnboardingNativeTest" name="'+n+'"/>' for n in ['startIntroductionEntersMainImmediatelyAndPersists','skipIntroductionEntersMainImmediatelyAndPersists'])
  return self.xml().replace('tests="2"', 'tests="4"').replace('</testsuite>',onboarding+'</testsuite>')
 def test_onboarding_and_roster_tests_pass(self):self.assertEqual(self.check(self.full_xml()),4)
 def test_roster_only_report_cannot_hide_missing_first_run_coverage(self):
  with self.assertRaises(ValueError):self.check(self.xml())
 def test_failure_or_skipped_is_never_green(self):
  for extra in ['<failure message="actual failure"/>','<error/>','<skipped/>']:
   with self.assertRaises(ValueError):self.check(self.full_xml().replace('</testcase>',extra+'</testcase>',1))
 def test_missing_or_wrong_test_is_never_green(self):
  for names in [NAMES[:1],['unrelated',NAMES[1]],[NAMES[0],NAMES[0]]]:
   with self.assertRaises(ValueError):self.check(self.xml(names=names))
 def test_report_failure_counter_is_honored(self):
  with self.assertRaises(ValueError):self.check(self.full_xml().replace('failures="0"','failures="1"'))
 def test_empty_reports_rejected(self):
  with tempfile.TemporaryDirectory() as d:
   with self.assertRaises(ValueError):self.module.verify_reports(pathlib.Path(d))
if __name__=='__main__':unittest.main()
