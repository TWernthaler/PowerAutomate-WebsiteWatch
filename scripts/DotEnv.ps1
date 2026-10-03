function Get-DotEnvConfig {
    param(
        [string]$Path
    )

    $config = @{}
    if (-not (Test-Path -Path $Path))
    {
        return $config
    }

    foreach ($line in Get-Content -Path $Path)
    {
        $trimmed = $line.Trim()
        if (-not $trimmed -or $trimmed.StartsWith("#"))
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

        if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'")))
        {
            $value = $value.Substring(1, $value.Length - 2)
        }

        $config[$key] = $value
    }

    return $config
}
