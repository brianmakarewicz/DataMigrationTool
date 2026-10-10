-- PACKAGE BODY DMT_SPLIT_FIXTURE_PKG
-- Offline fixture for test/unit/test_dmt_deploy_split.py (backlog #758). Shaped
-- like db/packages/dmt_ess_util_pkg.pkb.sql: a package body closed by a "/" line,
-- then a second PL/SQL block (a conditional recompile) closed by its own "/".
-- It is never deployed to a database; the test runs it against a fake connection.

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "DMT_SPLIT_FIXTURE_PKG" AS

    -- a comment line inside the body that ends in a semicolon;
    FUNCTION f RETURN VARCHAR2 IS
    BEGIN
        RETURN 'a;b';   -- a literal and a trailing comment, both with ';'
    END f;

END DMT_SPLIT_FIXTURE_PKG;
/

-- ---------------------------------------------------------------------------
-- Second block: recompile with a ccflag when a condition holds.
-- ---------------------------------------------------------------------------
declare
  l_n number;
begin
  select count(*) into l_n from dual;
  if l_n > 0 then
    execute immediate q'[ALTER PACKAGE DMT_SPLIT_FIXTURE_PKG COMPILE BODY PLSQL_CCFLAGS='flag:TRUE' REUSE SETTINGS]';
  end if;
end;
/
