rem git reset --soft
rem git init

rem git add -f ".gitignore"
rem git add -f "README.md"
rem git add -f "LICENSE"
rem git add -f "img"
rem git add "GUI Tools"
rem git add "Markers"
rem git add "KeyMaps"
rem git add "FX"
rem git add -f "index.xml"
rem git commit -m "CMD Add Files"
rem git -c gc.auto=0 commit -q -m "+ CMD Add Files +"
git add -A
git commit -m "CMD Add Files"
git push
popd
exit