from aiohttp import web, WSMsgType



async def websocket_handler(request):
    ws = web.WebSocketResponse()
    await ws.prepare(request)

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


def main():
    app = web.Application()
    app.router.add_get('/socket', websocket_handler)
    web.run_app(app)


if __name__ == '__main__':
    main()
