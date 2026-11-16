# Imports a Roboflow COCO JSON export on Windows without unpacking arbitrary ZIP paths.
[CmdletBinding()]
param([Parameter(Mandatory)][string]$ZipPath)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.IO.Compression.FileSystem
$root = Join-Path (Split-Path -Parent $PSScriptRoot) '.recognition-dataset'
$output = Join-Path $root 'roboflow'
$archive = [IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $ZipPath).Path)
$lists = @($archive.Entries | Where-Object { $_.Name -eq '_annotations.coco.json' })
$publisher = 'https://universe.roboflow.com/parkingbot-dataset/malaysian-food-image-recognition'
$rows = [Collections.Generic.List[object]]::new()
$seenCrops = [Collections.Generic.HashSet[string]]::new()
$seenPhotos = [Collections.Generic.HashSet[string]]::new()
$sha256 = [Security.Cryptography.SHA256]::Create()
$splitCounts = @{}
$skipped = 0

try {
    if (!$lists.Count) { throw 'The ZIP contains no _annotations.coco.json files. Export it as COCO JSON.' }
    New-Item -ItemType Directory -Force $output | Out-Null
    foreach ($list in $lists) {
        $prefix = $list.FullName.Substring(0, $list.FullName.Length - $list.Name.Length)
        $split = ($prefix.TrimEnd('/') -split '/')[-1]
        if ($split -notin 'train', 'valid', 'val', 'test') { throw "Unexpected COCO split: $prefix" }
        if ($splitCounts.ContainsKey($split)) { throw "Multiple annotation files for split $split" }
        if ($list.Length -gt 120MB) { throw "Annotations too large in $split" }
        $reader = [IO.StreamReader]::new($list.Open())
        try { $coco = $reader.ReadToEnd() | ConvertFrom-Json }
        finally { $reader.Dispose() }
        if (!$coco.categories -or !$coco.images -or !$coco.annotations) { throw "Incomplete COCO file in $split" }
        $classes = @{}
        foreach ($class in $coco.categories) {
            $id = $class.name.Trim().ToLowerInvariant() -replace '[^a-z0-9]+', '_'
            if ($id -eq 'satay_ayam') { $id = 'satay' }
            if ($id -notmatch '^[a-z0-9][a-z0-9_]*$') { throw "Invalid category name: $($class.name)" }
            $classes[[string]$class.id] = @{ id = $id; label = $class.name }
        }
        $annotations = $coco.annotations | Group-Object -Property image_id -AsHashTable -AsString
        $splitCounts[$split] = 0
        foreach ($photo in $coco.images) {
            if ($photo.file_name -match '[/\\]' -or $photo.id -notmatch '^\d+$') {
                throw "Unexpected image entry: $($photo.file_name)"
            }
            $entry = $archive.GetEntry("$prefix$($photo.file_name)")
            if (!$entry -or $entry.Length -gt 16MB) { throw "Missing or oversized image: $prefix$($photo.file_name)" }
            $buffer = [IO.MemoryStream]::new()
            try {
                $stream = $entry.Open()
                try { $stream.CopyTo($buffer) }
                finally { $stream.Dispose() }
                $hash = [BitConverter]::ToString($sha256.ComputeHash($buffer.ToArray())).Replace('-', '').ToLowerInvariant()
                $buffer.Position = 0
                $image = [Drawing.Image]::FromStream($buffer, $true, $true)
                try {
                    if ($image.Width -ne $photo.width -or $image.Height -ne $photo.height) {
                        throw "JPEG dimensions differ from labels: $prefix$($photo.file_name)"
                    }
                    $splitCounts[$split]++
                    if (!$seenPhotos.Add($hash)) { continue }
                    foreach ($annotation in $annotations[[string]$photo.id]) {
                        $class = $classes[[string]$annotation.category_id]
                        if (!$class -or $annotation.id -notmatch '^\d+$' -or $annotation.bbox.Count -ne 4) {
                            throw "Invalid annotation $($annotation.id) in $split"
                        }
                        if ($class.id -eq 'reference_card') { continue }
                        $x, $y, $width, $height = $annotation.bbox
                        $left = [Math]::Max(0, [int][Math]::Floor($x))
                        $top = [Math]::Max(0, [int][Math]::Floor($y))
                        $right = [Math]::Min($image.Width, [int][Math]::Ceiling($x + $width))
                        $bottom = [Math]::Min($image.Height, [int][Math]::Ceiling($y + $height))
                        if ($right - $left -lt 96 -or $bottom - $top -lt 96) { $skipped++; continue }
                        $rect = [Drawing.Rectangle]::new($left, $top, $right - $left, $bottom - $top)
                        $crop = [Drawing.Bitmap]::new($rect.Width, $rect.Height)
                        try {
                            $graphics = [Drawing.Graphics]::FromImage($crop)
                            try {
                                $graphics.DrawImage($image, [Drawing.Rectangle]::new(0, 0, $rect.Width, $rect.Height),
                                    $rect, [Drawing.GraphicsUnit]::Pixel)
                            } finally { $graphics.Dispose() }
                            $folder = Join-Path $output $class.id
                            New-Item -ItemType Directory -Force $folder | Out-Null
                            $name = "$split-$($photo.id)-$($annotation.id).jpg"
                            $destination = Join-Path $folder $name
                            $crop.Save($destination, [Drawing.Imaging.ImageFormat]::Jpeg)
                        } finally { $crop.Dispose() }
                        $cropHash = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()
                        if (!$seenCrops.Add($cropHash)) { continue }
                        $sourceGroup = $photo.file_name -replace '\.rf\.[a-f0-9]+\.(jpe?g|png)$', ''
                        $rows.Add([pscustomobject][ordered]@{
                            file = "roboflow/$($class.id)/$name"; subject_id = $class.id; kind = 'food'; label = $class.label
                            source = $publisher; creator = 'ParkingBot Dataset (publisher)'; license = 'CC BY 4.0'
                            license_url = 'https://creativecommons.org/licenses/by/4.0/'; review_status = 'needs_subject_review'
                            publisher_split = $split; publisher_image = $entry.FullName; publisher_source_group = $sourceGroup
                            original_sha256 = $hash
                            width = $rect.Width; height = $rect.Height; sha256 = $cropHash
                        })
                    }
                    [void]$annotations.Remove([string]$photo.id)
                } finally { $image.Dispose() }
            } finally { $buffer.Dispose() }
        }
        if ($annotations.Count) {
            # Identical input files across splits are decoded but only contribute crops once.
            $ids = [Collections.Generic.HashSet[string]]::new([string[]]@($coco.images | ForEach-Object { [string]$_.id }))
            foreach ($imageId in $annotations.Keys) {
                if (!$ids.Contains($imageId)) { throw "Annotation references a missing image $imageId in $split" }
            }
        }
        Write-Host "$split verified $($splitCounts[$split]) images"
    }
} finally {
    $sha256.Dispose()
    $archive.Dispose()
}

if (!$rows.Count) { throw 'No usable dish crops in the ZIP' }
$rows | Export-Csv -LiteralPath (Join-Path $root 'roboflow.csv') -NoTypeInformation -Encoding UTF8
Write-Host "Exported $($rows.Count) unique food crops; skipped $skipped tiny or empty crops."
