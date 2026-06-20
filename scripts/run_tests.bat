@echo off
echo Running Backend Tests...
python -m pytest backend\tests\ -v --tb=short

echo Running Frontend Tests...
cd frontend
call npm run test
cd ..
