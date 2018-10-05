rem Create build directory
md bin

rem Create temporary directory
md temp

rem Compile resources into a DLL called resource.dat
cd resource
brcc32 resource.rc
dcc32 resource.dpr
erase resource.res
erase ..\bin\resource.dat
move resource.dll ..\bin\resource.dat

rem Compile MapMaker
cd ..\src
dcc32 -B MapMaker.dpr

rem Compile AntAttack Game
dcc32 -B AntAttack.dpr

rem Compile Configuration
cd ..\cfg
dcc32 -B Configuration.dpr

rem Copy Maps and Music to bin
cd ..
copy maps bin
copy resource\*.mp3 bin

rem Copy OpenAL to bin
copy openal bin

rem Copy Help to bin
xcopy help\*.* bin\doc\ /s /y
