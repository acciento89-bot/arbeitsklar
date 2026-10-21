"""Require the two existing native tests and preserve their actual synthetic evidence."""
from pathlib import Path, PurePosixPath
import datetime, hashlib, io, json, re, shutil, subprocess, tarfile
import xml.etree.ElementTree as ET
EXPECTED={('de.kamilunavo.arbeitsklar.RosterNativeTest',n) for n in ['legacyStorageApplyReopenAndEndPreserveIndividualShifts','nativeCycleEditorPreviewApplyAndReopen']}
def verify_reports(folder):
 reports=list(Path(folder).rglob('TEST-*.xml'));cases=[]
 if not reports:raise ValueError('No actual connected Android test reports')
 for file in reports:
  root=ET.parse(file).getroot()
  for suite in root.iter('testsuite'):
   if any(int(suite.get(k,'0')) for k in ['failures','errors','skipped']):raise ValueError('Native report contains failures/errors/skips')
  for case in root.iter('testcase'):
   if any(case.find(k) is not None for k in ['failure','error','skipped']):raise ValueError('Native test did not pass')
   cases.append((case.get('classname'),case.get('name')))
 if len(cases)!=2 or set(cases)!=EXPECTED:raise ValueError('Expected exactly the two original roster native tests')
 return len(cases)
def verify_window(text):
 # ActivityScenario.close() intentionally ends the app; a clean launcher is valid.
 if not re.search(r'Window\{[^}]+\}',text): raise ValueError('Actual window dump missing')
 if re.search(r'Application Not Responding|isn.t responding|keeps stopping',text,re.I):
  raise ValueError('System dialog obscures actual native evidence')
def main():
 root=Path.cwd();proof=root/'.github/native-acceptance/proof';proof.mkdir(parents=True,exist_ok=True)
 state={'status':'FAILED','transactions':False,'version':'1.1.0 (8)'}
 def adb(args,timeout=15):
  result=subprocess.run(['adb','-s','emulator-5554',*args],capture_output=True,timeout=timeout)
  if result.returncode:raise RuntimeError('Owned emulator evidence command failed')
  return result.stdout
 try:
  reports=root/'android/app/build/outputs/androidTest-results/connected';state['nativeTestsPassed']=verify_reports(reports)
  windows=adb(['shell','dumpsys','window','windows']).decode(errors='replace');(proof/'native-evidence-window.txt').write_text(windows);verify_window(windows)
  for file in reports.rglob('TEST-*.xml'):shutil.copyfile(file,proof/file.name)
  identity=adb(['shell','dumpsys','package','de.kamilunavo.arbeitsklar']).decode(errors='replace');(proof/'installed-identity.txt').write_text(identity)
  if not re.search(r'\bversionCode=8\b',identity) or not re.search(r'\bversionName=1\.1\.0\b',identity):raise ValueError('Installed roster candidate mismatch')
  raw=adb(['exec-out','run-as','de.kamilunavo.arbeitsklar','cat','shared_prefs/arbeitsklar_v1.xml']);ET.fromstring(raw);(proof/'synthetic-roster.xml').write_bytes(raw)
  strings='\n'.join(node.text or '' for node in ET.fromstring(raw).iter('string'))
  if not all(name in strings for name in ['Native Folge','Native Einzeländerung']):raise ValueError('Actual synthetic cycle/editor snapshot missing')
  packed=adb(['exec-out','run-as','de.kamilunavo.arbeitsklar','tar','-cf','-','-C','files','roster-native-qa']);pictures=[]
  with tarfile.open(fileobj=io.BytesIO(packed)) as archive:
   members=archive.getmembers()
   if len(members)>32:raise ValueError('Unexpected native evidence count')
   for member in members:
    path=PurePosixPath(member.name)
    if member.isfile() and path.parent==PurePosixPath('roster-native-qa') and path.suffix=='.png':
     if member.size>10*1024*1024:raise ValueError('Oversized native screenshot')
     data=archive.extractfile(member).read()
     if not data.startswith(b'\x89PNG\r\n\x1a\n'):raise ValueError('Invalid actual screenshot')
     (proof/path.name).write_bytes(data);pictures.append(path.name)
  if set(pictures)!={'01-editor.png','02-preview.png','03-saved.png','04-individual-editor.png','05-individual-edit-persisted.png'}:raise ValueError('Native screenshot evidence incomplete')
  state['apkSHA256']={role:hashlib.sha256(file.read_bytes()).hexdigest() for role,file in [('product',root/'android/app/build/outputs/apk/debug/app-debug.apk'),('test',root/'android/app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk')]}
  state['actualStorageSHA256']=hashlib.sha256(raw).hexdigest();state['actualScreenshots']=pictures;state['status']='PASSED'
 except Exception as error:state['error']=str(error)
 state['utc']=datetime.datetime.now(datetime.timezone.utc).isoformat();(proof/'result.json').write_text(json.dumps(state,indent=2));print(json.dumps(state));return 0 if state['status']=='PASSED' else 1
if __name__=='__main__':raise SystemExit(main())
