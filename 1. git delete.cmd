@echo off

pushd "%CD%"
CD /D "%~dp0"

cmd /c rmdir .git /s /q
cmd /c rmdir .idea /s /q
cmd /c rmdir .gradle /s /q
