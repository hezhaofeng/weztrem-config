$env:VSCODE_SHELL_INTEGRATION = "0"
$env:VSCODE_NONCE = $null
$env:VSCODE_STABLE = $null
$env:VSCODE_SHELL_ENV_REPORTING = $null
$env:LANG = "zh_CN.UTF-8"
$env:LC_ALL = "zh_CN.UTF-8"
$env:PYTHONUTF8 = "1"
$env:PYTHONIOENCODING = "utf-8"

function Use-Utf8ConsoleEncoding {
    # 让 PowerShell 和原生命令都按 UTF-8 读写，避免中文输出乱码。
    chcp.com 65001 > $null
    $env:LANG = "zh_CN.UTF-8"
    $env:LC_ALL = "zh_CN.UTF-8"
    $env:PYTHONUTF8 = "1"
    $env:PYTHONIOENCODING = "utf-8"
    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [Console]::InputEncoding = $utf8NoBom
    [Console]::OutputEncoding = $utf8NoBom
    $script:OutputEncoding = $utf8NoBom
    $global:OutputEncoding = $utf8NoBom
}

function global:Start-GitBash {
    $gitBash = "D:\software\Git\bin\bash.exe"

    if (-not (Test-Path $gitBash)) {
        Write-Error "未找到 Git Bash：$gitBash"
        return
    }

    & $gitBash --login -i
}

Set-Alias -Name gitbash -Value Start-GitBash -Scope Global -Force

Use-Utf8ConsoleEncoding

if (Test-Path $PROFILE) {
    . $PROFILE
    Use-Utf8ConsoleEncoding
}

if ((Test-Path Variable:\Global:__VSCodeState) -and $Global:__VSCodeState) {
    if ($Global:__VSCodeState.OriginalPSConsoleHostReadLine) {
        Set-Item -Path Function:\global:PSConsoleHostReadLine -Value $Global:__VSCodeState.OriginalPSConsoleHostReadLine
    }

    Remove-Variable -Name __VSCodeState -Scope Global -ErrorAction SilentlyContinue
}

function global:prompt {
    $location = $executionContext.SessionState.Path.CurrentLocation
    "PS $location$('>' * ($nestedPromptLevel + 1)) "
}

$cliToolsScript = Join-Path $PSScriptRoot "cli-tools.ps1"
if (Test-Path $cliToolsScript) {
    . $cliToolsScript
}
