# format.ps1
$excludeExternalAddons = if ($env:EXCLUDE_EXTERNAL_ADDONS) { [int]$env:EXCLUDE_EXTERNAL_ADDONS } else { 1 }

# 引数が空でないか確認
if ($args.Count -eq 0)
{
    Write-Host "Usage: .\format.ps1 <path_to_gd_file_or_dir>" -ForegroundColor Yellow
    exit
}

# 渡された各引数について処理
foreach ($path in $args)
{
    if (Test-Path $path)
    {
        Write-Host "Searching in: $path"
        # 指定されたのがディレクトリなら中身を、ファイルならそれ自身を取得
        $files = Get-ChildItem -Path $path -Recurse -Filter *.gd
        if ($excludeExternalAddons -eq 1)
        {
            $files = $files | Where-Object {
                $normalized = $_.FullName.Replace('\', '/')
                -not $normalized.Contains("/addons/gdUnit4/") -and -not $normalized.Contains("/addons/GDQuest_GDScript_formatter/")
            }
        }

        $files | ForEach-Object {
            Write-Host "Formatting: $($_.Name)"
            # フォーマッタ実行
            & "scripts/gdscript-formatter.exe" --reorder-code $_.FullName
        }
    } else
    {
        Write-Warning "Path not found: $path"
    }
}
