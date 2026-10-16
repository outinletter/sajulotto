# Solar-term data

- Source: 한국천문연구원_특일 정보 `get24DivisionsInfo`, https://www.data.go.kr/data/15012690/openapi.do
- Retrieved: 2026-10-16, approved development account. No service key is included in the app or repository.
- Requests used `solYear`, `numOfRows=100`, and the service key. Public annual results are bundled so birth information never leaves the device for calendar calculations.
- 2000–2027: 28 annual responses were checked against Astronomy Engine 2.1.19. The accepted 26 years differ by at most one minute. 2011 (up to 1,439 minutes) and 2015 (20 minutes) failed the five-minute cross-check and use explicitly labeled astronomical fallback for the whole year. This check flags disagreement; it does not independently prove which source is correct.
- 2019 대한 `kst=1760` is normalized to 18:00; this matches the independent calculation. The raw correction is recorded in `normalizedEntries`.
- 1899–1999: calculated fallback. KASI returned no data for the tested 1900 and 1995 years; unavailable history is never labeled as official data.
- Generator: `node scripts/build-solar-terms.cjs /path/to/astronomy.js /path/to/kasi-terms.json`. The snapshot has `{source,url,retrievedAt,years:{YEAR:[{name,date:"YYYYMMDD",kst:"HHmm"}]}}`.
- Astronomy Engine: https://github.com/cosinekitty/astronomy, npm 2.1.19; package integrity pinned in the generator. Its angular accuracy specification is not a guarantee of one-minute timing for every historical event.
- Outputs: `vendor/solar-terms.js` and its iOS bundle copy. Update both together. Regenerate before adding support past 2027.

## Calculation conventions

Gregorian dates, fixed UTC+09:00, year changes at 입춘, month changes at the twelve 절 terms. Longitude correction is used only for the local mean hour/day clock; solar-term comparisons use the absolute KST instant. Day changes at corrected midnight. Equation of time, historic Korean civil-time offsets and daylight saving are not applied. Historical affected years and unknown/approximate times are flagged. 해외 출생, 대운, 세운, 격국, 용신 and 신강·신약 are not asserted.
