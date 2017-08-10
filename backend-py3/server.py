"""
WebSocket backend using aiohttp.

Route `/websocket` handles communication with the frontend. Only
accepted message from the frontend is for now `dashboard`, for which the
backend returns the current list of dashboards.

The backend also sends the current list of dashboards in case any change
is made on the filesystem.
"""

import argparse
from functools import partial
import json
import logging

from aiohttp import web, WSMsgType, WSCloseCode

from dashboards_watcher import DashboardsWatcher


def setup_logging():
    logger = logging.getLogger()
    logger.setLevel(logging.DEBUG)

    ch = logging.StreamHandler()
    ch.setLevel(logging.DEBUG)

    formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
    ch.setFormatter(formatter)

    logger.addHandler(ch)
    return logger


async def root_handler(_request):
    with open('frontend/index.html') as f:
        return web.Response(text=f.read(), content_type='text/html')


async def websocket_handler(request):
    logger = request.app['logger']
    ws = web.WebSocketResponse()
    await ws.prepare(request)
    logger.debug('New websocket connection %s', id(ws))

    async for msg in ws:
        if msg.type == WSMsgType.TEXT:
            data = json.loads(msg.data)
            if data['type'] == 'close':
                await ws.close()
            elif data['type'] == 'dashboards':
                await ws.send_json({'message': 'dashboards', 'dashboards': request.app['dashboards_watcher'].get_dashboard_names()})
            elif data['type'] == 'select_dashboard':
                request.app['dashboards'].register_websocket(data['dashboard'], ws)
                logger.debug('%s: select dashboard "%s"', id(ws), data['dashboard'])
            elif data['type'] == 'unselect_dashboard':
                request.app['dashboards'].unregister_websocket(ws)
                logger.debug('%s: unselect dashboard', id(ws))
        elif msg.type == WSMsgType.ERROR:
            logger.error('ws connection closed with exception %s', exc_info=ws.exception())

    logger.info('websocket connection closed')

    return ws


def coroutine(func):
    def start(*args, **kwargs):
        cr = func(*args, **kwargs)
        next(cr)
        return cr
    return start


class Dashboards:
    def __init__(self, loop):
        self.loop = loop
        self.dashboards = {}
        self.active_dashboards = {}
        self.websockets = {}
        self.logger = logging.getLogger('dashboards')

    def update(self, dashboards):
        self.logger.debug('Updating list of dashboards to %s', dashboards)
        self.dashboards = dashboards

    def register_websocket(self, dashboard, ws):
        if dashboard not in self.dashboards:
            raise KeyError('Dashboard %s not found' % dashboard)

        self.unregister_websocket(ws)

        if dashboard not in self.active_dashboards:
            self.logger.info('Calling setup for dashboard %s', dashboard)
            target = partial(self.broadcast, dashboard=dashboard)
            self.active_dashboards[dashboard] = self.dashboards[dashboard]['setup'](self.loop, target)

        message = {'message': 'dashboard'}
        message.update(**self.active_dashboards[dashboard])
        for graph in message['graphs']:
            del graph['task']
        ws.send_json(message)

        self.logger.info('Registering websocket %s on dashboard %s', id(ws), dashboard)
        self.websockets[ws] = dashboard

    def unregister_websocket(self, ws):
        if ws not in self.websockets:
            self.logger.warning('Trying to unregister websocket %s', id(ws))
            return

        dashboard = self.websockets[ws]
        self.logger.info('Removing websocket %s from dashboard %s', id(ws), dashboard)
        del self.websockets[ws]

        if not any(d == dashboard for d in self.websockets.values()):
            self.logger.info('Cancelling all graph tasks from dashboard %s', dashboard)
            for graph in self.active_dashboards[dashboard]['graphs']:
                graph['task'].cancel()
            del self.active_dashboards[dashboard]

    @coroutine
    def broadcast(self, dashboard, graph):
        while True:
            message = yield
            message.update(message='build', dashboard=dashboard, graph=graph)
            for ws in self.websockets:
                ws.send_json(message)
            self.logger.debug('broadcast message for dashboard %s from graph %s: %s', dashboard, graph, message)


async def stop_websockets(app):
    if 'websockets' not in app:
        return
    for ws in app['websockets']:
        await ws.close(code=WSCloseCode.GOING_AWAY, message='server shutdown')


async def start_background_tasks(app, args):
    async def notify_websockets_dashboards(dashboards):
        app['dashboards'].update(dashboards)
        for ws in app.get('websockets', []):
            await ws.send_json({'message': 'dashboards', 'dashboards': sorted(list(dashboards.keys()))})
    app['dashboards_watcher'] = DashboardsWatcher(app.loop, args.dashboard_dir, notify_websockets_dashboards)


async def stop_background_tasks(_app):
    pass


def run(args):
    app = web.Application()
    app['logger'] = setup_logging()
    app['websockets'] = {}
    app['dashboards'] = Dashboards(app.loop)

    app.router.add_get('/', root_handler)
    app.router.add_static('/static', 'frontend/static')
    app.router.add_get('/socket', websocket_handler)

    app.on_startup.append(partial(start_background_tasks, args=args))
    app.on_cleanup.append(stop_background_tasks)
    app.on_shutdown.append(stop_websockets)

    web.run_app(app)


def main(user_args=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('dashboard_dir', nargs='+', default=[], metavar='dashboard-dir',
                        help='All directories this program should watch for dashboards.')

    args = parser.parse_args(user_args)

    run(args)


if __name__ == '__main__':
    main()
