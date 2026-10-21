$headers = @{
    'apikey' = 'sb_publishable_6ERkrwdS5BLYRfd-JlBj2w_WTngwXsP'
    'Authorization' = 'Bearer sb_publishable_6ERkrwdS5BLYRfd-JlBj2w_WTngwXsP'
}

$raw = curl.exe -s -H "apikey: sb_publishable_6ERkrwdS5BLYRfd-JlBj2w_WTngwXsP" -H "Authorization: Bearer sb_publishable_6ERkrwdS5BLYRfd-JlBj2w_WTngwXsP" "https://yavslytukzgphvaqspcq.supabase.co/rest/v1/places?select=place_id,name,category,is_indoor"
$places = $raw | ConvertFrom-Json

Write-Host "Total places in Supabase: $($places.Count)"

$indoor = 0
$outdoor = 0
$unassigned = 0

foreach ($p in $places) {
    if ($p.is_indoor -eq $true) {
        $indoor++
    } elseif ($p.is_indoor -eq $false) {
        $outdoor++
    } else {
        $unassigned++
    }
}

Write-Host "Current Database Status:"
Write-Host "  Indoor (true):    $indoor"
Write-Host "  Outdoor (false):  $outdoor"
Write-Host "  Needs Review (null): $unassigned"
