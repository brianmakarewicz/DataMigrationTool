-- BASE-tier confirmation: a contact is LOADED only when its person party
-- positively exists in HZ_PARTIES (joined on the per_party_id the import stamps
-- on the interface row; PARTY_TYPE='PERSON'). STATUS is derived from base-table
-- presence, not the interface's own import_status; CONTACT_ID is the base party
-- id. Rows still in the interface with no base party are REJECTED. Rule #1.
SELECT
    i.contact_interface_id,
    b.party_id AS contact_id,
    i.vendor_name,
    i.first_name,
    i.last_name,
    CASE WHEN b.party_id IS NOT NULL THEN 'PROCESSED' ELSE 'REJECTED' END AS status,
    i.load_request_id,
    (
        SELECT LISTAGG(
                   CASE
                       WHEN r.attribute IS NOT NULL
                       THEN r.reject_lookup_code || ' [' || r.attribute || ']'
                       ELSE r.reject_lookup_code
                   END, '; ')
               WITHIN GROUP (ORDER BY r.rejection_id)
        FROM   poz_supplier_int_rejections r
        WHERE  r.parent_table = 'POZ_SUP_CONTACTS_INT'
        AND    r.parent_id    = i.contact_interface_id
    ) AS error_message
FROM   poz_sup_contacts_int i
LEFT JOIN hz_parties b ON b.party_id = i.per_party_id AND b.party_type = 'PERSON'
WHERE   i.load_request_id = :P_LOAD_REQUEST_ID
