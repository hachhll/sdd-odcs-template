-- SQL Transformation for partner_tdp
-- Generated based on Data Contract v1.0.0
-- Strategy: Full Overwrite

WITH 
-- Step 1: Agreements Filtered
agreements_df AS (
    SELECT 
        status,
        databegin,
        dataend,
        clientId,
        productarr
    FROM custom_cib_p4d_ppc.CppAgreement AS agr
    WHERE agr.isdeleted = false
      AND (agr.status IN (${partner_tdp_agr_status}) OR '${partner_tdp_agr_status}' = '')
),

-- Step 2: Join with Products
with_product_df AS (
    SELECT 
        agr.*
    FROM agreements_df AS agr
    INNER JOIN (
        SELECT productid FROM custom_cib_p4d_ppc.CppProduct 
        WHERE code IN (${partner_tdp_product_code}) AND isdeleted = false
    ) AS prod ON agr.productarr = prod.productid
),

-- Step 3: Join with Clients
with_client_df AS (
    SELECT 
        wp.*,
        cli.epk_id AS partner_epk_id
    FROM with_product_df AS wp
    INNER JOIN (
        SELECT clientId, epk_id FROM custom_cib_p4d_ppc.CppClient 
        WHERE isdeleted = false
    ) AS cli ON wp.clientId = cli.clientId
),

-- Step 4-5: Join with ESS Subjects and INN
with_inn_df AS (
    SELECT 
        wc.*,
        subj.subj_sk,
        subj.subj_dp_code,
        subj.head_office_flag,
        subj.entrepreneur_subj_sk,
        subj.entrepreneur_subj_dp_code,
        subj_h.inn_num AS inn
    FROM with_client_df AS wc
    INNER JOIN (
        SELECT sid, subj_sk, subj_dp_code, head_office_flag, entrepreneur_subj_sk, entrepreneur_subj_dp_code 
        FROM subj_org_idl.subj 
        WHERE deleted_flag = false
    ) AS subj ON wc.partner_epk_id = subj.sid
    INNER JOIN (
        SELECT subj_sk, subj_dp_code, inn_num FROM subj_org_idl.subj_h 
        WHERE CURRENT_DATE >= start_dt AND CURRENT_DATE <= end_dt
    ) AS subj_h ON subj.subj_sk = subj_h.subj_sk AND subj.subj_dp_code = subj_h.subj_dp_code
),

-- Step 6-8: KPP and OKVED
with_okved_df AS (
    SELECT 
        wi.*,
        kpp.kpp_code AS kpp,
        okv.code AS okved
    FROM with_inn_df AS wi
    LEFT JOIN (
        SELECT subj_sk, subj_dp_code, kpp_code FROM subj_org_idl.subj_org_kpp 
        WHERE deleted_flag = false
    ) AS kpp ON wi.subj_sk = kpp.subj_sk AND wi.subj_dp_code = kpp.subj_dp_code
    LEFT JOIN (
        SELECT subj_sk, subj_dp_code, okved2_sk, okved2_dp_code FROM subj_org_idl.subj_org_okved2 
        WHERE deleted_flag = false AND main_flag = true
    ) AS okv_lnk ON wi.subj_sk = okv_lnk.subj_sk AND wi.subj_dp_code = okv_lnk.subj_dp_code
    LEFT JOIN (
        SELECT okved2_sk, okved2_dp_code, code FROM subj_org_idl.okved2 
        WHERE deleted_flag = false
    ) AS okv ON okv_lnk.okved2_sk = okv.okved2_sk AND okv_lnk.okved2_dp_code = okv.okved2_dp_code
),

-- Step 9-10: Names (Org and IP)
with_names_df AS (
    SELECT 
        wo.*,
        org_nm.full_name AS partner_name,
        ind_nm.family_name AS last_name,
        ind_nm.first_name AS first_name,
        ind_nm.father_name AS middle_name
    FROM with_okved_df AS wo
    LEFT JOIN (
        SELECT subj_sk, subj_dp_code, full_name FROM subj_org_idl.subj_orgidfn 
        WHERE CURRENT_DATE >= start_dt AND CURRENT_DATE <= end_dt
    ) AS org_nm ON wo.subj_sk = org_nm.subj_sk AND wo.subj_dp_code = org_nm.subj_dp_code
    LEFT JOIN (
        SELECT subj_sk, subj_dp_code, family_name, first_name, father_name FROM subj_org_idl.subj_indidfn 
        WHERE CURRENT_DATE >= start_dt AND CURRENT_DATE <= end_dt
    ) AS ind_nm ON wo.entrepreneur_subj_sk = ind_nm.subj_sk AND wo.entrepreneur_subj_dp_code = ind_nm.subj_dp_code
),

-- Step 11: KNO Aggregate logic
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
        FROM subj_org_idl.subj_org_doc AS doc
        INNER JOIN (
            SELECT subj_org_doc_type_sk FROM subj_org_idl.subj_org_doc_type 
            WHERE subj_org_doc_type_code IN (${partner_tdp_doc_kno_code}) AND deleted_flag = false
        ) AS dtp ON doc.subj_org_doc_type_sk = dtp.subj_org_doc_type_sk
        WHERE doc.subj_org_doc_org_issue_code IS NOT NULL 
          AND doc.deleted_flag = false
    ) AS sub
    WHERE doc_sid = max_doc_sid
)

-- Step 12: Final Selection
SELECT 
    base.status,
    base.databegin AS data_begin,
    base.dataend AS data_end,
    base.partner_epk_id,
    base.partner_name,
    base.last_name,
    base.first_name,
    base.middle_name,
    base.inn,
    base.kpp,
    base.okved,
    base.head_office_flag,
    kno.kno,
    CURRENT_TIMESTAMP AS last_update
FROM with_names_df AS base
LEFT JOIN temp_kno_df AS kno ON base.subj_sk = kno.subj_sk;
