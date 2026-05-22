@echo off
set "SDK_ROOT=%LOCALAPPDATA%\Android\sdk"
if not exist "%SDK_ROOT%\cmdline-tools\latest" mkdir "%SDK_ROOT%\cmdline-tools\latest"
powershell -NoProfile -Command "Invoke-WebRequest 'https://dl.google.com/android/repository/commandlinetools-win-latest.zip' -OutFile ($env:TEMP + '\\cmdline-tools.zip') -UseBasicParsing"
powershell -NoProfile -Command "Expand-Archive -Path ($env:TEMP + '\\cmdline-tools.zip') -DestinationPath ($env:TEMP + '\\cmdline_tools_extract') -Force"
robocopy "%TEMP%\cmdline_tools_extract" "%SDK_ROOT%\cmdline-tools\latest" /e
rd /s /q "%TEMP%\cmdline_tools_extract"
"%SDK_ROOT%\cmdline-tools\latest\bin\sdkmanager.bat" --sdk_root="%SDK_ROOT%" "platform-tools" "platforms;android-33"
echo y| "%SDK_ROOT%\cmdline-tools\latest\bin\sdkmanager.bat" --sdk_root="%SDK_ROOT%" --licenses
exit /b %ERRORLEVEL%
