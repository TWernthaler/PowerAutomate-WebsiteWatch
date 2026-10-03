function Get-DotEnvConfig {
    param(
        [string]$Path
    )

    if (-not $Path)
    {
        $Path = Join-Path -Path $PSScriptRoot -ChildPath "..\.env"
    }

    $config = @{}
    if (-not (Test-Path -Path $Path))
    {
        return $config
    }

    foreach ($line in Get-Content -Path $Path)
    {
        $trimmed = $line.Trim()
        if ($trimmed -eq '' -or $trimmed.StartsWith("#"))
        {
            continue
        }

        $parts = $trimmed.Split("=", 2)
        if ($parts.Count -ne 2)
        {
            continue
        }

        $key = $parts[0].Trim()
        $value = $parts[1].Trim()
        $isQuoted = $value.Length -ge 2 -and (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'")))

        if ($isQuoted)
        {
            $value = $value.Substring(1, $value.Length - 2)
        }
        else
        {
            $value = ($value -replace '\s+#.*$', '').Trim()
        }

        $config[$key] = $value
    }

    return $config
}
