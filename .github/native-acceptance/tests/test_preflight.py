import pathlib, subprocess, tempfile, unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
class PreflightTests(unittest.TestCase):
 def test_observed_systemui_anr_aborts_before_tests(self):
  source=(ROOT/'run-cloud.sh').read_text().split('timeout 10s adb -s "$serial" shell dumpsys activity lastanr > "$proof/preflight-anr.txt"\n',1)[1].split('sleep 20',1)[0]
  with tempfile.TemporaryDirectory() as d:
   p=pathlib.Path(d);(p/'preflight-anr.txt').write_text('ANR in com.android.systemui\n')
   result=subprocess.run(['/bin/bash','-c','set -euo pipefail\nproof="$1"\n'+source+'\necho TESTS_STARTED', 'test',d],capture_output=True,text=True)
   self.assertNotEqual(result.returncode,0)
   self.assertNotIn('TESTS_STARTED',result.stdout)
