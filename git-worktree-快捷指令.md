# Git Worktree 快捷指令说明

这份文档说明 WezTerm 中新增的 Git worktree 快捷指令如何使用，以及这些指令背后的执行流程。当前设计只负责创建、查看、删除和清理 worktree；创建完成后会自动进入新目录，但不会自动启动 Codex CLI。进入新目录后，如果需要 Codex，再手动输入 `cxy`。

## 适用场景

Git worktree 适合把不同任务拆到不同工作目录中处理：

```text
一个任务 = 一个 worktree + 一个独立分支
```

典型目录结构：

```text
D:\work\spider-data-go-copy              主仓库
D:\work\spider-data-go-copy-feature-demo feature/demo 对应的 worktree
D:\work\spider-data-go-copy-fix-issue-1  fix/issue-1 对应的 worktree
```

这样主仓库不用频繁切分支，不同任务的未提交修改也不会互相干扰。

## 指令总览

这些指令由 `scripts\pwsh-wezterm.ps1` 加载 PowerShell 环境后生效。启动 WezTerm 默认 PowerShell 后，可以直接输入：

| 指令 | 作用 |
| --- | --- |
| `gwn` | 创建 Git worktree 并进入新目录 |
| `gwl` | 查看当前仓库关联的 worktree |
| `gwr` | 删除指定 worktree |
| `gwp` | 执行 `git worktree prune` 并重新列出 worktree |

`gwn` 表示 Git worktree new，只负责创建 worktree 并进入目录，不启动 Codex。推荐流程是：

```powershell
cd D:\work\spider-data-go-copy
gwn -Branch feature/demo
cxy
```

## 创建新 worktree

最常用方式：

```powershell
cd D:\work\spider-data-go-copy
gwn -Branch feature/demo
```

执行结果：

1. 解析主仓库根目录（在主仓库或任意关联 worktree 中执行均可）。
2. 自动计算 worktree 目录。
3. 执行 `git worktree add <目录> -b feature/demo`。
4. 输出当前分支。
5. 进入新 worktree 目录。

如果当前仓库目录名是 `spider-data-go-copy`，分支名是 `feature/demo`，默认目录会是：

```text
D:\work\spider-data-go-copy-feature-demo
```

分支名中的 `/` 会转换为 `-`，Windows 文件名非法字符也会被替换为 `-`。

## 交互式创建

不传分支名时，会提示输入分支名和 worktree 目录：

```powershell
gwn
```

适合临时创建任务目录，或者想手动指定目录名时使用。

如果当前路径不在任何 Git 仓库内（例如从启动器菜单直接打开 `gwn`），会先提示输入主仓库目录，再继续询问分支名。

如果传了 `-Branch` 但没传 `-WorktreePath`，脚本会直接使用默认目录，不再询问目录。这是为了让常用命令可以一行完成：

```powershell
gwn -Branch experiment/cache-test
```

## 指定 worktree 目录

可以显式指定目录：

```powershell
gwn -Branch feature/demo -WorktreePath D:\work\spider-feature-demo
```

也可以传相对路径。相对路径会按主仓库父目录解析：

```powershell
gwn -Branch feature/demo -WorktreePath spider-feature-demo
```

如果主仓库是 `D:\work\spider-data-go-copy`，上面的相对路径会解析为：

```text
D:\work\spider-feature-demo
```

## 指定分支基点

默认的新建分支模式基于主仓库当前 HEAD 创建分支。如果主仓库停在别的分支上，新分支就会从那里分叉；想明确从主干创建时，用 `-From` 指定基点：

```powershell
gwn -Branch feature/demo -From origin/main
```

等价于：

```powershell
git worktree add <目录> -b feature/demo origin/main
```

`-From` 只用于默认的新建分支模式，和 `-ExistingBranch` 或 `-Remote` 同时使用会报错。

## 基于已有本地分支创建

如果分支已经存在，不要再用默认的新建分支模式，否则 Git 会报分支已存在。此时使用 `-ExistingBranch`：

```powershell
gwn -Branch feature/demo -ExistingBranch
```

等价于：

```powershell
git worktree add <目录> feature/demo
```

注意：同一个分支不能同时被多个 worktree 检出。

## 基于远程分支创建

如果远程已有分支，本地还没有，可以使用 `-Remote`：

```powershell
gwn -Branch bugfix/login -Remote
```

脚本会先执行：

```powershell
git fetch origin bugfix/login
```

只拉取目标分支，避免大仓库全量 fetch。然后执行：

```powershell
git worktree add <目录> -b bugfix/login origin/bugfix/login
```

这个流程会基于 `origin/bugfix/login` 创建本地分支 `bugfix/login`，并把它检出到新 worktree 目录。

`-Remote` 和 `-ExistingBranch` 不能同时使用：本地已有分支用 `-ExistingBranch`，仅远程存在用 `-Remote`。

## 查看 worktree

在任意一个关联 worktree 或主仓库目录中执行：

```powershell
gwl
```

脚本会显示解析到的主仓库目录，然后执行：

```powershell
git worktree list
```

可以用它确认当前仓库有哪些 worktree、各自路径和绑定分支。

## 删除 worktree

删除前建议先进入目标 worktree 查看状态：

```powershell
git status
```

确认没有需要保留的修改后，在主仓库或任意关联 worktree 中执行：

```powershell
gwr -WorktreePath D:\work\spider-data-go-copy-feature-demo
```

脚本会先列出现有 worktree，然后要求输入 `y` 确认删除。确认后执行：

```powershell
git worktree remove <目录>
```

如果目录中还有未提交修改，Git 默认会拒绝删除。只有确认这些修改可以丢弃时，才使用：

```powershell
gwr -WorktreePath D:\work\spider-data-go-copy-feature-demo -Force
```

这会执行：

```powershell
git worktree remove --force <目录>
```

注意：删除 worktree 不会删除对应的本地分支，分支清理见"推荐日常流程"。

## 清理失效记录

如果曾经手动删除过 worktree 目录，Git 可能仍保留失效记录。执行：

```powershell
gwp
```

脚本会执行：

```powershell
git worktree prune
git worktree list
```

先清理失效记录，再显示当前 worktree 列表。

## 主仓库解析规则

默认不绑定固定项目目录。脚本按下面规则确定主仓库：

1. 如果传入 `-MainRepo`，优先使用它。
2. 如果没有传 `-MainRepo`，从当前路径解析。解析取的是共享 `.git` 目录（`git rev-parse --git-common-dir`）的父目录，所以无论当前在主仓库还是任意关联 worktree 中，得到的都是主仓库根目录。
3. 如果当前路径不在 Git 仓库内：`gwn` 会交互式询问主仓库目录（方便从启动器菜单直接打开），`gwl`/`gwr`/`gwp` 直接报错。

因此日常使用前，先进入目标仓库即可：

```powershell
cd D:\work\spider-data-go-copy
gwn -Branch feature/demo
```

特殊情况下，也可以显式指定仓库：

```powershell
gwn -MainRepo D:\work\spider-data-go-copy -Branch feature/demo
```

## 脚本加载流程

WezTerm 启动 PowerShell 时，加载链路是：

```text
wezterm.lua
  -> config\launch.lua
    -> scripts\pwsh-wezterm.ps1
      -> scripts\cli-tools.ps1
        -> scripts\git-worktree-tools.ps1
```

`git-worktree-tools.ps1` 最后注册全局别名：

```powershell
gwn -> New-GitWorktree
gwl -> Show-GitWorktrees
gwr -> Remove-GitWorktree
gwp -> Invoke-GitWorktreePrune
```

所以这些指令只在加载了 WezTerm 专用 PowerShell 启动脚本的终端中自动可用。

## 创建流程原理

`gwn -Branch feature/demo` 内部流程可以理解为：

```text
检查 git 是否可用
  -> 解析主仓库根目录（不在仓库内时交互式询问）
  -> 根据仓库名和分支名生成默认 worktree 目录
  -> 确认目标目录不存在
  -> 执行 git worktree add
  -> 检查当前分支
  -> cd 到新 worktree 目录
```

默认新分支模式对应（`-From` 可选，不传时基于主仓库当前 HEAD）：

```powershell
git worktree add <目录> -b <分支名> [<基点>]
```

已有本地分支模式对应：

```powershell
git worktree add <目录> <分支名>
```

远程分支模式对应：

```powershell
git fetch origin <分支名>
git worktree add <目录> -b <分支名> origin/<分支名>
```

## 推荐日常流程

新任务开发：

```powershell
cd D:\work\spider-data-go-copy
gwl
gwn -Branch feature/demo
cxy
```

修复远程已有分支：

```powershell
cd D:\work\spider-data-go-copy
gwn -Branch bugfix/login -Remote
cxy
```

任务结束后清理：

```powershell
git status
cd D:\work\spider-data-go-copy
gwr -WorktreePath D:\work\spider-data-go-copy-feature-demo
git branch -d feature/demo
gwp
```

`gwr` 只删除 worktree 目录，本地分支会保留。分支已合并、确认不再需要时用 `git branch -d` 删掉（未合并的分支要用 `-D` 强制删除）。如果保留分支，下次 `gwn -Branch` 建同名分支会报"分支已存在"，此时应改用 `-ExistingBranch`。

核心原则是：worktree 指令只负责工作目录和分支隔离，进入新目录后的开发工具由你手动选择，例如 `cxy`、编辑器或普通命令行。
