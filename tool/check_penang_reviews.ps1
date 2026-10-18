$raw = curl.exe -s -H "apikey: sb_publishable_6ERkrwdS5BLYRfd-JlBj2w_WTngwXsP" -H "Authorization: Bearer sb_publishable_6ERkrwdS5BLYRfd-JlBj2w_WTngwXsP" "https://yavslytukzgphvaqspcq.supabase.co/rest/v1/places?state=ilike.*Penang*&limit=500"
$list = $raw | ConvertFrom-Json

$withReviews = 0
$zeroReviews = 0
$nullReviews = 0

foreach ($p in $list) {
    if ($null -eq $p.user_ratings_total) {
        $nullReviews++
    } elseif ($p.user_ratings_total -gt 0) {
        $withReviews++
    } else {
        $zeroReviews++
    }
}

Write-Host "Total Penang in Supabase: $($list.Count)"
Write-Host "  With Reviews (>0): $withReviews"
Write-Host "  Zero Reviews (=0): $zeroReviews"
Write-Host "  Null Reviews:      $nullReviews"
