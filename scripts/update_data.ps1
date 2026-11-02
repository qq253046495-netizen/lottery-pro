# 每日开奖数据更新：抓官网 -> 提交 -> 推送到 GitHub
# 由 Windows 计划任务 "LotteryDataUpdate" 每天 21:40 调用
# 手动运行： powershell -NoProfile -ExecutionPolicy Bypass -File scripts\update_data.ps1

$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root
$log = Join-Path $root 'scripts\update.log'
$env:PYTHONIOENCODING = 'utf-8'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
$OutputEncoding = [System.Text.Encoding]::UTF8

function Log([string]$m) {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')  $m" | Out-File -FilePath $log -Append -Encoding utf8
}

# 执行外部程序 -> 输出追加到日志 -> 返回退出码
function Run([string]$exe, [string[]]$argv) {
    $out = & $exe @argv 2>&1
    $code = $LASTEXITCODE
    if ($out) { $out | ForEach-Object { ("$_" -replace "`r", "") } | Out-File -FilePath $log -Append -Encoding utf8 }
    return $code
}

function Find-Git {
    $c = Get-Command git -ErrorAction SilentlyContinue
    if ($c) { return $c.Source }
    $cands = @()
    $base = Join-Path $env:USERPROFILE '.workbuddy\binaries\PortableGit\versions'
    if (Test-Path $base) {
        $cands += Get-ChildItem $base -Directory -ErrorAction SilentlyContinue |
                  ForEach-Object { Join-Path $_.FullName 'bin\git.exe' }
        $cands += Get-ChildItem $base -Directory -ErrorAction SilentlyContinue |
                  ForEach-Object { Join-Path $_.FullName 'cmd\git.exe' }
    }
    $cands += 'E:\workbuddy\resources\vendor\PortableGit\mingw64\bin\git.exe'
    $cands += 'E:\workbuddy\resources\vendor\PortableGit\cmd\git.exe'
    $cands += 'C:\Program Files\Git\cmd\git.exe'
    foreach ($p in $cands) { if (Test-Path $p) { return $p } }
    return $null
}

function Find-Python {
    $c = Get-Command python -ErrorAction SilentlyContinue
    if ($c -and $c.Source -notlike '*WindowsApps*') { return $c.Source }
    $base = Join-Path $env:USERPROFILE '.workbuddy\binaries\python\versions'
    if (Test-Path $base) {
        $hit = Get-ChildItem $base -Directory -ErrorAction SilentlyContinue |
               ForEach-Object { Join-Path $_.FullName 'python.exe' } |
               Where-Object { Test-Path $_ } |
               Select-Object -First 1
        if ($hit) { return $hit }
    }
    return $null
}

Log "==== start ===="

$py  = Find-Python
$git = Find-Git
if (-not $py)  { Log "python NOT FOUND"; exit 1 }
if (-not $git) { Log "git NOT FOUND";    exit 1 }
Log "python=$py"
Log "git=$git"

# ---- 抓数据（失败绝不覆盖已有数据） ----
$code = Run $py @('scripts\fetch_lottery.py', '--n', '200', '--no-fallback')
if ($code -ne 0) { Log "fetch FAILED (exit=$code) -> 保留现有数据，不提交"; exit 1 }

# ---- 提交 ----
$null = Run $git (@('add', 'data'))
$msg = 'data: update ' + (Get-Date -Format 'yyyy-MM-dd')
$null = Run $git (@('-c', 'user.email=lottery-bot@local', '-c', 'user.name=lottery-bot', 'commit', '-m', $msg))

# ---- 推送（仓库配置了 http.proxy=127.0.0.1:7897；代理没开就直连重试） ----
$code = Run $git @('push', 'origin', 'main')
if ($code -ne 0) {
    Log "push via proxy failed (exit=$code) -> retry direct"
    $code = Run $git @('-c', 'http.proxy=', '-c', 'https.proxy=', 'push', 'origin', 'main')
}
if ($code -ne 0) { Log "push FAILED (exit=$code)"; exit 1 }

# ---- 刷新 jsDelivr 缓存（App 默认从它拉数据） ----
try {
    foreach ($t in @('dlt', 'ssq')) {
        $u = "https://purge.jsdelivr.net/gh/qq253046495-netizen/lottery-pro@main/data/$t.json"
        Invoke-WebRequest -Uri $u -TimeoutSec 20 -UseBasicParsing -ErrorAction Stop | Out-Null
    }
    Log "jsdelivr cache purged"
} catch {
    Log ("purge skip: " + $_.Exception.Message)
}

Log "done"
exit 0
