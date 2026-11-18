@echo off
REM ==========================================
REM SRVX_ROOT = корень утилиты, PROJECT_DIR = папка проекта
REM Нельзя set SRVX_ROOT=%CD% внутри (...): %CD% раскрывается ДО pushd.
REM ==========================================

if defined SRVX_ROOT goto HAVE_ROOT
pushd "%~dp0.." >nul
set "SRVX_ROOT=%CD%"
popd >nul
:HAVE_ROOT

if not defined PROJECT_DIR set "PROJECT_DIR=%CD%"

exit /b 0
