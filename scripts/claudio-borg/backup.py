#!/usr/bin/env python3
# ABOUTME: Capture claudio-box databases consistently and stream datasets to encrypted Borg.
# ABOUTME: Fail closed, retain nightly archives, and publish durable run and success records.
import argparse
import datetime as dt
import fcntl
import json
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import threading

HOME = Path('/home/esttorhe')
STATE = Path('/var/lib/claudio-borg')
SNAPSHOT = Path('/run/user/1000/claudio-borg-snapshot')
REPO = 'ssh://u672829-sub1@u672829.your-storagebox.de:23/./backup'
SECRET = 'op://wodzrmmziuws4zipwerklmkm5q/t55kltqlep7kx4c7cm2zduczyq/password'
DOLT = str(HOME / '.local/bin/dolt')
FLOOR = 2 * 1024**3


def timestamp():
    return dt.datetime.now(dt.timezone.utc).isoformat(timespec='seconds')


def write_json(path, value):
    temporary = path.with_suffix('.tmp')
    with temporary.open('w') as stream:
        json.dump(value, stream, sort_keys=True)
        stream.write('\n')
        stream.flush()
        os.fsync(stream.fileno())
    temporary.replace(path)


def run(command, *, env=None, capture=False):
    result = subprocess.run(command, env=env, text=True, stdin=subprocess.DEVNULL,
                            stdout=subprocess.PIPE if capture else None, check=True)
    return result.stdout if capture else None


def sql(database, query, env):
    return json.loads(run([DOLT, '--host', '100.75.168.99', '--port', '3306',
                           '--no-tls', '--user', 'beads', '--use-db', database,
                           'sql', '-r', 'json', '-q', query], env=env, capture=True))['rows']


def require(path, directory=False):
    if not (path.is_dir() if directory else path.is_file()):
        raise RuntimeError(f'Required dataset unavailable: {path}')
    # Opening the directory also detects access failures before Borg creates anything.
    if directory:
        list(path.iterdir())
    else:
        with path.open('rb') as stream:
            stream.read(1)


def backup(passphrase_stdin):
    started = timestamp()
    archive = 'claudio-box-' + dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    record = dict(schema_version=1, started_at=started, status='running',
                  archive=archive, finished_at=None, exit_code=None)
    write_json(STATE / 'last-run.json', record)
    print(f'{started} starting {archive}', flush=True)
    stop = threading.Event()
    minimum = [shutil.disk_usage('/').free]

    def sample():
        while not stop.is_set():
            minimum[0] = min(minimum[0], shutil.disk_usage('/').free)
            stop.wait(0.25)

    def space():
        minimum[0] = min(minimum[0], shutil.disk_usage('/').free)
        if minimum[0] < FLOOR:
            raise RuntimeError('Root filesystem fell below the 2 GiB free-space floor')

    monitor = threading.Thread(target=sample, daemon=True)
    monitor.start()
    owned_snapshot = False
    code = 1
    try:
        space()
        run(['df', '-h', '/'])
        for name in ('.openclaw', '.openviking'):
            require(HOME / name, directory=True)
        for name in ('.blogwatcher/blogwatcher.db', 'dolt-remote/config.yaml',
                     'dolt-remote/.beads-password'):
            require(HOME / name)
        if passphrase_stdin:
            secret = sys.stdin.readline().rstrip('\r\n')
        else:
            secret = run(['op', 'read', SECRET], capture=True).rstrip('\r\n')
        if not secret:
            raise RuntimeError('Borg passphrase is empty')
        borg_env = dict(os.environ, BORG_PASSPHRASE=secret, BORG_REPO=REPO,
                        BORG_RSH='ssh -o BatchMode=yes -o IdentitiesOnly=yes '
                        '-i /home/esttorhe/.ssh/id_membrain_backup '
                        '-o UserKnownHostsFile=/home/esttorhe/.ssh/known_hosts_membrain '
                        '-o StrictHostKeyChecking=yes')
        secret = None
        dolt_secret = (HOME / 'dolt-remote/.beads-password').read_text().strip()
        if not dolt_secret:
            raise RuntimeError('Dolt credential is empty')
        dolt_env = dict(os.environ, DOLT_CLI_PASSWORD=dolt_secret)
        dolt_secret = None
        # Never overwrite a snapshot left by an interrupted run; it needs inspection.
        SNAPSHOT.mkdir(mode=0o700)
        owned_snapshot = True
        os.chown(SNAPSHOT, 1000, 1000)
        sqlite = SNAPSHOT / 'blogwatcher.db'
        run(['sqlite3', '-readonly', str(HOME / '.blogwatcher/blogwatcher.db'),
             '.timeout 30000', f".backup '{sqlite}'"])
        integrity = run(['sqlite3', '-readonly', str(sqlite), 'PRAGMA integrity_check;'], capture=True).strip()
        if integrity != 'ok':
            raise RuntimeError('SQLite snapshot integrity check failed')
        print('SQLite snapshot PRAGMA integrity_check: ok', flush=True)
        datasets = []
        for database in ('fitforge', 'second_brain'):
            target = SNAPSHOT / database
            target.mkdir(mode=0o700)
            os.chown(target, 1000, 1000)
            result = sql(database, f"CALL DOLT_BACKUP('sync-url', 'file://{target}');", dolt_env)
            if len(result) != 1 or str(result[0].get('status')) != '0':
                raise RuntimeError(f'Dolt backup did not report success: {database}: {result}')
            if not any(target.iterdir()):
                raise RuntimeError(f'Dolt backup is empty: {database}')
            datasets.append(dict(database=database, status=0, captured_at=timestamp()))
            print(f'Dolt {database} DOLT_BACKUP sync-url: {json.dumps(result)}', flush=True)
        write_json(SNAPSHOT / 'capture.json', dict(sqlite_integrity=integrity, dolt=datasets))
        space()
        # Ancillary configuration is read directly; no second plaintext credential copy.
        paths = [HOME / '.openclaw', HOME / '.openviking', SNAPSHOT,
                 HOME / 'dolt-remote/config.yaml', HOME / 'dolt-remote/.beads-password',
                 HOME / 'dolt-remote/.doltcfg', HOME / '.dolt/config_global.json']
        for database in ('fitforge', 'second_brain'):
            for name in ('config.json', 'repo_state.json'):
                path = HOME / 'dolt-remote/databases' / database / '.dolt' / name
                if path.exists():
                    paths.append(path)
        pending = 'pending-' + archive
        run(['borg', 'create', '--stats', '--compression', 'lz4', '::' + pending,
             *map(str, paths)], env=borg_env)
        space()
        shutil.rmtree(SNAPSHOT)
        owned_snapshot = False
        run(['borg', 'rename', '::' + pending, archive], env=borg_env)
        run(['borg', 'prune', '--list', '--glob-archives', 'claudio-box-*',
             '--keep-daily', '7', '--keep-weekly', '4', '--keep-monthly', '6'], env=borg_env)
        run(['borg', 'compact'], env=borg_env)
        run(['borg', 'list'], env=borg_env)
        run(['borg', 'info', '::' + archive], env=borg_env)
        space()
        code = 0
    except (Exception, KeyboardInterrupt) as error:
        # Commands never carry secrets in argv. Avoid dumping environment or SQL rows.
        print(f'{timestamp()} FAILED: {type(error).__name__}: {error}', file=sys.stderr, flush=True)
    finally:
        if owned_snapshot:
            try:
                shutil.rmtree(SNAPSHOT)
            except OSError as error:
                print(f'Snapshot cleanup failed: {error}', file=sys.stderr, flush=True)
                code = 1
        stop.set()
        monitor.join()
        record.update(status='success' if code == 0 else 'failed', exit_code=code,
                      finished_at=timestamp(), min_root_free_bytes=minimum[0],
                      free_space_sample_interval_seconds=0.25)
        write_json(STATE / 'last-run.json', record)
        if code == 0:
            write_json(STATE / 'last-success.json', record)
        run(['df', '-h', '/'])
        print(json.dumps(record), flush=True)
    return code


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--passphrase-stdin', action='store_true',
                        help='Read the passphrase once from stdin for supervised runs')
    args = parser.parse_args()
    if os.geteuid() != 0:
        parser.error('Run as root to include root-owned OpenViking configuration')
    os.umask(0o077)
    STATE.mkdir(parents=True, exist_ok=True, mode=0o700)
    with (STATE / 'lock').open('a') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            print('Another backup holds the lock', file=sys.stderr)
            return 1
        with (STATE / 'backup.log').open('a', buffering=1) as log:
            os.dup2(log.fileno(), 1)
            os.dup2(log.fileno(), 2)
            def interrupted(signum, frame):
                raise KeyboardInterrupt(f'Signal {signum}')
            signal.signal(signal.SIGTERM, interrupted)
            return backup(args.passphrase_stdin)


if __name__ == '__main__':
    sys.exit(main())
