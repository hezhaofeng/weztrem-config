function global:Invoke-RequiredExternalCommand {
    param(
        [Parameter(Mandatory)]
        [string] $CommandName,

        [string] $DisplayName = $CommandName,

        [string[]] $CommandArgs = @()
    )

    $resolvedCommand = Get-Command $CommandName -CommandType Application,ExternalScript -ErrorAction SilentlyContinue | Select-Object -First 1

    if (-not $resolvedCommand) {
        Write-Error "未找到 $DisplayName 命令，请确认已安装并在 PATH 中。"
        return
    }

    & $resolvedCommand.Source @CommandArgs
}

function global:Start-OptionalCommand {
    param(
        [Parameter(Mandatory)]
        [string] $CommandName,

        [string] $DisplayName = $CommandName,

        [string[]] $CommandArgs = @()
    )

    $resolvedCommand = Get-Command $CommandName -CommandType Application,ExternalScript -ErrorAction SilentlyContinue | Select-Object -First 1

    if (-not $resolvedCommand) {
        Write-Warning "未找到 $DisplayName 命令；请先安装或把它加入 PATH，然后重新打开此启动项。"
        return
    }

    & $resolvedCommand.Source @CommandArgs
}

function global:Invoke-WezTermCodex {
    Invoke-RequiredExternalCommand -CommandName "codex" -DisplayName "Codex CLI" -CommandArgs (@("--no-alt-screen") + $args)
}

function global:codex {
    Invoke-WezTermCodex @args
}

function global:Start-CodexYolo {
    codex --yolo
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

Set-Alias -Name cxy -Value Start-CodexYolo -Scope Global -Force
Set-Alias -Name ccd -Value Start-ClaudeDangerously -Scope Global -Force
Set-Alias -Name cxu -Value Update-CodexCli -Scope Global -Force
Set-Alias -Name ccu -Value Update-ClaudeCli -Scope Global -Force
