# Stage B5 — ESS-output / import-report parsing unit suite (2026-07-08)

Result: **23 passed / 0 failed**, fully offline (no Fusion call; the one download-path test
runs with FUSION_URL temporarily NULLed and restored). Full runner: **4/4 suites green**
(`test_csv_intake` 16, `test_dmt_util_pkg` 31, `test_fusion_calls` SKIPPED-clean,
`test_import_report` 23), run twice — rerun-stable, self-cleaning. Invalid-object count 47
(below the 49 Stage A baseline).

Suite: `test/unit/test_import_report.sql`. Fixtures + provenance: `test/unit/fixtures/README.md`
(real RCV ESS log from the frozen ATP `DMT_LOG_TBL`; real Projects import-report structure/error
row from the documented live download of ESS 9401822; synthetic Contract v1 response per
DMT_DESIGN.html section 5; synthetic >32K payload generated in-test).

Pre-fix exposure proven: the HEAD package versions were redeployed (git stash) and the suite
run against them — it fails immediately (ORA-31012 out of PARSE_ERRORS) and would continue to
fail tests 20/21/22; with the fixes redeployed it is green.

## Defects found and FIXED (redeployed from the committed files)

1. **`DMT_IMPORT_REPORT_PKG.PARSE_ERRORS` was dead on the target DB** —
   `XMLTYPE.extract('count(/*/*)')` raises ORA-31012 (count() is not a node-set XPath) on the
   26ai Docker instance, so the parser failed on EVERY input (worked on the frozen 19c ATP).
   Fixed: positional iteration bounded by `EXISTSNODE` probes instead of three `count()` extracts
   (`db/packages/dmt_import_report_pkg.pkb.sql`).
2. **`DMT_ESS_UTIL_PKG.CAPTURE_ESS_HIERARCHY`** — `<reportBytes>` via REGEXP into a
   `VARCHAR2(32767)` + single-shot UTL_ENCODE decode (the >32K truncation family, 3rd sighting).
   Now delegates to `DMT_UTIL_PKG.BIP_REPORT_XML`.
3. **`DMT_ESS_UTIL_PKG.CAPTURE_REPORT_ESS_JOB`** — identical inline decode (4th sighting).
   Same delegation.
4. **`DMT_UTIL_PKG.BIP_REQUEST`** — inline decoder 4-aligned over raw chunks without stripping
   base64 line breaks (same family). Now `BASE64_DECODE_CLOB` + `CONVERTTOCLOB`.
5. **`DMT_UTIL_PKG.REFRESH_LOOKUPS`** — a 5th inline copy of the same whitespace-unsafe chunk
   decoder, found by the suite's consolidation guard (test 21). Now `BIP_REPORT_XML`.
6. **`DMT_UTIL_PKG.basic_auth_header`** — `UTL_ENCODE.BASE64_ENCODE` inserts CR/LF every 64
   output chars, corrupting the header for any user:password over 48 bytes. Fixed (CR/LF strip),
   promoted to a public `BASIC_AUTH_HEADER(p_username, p_password)` (defaults = config), and the
   two private copies in `DMT_ESS_UTIL_PKG.soap_http/soap_http_blob` now delegate to it.
   Regression-guarded by tests 20–23 (USER_SOURCE consolidation checks + >48-byte round trip).

## Gaps vs the section 5 contract (DOCUMENTED, not fixed — for the Stage B blind review)

1. No shared `DMT_IMPORT_REPORT_PKG.APPLY_ERRORS(p_tfm_table, p_key_column, p_run_id)` — the
   [IMPORT_REPORT] row-matching UPDATE remains per-reconciler (section 5 end-state, P2).
2. `PARSE_AND_LOG_ERRORS` has no XML-injection seam (always downloads) — the `[IMPORT_REPORT]`
   log-tag emission is untestable offline. Proposed: overload taking `p_xml IN CLOB`.
3. `PARSE_AND_LOG_ERRORS` returns 0 for both "no errors" and "download/parse failed"
   (WHEN OTHERS → 0) — indistinguishable, against "0 rows = investigate" and the section 7
   error-code contract.
4. `DMT_ESS_UTIL_PKG.GET_ESS_OUTPUT_XML/_TEXT` swallow every exception and RETURN the literal
   'Error downloading ESS output…' string AS the content CLOB — callers then parse an error
   message as if it were the report.
5. `PARSE_ERRORS` extracts error rows only — no API for report summary counts
   (PROJECT_ACCEPTED/REJECTED/WARNING) or success lists.
6. `t_import_error.error_message` is `VARCHAR2(4000)` (SUBSTRed) though log/ERROR_TEXT are CLOBs.
7. (Note) `PARSE_ERRORS` child-value extraction calls `.getStringVal()` on the result of
   `extract('…/text()')`, which is NULL for empty elements — an empty `<X_MSG/>` would raise
   inside the per-child guard block and be skipped; benign today, worth normalising when
   APPLY_ERRORS is built.
