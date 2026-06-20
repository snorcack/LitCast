from fastapi import APIRouter, BackgroundTasks
from pydantic import BaseModel
from pathlib import Path
from backend.rag.retriever import BookRetriever

router = APIRouter(prefix="/library", tags=["library"])
retriever = BookRetriever()

class IngestRequest(BaseModel):
    filename: str

class RagQueryRequest(BaseModel):
    book_slug: str
    query: str
    persona_bias_prefix: str = ""

@router.get("")
async def list_library():
    return {"books": retriever.list_books()}

@router.post("/ingest")
async def ingest_book(req: IngestRequest, bg_tasks: BackgroundTasks):
    path = Path("books") / req.filename
    if not path.exists():
        return {"error": "File not found"}
    book_slug = path.stem.lower().replace(" ", "_").replace("-", "_")
    return {"status": "ingesting", "book": book_slug}

@router.get("/ingest/progress")
async def ingest_progress():
    pass

@router.post("/test_query")
async def test_rag_query(req: RagQueryRequest):
    res = retriever.query(
        book_slug=req.book_slug,
        topic=req.query,
        persona_bias_prefix=req.persona_bias_prefix,
        agent_question="What does this text say about the topic?"
    )
    return {"results": res}
