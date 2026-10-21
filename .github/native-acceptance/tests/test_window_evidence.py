"""Replay actual ANR evidence so successful Compose tests cannot mask a dialog."""
import importlib.util,pathlib,unittest
p=pathlib.Path(__file__).resolve().parents[1]/'verify-native-results.py';s=importlib.util.spec_from_file_location('native',p);m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
class WindowTests(unittest.TestCase):
 def test_launcher_anr_rejected(self):
  with self.assertRaises(ValueError):m.verify_window('Window #6 Window{4e411f5 u0 Application Not Responding: com.google.android.apps.nexuslauncher}:')
 def test_empty_evidence_rejected(self):
  with self.assertRaises(ValueError):m.verify_window('')
 def test_actual_window_dump_required(self):
  with self.assertRaises(ValueError):m.verify_window('Unable to inspect windows')
 def test_valid_app_window(self):m.verify_window('Window{abc u0 de.kamilunavo.arbeitsklar/de.kamilunavo.arbeitsklar.MainActivity}')
