# ABOUTME: Verify fail-closed backup behavior against the real claudio-box service.
# ABOUTME: Inject a mount-namespace access failure without changing any source dataset.
import json
import subprocess
import uuid

BASE = '/var/lib/claudio-borg'


def ssh(command):
    return subprocess.run(['ssh', '-o', 'BatchMode=yes', 'claudio-box', command],
                          capture_output=True, text=True, timeout=60)


def read(name):
    result = ssh(f'sudo -n cat {BASE}/{name}')
    assert result.returncode == 0, result.stderr
    return result.stdout


def test_unreadable_sqlite_fails_without_replacing_success():
    success = read('last-success.json')
    unit = 'claudio-borg-access-test-' + uuid.uuid4().hex
    result = ssh('sudo -n systemd-run --quiet --wait --pipe --collect '
                 f'--unit={unit} --uid=root '
                 '--property=InaccessiblePaths=/home/esttorhe/.blogwatcher '
                 '--setenv=HOME=/home/esttorhe '
                 '--setenv=PATH=/home/esttorhe/.local/bin:/usr/bin:/bin '
                 '/usr/bin/python3 /usr/local/lib/claudio-borg/backup.py')
    assert result.returncode == 1, (result.returncode, result.stdout, result.stderr)
    record = json.loads(read('last-run.json'))
    assert record['status'] == 'failed'
    assert record['exit_code'] == 1
    assert record['finished_at'] is not None
    assert read('last-success.json') == success
    assert ssh('test ! -e /run/user/1000/claudio-borg-snapshot').returncode == 0
    log = read('backup.log')
    attempt = log[log.rindex('starting ' + record['archive']):]
    assert '.blogwatcher/blogwatcher.db' in attempt
    assert 'SQLite snapshot PRAGMA' not in attempt
    assert 'Archive name:' not in attempt


def test_missing_systemd_credentials_fails_without_replacing_success():
    success = read('last-success.json')
    unit = 'claudio-borg-credential-test-' + uuid.uuid4().hex
    result = ssh('sudo -n systemd-run --quiet --wait --pipe --collect '
                 f'--unit={unit} --uid=root '
                 '--setenv=HOME=/home/esttorhe '
                 '--setenv=PATH=/home/esttorhe/.local/bin:/usr/bin:/bin '
                 '/usr/bin/python3 /usr/local/lib/claudio-borg/backup.py')
    assert result.returncode == 1, (result.returncode, result.stdout, result.stderr)
    record = json.loads(read('last-run.json'))
    assert record['status'] == 'failed'
    assert read('last-success.json') == success
    attempt = read('backup.log').split('starting ' + record['archive'], 1)[1]
    assert 'Missing systemd credential directory' in attempt
    assert 'Archive name:' not in attempt
