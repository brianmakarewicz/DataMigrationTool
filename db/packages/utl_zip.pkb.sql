-- PACKAGE BODY UTL_ZIP

  CREATE OR REPLACE EDITIONABLE PACKAGE BODY "UTL_ZIP" IS

    FUNCTION little_endian (p_big IN NUMBER, p_bytes IN PLS_INTEGER := 4) RETURN RAW IS
    BEGIN
        RETURN UTL_RAW.SUBSTR(
                   UTL_RAW.CAST_FROM_BINARY_INTEGER(p_big, UTL_RAW.LITTLE_ENDIAN),
                   1, p_bytes);
    END little_endian;

    PROCEDURE add1file (
        p_zipped_blob IN OUT BLOB,
        p_name        IN     VARCHAR2,
        p_content     IN     BLOB
    ) IS
        t_now  DATE;
        t_blob BLOB;
        t_clen INTEGER;
    BEGIN
        t_now  := SYSDATE;
        t_blob := UTL_COMPRESS.LZ_COMPRESS(p_content);
        t_clen := DBMS_LOB.GETLENGTH(t_blob);

        IF p_zipped_blob IS NULL THEN
            DBMS_LOB.CREATETEMPORARY(p_zipped_blob, TRUE);
        END IF;

        DBMS_LOB.APPEND(p_zipped_blob,
            UTL_RAW.CONCAT(
                HEXTORAW('504B0304'),   -- Local file header signature
                HEXTORAW('1400'),       -- Version 2.0
                HEXTORAW('0000'),       -- No general purpose bits
                HEXTORAW('0800'),       -- Deflate compression
                little_endian(           -- File last modification time
                    TO_NUMBER(TO_CHAR(t_now,'ss'))   / 2    +
                    TO_NUMBER(TO_CHAR(t_now,'mi'))   * 32   +
                    TO_NUMBER(TO_CHAR(t_now,'hh24')) * 2048, 2),
                little_endian(           -- File last modification date
                    TO_NUMBER(TO_CHAR(t_now,'dd'))   +
                    TO_NUMBER(TO_CHAR(t_now,'mm'))   * 32   +
                    (TO_NUMBER(TO_CHAR(t_now,'yyyy')) - 1980) * 512, 2),
                DBMS_LOB.SUBSTR(t_blob, 4, t_clen - 7),    -- CRC-32
                little_endian(t_clen - 18),                -- Compressed size
                little_endian(DBMS_LOB.GETLENGTH(p_content)), -- Uncompressed size
                little_endian(LENGTH(p_name), 2),          -- File name length
                HEXTORAW('0000'),                           -- Extra field length
                UTL_RAW.CAST_TO_RAW(p_name)                -- File name
            )
        );

        -- Append compressed content (skip 10-byte LZ header and 8-byte trailer)
        DBMS_LOB.COPY(p_zipped_blob, t_blob, t_clen - 18,
                      DBMS_LOB.GETLENGTH(p_zipped_blob) + 1, 11);

        DBMS_LOB.FREETEMPORARY(t_blob);
    END add1file;

    PROCEDURE finish_zip (p_zipped_blob IN OUT BLOB) IS
        t_cnt              PLS_INTEGER := 0;
        t_offs             INTEGER;
        t_offs_dir_header  INTEGER;
        t_offs_end_header  INTEGER;
        t_comment          RAW(32767) := UTL_RAW.CAST_TO_RAW('Implementation by Anton Scheffer');
    BEGIN
        t_offs_dir_header := DBMS_LOB.GETLENGTH(p_zipped_blob);
        t_offs := DBMS_LOB.INSTR(p_zipped_blob, HEXTORAW('504B0304'), 1);

        WHILE t_offs > 0 LOOP
            t_cnt := t_cnt + 1;
            DBMS_LOB.APPEND(p_zipped_blob,
                UTL_RAW.CONCAT(
                    HEXTORAW('504B0102'),   -- Central directory file header signature
                    HEXTORAW('1400'),       -- Version 2.0
                    DBMS_LOB.SUBSTR(p_zipped_blob, 26, t_offs + 4),
                    HEXTORAW('0000'),       -- File comment length
                    HEXTORAW('0000'),       -- Disk number where file starts
                    HEXTORAW('0100'),       -- Internal file attributes
                    HEXTORAW('2000B681'),   -- External file attributes
                    little_endian(t_offs - 1),  -- Relative offset of local file header
                    DBMS_LOB.SUBSTR(        -- File name
                        p_zipped_blob,
                        UTL_RAW.CAST_TO_BINARY_INTEGER(
                            DBMS_LOB.SUBSTR(p_zipped_blob, 2, t_offs + 26),
                            UTL_RAW.LITTLE_ENDIAN),
                        t_offs + 30)
                )
            );
            t_offs := DBMS_LOB.INSTR(p_zipped_blob, HEXTORAW('504B0304'), t_offs + 32);
        END LOOP;

        t_offs_end_header := DBMS_LOB.GETLENGTH(p_zipped_blob);
        DBMS_LOB.APPEND(p_zipped_blob,
            UTL_RAW.CONCAT(
                HEXTORAW('504B0506'),                                     -- End of central directory signature
                HEXTORAW('0000'),                                         -- Number of this disk
                HEXTORAW('0000'),                                         -- Disk where central directory starts
                little_endian(t_cnt, 2),                                  -- Records on this disk
                little_endian(t_cnt, 2),                                  -- Total records
                little_endian(t_offs_end_header - t_offs_dir_header),    -- Size of central directory
                little_endian(t_offs_dir_header),                         -- Offset of central directory
                little_endian(NVL(UTL_RAW.LENGTH(t_comment), 0), 2),     -- Comment length
                t_comment
            )
        );
    END finish_zip;

END UTL_ZIP;
/
