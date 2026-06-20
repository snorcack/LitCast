from fastapi import APIRouter, Request
from fastapi.responses import StreamingResponse
import redis.asyncio as aioredis
import asyncio
from backend.config import settings

router = APIRouter(prefix="/stream", tags=["stream"])

async def event_generator(session_id: str, request: Request):
    redis = aioredis.from_url(settings.redis_url, decode_responses=True)
    pubsub = redis.pubsub()
    await pubsub.subscribe(f"session:{session_id}:events")

    try:
        while True:
            if await request.is_disconnected():
                break

            message = await pubsub.get_message(ignore_subscribe_messages=True, timeout=0.1)
            if message:
                yield f"data: {message['data']}\n\n"
            else:
                yield ": keepalive\n\n"

    finally:
        await pubsub.unsubscribe()
        await redis.aclose()

@router.get("")
async def sse_stream(session_id: str, request: Request):
    return StreamingResponse(event_generator(session_id, request), media_type="text/event-stream")
