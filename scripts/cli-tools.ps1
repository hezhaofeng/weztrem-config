function global:Invoke-RequiredExternalCommand {
    param(
        [Parameter(Mandatory)]
        [string] $CommandName,

        [string] $DisplayName = $CommandName,

        [string[]] $CommandArgs = @()
    )

    # Windows 上 pnpm、Codex 等工具通常同时提供 .cmd 和 .ps1 启动器。
    # 优先使用应用程序启动器，避免 PowerShell 执行策略阻止同名 .ps1 脚本。
    $resolvedCommand = Get-Command $CommandName -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $resolvedCommand) {
        $resolvedCommand = Get-Command $CommandName -CommandType ExternalScript -ErrorAction SilentlyContinue | Select-Object -First 1
    }

    if (-not $resolvedCommand) {
        Write-Error "未找到 $DisplayName 命令，请确认已安装并在 PATH 中。"
        return
    }

    & $resolvedCommand.Source @CommandArgs
    $commandSucceeded = $?
    $exitCode = $LASTEXITCODE

    if ($resolvedCommand.CommandType -eq [System.Management.Automation.CommandTypes]::Application) {
        if ($exitCode -ne 0) {
            Write-Error "$DisplayName 执行失败，退出码：$exitCode。"
        }
    }
    elseif (-not $commandSucceeded) {
        Write-Error "$DisplayName 脚本执行失败。"
    }
}

function global:Start-OptionalCommand {
    param(
        [Parameter(Mandatory)]
        [string] $CommandName,

        [string] $DisplayName = $CommandName,

        [string[]] $CommandArgs = @()
    )

    $resolvedCommand = Get-Command $CommandName -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $resolvedCommand) {
        $resolvedCommand = Get-Command $CommandName -CommandType ExternalScript -ErrorAction SilentlyContinue | Select-Object -First 1
    }

    if (-not $resolvedCommand) {
        Write-Warning "未找到 $DisplayName 命令；请先安装或把它加入 PATH，然后重新打开此启动项。"
        return
    }

    & $resolvedCommand.Source @CommandArgs
    $commandSucceeded = $?
    $exitCode = $LASTEXITCODE

    if ($resolvedCommand.CommandType -eq [System.Management.Automation.CommandTypes]::Application) {
        if ($exitCode -ne 0) {
            Write-Error "$DisplayName 执行失败，退出码：$exitCode。"
        }
    }
    elseif (-not $commandSucceeded) {
        Write-Error "$DisplayName 脚本执行失败。"
    }
}

function global:Start-CodexYolo {
    Invoke-RequiredExternalCommand -CommandName "codex" -DisplayName "Codex CLI" -CommandArgs @("--yolo")
}

function global:Start-ClaudeDangerously {
    Invoke-RequiredExternalCommand -CommandName "claude" -DisplayName "Claude CLI" -CommandArgs @("--dangerously-skip-permissions")
}

function global:Update-CodexCli {
    Invoke-RequiredExternalCommand -CommandName "pnpm" -DisplayName "pnpm" -CommandArgs @("add", "-g", "@openai/codex@latest")
}

function global:Update-ClaudeCli {
    Invoke-RequiredExternalCommand -CommandName "claude" -DisplayName "Claude CLI" -CommandArgs @("update")
}

function global:Update-PnpmCli {
    Invoke-RequiredExternalCommand -CommandName "pnpm" -DisplayName "pnpm" -CommandArgs @("self-update")
}

$gitWorktreeToolsScript = Join-Path $PSScriptRoot "git-worktree-tools.ps1"
if (Test-Path $gitWorktreeToolsScript) {
    . $gitWorktreeToolsScript
}

Set-Alias -Name cxy -Value Start-CodexYolo -Scope Global -Force
Set-Alias -Name ccd -Value Start-ClaudeDangerously -Scope Global -Force
Set-Alias -Name cxu -Value Update-CodexCli -Scope Global -Force
Set-Alias -Name ccu -Value Update-ClaudeCli -Scope Global -Force
Set-Alias -Name pnu -Value Update-PnpmCli -Scope Global -Force
