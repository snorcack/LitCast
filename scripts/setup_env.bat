@echo off
echo Checking dependencies...
python -c "import sys; assert sys.version_info >= (3, 11)" || echo Python 3.11+ required
node -v | findstr /R "^v[1-9][8-9].* ^v2[0-9].*" >nul || echo Node 18+ required

echo Setting up virtual environment...
pip install -r requirements.txt

echo Setting up frontend...
cd frontend
call npm install
cd ..

if not exist .env (
    copy .env.example .env
    echo Copied .env.example to .env
)

echo Setting up directories...
if not exist books mkdir books
if not exist chroma_db mkdir chroma_db
if not exist episodes mkdir episodes

echo Setup complete. Edit .env with your API keys, then run scripts\run_dev.bat
