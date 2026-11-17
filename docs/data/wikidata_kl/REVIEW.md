# Kuala Lumpur source review — 18 November 2026

Nine real attraction identities and coordinates were fetched in a single
Wikidata `wbgetentities` response. `source_snapshot.json` preserves the structured
source; `catalog_draft.json` is the unreviewed fetch output. The reviewed version
records source entity URLs and revision IDs. Names/coordinates were checked
against the returned labels, descriptions, coordinate statements and KL bounds.
Only one non-deprecated/preferred coordinate was accepted for each entity.

This is a source-data review, not an on-site survey or verification of current
business operation. Categories are Citylore editorial classifications based on
the entity identities (museum, mosque, market, garden, landmark, bird park).
No ratings, review counts, opening times, prices, descriptions or photos are
imported. These fields remain unavailable rather than fabricated.

The source's structured data is CC0:
https://www.wikidata.org/wiki/Wikidata:Copyright
https://creativecommons.org/publicdomain/zero/1.0/
This does not license photos linked by Wikidata. Existing individually licensed
photos for Petronas Towers, Bird Park and the museum are associated by exact
entity identity in the app's image resolver; photo credits remain unchanged.

`catalog_reviewed.json` passed the import validator: 9 accepted, 0 rejected.
`docs/database/import_wikidata_kl.sql` contains nine independent-ID upserts in a
transaction. It does not relabel, overwrite or delete Google rows, change request
budgets, or call any paid APIs. A same-ID independent row is updated; a conflicting
row with another data source is skipped. This file is prepared, not executed.

## Manual import

1. Open `docs/database/import_wikidata_kl.sql` and copy the whole file.
2. In the correct Supabase project, create a new SQL Editor query, paste and Run.
3. Run this read-only verification:

```sql
SELECT place_id, name, catalog_status, catalog_source_url
FROM public.places
WHERE data_source = 'independent'
  AND catalog_status = 'published'
  AND place_id LIKE 'wikidata_%'
ORDER BY place_id;
```

Expect these nine records unless a conflicting ID was skipped. Then tap Try Again
in Explore with Kuala Lumpur selected. Other states still need their own real
independent catalog; this bounded import does not cover all Malaysian attractions.
Several places still have no independently licensed photo or rating.
