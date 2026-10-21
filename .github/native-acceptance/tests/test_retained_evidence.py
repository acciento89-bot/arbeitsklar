"""Exercise the actual Gradle invocation: AGP otherwise deletes proof with the app."""
import os,pathlib,subprocess,tempfile,unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
class RetainedEvidenceTests(unittest.TestCase):
 def test_connected_test_invocation_retains_app_until_evidence_capture(self):
  command=next(l for l in (ROOT/'run-cloud.sh').read_text().splitlines() if l.startswith('gradle ') and 'connectedDebugAndroidTest' in l)
  with tempfile.TemporaryDirectory() as d:
   p=pathlib.Path(d);fake=p/'gradle';fake.write_text('#!/bin/sh\nfor argument; do\n if [ "$argument" = "-Pandroid.injected.androidTest.leaveApksInstalledAfterRun=true" ]; then exit 0; fi\ndone\necho "AGP will uninstall the evidence" >&2\nexit 9\n');fake.chmod(0o700)
   result=subprocess.run(['/bin/bash','-c','set -euo pipefail\nproof="$1"\n'+command,'test',d],env={**os.environ,'PATH':d+':'+os.environ['PATH']},capture_output=True,text=True)
   self.assertEqual(result.returncode,0,result.stdout+result.stderr)
