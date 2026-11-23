import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent.parent

class MakeGateTests(unittest.TestCase):
    def run_make(self, target, failure='', shell_flags='-eo pipefail -c', overrides=None):
        (ROOT / '.tmp').mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=ROOT / '.tmp') as directory:
            root = Path(directory)
            log = root / 'commands.log'
            (root / 'project.yml').write_bytes((ROOT / 'project.yml').read_bytes())
            tools = {
                'swiftformat': 'printf "swiftformat %s\\n" "$*" >> "$COMMAND_LOG"',
                'swiftlint': 'exit 0',
                'xcodegen': 'printf "xcodegen\\n" >> "$COMMAND_LOG"',
                'xcodebuild': 'printf "xcodebuild %s\\n" "$1" >> "$COMMAND_LOG"\necho "TEST SUCCEEDED"\nif [ "$FAIL_VERB" = "$1" ]; then exit 7; fi',
            }
            tools.update(overrides or {})
            for name, body in tools.items():
                path = root / name
                path.write_text('#!/bin/sh\n' + body + '\n')
                path.chmod(0o755)
            result = subprocess.run(['make', '-f', str(ROOT / 'Makefile'), target,
                                     '.SHELLFLAGS=' + shell_flags,
                                     'RESOLVE_SIM_ID=printf simulator', 'SIM_ID_GUARD=true'],
                                    cwd=root, env=dict(os.environ, PATH=str(root)+os.pathsep+os.environ['PATH'],
                                                      BASH_ENV=os.devnull,
                                                      COMMAND_LOG=str(log), FAIL_VERB=failure),
                                    text=True, capture_output=True)
            return result, log.read_text() if log.exists() else ''

    def test_check_is_read_only(self):
        result, log = self.run_make('check')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('swiftformat --lint', log)
        self.assertNotIn('xcodegen', log)
        self.assertIn('xcodebuild build', log)
        self.assertIn('xcodebuild test', log)

    def test_check_preserves_build_failure(self):
        result, _ = self.run_make('check', 'build')
        self.assertNotEqual(result.returncode, 0)

    def test_test_pipelines_preserve_failure(self):
        for shell_flags in ['-eo pipefail -c', '-c']:
            for target in ['test', 'ui-test', 'coverage', 'check']:
                with self.subTest(target=target, shell_flags=shell_flags):
                    result, _ = self.run_make(target, 'test', shell_flags)
                    self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_build_still_formats(self):
        result, log = self.run_make('build')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('swiftformat . --quiet', log)
        self.assertIn('xcodegen', log)

    def test_clean_checkout(self):
        (ROOT / '.tmp').mkdir(exist_ok=True)
        with tempfile.TemporaryDirectory(dir=ROOT / '.tmp') as directory:
            checkout = Path(directory)
            for name in ['Makefile', 'project.yml']:
                (checkout / name).write_bytes((ROOT / name).read_bytes())
            with patch.dict(self.run_make.__globals__, ROOT=checkout):
                result, _ = self.run_make('check')
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_release_rejects_existing_tag_with_large_tag_list(self):
        git = '''case "$1" in
status) exit 0 ;;
rev-parse) echo main ;;
tag)
    awk -F'"' '/MARKETING_VERSION:/ {print "v"$2; exit}' project.yml
    python3 -c 'import os; os.write(1, b"v0.0.0\\n" * 100000)'
    ;;
esac'''
        result, _ = self.run_make('release', overrides={'git': git})
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('already exists. Bump version first.', result.stdout)

if __name__ == '__main__':
    unittest.main(verbosity=2)
