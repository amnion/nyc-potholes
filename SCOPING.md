# NYC Pothole Reporting Gap — Scoping Doc

**Author:** Jacob Edwards
**Last updated:** [date]
**Status:** Draft → Locked end of Day 1

## Question

Where in NYC are potholes systematically under-reported to 311 relative to where DOT actually finds and repairs them, and what neighborhood characteristics correlate with the gap?

## Stakeholder (hypothetical)

A director of street operations at NYC DOT who decides where to (a) push proactive inspection routes and (b) target 311 outreach. The deliverable should help them rank districts and justify the ranking.

*(Real audience: hiring managers reading the portfolio. Stakeholder framing is for the write-up.)*

## Unit of analysis

NYC City Council District (51 districts). Policy-readable, statistically stable, finer than borough. Note: districts were redrawn in 2023 — handle pre/post separately or restrict to 2023+.

## Time window

Calendar years 2023 and 2024 (two full years post-redistricting). Cleaner than dragging in 2022 with the old boundaries.

## Data sources

| Source | Status | Notes |
|---|---|---|
| 311 Service Requests (Street Condition / Pothole) | Confirmed | Filter on `complaint_type` and `descriptor` |
| Street Pothole Work Orders – Closed (DOT) | Confirmed, updated Apr 2026 | The "ground truth" layer |
| LION Street Centerline | Confirmed | For road-miles per district |
| ACS 5-year estimates | Confirmed | Census tract → council district via crosswalk |
| Council district shapefiles | Confirmed | For geospatial join |
| NYC DOT truck routes (stretch) | Available | Only if Day 5 model needs it |

## Primary outcome metric

**Pothole Reporting Gap Index**: per-district residual from a negative binomial regression of monthly 311 reports on DOT repairs + road-miles + population + 2–3 ACS covariates, with bootstrap 95% CIs. Positive = over-reported relative to repairs; negative = under-reported.

## Secondary views (dashboard only, not modeled)

- 311 reports per road-mile by district
- Ratio of 311 reports to DOT repairs by district
- Time-to-closure for 311 reports by district

## Deliverables

1. Long-form write-up on `amnion.github.io`
2. Tableau Public dashboard (one workbook, three coordinated views)
3. GitHub repo, reproducible from clean clone via single command
4. LinkedIn launch post (week after ship)

## Out of scope (explicit)

- Non-pothole 311 complaints
- Sub-district resolution (census tract, block)
- Causal claims about *why* districts under-report
- Predictive modeling of future potholes
- Comparisons to other cities
- Power BI build (possible follow-up; not in v1)
- More than 3 ACS covariates in the model

## Key assumptions

- DOT closed work orders are roughly proportional to true pothole incidence at district scale. Acknowledged limit: DOT inspection routing is itself non-random.
- Council district is the right granularity. Sensitivity-checked on Day 6 against community district.
- Two years of data is enough for stable district-level estimates given monthly observations (51 districts × 24 months = 1,224 obs).
- Pothole reports may be duplicated (same pothole, multiple callers); dedupe by location + 7-day window.

## Open risks

- **Geocoding quality.** Day 1 spot-check. If DOT lat/longs are noisy, may need to fall back to street-segment matching.
- **DOT work orders bias.** DOT may inspect wealthier districts more (or less). Will be flagged prominently in Limitations regardless of which direction it cuts.
- **Redistricting.** Sticking to 2023+ avoids the boundary problem but cuts sample.
- **Dataset pivot.** If DOT work orders prove unusable, fall back to Citywide Pavement Rating as the need-side benchmark. Do not pivot off potholes.

## Definition of done

- [ ] Write-up live on portfolio with embedded dashboard
- [ ] Tableau Public dashboard published, three views, working filters
- [ ] GitHub repo: README with screenshot, `make all` reproduces pipeline end-to-end
- [ ] Limitations section names the top 3 caveats honestly
- [ ] One outside reader (a friend, an alum) read it and could explain the headline finding back to me

## Timeline

Days 1–10 per project plan. Slip means cutting from "Open risks" sensitivity work first, then secondary dashboard views, never from the write-up or the limitations section.