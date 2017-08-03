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
logger = setup_logging()


async def websocket_handler(request):
    ws = web.WebSocketResponse()
    await ws.prepare(request)

    if 'websockets' not in request.app:
        request.app['websockets'] = set([ws])
    else:
        request.app['websockets'].add(ws)

    async for msg in ws:
        if msg.type == WSMsgType.TEXT:
            if msg.data == 'close':
                await ws.close()
            elif msg.data == 'dashboards':
                await ws.send_json({'message': 'dashboards', 'dashboards': request.app['dashboards_watcher'].get_dashboard_names()})
        elif msg.type == aiohttp.WSMsgType.ERROR:
            logger.error('ws connection closed with exception {}'.format(ws.exception()))

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


async def stop_background_tasks(app):
    pass


def run(args):
    app = web.Application()
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
