@echo off
rem 构建并部署 Web 到 Cloudflare Pages。
rem   tool\deploy_web.bat           构建 + 部署
rem   tool\deploy_web.bat build     只构建，不部署
rem
rem --no-tree-shake-icons 是必需的：图标瘦身要调用 Flutter 自带的 font-subset.exe，
rem 该文件无数字签名，会被 Windows 11 的智能应用控制（Smart App Control）拦截，
rem 直接用 flutter build web 会在 web_release_bundle 阶段报「应用程序控制策略已阻止此文件」。

setlocal
cd /d "%~dp0.."

echo [1/2] flutter build web --release --no-tree-shake-icons
call flutter build web --release --no-tree-shake-icons
if errorlevel 1 goto fail

if /i "%~1"=="build" (
  echo.
  echo build only, skip deploy.
  exit /b 0
)

echo.
echo [2/2] npx wrangler pages deploy build\web --project-name skneo
call npx wrangler pages deploy build\web --project-name skneo
if errorlevel 1 goto fail

echo.
echo done.
exit /b 0

:fail
echo.
echo FAILED. 见上面的输出。
exit /b 1
