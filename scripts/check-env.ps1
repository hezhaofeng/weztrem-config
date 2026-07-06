param(
    [switch] $Json,
    [switch] $SkipWezTermConfigCheck
)

$ErrorActionPreference = "Continue"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$Results = [System.Collections.Generic.List[object]]::new()

function Add-CheckResult {
    param(
        [Parameter(Mandatory)]
        [ValidateSet("OK", "WARN", "MISS")]
        [string] $Status,

        [Parameter(Mandatory)]
        [string] $Category,

        [Parameter(Mandatory)]
        [string] $Name,

        [string] $Version = "",
        [string] $Path = "",
        [string] $Note = "",
        [string] $InstallHint = ""
    )

    $Results.Add([pscustomobject]@{
        Status = $Status
        Category = $Category
        Name = $Name
        Version = $Version
        Path = $Path
        Note = $Note
        InstallHint = $InstallHint
    })
}

function ConvertTo-CommandLine {
    param(
        [string[]] $Arguments = @()
    )

    ($Arguments | ForEach-Object {
        if ($_ -match '^[A-Za-z0-9_./:=+\-]+$') {
            $_
        } else {
            '"' + ($_ -replace '\\(?=")', '\\' -replace '"', '\"') + '"'
        }
    }) -join " "
}

function Invoke-ExternalVersion {
    param(
        [Parameter(Mandatory)]
        [string] $Source,

        [string[]] $Arguments = @(),
        [int] $TimeoutMilliseconds = 3000
    )

    if ($Arguments.Count -eq 0) {
        return ""
    }

    $fileName = $Source
    $processArguments = ConvertTo-CommandLine -Arguments $Arguments

    if ($Source -like "*.ps1") {
        $fileName = if (Get-Command "pwsh" -CommandType Application -ErrorAction SilentlyContinue) { "pwsh" } else { "powershell" }
        $processArguments = ConvertTo-CommandLine -Arguments (@("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $Source) + $Arguments)
    } elseif ($Source -like "*.cmd" -or $Source -like "*.bat") {
        $fileName = "cmd"
        $processArguments = ConvertTo-CommandLine -Arguments (@("/c", $Source) + $Arguments)
    }

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $fileName
    $startInfo.Arguments = $processArguments
    $startInfo.UseShellExecute = $false
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.CreateNoWindow = $true

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo

    try {
        [void] $process.Start()
        if (-not $process.WaitForExit($TimeoutMilliseconds)) {
            $process.Kill()
            return ""
        }

        $output = $process.StandardOutput.ReadToEnd()
        if (-not $output) {
            $output = $process.StandardError.ReadToEnd()
        }

        return (($output -split "`r?`n") | Where-Object { $_.Trim() } | Select-Object -First 1).Trim()
    } catch {
        return ""
    } finally {
        if ($process) {
            $process.Dispose()
        }
    }
}

function Get-CommandVersion {
    param(
        [Parameter(Mandatory)]
        [string] $CommandName,

        [string[]] $VersionArgs = @("--version")
    )

    $command = Get-Command $CommandName -CommandType Application,ExternalScript,Cmdlet -ErrorAction SilentlyContinue |
        Select-Object -First 1

    if (-not $command) {
        return $null
    }

    $version = ""
    if ($command.CommandType -in @("Application", "ExternalScript")) {
        $version = Invoke-ExternalVersion -Source $command.Source -Arguments $VersionArgs
    } elseif ($command.Version) {
        $version = $command.Version.ToString()
    }

    [pscustomobject]@{
        Name = $CommandName
        Version = $version
        Source = if ($command.Source) { $command.Source } else { $command.Name }
    }
}

function Test-CommandTool {
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [string] $Category,

        [ValidateSet("Required", "Optional")]
        [string] $Level = "Optional",

        [string] $DisplayName = $Name,
        [string] $Note = "",
        [string] $InstallHint = "",
        [string[]] $VersionArgs = @("--version")
    )

    $command = Get-CommandVersion -CommandName $Name -VersionArgs $VersionArgs
    if ($command) {
        Add-CheckResult -Status "OK" -Category $Category -Name $DisplayName -Version $command.Version -Path $command.Source -Note $Note -InstallHint $InstallHint
        return
    }

    $status = if ($Level -eq "Required") { "MISS" } else { "WARN" }
    Add-CheckResult -Status $status -Category $Category -Name $DisplayName -Note $Note -InstallHint $InstallHint
}

function Test-PathItem {
    param(
        [Parameter(Mandatory)]
        [string] $Path,

        [Parameter(Mandatory)]
        [string] $Category,

        [Parameter(Mandatory)]
        [string] $Name,

        [ValidateSet("Required", "Optional")]
        [string] $Level = "Optional",

        [string] $Note = ""
    )

    if (Test-Path -LiteralPath $Path) {
        Add-CheckResult -Status "OK" -Category $Category -Name $Name -Path $Path -Note $Note
        return
    }

    $status = if ($Level -eq "Required") { "MISS" } else { "WARN" }
    Add-CheckResult -Status $status -Category $Category -Name $Name -Path $Path -Note $Note
}

function Test-FontName {
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [ValidateSet("Required", "Optional")]
        [string] $Level = "Optional"
    )

    $registeredFonts = @()
    $fontRegistryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts",
        "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
    )

    foreach ($registryPath in $fontRegistryPaths) {
        if (Test-Path -LiteralPath $registryPath) {
            $registeredFonts += (Get-ItemProperty -LiteralPath $registryPath).PSObject.Properties |
                Where-Object { $_.Name -like "*$Name*" }
        }
    }

    if ($registeredFonts.Count -gt 0) {
        Add-CheckResult -Status "OK" -Category "字体" -Name $Name -Path ($registeredFonts[0].Value)
        return
    }

    $fontRoots = @(
        "$env:WINDIR\Fonts",
        "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }

    $font = $fontRoots |
        ForEach-Object { Get-ChildItem -LiteralPath $_ -File -ErrorAction SilentlyContinue } |
        Where-Object { $_.BaseName -like "*$Name*" } |
        Select-Object -First 1

    if ($font) {
        Add-CheckResult -Status "OK" -Category "字体" -Name $Name -Path $font.FullName
        return
    }

    $status = if ($Level -eq "Required") { "MISS" } else { "WARN" }
    Add-CheckResult -Status $status -Category "字体" -Name $Name -Note "配置中用于终端文字或 Nerd Font 图标显示。"
}

function Invoke-WezTermConfigCheck {
    if ($SkipWezTermConfigCheck) {
        Add-CheckResult -Status "WARN" -Category "WezTerm" -Name "配置加载检查" -Note "已通过 -SkipWezTermConfigCheck 跳过。"
        return
    }

    $wezterm = Get-Command "wezterm" -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $wezterm) {
        Add-CheckResult -Status "MISS" -Category "WezTerm" -Name "配置加载检查" -Note "未找到 wezterm，无法执行配置加载检查。"
        return
    }

    $configFile = Join-Path $RepoRoot "wezterm.lua"
    try {
        $output = & $wezterm.Source --config-file $configFile show-keys 2>&1 | Select-Object -First 3
        $exitCode = $LASTEXITCODE
        $note = (($output | Out-String).Trim())
        if ($exitCode -eq 0 -or $note -match "Default key table") {
            Add-CheckResult -Status "OK" -Category "WezTerm" -Name "配置加载检查" -Path $configFile -Note (($output | Out-String).Trim())
        } else {
            Add-CheckResult -Status "MISS" -Category "WezTerm" -Name "配置加载检查" -Path $configFile -Note (($output | Out-String).Trim())
        }
    } catch {
        Add-CheckResult -Status "MISS" -Category "WezTerm" -Name "配置加载检查" -Path $configFile -Note $_.Exception.Message
    }
}

function Write-TextReport {
    $groups = $Results | Group-Object Category | Sort-Object Name
    foreach ($group in $groups) {
        Write-Host ""
        Write-Host "[$($group.Name)]"
        foreach ($item in ($group.Group | Sort-Object Status, Name)) {
            $symbol = switch ($item.Status) {
                "OK" { "[OK]" }
                "WARN" { "[WARN]" }
                "MISS" { "[MISS]" }
            }

            $line = "{0} {1}" -f $symbol, $item.Name
            if ($item.Version) { $line += " | $($item.Version)" }
            if ($item.Path) { $line += " | $($item.Path)" }
            Write-Host $line

            if ($item.Note) {
                Write-Host "     说明：$($item.Note)"
            }
            if ($item.InstallHint) {
                Write-Host "     建议：$($item.InstallHint)"
            }
        }
    }

    $missCount = @($Results | Where-Object Status -eq "MISS").Count
    $warnCount = @($Results | Where-Object Status -eq "WARN").Count
    Write-Host ""
    Write-Host "汇总：缺失 $missCount 项，提醒 $warnCount 项。"
}

$psVersion = $PSVersionTable.PSVersion.ToString()
Add-CheckResult -Status "OK" -Category "系统" -Name "PowerShell 当前版本" -Version $psVersion -Path $PSHOME
Add-CheckResult -Status "OK" -Category "系统" -Name "操作系统" -Version ([System.Environment]::OSVersion.VersionString)
Add-CheckResult -Status "OK" -Category "系统" -Name "当前仓库" -Path $RepoRoot

Test-CommandTool -Name "wezterm" -Category "WezTerm" -Level Required -DisplayName "WezTerm CLI" -InstallHint "winget install wez.wezterm"
Invoke-WezTermConfigCheck
Test-PathItem -Path (Join-Path $RepoRoot "wezterm.lua") -Category "WezTerm" -Name "入口配置 wezterm.lua" -Level Required
Test-PathItem -Path (Join-Path $RepoRoot "scripts\pwsh-wezterm.ps1") -Category "WezTerm" -Name "PowerShell 启动脚本" -Level Required
Test-PathItem -Path (Join-Path $RepoRoot "scripts\cli-tools.ps1") -Category "WezTerm" -Name "CLI 别名脚本" -Level Required
Test-PathItem -Path (Join-Path $RepoRoot "scripts\git-worktree-tools.ps1") -Category "WezTerm" -Name "Git worktree 辅助脚本" -Level Required
Test-PathItem -Path (Join-Path $RepoRoot "backdrops\space.png") -Category "WezTerm" -Name "背景图片 space.png" -Level Optional -Note "配置当前使用纯色背景，该图片未启用，保留备用。"

Test-CommandTool -Name "pwsh" -Category "Shell/启动项" -Level Required -DisplayName "PowerShell 7" -InstallHint "winget install Microsoft.PowerShell" -VersionArgs @("-NoLogo", "-NoProfile", "-Command", '$PSVersionTable.PSVersion.ToString()')
Test-CommandTool -Name "powershell" -Category "Shell/启动项" -Level Required -DisplayName "Windows PowerShell" -VersionArgs @("-NoLogo", "-NoProfile", "-Command", '$PSVersionTable.PSVersion.ToString()')
Test-CommandTool -Name "cmd" -Category "Shell/启动项" -Level Required -DisplayName "命令提示符" -VersionArgs @("/c", "ver")
Test-CommandTool -Name "git" -Category "Shell/启动项" -Level Required -DisplayName "Git CLI" -InstallHint "winget install Git.Git"
Test-CommandTool -Name "nu" -Category "Shell/启动项" -Level Optional -DisplayName "Nushell" -InstallHint "winget install Nushell.Nushell"
Test-PathItem -Path "D:\software\Git\bin\bash.exe" -Category "Shell/启动项" -Name "Git Bash 固定路径" -Level Optional -Note "launch.lua 当前写死了这个路径；迁移到新机器时要么保持路径一致，要么改 launch.lua。"

Test-CommandTool -Name "yazi" -Category "Yazi" -Level Required -DisplayName "Yazi 文件管理器" -InstallHint "winget install sxyazi.yazi"
Test-CommandTool -Name "ya" -Category "Yazi" -Level Optional -DisplayName "Yazi 插件管理器 ya" -InstallHint "通常随 Yazi 一起安装。"
Test-CommandTool -Name "file" -Category "Yazi 配套工具" -Level Optional -DisplayName "file" -Note "用于文件类型识别。"
Test-CommandTool -Name "rg" -Category "Yazi 配套工具" -Level Optional -DisplayName "ripgrep" -InstallHint "winget install BurntSushi.ripgrep.MSVC"
Test-CommandTool -Name "fd" -Category "Yazi 配套工具" -Level Optional -DisplayName "fd" -InstallHint "winget install sharkdp.fd"
Test-CommandTool -Name "fzf" -Category "Yazi 配套工具" -Level Optional -DisplayName "fzf" -InstallHint "winget install junegunn.fzf"
Test-CommandTool -Name "zoxide" -Category "Yazi 配套工具" -Level Optional -DisplayName "zoxide" -InstallHint "winget install ajeetdsouza.zoxide"
Test-CommandTool -Name "bat" -Category "Yazi 配套工具" -Level Optional -DisplayName "bat" -InstallHint "winget install sharkdp.bat"
Test-CommandTool -Name "jq" -Category "Yazi 配套工具" -Level Optional -DisplayName "jq" -InstallHint "winget install jqlang.jq"
Test-CommandTool -Name "ffmpeg" -Category "Yazi 配套工具" -Level Optional -DisplayName "FFmpeg" -InstallHint "winget install Gyan.FFmpeg"
Test-CommandTool -Name "7z" -Category "Yazi 配套工具" -Level Optional -DisplayName "7-Zip CLI" -InstallHint "winget install 7zip.7zip" -VersionArgs @()
Test-CommandTool -Name "magick" -Category "Yazi 配套工具" -Level Optional -DisplayName "ImageMagick" -InstallHint "winget install ImageMagick.ImageMagick"
Test-CommandTool -Name "pdftoppm" -Category "Yazi 配套工具" -Level Optional -DisplayName "Poppler pdftoppm" -Note "用于 PDF 预览；Windows 上常通过 Scoop/Chocolatey 安装 poppler。" -VersionArgs @()

Test-CommandTool -Name "codex" -Category "AI CLI/启动项" -Level Optional -DisplayName "Codex CLI" -InstallHint "pnpm add -g @openai/codex@latest"
Test-CommandTool -Name "claude" -Category "AI CLI/启动项" -Level Optional -DisplayName "Claude CLI"
Test-CommandTool -Name "pnpm" -Category "AI CLI/启动项" -Level Optional -DisplayName "pnpm" -InstallHint "corepack enable 或 winget install pnpm.pnpm"

Test-CommandTool -Name "stylua" -Category "开发工具" -Level Optional -DisplayName "StyLua 格式化" -Note "AGENTS.md 约定改动 Lua 后执行 stylua ." -InstallHint "winget install JohnnyMorganz.StyLua"
Test-CommandTool -Name "selene" -Category "开发工具" -Level Optional -DisplayName "Selene 静态检查" -Note "AGENTS.md 约定改动 Lua 后执行 selene ." -InstallHint "cargo install selene，或从 GitHub Releases 下载"

Test-FontName -Name "JetBrainsMono" -Level Required
Test-FontName -Name "MesloLGM" -Level Required
Test-FontName -Name "Microsoft YaHei" -Level Required
Test-FontName -Name "Segoe UI Emoji" -Level Required

if ($Json) {
    $Results | ConvertTo-Json -Depth 4
} else {
    Write-TextReport
}
