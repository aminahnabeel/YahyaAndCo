# Staged installer: Temurin JDK 17 (user-local) + Android cmdline-tools
# Run in PowerShell: powershell -NoProfile -ExecutionPolicy Bypass -File .install_scripts\install_jdk_and_sdk.ps1

$ErrorActionPreference = 'Stop'

Write-Host "1) Paths"
$zip = Join-Path $env:TEMP 'temurin17.zip'
$tmp = Join-Path $env:TEMP 'temurin_extract'
$installDir = Join-Path $env:USERPROFILE 'AppData\Local\Programs\temurin-17'

Write-Host "2) Download Temurin 17 to $zip"
Invoke-WebRequest -Uri 'https://github.com/adoptium/temurin17-binaries/releases/latest/download/OpenJDK17U-jdk_x64_windows_hotspot.zip' -OutFile $zip -UseBasicParsing

Write-Host "3) Extracting to $tmp"
if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
Expand-Archive -Path $zip -DestinationPath $tmp -Force
$inner = Get-ChildItem $tmp | Where-Object { $_.PsIsContainer } | Select-Object -First 1
if (-not $inner) { throw "Extraction failed: no inner folder" }

Write-Host "4) Moving to $installDir"
if (Test-Path $installDir) { Remove-Item $installDir -Recurse -Force }
Move-Item -Path $inner.FullName -Destination $installDir

Write-Host "5) Set JAVA_HOME for session and user"
$env:JAVA_HOME = $installDir
$env:Path = "$installDir\bin;" + $env:Path
setx JAVA_HOME "$installDir" | Out-Null

Write-Host "6) Verify java"
& "$installDir\bin\java.exe" -version

Write-Host "7) Install Android cmdline-tools"
$sdkRoot = Join-Path $env:LOCALAPPDATA 'Android\sdk'
if (-not (Test-Path $sdkRoot)) { New-Item -ItemType Directory -Force -Path $sdkRoot | Out-Null }
$zip2 = Join-Path $env:TEMP 'cmdline-tools.zip'
$tmp2 = Join-Path $env:TEMP 'cmdline_tools_extract'
Invoke-WebRequest -Uri 'https://dl.google.com/android/repository/commandlinetools-win-latest.zip' -OutFile $zip2 -UseBasicParsing
if (Test-Path $tmp2) { Remove-Item $tmp2 -Recurse -Force }
Expand-Archive -Path $zip2 -DestinationPath $tmp2 -Force
$ex = Get-ChildItem $tmp2 | Where-Object { $_.PsIsContainer } | Select-Object -First 1
$final = Join-Path $sdkRoot 'cmdline-tools\latest'
if (Test-Path $final) { Remove-Item $final -Recurse -Force }
New-Item -ItemType Directory -Force -Path $final | Out-Null
Move-Item -Path (Join-Path $ex.FullName '*') -Destination $final

Write-Host "8) sdkmanager location:" (Join-Path $final 'bin\sdkmanager.bat')

Write-Host "9) Install platform-tools and platforms;android-33"
$sd = Join-Path $final 'bin\sdkmanager.bat'
cmd /c `"$sd`" --sdk_root=`"$sdkRoot`" "platform-tools" "platforms;android-33"

Write-Host "10) Accept licenses"
cmd /c "echo y|`"$sd`" --sdk_root=`"$sdkRoot`" --licenses"

Write-Host "Done. Run 'flutter doctor -v' and then 'flutter build apk' in project root."