-- SQL Transformation for partner_tdp (v2)
-- Generated based on Data Contract partner_tdp_v2.yaml

WITH 
-- Step: read_agreements (agreements_df)
agreements_df AS (
    SELECT 
        status, 
        databegin, 
        dataend, 
        clientId, 
        productarr
    FROM custom_cib_p4d_ppc.CppAgreement agr
    WHERE agr.isdeleted = false 
      AND (agr.status IN (${partner_tdp_agr_status}) OR '${partner_tdp_agr_status}' = '')
),

-- Step: join_product (with_product_df)
with_product_df AS (
    SELECT 
        agreements_df.*
    FROM agreements_df
    INNER JOIN (
        SELECT productid 
        FROM custom_cib_p4d_ppc.CppProduct 
        WHERE code IN (${partner_tdp_product_code}) 
          AND isdeleted = false
    ) prod ON agreements_df.productarr = prod.productid
),

-- Step: join_client (with_client_df)
with_client_df AS (
    SELECT 
        with_product_df.*, 
        cli.epk_id AS partner_epk_id
    FROM with_product_df
    INNER JOIN (
        SELECT clientId, epk_id 
        FROM custom_cib_p4d_ppc.CppClient 
        WHERE isdeleted = false
    ) cli ON with_product_df.clientId = cli.clientId
),

-- Step: join_subj (ess_subj_df)
ess_subj_df AS (
    SELECT 
        with_client_df.*, 
        subj.subj_sk, 
        subj.subj_dp_code, 
        subj.head_office_flag, 
        subj.entrepreneur_subj_sk, 
        subj.entrepreneur_subj_dp_code
    FROM with_client_df
    INNER JOIN (
        SELECT sid, subj_sk, subj_dp_code, head_office_flag, entrepreneur_subj_sk, entrepreneur_subj_dp_code 
        FROM subj_org_idl.subj 
        WHERE deleted_flag = false
    ) subj ON with_client_df.partner_epk_id = subj.sid
),

-- Step: join_subj_h (with_inn_df)
with_inn_df AS (
    SELECT 
        ess_subj_df.*, 
        subj_h.inn_num AS inn
    FROM ess_subj_df
    INNER JOIN (
        SELECT subj_sk, subj_dp_code, inn_num 
        FROM subj_org_idl.subj_h 
        WHERE CURRENT_TIMESTAMP >= start_dt AND CURRENT_TIMESTAMP <= end_dt
    ) subj_h ON ess_subj_df.subj_sk = subj_h.subj_sk AND ess_subj_df.subj_dp_code = subj_h.subj_dp_code
),

-- Step: join_subj_org_kpp (with_kpp_df)
with_kpp_df AS (
    SELECT 
        with_inn_df.*, 
        kpp.kpp_code AS kpp
    FROM with_inn_df
    LEFT JOIN (
        SELECT subj_sk, subj_dp_code, kpp_code 
        FROM subj_org_idl.subj_org_kpp 
        WHERE deleted_flag = false
    ) kpp ON with_inn_df.subj_sk = kpp.subj_sk AND with_inn_df.subj_dp_code = kpp.subj_dp_code
),

-- Step: join_subj_org_okved2 (okved_link_df)
okved_link_df AS (
    SELECT 
        with_kpp_df.*, 
        okv_lnk.okved2_sk, 
        okv_lnk.okved2_dp_code
    FROM with_kpp_df
    LEFT JOIN (
        SELECT subj_sk, subj_dp_code, okved2_sk, okved2_dp_code 
        FROM subj_org_idl.subj_org_okved2 
        WHERE deleted_flag = false 
          AND main_flag = true
    ) okv_lnk ON with_kpp_df.subj_sk = okv_lnk.subj_sk AND with_kpp_df.subj_dp_code = okv_lnk.subj_dp_code
),

-- Step: join_okved2 (okved_code_df)
okved_code_df AS (
    SELECT 
        okved_link_df.*, 
        okv.code AS okved
    FROM okved_link_df
    LEFT JOIN (
        SELECT okved2_sk, okved2_dp_code, code 
        FROM subj_org_idl.okved2 
        WHERE deleted_flag = false
    ) okv ON okved_link_df.okved2_sk = okv.okved2_sk AND okved_link_df.okved2_dp_code = okv.okved2_dp_code
),

-- Step: join_subj_orgidfn (with_org_name_df)
with_org_name_df AS (
    SELECT 
        okved_code_df.*, 
        org_nm.full_name AS partner_name
    FROM okved_code_df
    LEFT JOIN (
        SELECT subj_sk, subj_dp_code, full_name 
        FROM subj_org_idl.subj_orgidfn 
        WHERE CURRENT_TIMESTAMP >= start_dt AND CURRENT_TIMESTAMP <= end_dt
    ) org_nm ON okved_code_df.subj_sk = org_nm.subj_sk AND okved_code_df.subj_dp_code = org_nm.subj_dp_code
),

-- Step: join_subj_indidfn (with_ip_name_df)
with_ip_name_df AS (
    SELECT 
        with_org_name_df.*, 
        ind_nm.family_name AS last_name, 
        ind_nm.first_name AS first_name, 
        ind_nm.father_name AS middle_name
    FROM with_org_name_df
    LEFT JOIN (
        SELECT subj_sk, subj_dp_code, family_name, first_name, father_name 
        FROM subj_org_idl.subj_indidfn 
        WHERE CURRENT_TIMESTAMP >= start_dt AND CURRENT_TIMESTAMP <= end_dt
    ) ind_nm ON with_org_name_df.entrepreneur_subj_sk = ind_nm.subj_sk AND with_org_name_df.entrepreneur_subj_dp_code = ind_nm.subj_dp_code
),

-- Step: aggregate_kno (temp_kno_df)
temp_kno_df AS (
    SELECT 
        subj_sk, 
        kno
    FROM (
        SELECT 
            doc.subj_sk, 
            doc.subj_org_doc_org_issue_code AS kno, 
            doc.sid AS doc_sid,
            MAX(doc.sid) OVER (PARTITION BY doc.subj_sk) AS max_doc_sid
        FROM subj_org_idl.subj_org_doc doc
        INNER JOIN (
            SELECT subj_org_doc_type_sk 
            FROM subj_org_idl.subj_org_doc_type 
            WHERE subj_org_doc_type_code IN (${partner_tdp_doc_kno_code}) 
              AND deleted_flag = false
        ) dtp ON doc.subj_org_doc_type_sk = dtp.subj_org_doc_type_sk
        WHERE doc.subj_org_doc_org_issue_code IS NOT NULL 
          AND doc.deleted_flag = false
    ) sub
    WHERE doc_sid = max_doc_sid
)

-- Step: final_join_kno (final_df) & SELECT final fields
SELECT 
    with_ip_name_df.status,
    with_ip_name_df.databegin AS data_begin,
    with_ip_name_df.dataend AS data_end,
    with_ip_name_df.partner_epk_id,
    with_ip_name_df.partner_name,
    with_ip_name_df.last_name,
    with_ip_name_df.first_name,
    with_ip_name_df.middle_name,
    with_ip_name_df.inn,
    with_ip_name_df.kpp,
    with_ip_name_df.okved,
    with_ip_name_df.head_office_flag,
    temp_kno_df.kno,
    CURRENT_TIMESTAMP AS last_update
FROM with_ip_name_df
LEFT JOIN temp_kno_df ON with_ip_name_df.subj_sk = temp_kno_df.subj_sk;
