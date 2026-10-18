$headers = @{
    'apikey' = 'sb_publishable_6ERkrwdS5BLYRfd-JlBj2w_WTngwXsP'
    'Authorization' = 'Bearer sb_publishable_6ERkrwdS5BLYRfd-JlBj2w_WTngwXsP'
    'Content-Type' = 'application/json'
}

Write-Host "Fetching all places from Supabase..."
$raw = curl.exe -s -H "apikey: sb_publishable_6ERkrwdS5BLYRfd-JlBj2w_WTngwXsP" -H "Authorization: Bearer sb_publishable_6ERkrwdS5BLYRfd-JlBj2w_WTngwXsP" "https://yavslytukzgphvaqspcq.supabase.co/rest/v1/places?select=place_id,name,category,is_indoor"
$places = $raw | ConvertFrom-Json

Write-Host "Total places found: $($places.Count)"

function Classify-Place($category, $name) {
    $cat = $category.ToLower().Trim()
    $nm = $name.ToLower().Trim()

    # 1. PRIMARY CHECK: Indoor categories (Food, Dining, Museums, Shopping, Hospitality)
    $indoorCats = @(
        'restaurant', 'cafe', 'coffee', 'bakery', 'food court', 'hawker',
        'diner', 'bar', 'bistro', 'buffet', 'eatery', 'museum', 'art gallery',
        'gallery', 'aquarium', 'shopping mall', 'mall', 'supermarket', 'department store',
        'store', 'shop', 'hotel', 'resort', 'cinema', 'theater', 'library',
        'indoor', 'bowling', 'gym', 'spa'
    )
    foreach ($k in $indoorCats) {
        if ($cat.Contains($k)) { return $true }
    }

    # 2. PRIMARY CHECK: Outdoor categories (Nature, Beaches, Parks, Hiking)
    $outdoorCats = @(
        'beach', 'botanical garden', 'garden', 'hiking', 'nature',
        'scenic', 'waterfall', 'mountain', 'hill', 'peak', 'forest', 'woods',
        'jungle', 'camp', 'zoo', 'safari', 'wildlife', 'farm', 'plantation',
        'lookout', 'lake', 'river', 'island', 'pier', 'jetty', 'bridge'
    )
    foreach ($k in $outdoorCats) {
        if ($cat.Contains($k)) { return $false }
    }

    if ($cat -eq 'park' -or $cat.Contains('park')) {
        return $false
    }

    # 3. SECONDARY CHECK: Ambiguous category (Tourist attraction, Historical landmark, etc.)
    # Check indoor name keywords first
    $indoorNames = @(
        'museum', 'muzium', 'art gallery', 'gallery', 'aquarium', 'shopping mall',
        'mall', 'plaza', 'komtar', 'complex', 'indoor', 'cinema', 'tower', 'menara'
    )
    foreach ($k in $indoorNames) {
        if ($nm.Contains($k)) { return $true }
    }

    # Check outdoor name keywords
    $outdoorNames = @(
        'beach', 'pantai', 'bay', 'teluk', 'waterfall', 'air terjun', 'cascade',
        'jeram', 'hill', 'bukit', 'peak', 'gunung', 'mountain', 'botanical garden',
        'forest', 'hutan', 'jungle', 'trail', 'hiking', 'walkway',
        'treetop', 'viewpoint', 'view point', 'lookout', 'viewing deck', 'viewing area',
        'wave breaker', 'street art', 'mural', 'jetties', 'jetty', 'pier',
        'promenade', 'fort', 'nature'
    )
    foreach ($k in $outdoorNames) {
        if ($nm.Contains($k)) { return $false }
    }

    return $null
}

$indoorList = @()
$outdoorList = @()
$unassignedList = @()
$updateCount = 0

foreach ($p in $places) {
    $classified = Classify-Place $p.category $p.name
    
    if ($classified -eq $true) {
        $indoorList += $p
    } elseif ($classified -eq $false) {
        $outdoorList += $p
    } else {
        $unassignedList += $p
    }

    # If classification differs from database, patch it!
    if ($p.is_indoor -ne $classified) {
        $id = $p.place_id
        $body = @{ 'is_indoor' = $classified } | ConvertTo-Json -Compress
        $patchUrl = "https://yavslytukzgphvaqspcq.supabase.co/rest/v1/places?place_id=eq.$id"
        
        $null = Invoke-RestMethod -Uri $patchUrl -Headers $headers -Method Patch -Body $body
        $updateCount++
        Write-Host "  Updated [$($p.name)]: is_indoor = $classified"
    }
}

Write-Host "Classification Summary:"
Write-Host "  Indoor:  $($indoorList.Count)"
Write-Host "  Outdoor: $($outdoorList.Count)"
Write-Host "  Needs Review (Null): $($unassignedList.Count)"
Write-Host "  Total Patched: $updateCount"

# Clean up indoor_places and outdoor_places sub-tables using a WHERE clause that matches all
Write-Host "Syncing indoor_places..."
try {
    $null = Invoke-RestMethod -Uri "https://yavslytukzgphvaqspcq.supabase.co/rest/v1/indoor_places?id=not.is.null" -Headers $headers -Method Delete
} catch {
    Write-Host "  indoor delete note: $($_.Exception.Message)"
}

$indoorPayload = @()
foreach ($p in $indoorList) {
    $indoorPayload += @{
        'place_id' = $p.place_id
        'is_air_conditioned' = $true
    }
}
$indoorJson = $indoorPayload | ConvertTo-Json -Depth 5 -Compress
$null = Invoke-RestMethod -Uri 'https://yavslytukzgphvaqspcq.supabase.co/rest/v1/indoor_places' -Headers $headers -Method Post -Body $indoorJson
Write-Host "  Successfully synced $($indoorPayload.Count) rows to indoor_places."

Write-Host "Syncing outdoor_places..."
try {
    $null = Invoke-RestMethod -Uri "https://yavslytukzgphvaqspcq.supabase.co/rest/v1/outdoor_places?id=not.is.null" -Headers $headers -Method Delete
} catch {
    Write-Host "  outdoor delete note: $($_.Exception.Message)"
}

$outdoorPayload = @()
foreach ($p in $outdoorList) {
    $outdoorPayload += @{
        'place_id' = $p.place_id
        'is_rain_sensitive' = $true
    }
}
$outdoorJson = $outdoorPayload | ConvertTo-Json -Depth 5 -Compress
$null = Invoke-RestMethod -Uri 'https://yavslytukzgphvaqspcq.supabase.co/rest/v1/outdoor_places' -Headers $headers -Method Post -Body $outdoorJson
Write-Host "  Successfully synced $($outdoorPayload.Count) rows to outdoor_places."

Write-Host "ALL PLACES AUTOMATICALLY CLASSIFIED AND SYNCED!"
