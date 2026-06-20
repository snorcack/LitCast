#!/bin/bash
set -e

echo "Checking dependencies..."
python -c "import sys; assert sys.version_info >= (3, 11)" || echo "Python 3.11+ required"
node -v | grep -E "^v(18|19|20|21|22|23)" > /dev/null || echo "Node 18+ required"

echo "Setting up virtual environment..."
pip install -r requirements.txt

echo "Setting up frontend..."
cd frontend && npm install && cd ..

if [ ! -f .env ]; then
  cp .env.example .env
  echo "Copied .env.example to .env"
fi

echo "Setting up directories..."
mkdir -p books chroma_db episodes

echo "Setup complete. Edit .env with your API keys, then run scripts/run_dev.sh"
