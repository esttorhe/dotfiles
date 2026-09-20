# ABOUTME: Exercise backup warnings and rollback with real Borg repositories on claudio-box.
# ABOUTME: Keep test markers and tiny datasets isolated while using real SQLite and Dolt captures.
import importlib.util
import json
import os
from pathlib import Path
import shutil
import sqlite3
import subprocess
import tempfile
import uuid

import pytest


@pytest.fixture
def job(monkeypatch):
    spec = importlib.util.spec_from_file_location('backup', Path(__file__).with_name('backup.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    # The live Dolt server must reach this private snapshot as its owning uid.
    snapshot = Path('/run/user/1000') / ('claudio-borg-test-' + uuid.uuid4().hex)
    with tempfile.TemporaryDirectory(prefix='claudio-borg-test-', dir='/var/tmp') as temporary:
        root = Path(temporary)
        home = root / 'home'
        for name in ('.openclaw', '.openviking', '.blogwatcher', 'dolt-remote/.doltcfg', '.dolt'):
            (home / name).mkdir(parents=True)
        (home / '.openclaw/state').write_text('tiny Borg integration dataset\n')
        (home / '.dolt/config_global.json').write_text('{}')
        (home / 'dolt-remote/config.yaml').write_text('test dataset\n')
        (home / 'dolt-remote/.beads-password').symlink_to(module.HOME / 'dolt-remote/.beads-password')
        with sqlite3.connect(home / '.blogwatcher/blogwatcher.db') as connection:
            connection.execute('CREATE TABLE entries (value TEXT)')
            connection.execute("INSERT INTO entries VALUES ('integration')")
        state = root / 'state'
        state.mkdir()
        env = dict(os.environ, BORG_REPO=str(root / 'repo'),
                   BORG_CACHE_DIR=str(root / 'cache'), BORG_SECURITY_DIR=str(root / 'security'))
        for key in ('BORG_CACHE_DIR', 'BORG_SECURITY_DIR'):
            monkeypatch.setenv(key, env[key])
        subprocess.run(['borg', 'init', '--encryption=none'], env=env, check=True,
                       capture_output=True, text=True)
        monkeypatch.setattr(module, 'HOME', home)
        monkeypatch.setattr(module, 'STATE', state)
        monkeypatch.setattr(module, 'SNAPSHOT', snapshot)
        monkeypatch.setattr(module, 'REPO', env['BORG_REPO'])
        try:
            yield module, env
        finally:
            if snapshot.exists():
                shutil.rmtree(snapshot)


def archives(env):
    result = subprocess.run(['borg', 'list', '--json'], env=env, check=True,
                            capture_output=True, text=True)
    return [item['name'] for item in json.loads(result.stdout)['archives']]


def marker(module):
    return json.loads((module.STATE / 'last-run.json').read_text())


def test_create_warning_completes_and_records_text(job, capfd):
    module, env = job
    missing = module.HOME / '.dolt/config_global.json'
    missing.unlink()
    assert module.backup(False) == 0
    record = marker(module)
    assert record['status'] == 'success' and record['exit_code'] == 0
    assert record['schema_version'] == 1
    assert archives(env) == [record['archive']]
    assert any(w['command'] == 'create' and str(missing) in w['message']
               for w in record['warnings'])
    assert str(missing) in capfd.readouterr().err
    assert json.loads((module.STATE / 'last-success.json').read_text()) == record
    print('exit 1: renamed archive; status=success exit_code=0; warning in marker and log')


def test_borg_error_is_fatal(job, monkeypatch, capfd):
    module, env = job
    monkeypatch.setattr(module, 'REPO', env['BORG_REPO'] + '-absent')
    assert module.backup(False) != 0
    record = marker(module)
    assert record['status'] == 'failed' and record['exit_code'] != 0
    assert 'exit status 2' in record['error']
    assert not (module.STATE / 'last-success.json').exists()
    assert archives(env) == []
    capfd.readouterr()
    print('exit 2: status=failed exit_code=1; original Borg error preserved')


@pytest.mark.parametrize('cleanup_fails', [False, True])
def test_failure_after_create_preserves_original(job, monkeypatch, capfd, cleanup_fails):
    module, env = job
    real_borg = module.borg

    def interrupted(command, **kwargs):
        if cleanup_fails and command[0] == 'delete':
            # Real Borg error: malformed CLI option, before any repository mutation.
            return real_borg(['delete', '--invalid-cleanup-test-option'], **kwargs)
        result = real_borg(command, **kwargs)
        if command[0] == 'create':
            raise RuntimeError('forced failure after real create')
        return result

    monkeypatch.setattr(module, 'borg', interrupted)
    assert module.backup(False) == 1
    record = marker(module)
    assert record['error'] == 'RuntimeError: forced failure after real create'
    assert record['status'] == 'failed' and record['exit_code'] == 1
    assert not (module.STATE / 'last-success.json').exists()
    assert archives(env) == (['pending-' + record['archive']] if cleanup_fails else [])
    output = capfd.readouterr()
    assert ('Pending archive cleanup failed:' in output.err) == cleanup_fails
    print(f'failure after create: original error retained; cleanup_fails={cleanup_fails}; '
          f'archives={archives(env)}')


def test_failure_after_rename_keeps_archive(job, monkeypatch, capfd):
    module, env = job
    real_borg = module.borg

    def interrupted(command, **kwargs):
        if command[0] == 'prune':
            return real_borg(['prune', '--invalid-prune-test-option'], **kwargs)
        assert command[0] != 'delete'
        return real_borg(command, **kwargs)

    monkeypatch.setattr(module, 'borg', interrupted)
    assert module.backup(False) == 1
    assert archives(env) == [marker(module)['archive']]
    capfd.readouterr()
    print('failure after rename: completed archive retained; no cleanup delete')


def test_failure_before_credentials(job, capfd):
    module, env = job
    shutil.rmtree(module.HOME / '.openclaw')
    assert module.backup(False) == 1
    assert 'Required dataset unavailable' in marker(module)['error']
    assert archives(env) == []
    capfd.readouterr()
    print('failure before borg_env: original dataset error retained')


def test_non_borg_exit_one_is_fatal(job, capfd):
    module, _ = job
    for command in (['sqlite3', ':memory:', 'SELECT * FROM absent_table;'],
                    [module.DOLT, 'sql', '-q', 'SELECT * FROM absent_table;'],
                    ['df', '/nonexistent-claudio-borg-test-path']):
        with pytest.raises(subprocess.CalledProcessError) as error:
            module.run(command)
        assert error.value.returncode == 1
    capfd.readouterr()
    print('sqlite3, dolt, df: real exit 1 raises CalledProcessError')
