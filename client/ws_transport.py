"""Ordered WSS -> asyncio MSNP transport for Storm MSN.

TCP preserves write order; a WebSocket writer must preserve it as well.
All writes are queued and forwarded by one sender task.
"""
import asyncio

class WSWriter:
    def __init__(self, conn, rx_task):
        self.conn = conn
        self.rx_task = rx_task
        self.outbox = asyncio.Queue(maxsize=256)
        self.sender_task = asyncio.create_task(self._sender())
        self.close_task = None
        self._closing = False

    async def _sender(self):
        try:
            while True:
                data = await self.outbox.get()
                if data is None:
                    break
                await self.conn.send(data)
        except Exception:
            pass
        finally:
            try:
                await self.conn.close()
                await self.conn.wait_closed()
            except Exception:
                pass

    def write(self, data):
        if self._closing:
            return
        try:
            self.outbox.put_nowait(bytes(data))
        except asyncio.QueueFull:
            self.close()
            raise ConnectionError("Fila de envio excedida")

    def close(self):
        if self._closing:
            return
        self._closing = True
        try:
            self.outbox.put_nowait(None)
        except asyncio.QueueFull:
            self.sender_task.cancel()
        self.close_task = self.sender_task

    async def wait_closed(self):
        self.close()
        try:
            await asyncio.wait_for(self.sender_task, 5)
        except (asyncio.CancelledError, asyncio.TimeoutError):
            self.sender_task.cancel()
        if not self.rx_task.done():
            try:
                await asyncio.wait_for(self.rx_task, 2)
            except (asyncio.TimeoutError, asyncio.CancelledError):
                self.rx_task.cancel()

    def is_closing(self):
        return self._closing or self.conn.close_code is not None


async def open_transport(host, port):
    host = host.strip()
    if host in ("127.0.0.1", "localhost", "::1") or host.startswith("tcp://"):
        return await asyncio.open_connection(host.replace("tcp://", ""), port)

    try:
        import websockets
    except ImportError as ex:
        raise RuntimeError("Instale websockets: pip install websockets") from ex

    hostname = host.replace("wss://", "").replace("https://", "").strip("/")
    ws = await websockets.connect(
        "wss://" + hostname + "/ws/" + str(port),
        open_timeout=15, max_size=32768, ping_interval=30, compression=None,
    )
    reader = asyncio.StreamReader()

    async def incoming():
        try:
            async for message in ws:
                if isinstance(message, bytes):
                    reader.feed_data(message)
        except Exception:
            pass
        finally:
            reader.feed_eof()

    task = asyncio.create_task(incoming())
    return reader, WSWriter(ws, task)
