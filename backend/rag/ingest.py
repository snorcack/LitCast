import argparse
from pathlib import Path
from backend.rag.retriever import BookRetriever

class BookIngestor:
    def __init__(self):
        pass

    def ingest(self, path: Path):
        book_slug = path.stem.lower().replace(" ", "_").replace("-", "_")
        return book_slug

if __name__ == "__main__":
    pass
