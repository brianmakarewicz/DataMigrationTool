-- DMT_CONFIG_ADMIN_V
-- Front-end-facing configuration grid (rendered generically on the Administration
-- page via DMT_RENDER_VIEW). CONFIG_VALUE is MASKED for any row whose CONFIG_KEY
-- denotes a secret (password / pwd / secret / wallet / token / credential) so that
-- no password value is ever shown from the UI. The stored value in DMT_CONFIG_TBL is
-- unchanged; only the display through this view is masked.
CREATE OR REPLACE EDITIONABLE VIEW "DMT_CONFIG_ADMIN_V" ("CONFIG_KEY", "CONFIG_VALUE", "DESCRIPTION", "LAST_UPDATED_DATE", "LAST_UPDATED_BY")  AS
  SELECT
    CONFIG_KEY,
    CASE
      WHEN UPPER(CONFIG_KEY) LIKE '%PASSWORD%'
        OR UPPER(CONFIG_KEY) LIKE '%PWD%'
        OR UPPER(CONFIG_KEY) LIKE '%SECRET%'
        OR UPPER(CONFIG_KEY) LIKE '%WALLET%'
        OR UPPER(CONFIG_KEY) LIKE '%TOKEN%'
        OR UPPER(CONFIG_KEY) LIKE '%CREDENTIAL%'
      THEN '********'
      ELSE CONFIG_VALUE
    END AS CONFIG_VALUE,
    -- CONFIG_CATEGORY does not exist on DMT_CONFIG_TBL
    DESCRIPTION,
    -- CREATED_DATE does not exist on DMT_CONFIG_TBL
    LAST_UPDATED_DATE,
    LAST_UPDATED_BY
FROM
    DMT_CONFIG_TBL
ORDER BY
    CONFIG_KEY;
