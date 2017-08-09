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

    request.app['websockets'][ws] = {'socket': ws, 'dashboard': None}

    async for msg in ws:
        if msg.type == WSMsgType.TEXT:
            data = json.loads(msg.data)
            if data['type'] == 'close':
                await ws.close()
            elif data['type'] == 'dashboards':
                await ws.send_json({'message': 'dashboards', 'dashboards': request.app['dashboards_watcher'].get_dashboard_names()})
            elif data['type'] == 'select_dashboard':
                request.app['websockets'][ws]['dashboard'] = data['dashboard']
                logger.debug('%s: select dashboard "%s"', id(ws), request.app['websockets'][ws]['dashboard'])
            elif data['type'] == 'unselect_dashboard':
                old_dashboard = request.app['websockets'][ws]['dashboard']
                request.app['websockets'][ws]['dashboard'] = None
                logger.debug('%s: unselect dashboard, was "%s"', id(ws), old_dashboard)
        elif msg.type == WSMsgType.ERROR:
            logger.error('ws connection closed with exception %s', exc_info=ws.exception())

    logger.info('websocket connection closed')

    return ws


async def stop_websockets(app):
    if 'websockets' not in app:
        return
    for ws in app['websockets']:
        await ws.close(code=WSCloseCode.GOING_AWAY, message='server shutdown')


async def start_background_tasks(app, args):
    async def notify_websockets(dashboard_list):
        for ws in app.get('websockets', []):
            await ws.send_json({'message': 'dashboards', 'dashboards': dashboard_list})
    app['dashboards_watcher'] = DashboardsWatcher(app.loop, args.dashboard_dir, notify_websockets)


async def stop_background_tasks(_app):
    pass


def run(args):
    app = web.Application()
    app['logger'] = setup_logging()
    app['websockets'] = {}

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
