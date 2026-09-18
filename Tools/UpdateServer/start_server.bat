@echo off
rem Simple static file server for the hot-update demo.
rem Serves this folder at http://127.0.0.1:8000/
cd /d "%~dp0"
where python >nul 2>nul
if %errorlevel%==0 (
    python -m http.server 8000
    goto :eof
)
where npx >nul 2>nul
if %errorlevel%==0 (
    npx http-server -p 8000 -c-1 .
    goto :eof
)
echo No python or npx found. Install python or node, then run again.
pause
