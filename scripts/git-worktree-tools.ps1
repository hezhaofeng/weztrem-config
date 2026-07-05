function global:Resolve-GitWorktreeMainRepo {
    param(
        [string] $MainRepo = ""
    )

    $git = Get-Command "git" -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $git) {
        throw "未找到 git 命令，请确认 Git 已安装并在 PATH 中。"
    }

    if ($MainRepo) {
        if (-not (Test-Path -LiteralPath $MainRepo)) {
            throw "指定的主仓库目录不存在：$MainRepo"
        }

        $startPath = (Resolve-Path -LiteralPath $MainRepo).Path
    } else {
        $startPath = (Get-Location).Path
    }

    # 用 --git-common-dir 而不是 --show-toplevel：后者在关联 worktree 中返回的是
    # 该 worktree 的根目录；主仓库根目录应取共享 .git 目录的父目录。
    $commonDir = & $git.Source -C $startPath rev-parse --git-common-dir 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $commonDir) {
        if ($MainRepo) {
            throw "指定目录不是 Git 仓库：$startPath"
        }

        throw "当前路径不在 Git 仓库内。请先 cd 到主仓库目录，或显式传入 -MainRepo。"
    }

    $commonDir = ($commonDir | Select-Object -First 1).Trim()
    if (-not [System.IO.Path]::IsPathRooted($commonDir)) {
        $commonDir = Join-Path $startPath $commonDir
    }

    Split-Path -Parent (Resolve-Path -LiteralPath $commonDir).Path
}

function global:Invoke-GitWorktreeCommand {
    param(
        [Parameter(Mandatory)]
        [string] $MainRepo,

        [Parameter(Mandatory)]
        [string[]] $GitArgs
    )

    $git = Get-Command "git" -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $git) {
        throw "未找到 git 命令，请确认 Git 已安装并在 PATH 中。"
    }

    & $git.Source -C $MainRepo @GitArgs
    if ($LASTEXITCODE -ne 0) {
        throw "git 命令执行失败：git -C `"$MainRepo`" $($GitArgs -join ' ')"
    }
}

function global:ConvertTo-GitWorktreeDirectoryName {
    param(
        [Parameter(Mandatory)]
        [string] $Branch
    )

    $name = $Branch -replace "[\\/]+", "-"
    $invalidPattern = "[{0}]" -f [regex]::Escape((-join [System.IO.Path]::GetInvalidFileNameChars()))
    $name = ($name -replace $invalidPattern, "-").Trim(" ._-")

    if ($name) {
        return $name
    }

    "task"
}

function global:Get-DefaultGitWorktreePath {
    param(
        [Parameter(Mandatory)]
        [string] $MainRepo,

        [Parameter(Mandatory)]
        [string] $Branch
    )

    $mainItem = Get-Item -LiteralPath $MainRepo
    $projectName = $mainItem.Name
    $worktreeName = ConvertTo-GitWorktreeDirectoryName -Branch $Branch

    Join-Path $mainItem.Parent.FullName "$projectName-$worktreeName"
}

function global:Show-GitWorktrees {
    param(
        [string] $MainRepo = ""
    )

    $repo = Resolve-GitWorktreeMainRepo -MainRepo $MainRepo
    Write-Host "主仓库：$repo"
    Invoke-GitWorktreeCommand -MainRepo $repo -GitArgs @("worktree", "list")
}

function global:New-GitWorktree {
    param(
        [string] $Branch = "",
        [string] $WorktreePath = "",
        [string] $MainRepo = "",
        [string] $From = "",
        [switch] $ExistingBranch,
        [switch] $Remote
    )

    if ($ExistingBranch -and $Remote) {
        throw "-ExistingBranch 和 -Remote 不能同时使用：本地已有分支用 -ExistingBranch，仅远程存在用 -Remote。"
    }

    if ($From -and ($ExistingBranch -or $Remote)) {
        throw "-From 只能用于默认的新建分支模式，不能和 -ExistingBranch 或 -Remote 一起使用。"
    }

    try {
        $repo = Resolve-GitWorktreeMainRepo -MainRepo $MainRepo
    } catch {
        $gitMissing = -not (Get-Command "git" -CommandType Application -ErrorAction SilentlyContinue)
        if ($MainRepo -or $gitMissing) {
            throw
        }

        # 从启动器菜单打开时，新面板的初始目录通常不在仓库内，改为交互式补问。
        $inputRepo = Read-Host "当前路径不在 Git 仓库内，请输入主仓库目录"
        if (-not $inputRepo) {
            throw "主仓库目录不能为空。"
        }

        $repo = Resolve-GitWorktreeMainRepo -MainRepo $inputRepo
    }

    $branchWasProvided = [bool] $Branch

    if (-not $Branch) {
        $Branch = Read-Host "请输入分支名，例如 feature/demo"
    }

    if (-not $Branch) {
        throw "分支名不能为空。"
    }

    if (-not $WorktreePath) {
        $defaultPath = Get-DefaultGitWorktreePath -MainRepo $repo -Branch $Branch
        if ($branchWasProvided) {
            $WorktreePath = $defaultPath
        } else {
            $inputPath = Read-Host "请输入 worktree 目录，直接回车使用 $defaultPath"
            $WorktreePath = if ($inputPath) { $inputPath } else { $defaultPath }
        }
    }

    if (-not [System.IO.Path]::IsPathRooted($WorktreePath)) {
        $WorktreePath = Join-Path (Split-Path -Parent $repo) $WorktreePath
    }

    if (Test-Path -LiteralPath $WorktreePath) {
        throw "目标目录已存在：$WorktreePath"
    }

    Write-Host "主仓库：$repo"
    Write-Host "新分支：$Branch"
    if ($From) {
        Write-Host "分支基点：$From"
    }
    Write-Host "新目录：$WorktreePath"

    if ($Remote) {
        Invoke-GitWorktreeCommand -MainRepo $repo -GitArgs @("fetch", "origin", $Branch)
        Invoke-GitWorktreeCommand -MainRepo $repo -GitArgs @(
            "worktree",
            "add",
            $WorktreePath,
            "-b",
            $Branch,
            "origin/$Branch"
        )
    } elseif ($ExistingBranch) {
        Invoke-GitWorktreeCommand -MainRepo $repo -GitArgs @("worktree", "add", $WorktreePath, $Branch)
    } else {
        $addArgs = @("worktree", "add", $WorktreePath, "-b", $Branch)
        if ($From) {
            $addArgs += $From
        }

        Invoke-GitWorktreeCommand -MainRepo $repo -GitArgs $addArgs
    }

    Invoke-GitWorktreeCommand -MainRepo $WorktreePath -GitArgs @("branch", "--show-current")
    Set-Location -LiteralPath $WorktreePath
}

function global:Remove-GitWorktree {
    param(
        [string] $WorktreePath = "",
        [string] $MainRepo = "",
        [switch] $Force
    )

    $repo = Resolve-GitWorktreeMainRepo -MainRepo $MainRepo
    Show-GitWorktrees -MainRepo $repo

    if (-not $WorktreePath) {
        $WorktreePath = Read-Host "请输入要删除的 worktree 目录"
    }

    if (-not $WorktreePath) {
        throw "worktree 目录不能为空。"
    }

    if (-not [System.IO.Path]::IsPathRooted($WorktreePath)) {
        $WorktreePath = Join-Path (Split-Path -Parent $repo) $WorktreePath
    }

    $confirmation = Read-Host "确认删除 $WorktreePath ? 输入 y 继续"
    if ($confirmation -ne "y") {
        Write-Host "已取消删除。"
        return
    }

    $gitArgs = @("worktree", "remove")
    if ($Force) {
        $gitArgs += "--force"
    }
    $gitArgs += $WorktreePath

    Invoke-GitWorktreeCommand -MainRepo $repo -GitArgs $gitArgs
}

function global:Invoke-GitWorktreePrune {
    param(
        [string] $MainRepo = ""
    )

    $repo = Resolve-GitWorktreeMainRepo -MainRepo $MainRepo
    Invoke-GitWorktreeCommand -MainRepo $repo -GitArgs @("worktree", "prune")
    Show-GitWorktrees -MainRepo $repo
}

Set-Alias -Name gwl -Value Show-GitWorktrees -Scope Global -Force
Set-Alias -Name gwn -Value New-GitWorktree -Scope Global -Force
Set-Alias -Name gwr -Value Remove-GitWorktree -Scope Global -Force
Set-Alias -Name gwp -Value Invoke-GitWorktreePrune -Scope Global -Force
