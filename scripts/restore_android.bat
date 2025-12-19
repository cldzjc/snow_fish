@echo off
REM 备份 android 目录并用 flutter create 恢复平台脚本（Windows）

setlocal
set PROJECT_DIR=%~dp0..
set PROJECT_DIR=%PROJECT_DIR:~0,-1%
echo Project dir: %PROJECT_DIR%

REM 1) 备份当前 android 目录
if exist "%PROJECT_DIR%\backup_android" (
  echo backup_android already exists. Skipping backup creation.
) else (
  echo Backing up android -> backup_android ...
  xcopy "%PROJECT_DIR%\android" "%PROJECT_DIR%\backup_android\" /E /I /Y >nul
  if errorlevel 1 (
    echo Backup may have errors, continue...
  ) else (
    echo Backup done.
  )
)

REM 2) 让 Flutter 恢复平台目录（会覆盖 android/ios 等）
cd /d "%PROJECT_DIR%"
echo Running: flutter create .
flutter create . 
if errorlevel 1 (
  echo flutter create failed. Aborting.
  pause
  exit /b 1
)

REM 3) 清理并获取依赖
echo Running: flutter clean
flutter clean
echo Running: flutter pub get
flutter pub get

echo.
echo 完成：
echo - 请把你的 google-services.json 放到: %PROJECT_DIR%\android\app\google-services.json
echo - 请把你的 GoogleService-Info.plist 放到: %PROJECT_DIR%\ios\Runner\GoogleService-Info.plist
echo - 如果使用本地演示模式，请确认 lib/config.dart 中 USE_LOCAL_DATA 的值
echo - 然后运行: flutter run
pause
endlocal
