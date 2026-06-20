from fastapi import APIRouter, WebSocket, WebSocketDisconnect
import redis.asyncio as aioredis
import asyncio
from backend.config import settings

router = APIRouter(tags=["ws"])

@router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket, session_id: str):
    await websocket.accept()

    redis = aioredis.from_url(settings.redis_url, decode_responses=True)
    pubsub = redis.pubsub()
    await pubsub.subscribe(f"session:{session_id}:events")

    try:
        while True:
            message = await pubsub.get_message(ignore_subscribe_messages=True, timeout=0.1)
            if message:
                await websocket.send_text(message["data"])

            try:
                data = await asyncio.wait_for(websocket.receive_text(), timeout=0.1)
                if data == "ping":
                    await websocket.send_text('{"type": "pong"}')
            except asyncio.TimeoutError:
                pass
    except WebSocketDisconnect:
        pass
    except Exception as e:
        pass
    finally:
        await pubsub.unsubscribe()
        await redis.aclose()
