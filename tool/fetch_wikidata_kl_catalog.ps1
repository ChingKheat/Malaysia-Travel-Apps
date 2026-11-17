# One bounded public-data request; no Google calls and no database connection.
# Output is a draft until the fetched identity/coordinates/source are reviewed.
param([string]$OutputDirectory = 'docs/data/wikidata_kl')
$ErrorActionPreference = 'Stop'
$taskEntities = [ordered]@{
  Q2660049 = 'Nature, Wildlife, Park'
  Q3330187 = 'Sights, Museum, Culture'
  Q12061078 = 'Nature, Garden, Park'
  Q83063 = 'Sights, Landmark, Architecture'
  Q745016 = 'Sights, Landmark, Tower'
  Q1356818 = 'Sights, Religion, Culture'
  Q615958 = 'Sights, Historic, Architecture'
  Q1041262 = 'Shopping, Market, Culture'
  Q3043065 = 'Sights, Historic, Landmark'
}
$taskIds = ($taskEntities.Keys -join '|')
$taskUri = 'https://www.wikidata.org/w/api.php?action=wbgetentities&ids=' +
  [Uri]::EscapeDataString($taskIds) + '&props=labels%7Cdescriptions%7Cclaims%7Cinfo&languages=en&format=json&redirects=yes'
$taskResponse = Invoke-RestMethod $taskUri -Headers @{'User-Agent'='CityloreCatalogReview/1.0 (bounded educational catalog import)'}
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$taskResponse | ConvertTo-Json -Depth 100 | Set-Content -Encoding utf8 (Join-Path $OutputDirectory 'source_snapshot.json')
$taskRows = foreach ($taskId in $taskEntities.Keys) {
  $taskEntity = $taskResponse.entities.$taskId
  if (!$taskEntity -or $taskEntity.missing) { throw "Missing entity: $taskId" }
  $taskCoordinates = @($taskEntity.claims.P625 | Where-Object {
    $_.rank -ne 'deprecated' -and $_.mainsnak.snaktype -eq 'value'
  })
  $taskPreferred = @($taskCoordinates | Where-Object rank -eq 'preferred')
  if ($taskPreferred.Count -gt 0) { $taskCoordinates = $taskPreferred }
  if ($taskCoordinates.Count -ne 1) { throw "Review ambiguous coordinates: $taskId" }
  $taskPoint = $taskCoordinates[0].mainsnak.datavalue.value
  if ($taskPoint.latitude -lt 3 -or $taskPoint.latitude -gt 3.3 -or
      $taskPoint.longitude -lt 101.5 -or $taskPoint.longitude -gt 101.9) {
    throw "Coordinates outside review area: $taskId"
  }
  [PSCustomObject][ordered]@{
    place_id = "wikidata_$taskId"
    name = $taskEntity.labels.en.value
    state = 'Kuala Lumpur'
    category = $taskEntities[$taskId]
    latitude = $taskPoint.latitude
    longitude = $taskPoint.longitude
    data_source = 'independent'
    reviewed = $false
    catalog_source_url = "https://www.wikidata.org/wiki/$taskId"
    catalog_license = 'CC0-1.0 (Wikidata structured data)'
    catalog_verified_at = [DateTime]::UtcNow.ToString('o')
    source_revision = $taskEntity.lastrevid
    source_description = $taskEntity.descriptions.en.value
  }
}
$taskRows | ConvertTo-Json -Depth 10 | Set-Content -Encoding utf8 (Join-Path $OutputDirectory 'catalog_draft.json')
$taskRows | Select-Object place_id,name,latitude,longitude,source_description | Format-Table -AutoSize
