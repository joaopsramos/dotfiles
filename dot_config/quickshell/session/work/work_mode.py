"""Apply the work monitor layout and launch missing applications."""
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys

DISABLE = 'hl.monitor({ output = "HDMI-A-1", disabled = true })'
RESTORE = 'hl.monitor({ output = "HDMI-A-1", disabled = false, mode = "2560x1080@60", position = "0x0", scale = 1 })'
MOVE = 'for i = 1, 5 do hl.dispatch(hl.dsp.workspace.move({ workspace = tostring(i), monitor = "HDMI-A-1" })) end'
APPS = (
    (('brave', 'brave-browser', 'brave-bin'), ('brave', 'brave-browser', 'brave-bin')),
    (('spotify',), ('spotify',)),
    (('lan-mouse',), ('lan-mouse',)),
)
FOCUS_WORKSPACE = 'hl.dispatch(hl.dsp.focus({ workspace = "1" }))'


def running_executable_names():
    names = set()
    uid = os.getuid()
    for proc in Path('/proc').iterdir():
        if not proc.name.isdigit():
            continue
        try:
            if proc.stat().st_uid != uid:
                continue
            comm = (proc / 'comm').read_text().strip().lower()
            args = (proc / 'cmdline').read_bytes().split(b'\0')
            executable = Path(os.fsdecode(args[0])).name.lower() if args[0] else ''
            names.update(name for name in (comm, executable) if name)
        except (OSError, IndexError):
            continue
    return names


def apply(activate):
    commands = [DISABLE, FOCUS_WORKSPACE] if activate else [RESTORE, MOVE]
    for command in commands:
        subprocess.run(['hyprctl', 'eval', command], check=True)
    if not activate:
        return
    running_names = running_executable_names()
    errors = []
    for names, candidates in APPS:
        if running_names.intersection(names):
            continue
        executable = next((path for name in candidates if (path := shutil.which(name))), None)
        if not executable:
            errors.append(f'Application not found: {candidates[0]}')
            continue
        try:
            if names == ('lan-mouse',):
                command = (f'hl.dispatch(hl.dsp.exec_cmd({json.dumps(shlex.quote(executable))}, '
                           '{ workspace = "special:magic silent" }))')
                subprocess.run(['hyprctl', 'eval', command], check=True)
            else:
                subprocess.Popen([executable], start_new_session=True, stdin=subprocess.DEVNULL,
                                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except OSError as error:
            errors.append(str(error))
    if errors:
        raise RuntimeError('; '.join(errors))


if __name__ == '__main__':
    try:
        if sys.argv[1:] not in (['activate'], ['restore']):
            raise ValueError('Expected activate or restore')
        apply(sys.argv[1] == 'activate')
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as error:
        print(error, file=sys.stderr)
        sys.exit(1)
