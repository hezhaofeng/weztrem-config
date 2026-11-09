function global:Get-RegisteredEnvironment {
    $registered = @{}
    $registeredPaths = @()
    foreach ($scope in @("Machine", "User")) {
        $variables = [Environment]::GetEnvironmentVariables($scope)
        foreach ($name in $variables.Keys) {
            if ($name -ieq "Path") {
                $registeredPaths += [string] $variables[$name]
            } else {
                $registered[$name] = [string] $variables[$name]
            }
        }
    }
    $registered["Path"] = $registeredPaths -join ";"
    return $registered
}

function global:Update-Environment {
    $registered = Get-RegisteredEnvironment
    $snapshotVariable = Get-Variable -Name WezTermEnvironmentSnapshot -Scope Global -ErrorAction SilentlyContinue
    $previous = if ($snapshotVariable) { $snapshotVariable.Value } else { @{} }

    # 只删除本会话曾同步过、且没有被程序临时覆盖的变量，保留来源未知的进程变量。
    foreach ($name in $previous.Keys) {
        if ($name -ine "Path" -and -not $registered.ContainsKey($name) -and
            [Environment]::GetEnvironmentVariable($name) -ceq $previous[$name]) {
            Remove-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue
        }
    }

    $knownPath = if ($previous.ContainsKey("Path")) { $previous["Path"] } else { $registered["Path"] }
    $knownEntries = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($entry in ($knownPath -split ";")) {
        if ($entry.Trim()) {
            [void] $knownEntries.Add($entry.Trim().TrimEnd("\"))
        }
    }

    # 临时路径放在注册路径之前，保留虚拟环境优先级；已移除的已知注册路径不再带回。
    $processEntries = @($env:Path -split ";" | Where-Object {
        $_.Trim() -and -not $knownEntries.Contains($_.Trim().TrimEnd("\"))
    })
    $pathEntries = [System.Collections.Generic.List[string]]::new()
    $seenEntries = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($entry in ($processEntries + @($registered["Path"] -split ";"))) {
        $entry = $entry.Trim()
        if ($entry -and $seenEntries.Add($entry.TrimEnd("\"))) {
            $pathEntries.Add($entry)
        }
    }

    foreach ($name in $registered.Keys) {
        if ($name -ine "Path") {
            [Environment]::SetEnvironmentVariable($name, $registered[$name], "Process")
        }
    }
    $env:Path = $pathEntries -join ";"
    $global:WezTermEnvironmentSnapshot = $registered
}

Set-Alias -Name refreshenv -Value Update-Environment -Scope Global -Force
