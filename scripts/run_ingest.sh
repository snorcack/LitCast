#!/bin/bash
set -e
python -m backend.rag.ingest "$@"
