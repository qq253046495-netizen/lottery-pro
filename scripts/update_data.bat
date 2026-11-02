@echo off
REM 每日开奖数据更新：抓官网 -> 提交 -> 推送到 GitHub
REM 由 Windows 计划任务 "LotteryDataUpdate" 每天 21:40 调用
setlocal
cd /d "%~dp0.."

echo [%date% %time%] start >> scripts\update.log

python scripts\fetch_lottery.py --n 200 --no-fallback >> scripts\update.log 2>&1
if errorlevel 1 (
    echo [%date% %time%] fetch FAILED, keep existing data >> scripts\update.log
    exit /b 1
)

git add data
git -c user.email=lottery-bot@local -c user.name=lottery-bot commit -m "data: update %date%" >> scripts\update.log 2>&1
git push origin main >> scripts\update.log 2>&1

if errorlevel 1 (
    echo [%date% %time%] push FAILED >> scripts\update.log
    exit /b 1
)
echo [%date% %time%] done >> scripts\update.log
endlocal
