# Run with Windows PowerShell from the checked-out project.
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('food', 'landmark', 'cuisine', 'google-landmarks')]
    [string]$Source,
    [ValidateRange(1, 20)]
    [int]$PhotosPerSubject = 6,
    [string[]]$SubjectIds = @()
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Web
$root = Join-Path (Split-Path -Parent $PSScriptRoot) '.recognition-dataset'
$output = Join-Path $root $Source
$manifestName = if ($SubjectIds.Count) { "$Source-selected.csv" } else { "$Source.csv" }
New-Item -ItemType Directory -Force $output | Out-Null
$userAgent = 'CityloreDataset/1.0 (Malaysia-Travel-Apps student research; reference photo collection)'
$rows = [Collections.Generic.List[object]]::new()
$hashes = [Collections.Generic.HashSet[string]]::new()

function Get-Text([string]$Url) {
    $payload = & curl.exe --fail --location --silent --show-error --max-time 15 -A $userAgent $Url
    if ($LASTEXITCODE -ne 0) { throw "Could not fetch $Url" }
    return $payload -join "`n"
}

function Save-Photo([string]$Url, [string]$File, [string]$ExpectedHash = '') {
    if (Test-Path -LiteralPath $File) {
        $candidate = $File
    } else {
        $candidate = "$File.part"
        & curl.exe --fail --location --silent --show-error --max-time 15 --max-filesize 16000000 -A $userAgent -o $candidate $Url
        if ($LASTEXITCODE -ne 0) { throw "Could not download $Url" }
    }
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $candidate).Hash.ToLowerInvariant()
    if ($ExpectedHash -and $hash -ne $ExpectedHash) { throw "SHA-256 mismatch for $File" }
    $stream = [IO.File]::OpenRead($candidate)
    try {
        $image = [Drawing.Image]::FromStream($stream, $true, $true)
        try {
            if ($image.RawFormat.Guid -ne [Drawing.Imaging.ImageFormat]::Jpeg.Guid -or
                [Math]::Min($image.Width, $image.Height) -lt 224) {
                throw "Expected a JPEG with both sides at least 224 pixels: $File"
            }
            $width = $image.Width
            $height = $image.Height
        } finally { $image.Dispose() }
    } finally { $stream.Dispose() }
    if ($candidate -ne $File) { Move-Item -LiteralPath $candidate -Destination $File }
    return @{ sha256 = $hash; width = $width; height = $height }
}

function Add-Photo($Record, $Image) {
    if (!$hashes.Add($Image.sha256)) { return $false }
    $Record.width = $Image.width
    $Record.height = $Image.height
    $Record.sha256 = $Image.sha256
    $rows.Add([pscustomobject]$Record)
    return $true
}

function Get-LandmarkIndex($Subjects) {
    $metadataFolder = Join-Path $root 'metadata'
    $categoryFile = Join-Path $metadataFolder 'google-landmarks-categories.csv'
    $trainFile = Join-Path $metadataFolder 'google-landmarks-train-first-24mb.csv'
    New-Item -ItemType Directory -Force $metadataFolder | Out-Null
    if (!(Test-Path -LiteralPath $categoryFile)) {
        & curl.exe --fail --location --silent --show-error --max-time 190 'https://s3.amazonaws.com/google-landmark/metadata/train_label_to_category.csv' -o "$categoryFile.part"
        if ($LASTEXITCODE -ne 0) { throw 'Could not download Google Landmarks category metadata' }
        Move-Item -LiteralPath "$categoryFile.part" -Destination $categoryFile
    }
    if (!(Test-Path -LiteralPath $trainFile)) {
        & curl.exe --fail --location --silent --show-error --max-time 190 -r 0-23999999 'https://s3.amazonaws.com/google-landmark/metadata/train.csv' -o "$trainFile.part"
        if ($LASTEXITCODE -ne 0) { throw 'Could not download the Google Landmarks train metadata sample' }
        Move-Item -LiteralPath "$trainFile.part" -Destination $trainFile
    }
    $byCategory = @{}
    foreach ($subject in $Subjects) {
        foreach ($category in $subject.categories.Split('|')) {
            $byCategory[$category.Replace(' ', '_')] = $subject.subject_id
        }
    }
    $byId = @{}
    foreach ($mapping in (Import-Csv -LiteralPath $categoryFile)) {
        $category = [Uri]::UnescapeDataString(($mapping.category -split 'Category:', 2)[-1])
        if ($byCategory.ContainsKey($category)) { $byId[$mapping.landmark_id] = $byCategory[$category] }
    }
    $titles = @{}
    foreach ($line in [IO.File]::ReadLines($trainFile)) {
        # A byte-range response may end with an incomplete CSV line.
        if ($line -notmatch '^([a-f0-9]{16}),"?https?://upload\.wikimedia\.org/wikipedia/commons/.+?/([^/"]+\.jpe?g)"?,(\d+)$') {
            continue
        }
        $googleId = $Matches[1]
        $landmarkId = $Matches[3]
        if (!$byId.ContainsKey($landmarkId)) { continue }
        $title = 'File:' + [Uri]::UnescapeDataString($Matches[2]).Replace('_', ' ')
        $id = $byId[$landmarkId]
        if (!$titles.ContainsKey($id)) { $titles[$id] = [ordered]@{} }
        $titles[$id][$title] = $googleId
    }
    return $titles
}

if ($Source -eq 'cuisine') {
    $baseUrl = 'https://huggingface.co/datasets/ychwodhrey/malaysian-cuisine'
    $tree = Get-Text 'https://huggingface.co/api/datasets/ychwodhrey/malaysian-cuisine/tree/main?recursive=true' | ConvertFrom-Json
    $metadata = Get-Text "$baseUrl/raw/main/images/metadata.csv"
    $metadata | Set-Content -LiteralPath (Join-Path $output 'publisher-labels.csv') -Encoding UTF8
    foreach ($entry in ($metadata | ConvertFrom-Csv)) {
        $name = $entry.file_name
        if ($name -notmatch '^[a-z0-9_]+\.jpg$') { throw "Unexpected publisher filename $name" }
        $file = $tree | Where-Object { $_.path -eq "images/$name" }
        if (!$file.lfs.oid) { throw "Missing publisher hash for $name" }
        $url = "$baseUrl/resolve/main/images/$name"
        $photo = Save-Photo $url (Join-Path $output $name) $file.lfs.oid
        [void](Add-Photo ([ordered]@{
            file = "$Source/$name"; subject_id = $entry.label; kind = 'food'; label = $entry.Name
            source = "$baseUrl/blob/main/images/$name"; creator = ''; license = 'Apache-2.0 (dataset declaration)'
            license_url = 'https://www.apache.org/licenses/LICENSE-2.0'; review_status = 'needs_provenance_and_subject_review'
        }) $photo)
    }
} else {
    $subjects = Import-Csv (Join-Path $PSScriptRoot 'recognition_dataset_subjects.csv') |
        Where-Object {
            ($_.kind -eq $Source -or ($Source -eq 'google-landmarks' -and $_.kind -eq 'landmark')) -and
            (!$SubjectIds.Count -or $_.subject_id -in $SubjectIds)
        }
    $knownSources = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    if ($Source -eq 'google-landmarks') {
        $landmarkIndex = Get-LandmarkIndex $subjects
        $commonsManifest = Join-Path $root 'landmark.csv'
        if (Test-Path -LiteralPath $commonsManifest) {
            foreach ($row in (Import-Csv -LiteralPath $commonsManifest)) {
                [void]$knownSources.Add([Uri]::UnescapeDataString($row.source))
            }
        }
    }
    foreach ($subject in $subjects) {
        $count = 0
        $contributors = @{}
        $queries = if ($Source -eq 'google-landmarks') {
            $indexed = $landmarkIndex[$subject.subject_id]
            if ($indexed) {
                $titles = @($indexed.Keys)
                for ($offset = 0; $offset -lt [Math]::Min(60, $titles.Count); $offset += 20) {
                    $last = [Math]::Min($offset + 19, $titles.Count - 1)
                    '&titles=' + [Uri]::EscapeDataString(($titles[$offset..$last] -join '|'))
                }
            }
        } else {
            foreach ($category in $subject.categories.Split('|')) {
                $title = [Uri]::EscapeDataString("Category:$category")
                "&generator=categorymembers&gcmtitle=$title&gcmtype=file&gcmlimit=40"
            }
        }
        foreach ($query in $queries) {
            $api = 'https://commons.wikimedia.org/w/api.php?action=query&format=json&formatversion=2'
            $api += $query
            $api += '&prop=imageinfo&iiprop=url%7Csize%7Cextmetadata&iiurlwidth=640'
            $api += '&iiextmetadatafilter=Artist%7CLicenseShortName%7CLicenseUrl%7CRestrictions'
            try { $listing = Get-Text $api | ConvertFrom-Json }
            catch { Write-Warning $_; continue }
            $candidates = foreach ($page in $listing.query.pages) {
                if (!$page.imageinfo) { continue }
                $info = $page.imageinfo[0]
                $license = $info.extmetadata.LicenseShortName.value
                $artist = [Web.HttpUtility]::HtmlDecode(([string]$info.extmetadata.Artist.value -replace '<[^>]+>', '')).Trim()
                if ($page.title -match '\.jpe?g$' -and $info.thumburl -and $info.descriptionurl -and
                    $artist -and $license -match '^(CC BY(-SA)? [234]\.\d|CC0|Public domain)$' -and
                    !$info.extmetadata.Restrictions.value) {
                    [pscustomobject]@{ page = $page; photo = $info; creator = $artist; license = $license }
                }
            }
            $attempts = 0
            foreach ($candidate in $candidates) {
                if ($contributors[$candidate.creator] -ge 2) { continue }
                if ($knownSources.Contains([Uri]::UnescapeDataString($candidate.photo.descriptionurl))) { continue }
                $filename = "$($candidate.page.pageid).jpg"
                $folder = Join-Path $output $subject.subject_id
                New-Item -ItemType Directory -Force $folder | Out-Null
                $destination = Join-Path $folder $filename
                if (!(Test-Path -LiteralPath $destination)) {
                    if ($attempts -ge $PhotosPerSubject * 2) { continue }
                    $attempts++
                }
                try {
                    $url = $candidate.photo.thumburl -replace '\?.*$', ''
                    $photo = Save-Photo $url $destination
                } catch { Write-Warning $_; continue }
                $added = Add-Photo ([ordered]@{
                    file = "$Source/$($subject.subject_id)/$filename"; subject_id = $subject.subject_id
                    kind = $subject.kind; label = $subject.label; source = $candidate.photo.descriptionurl
                    creator = $candidate.creator; license = $candidate.license
                    license_url = $candidate.photo.extmetadata.LicenseUrl.value; review_status = 'needs_subject_review'
                    google_landmarks_id = if ($Source -eq 'google-landmarks') { $indexed[$candidate.page.title] } else { '' }
                }) $photo
                if ($added) {
                    $count++
                    $contributors[$candidate.creator]++
                    [void]$knownSources.Add([Uri]::UnescapeDataString($candidate.photo.descriptionurl))
                }
                if ($count -ge $PhotosPerSubject) { break }
            }
            if ($count -ge $PhotosPerSubject) { break }
        }
        Write-Host "$($subject.label) $count/$PhotosPerSubject"
        if ($rows.Count) {
            $rows | Export-Csv -LiteralPath (Join-Path $root $manifestName) -NoTypeInformation -Encoding UTF8
        }
    }
}

if (!$rows.Count) { throw "No valid photos for $Source" }
$rows | Export-Csv -LiteralPath (Join-Path $root $manifestName) -NoTypeInformation -Encoding UTF8
Write-Host "Validated $($rows.Count) unique JPEGs for $Source."
