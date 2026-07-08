-- PACKAGE UTL_ZIP

  CREATE OR REPLACE EDITIONABLE PACKAGE "UTL_ZIP" IS

    PROCEDURE add1file (
        p_zipped_blob IN OUT BLOB,
        p_name        IN     VARCHAR2,
        p_content     IN     BLOB
    );

    PROCEDURE finish_zip (p_zipped_blob IN OUT BLOB);

END UTL_ZIP;
/
