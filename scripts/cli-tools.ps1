function global:Invoke-RequiredExternalCommand {
    param(
        [Parameter(Mandatory)]
        [string] $CommandName,

        [string] $DisplayName = $CommandName,

        [string[]] $CommandArgs = @(),

        [switch] $PreferExternalScript
    )

    # Windows 上 pnpm、Codex 等工具通常同时提供 .cmd 和 .ps1 启动器。
    # 默认优先使用应用程序启动器，避免 PowerShell 执行策略阻止同名 .ps1 脚本。
    $commandTypes = if ($PreferExternalScript) {
        @("ExternalScript", "Application")
    } else {
        @("Application", "ExternalScript")
    }
    $resolvedCommand = $null
    foreach ($commandType in $commandTypes) {
        $resolvedCommand = Get-Command $CommandName -CommandType $commandType -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($resolvedCommand) {
            break
        }
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

function global:Invoke-WithLocalProxy {
    param(
        [Parameter(Mandatory)]
        [scriptblock] $ScriptBlock,

        [string] $ProxyUrl = "http://127.0.0.1:7890"
    )

    # Windows 环境变量名不区分大小写，设置 HTTP_PROXY 即同时覆盖 http_proxy。
    $proxyVariableNames = @("HTTP_PROXY", "HTTPS_PROXY")
    $originalValues = @{}
    foreach ($name in $proxyVariableNames) {
        $originalValues[$name] = [Environment]::GetEnvironmentVariable($name)
        [Environment]::SetEnvironmentVariable($name, $ProxyUrl)
    }

    try {
        & $ScriptBlock
    }
    finally {
        # 代理只作用于被包装的命令，结束后恢复原值。原本不存在的变量必须显式删除：
        # PowerShell 7 下用 SetEnvironmentVariable 传 $null 不会删除变量，而是留下一个空值。
        foreach ($name in $proxyVariableNames) {
            if ($null -eq $originalValues[$name]) {
                Remove-Item -Path "Env:$name" -ErrorAction SilentlyContinue
            } else {
                [Environment]::SetEnvironmentVariable($name, $originalValues[$name])
            }
        }
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

function global:Start-AntigravityDangerously {
    # Antigravity 需要经本地代理访问网络，代理只在本次调用期间生效。
    Invoke-WithLocalProxy -ScriptBlock {
        Invoke-RequiredExternalCommand -CommandName "agy" -DisplayName "Antigravity CLI" -CommandArgs @("--dangerously-skip-permissions")
    }
}

function global:Update-AntigravityCli {
    Invoke-WithLocalProxy -ScriptBlock {
        Invoke-RequiredExternalCommand -CommandName "agy" -DisplayName "Antigravity CLI" -CommandArgs @("update")
    }
}

function global:Update-PnpmCli {
    # self-update 会重写 pnpm.cmd；改用 PowerShell 启动器，避免 cmd.exe 继续读取被覆盖后的批处理文件。
    Invoke-RequiredExternalCommand -CommandName "pnpm" -DisplayName "pnpm" -CommandArgs @("self-update") -PreferExternalScript
}

function global:Resolve-GitBashPath {
    $gitBash = "D:\software\Git\bin\bash.exe"
    if (Test-Path -LiteralPath $gitBash -PathType Leaf) {
        return $gitBash
    }

    $git = Get-Command "git" -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($git) {
        $gitRoot = Split-Path -Parent (Split-Path -Parent $git.Source)
        $candidate = Join-Path $gitRoot "bin\bash.exe"
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return $candidate
        }
    }
    return $null
}

function global:Start-GitBash {
    $gitBash = Resolve-GitBashPath
    if (-not $gitBash) {
        Write-Error "未找到 Git Bash，请确认 Git 已安装并在 PATH 中。"
        return
    }

    $commandArgs = @("--login", "-i")
    & $gitBash @commandArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Git Bash 执行失败，退出码：$LASTEXITCODE。"
    }
}

$gitWorktreeToolsScript = Join-Path $PSScriptRoot "git-worktree-tools.ps1"
if (Test-Path $gitWorktreeToolsScript) {
    . $gitWorktreeToolsScript
}

Set-Alias -Name cxy -Value Start-CodexYolo -Scope Global -Force
Set-Alias -Name ccd -Value Start-ClaudeDangerously -Scope Global -Force
Set-Alias -Name cxu -Value Update-CodexCli -Scope Global -Force
Set-Alias -Name ccu -Value Update-ClaudeCli -Scope Global -Force
Set-Alias -Name agd -Value Start-AntigravityDangerously -Scope Global -Force
Set-Alias -Name agu -Value Update-AntigravityCli -Scope Global -Force
Set-Alias -Name pnu -Value Update-PnpmCli -Scope Global -Force
Set-Alias -Name gitbash -Value Start-GitBash -Scope Global -Force
