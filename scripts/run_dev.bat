@echo off
start "Backend" cmd /c "uvicorn backend.main:app --reload --host 0.0.0.0 --port 8000"
start "Frontend" cmd /c "cd frontend && npm run dev"
echo Both Backend and Frontend are starting in new windows...
