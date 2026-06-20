#!/bin/bash
set -e
echo "Running Backend Tests..."
python -m pytest backend/tests/ -v --tb=short

echo "Running Frontend Tests..."
cd frontend && npm run test
