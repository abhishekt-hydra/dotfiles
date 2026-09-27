import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'script/seed-dotfiles.py'


class MigrationTest(unittest.TestCase):
    def test_migration_preserves_live_files_and_directory_neighbors(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            repo, home = root / 'repo', root / 'home'
            (repo / 'script').mkdir(parents=True)
            home.mkdir()
            shutil.copy2(SCRIPT, repo / 'script/seed-dotfiles.py')
            source = repo / 'dotfiles/common'
            (source / '.config/app').mkdir(parents=True)
            (source / '.zshrc').write_text('source rc')
            (source / '.aliases').write_text('source aliases')
            (source / '.config/app/config').write_text('app config')
            (source / '.new').write_text('new file')
            (home / '.zshrc').symlink_to(source / '.zshrc')
            (home / '.aliases').write_text('local edits win')
            (home / '.config').mkdir()
            external = root / 'external'
            external.mkdir()
            (external / 'config').symlink_to(source / '.config/app/config')
            (external / 'session').write_text('unmanaged neighbor')
            (home / '.config/app').symlink_to(external)
            env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(home / '.config'))
            cmd = ['python3', str(repo / 'script/seed-dotfiles.py'), 'common']
            subprocess.run(cmd, env=env, check=True, capture_output=True)
            self.assertFalse((home / '.zshrc').is_symlink())
            self.assertEqual((home / '.zshrc').read_text(), 'source rc')
            self.assertEqual((home / '.aliases').read_text(), 'local edits win')
            self.assertFalse((home / '.config/app').is_symlink())
            self.assertFalse((home / '.config/app/config').is_symlink())
            self.assertEqual((home / '.config/app/session').read_text(), 'unmanaged neighbor')
            self.assertEqual((home / '.new').read_text(), 'new file')
            backups = list((home / '.local/state/dotfiles/backups').iterdir())
            self.assertEqual(len(backups), 1)
            self.assertEqual((backups[0] / '.zshrc').read_text(), 'source rc')
            self.assertFalse((backups[0] / '.zshrc').is_symlink())
            before = {str(p): p.read_bytes() for p in (home / '.config/mise').rglob('*.toml')}
            (home / '.zshrc').write_text('new live edit')
            subprocess.run(cmd, env=env, check=True, capture_output=True)
            self.assertEqual((home / '.zshrc').read_text(), 'new live edit')
            self.assertEqual(before, {str(p): p.read_bytes() for p in (home / '.config/mise').rglob('*.toml')})
            self.assertEqual(len(list((home / '.local/state/dotfiles/backups').iterdir())), 1)
            (home / '.zshrc').unlink()
            (home / '.zshrc').symlink_to(home / 'missing')
            self.assertNotEqual(subprocess.run(cmd, env=env, capture_output=True).returncode, 0)
            self.assertTrue((home / '.zshrc').is_symlink())


if __name__ == '__main__':
    unittest.main()
