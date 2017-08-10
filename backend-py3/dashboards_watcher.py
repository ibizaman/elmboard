"""
This module exposes the class DashboardsWatcher that watches multiple
paths on the filesystem for changes to dashboard files and calls an
awaitable callback in case something changes.

A dashboard file is a python file ending in `.py` and
"""
import asyncio
import logging
import importlib.util
from pathlib import Path

import pyinotify


class DashboardsWatcher(pyinotify.ProcessEvent):
    """
    Watches multiple paths for new or modified dashboards.
    Calls given callback if the list of dashboards changed.
    """
    logger = logging.getLogger(__name__)

    # pylint: disable=no-member
    mask = pyinotify.IN_DELETE \
        | pyinotify.IN_CREATE \
        | pyinotify.IN_CLOSE_WRITE \
        | pyinotify.IN_MOVED_TO \
        | pyinotify.IN_MOVED_FROM \

    def __init__(self, loop, paths, callback):
        """
        @param loop: asyncio or trollius event loop instance.
        @type loop: asyncio.BaseEventLoop or trollius.BaseEventLoop instance.

        @param callback: Functor called if the list of dashboard changed.
                         Expects to receive the list of dashboards as
                         single parameter.
        @type callback: awaitable functor.
        """
        super().__init__()

        self.paths = [Path(p) for p in paths]
        self.callback = callback

        # We start watching the folders before initializing the
        # dashboards to avoid race conditions.
        wm = pyinotify.WatchManager()
        notifier = pyinotify.AsyncioNotifier(wm, loop, default_proc_fun=self, callback=self.schedule_callback)
        self.logger.info('Watching paths %s', ', '.join('"' + str(d) + '"' for d in self.paths))
        for path in self.paths:
            wm.add_watch(str(path), self.mask, rec=True, auto_add=True)

        self.dashboards = {}
        for path in self.paths:
            for dashboard in path.iterdir():
                self.load_dashboard(dashboard)

        current_dashboards = self.get_dashboard_names()
        if current_dashboards:
            self.logger.info('Initializing with dashboards %s', ', '.join('"' + d + '"' for d in current_dashboards))
        else:
            self.logger.info('Initializing without any dashboard')

        self.schedule_callback(notifier)

    def get_dashboard_names(self):
        return sorted(list(self.dashboards.keys()))

    @staticmethod
    def is_dashboard(path):
        """
        Python files are considered to be dashboards. Python files
        starting by an underscore `_` are excluded to avoid considering
        __init__.py as a dashboard. This also allows the dashboards to
        put code in common in a file beginning by an underscore, named
        `_util.py` for example.
        """
        return path.is_file() and path.suffix == '.py' and not path.stem.startswith('_')

    def load_dashboard(self, path):
        if not self.is_dashboard(path):
            return False

        try:
            module = import_module(path)
        except Exception as e:
            self.logger.error(
                'Tried to import module "%s" under path "%s" but got the following exception:',
                path.stem,
                path,
                exc_info=e)
            return False
        else:
            self.dashboards[path.stem] = {
                'path': path,
                'module': module,
            }

            return path.stem

    def process_IN_CREATE(self, event):
        new_dashboard = self.load_dashboard(Path(event.pathname))
        if new_dashboard:
            self.logger.info('Adding new dashboard "%s"', new_dashboard)
            return new_dashboard
        return None

    def process_IN_DELETE(self, event):
        if event.name in self.dashboards:
            del self.dashboards[event.name]
            self.logger.info('Deleting dashboard "%s"', event.name)
            return event.name
        return None

    def process_IN_CLOSE_WRITE(self, event):
        reloaded_dashboard = self.load_dashboard(Path(event.pathname))
        if reloaded_dashboard:
            self.logger.info('Reloading dashboard "%s"', reloaded_dashboard)
            return reloaded_dashboard
        return None

    def process_IN_MOVED_TO(self, event):
        # We create a sort of Event class with only a name attribute,
        # this allows us to call self.process_IN_DELETE and simplify
        # this method's implementation.
        class OldEvent:
            name = Path(event.src_pathname).stem
        self.process_IN_DELETE(OldEvent)
        self.process_IN_CREATE(event)

    def schedule_callback(self, notifier):
        self.logger.debug('Scheduling a call to the callback')
        # Calling an awaitable function returns a coroutine, which is
        # what asyncio.ensure_future expects:
        #
        #     >>> async def a():
        #     ...     pass
        #     ...
        #     >>> a()
        #     <coroutine object a at 0x7f12144af150>
        asyncio.ensure_future(self.callback(self.dashboards), loop=notifier.loop)


def import_module(path):
    spec = importlib.util.spec_from_file_location('dashboard.' + path.stem, str(path))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module
