import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch


spec = importlib.util.spec_from_file_location(
    'work_mode', Path(__file__).resolve().parents[1] / 'session/work/work_mode.py')
work_mode = importlib.util.module_from_spec(spec)
spec.loader.exec_module(work_mode)


class WorkModeTests(unittest.TestCase):
    def test_focuses_workspace_before_launching_and_routes_lan_mouse(self):
        events = []
        with patch.object(work_mode, 'running_executable_names', return_value=set()), \
                patch.object(work_mode.shutil, 'which', side_effect=lambda name: '/usr/bin/' + name), \
                patch.object(work_mode.subprocess, 'run', side_effect=lambda args, **kw: events.append(args)), \
                patch.object(work_mode.subprocess, 'Popen', side_effect=lambda args, **kw: events.append(args)):
            work_mode.apply(True)
        self.assertEqual(events[:2], [
            ['hyprctl', 'eval', work_mode.DISABLE],
            ['hyprctl', 'eval', work_mode.FOCUS_WORKSPACE],
        ])
        self.assertEqual(events[2], ['/usr/bin/brave'])
        self.assertEqual(events[3], ['/usr/bin/spotify'])
        self.assertIn('hl.dsp.exec_cmd', events[4][2])
        self.assertIn('special:magic silent', events[4][2])
        self.assertEqual(len(events), 5)

    def test_running_apps_are_not_relaunched(self):
        with patch.object(work_mode, 'running_executable_names',
                          return_value={'brave', 'spotify', 'lan-mouse'}), \
                patch.object(work_mode.subprocess, 'run') as run, \
                patch.object(work_mode.subprocess, 'Popen') as launch:
            work_mode.apply(True)
        self.assertEqual(run.call_count, 2)
        launch.assert_not_called()

    def test_restore_only_restores_monitors(self):
        with patch.object(work_mode.subprocess, 'run') as run:
            work_mode.apply(False)
        self.assertEqual([call.args[0] for call in run.call_args_list], [
            ['hyprctl', 'eval', work_mode.RESTORE],
            ['hyprctl', 'eval', work_mode.MOVE],
        ])
