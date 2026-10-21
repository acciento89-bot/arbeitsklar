"""Reproduce the actual cloud failure: emulator exists in SDK, not in PATH."""
import json, os, pathlib, shutil, subprocess, sys, tempfile, unittest
ROOT=pathlib.Path(__file__).resolve().parents[1]
class CleanupShellTests(unittest.TestCase):
 def test_sdk_emulator_inventory_works_when_emulator_is_not_on_path(self):
  with tempfile.TemporaryDirectory() as d:
   p=pathlib.Path(d);sdk=p/'sdk';bin=p/'bin';bin.mkdir();proof=p/'.github/native-acceptance/proof';proof.mkdir(parents=True)
   shutil.copyfile(ROOT/'verify_cleanup.py',proof.parent/'verify_cleanup.py')
   def executable(path,source):
    path.parent.mkdir(parents=True,exist_ok=True);path.write_text('#!/bin/sh\n'+source+'\n');path.chmod(0o700)
   executable(bin/'timeout','shift; exec "$@"')
   executable(bin/'adb','if [ "$1" = devices ]; then printf "List of devices attached\\n\\n"; fi; exit 0')
   executable(sdk/'emulator/emulator','test "$1" = -list-avds || exit 9; exit 0')
   executable(sdk/'cmdline-tools/latest/bin/avdmanager','exit 0')
   (bin/'python3').symlink_to(sys.executable)
   source=(ROOT/'run-cloud.sh').read_text().split('trap cleanup EXIT\n',1)[0]+'cleanup\n'
   env={**os.environ,'GITHUB_ACTIONS':'true','GITHUB_WORKSPACE':str(p),'ANDROID_HOME':str(sdk),'PATH':str(bin)+':/usr/bin:/bin'}
   result=subprocess.run(['/bin/bash','-c',source],env=env,text=True,capture_output=True,timeout=20)
   self.assertEqual(result.returncode,0,result.stdout+result.stderr)
   self.assertTrue(json.loads((proof/'cleanup.json').read_text())['deviceDeletedVerified'])
if __name__=='__main__':unittest.main()
