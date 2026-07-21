-- DMT_PARTITION_KEY_TBL — schema-level nested-table type of partition-key
-- tokens (work-queue-ID core, 2026-07-20).
--
-- A spawn-per-partition object (Items/Assets/Requisitions — see
-- DMT_CEMLI_SPLIT_CFG.CHILD_PARTITION_COLUMN) returns its distinct partition
-- tokens from a per-object GET_PARTITION_KEYS function that reads its OWN
-- transform table(s) with STATIC SQL. The queue worker calls that function
-- through the sanctioned registered-dispatch path (DMT_QUEUE_WORKER_PKG.
-- invoke_registered, style KEYS) and spawns one child work-queue item per
-- token. Each token is OPAQUE to the engine — it is stored on the child and
-- handed back as the child's row filter; the engine never parses it, so a
-- future composite-key object stays self-contained.
--
-- VARCHAR2(4000): a token is one CHILD_PARTITION_COLUMN value rendered with
-- TO_CHAR; 4000 leaves headroom for a future composite (delimited) token.
-- Re-runnable: CREATE OR REPLACE TYPE.
CREATE OR REPLACE TYPE "DMT_PARTITION_KEY_TBL" AS TABLE OF VARCHAR2(4000);
/
