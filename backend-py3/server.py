from aiohttp import web, WSMsgType, WSCloseCode



async def websocket_handler(request):
    ws = web.WebSocketResponse()
    await ws.prepare(request)

    if 'websockets' not in request.app:
        request.app['websockets'] = set([ws])
    else:
        request.app['websockets'].add(ws)

    async for msg in ws:
        if msg.type == WSMsgType.TEXT:
            print(msg.data)
            if msg.data == 'close':
                await ws.close()
            elif msg.data == 'dashboards':
                await ws.send_json({'message': 'dashboards', 'dashboards': ['one', 'two']})
        elif msg.type == aiohttp.WSMsgType.ERROR:
            print('ws connection closed with exception {}'.format(ws.exception()))

    print('websocket connection closed')

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
