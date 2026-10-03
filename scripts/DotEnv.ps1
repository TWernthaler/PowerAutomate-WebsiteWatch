function Get-DotEnvConfig {
    param(
        [string]$Path
    )

    if (-not $Path)
    {
        # Default: repository root .env (DotEnv.ps1 lives in /scripts).
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

        if ($value -match '^"(.*)"$')
        {
            $value = $Matches[1]
        }
        elseif ($value -match "^'(.*)'$")
        {
            $value = $Matches[1]
        }
        else
        {
            $value = ($value -replace '\s+#.*$', '').Trim()
        }

        $config[$key] = $value
    }

    return $config
}
