import logging

from aiohttp import web, WSMsgType, WSCloseCode

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
                await ws.send_json({'message': 'dashboards', 'dashboards': ['one', 'two']})
        elif msg.type == aiohttp.WSMsgType.ERROR:
            logger.error('ws connection closed with exception {}'.format(ws.exception()))

    logger.info('websocket connection closed')

    return ws


async def stop_websockets(app):
    if 'websockets' not in app:
        return
    for ws in app['websockets']:
        await ws.close(code=WSCloseCode.GOING_AWAY, message='server shutdown')


def main():
    app = web.Application()
    app.router.add_get('/socket', websocket_handler)

    app.on_shutdown.append(stop_websockets)

    web.run_app(app)


if __name__ == '__main__':
    main()
