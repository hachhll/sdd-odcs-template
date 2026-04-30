-- Скрипт подготовки данных для тестирования partner_tdp.sql
-- Предполагаемые значения переменных:
-- ${partner_tdp_agr_status} = 'active', 'pending'
-- ${partner_tdp_product_code} = 'PROD_TDP_V1'
-- ${partner_tdp_doc_kno_code} = '48', '50'

-- 1. Справочник продуктов
INSERT INTO custom_cib_p4d_ppc.CppProduct (productid, code, isdeleted) VALUES 
('p_valid', 'PROD_TDP_V1', false),
('p_invalid', 'OTHER_PROD', false),
('p_deleted', 'PROD_TDP_V1', true);

-- 2. Клиенты
INSERT INTO custom_cib_p4d_ppc.CppClient (clientId, epk_id, isdeleted) VALUES 
('cli_01', 'epk_org_valid', false),
('cli_02', 'epk_ip_valid', false),
('cli_03', 'epk_deleted', true);

-- 3. Согласия (Agreements)
-- Сценарий 1: ЮЛ, статус active
INSERT INTO custom_cib_p4d_ppc.CppAgreement (status, databegin, dataend, clientId, productarr, isdeleted) VALUES 
('active', '2026-01-01', '2026-12-31', 'cli_01', 'p_valid', false);

-- Сценарий 2: ИП, статус pending (проверка фильтра по списку статусов)
INSERT INTO custom_cib_p4d_ppc.CppAgreement (status, databegin, dataend, clientId, productarr, isdeleted) VALUES 
('pending', '2025-05-01', '2027-01-01', 'cli_02', 'p_valid', false);

-- Сценарий 3: Невалидные (не должны попасть в результат)
INSERT INTO custom_cib_p4d_ppc.CppAgreement (status, databegin, dataend, clientId, productarr, isdeleted) VALUES 
('closed', '2026-01-01', '2026-12-31', 'cli_01', 'p_valid', false), -- не тот статус
('active', '2026-01-01', '2026-12-31', 'cli_01', 'p_invalid', false), -- не тот продукт
('active', '2026-01-01', '2026-12-31', 'cli_03', 'p_valid', false); -- удаленный клиент

-- 4. Субъекты (ESS)
INSERT INTO subj_org_idl.subj (sid, subj_sk, subj_dp_code, head_office_flag, entrepreneur_subj_sk, entrepreneur_subj_dp_code, deleted_flag) VALUES 
('epk_org_valid', 100, 'TDP', '1', NULL, NULL, false),
('epk_ip_valid',  200, 'TDP', '0', 300, 'TDP', false);

-- 5. История субъектов (ИНН)
INSERT INTO subj_org_idl.subj_h (subj_sk, subj_dp_code, inn_num, start_dt, end_dt) VALUES 
(100, 'TDP', '7700000001', '2000-01-01', '2099-12-31'), -- актуально
(200, 'TDP', '5000000002', '2000-01-01', '2099-12-31'), -- актуально
(100, 'TDP', '0000000000', '1990-01-01', '1995-01-01'); -- просрочено

-- 6. КПП (Только для ЮЛ)
INSERT INTO subj_org_idl.subj_org_kpp (subj_sk, subj_dp_code, kpp_code, deleted_flag) VALUES 
(100, 'TDP', '770101001', false);

-- 7. ОКВЭД (Только для ЮЛ)
INSERT INTO subj_org_idl.subj_org_okved2 (subj_sk, subj_dp_code, okved2_sk, okved2_dp_code, deleted_flag, main_flag) VALUES 
(100, 'TDP', 55, 'TDP', false, true);
INSERT INTO subj_org_idl.okved2 (okved2_sk, okved2_dp_code, code, deleted_flag) VALUES 
(55, 'TDP', '62.01', false);

-- 8. Наименования
-- Для ЮЛ
INSERT INTO subj_org_idl.subj_orgidfn (subj_sk, subj_dp_code, full_name, start_dt, end_dt) VALUES 
(100, 'TDP', 'ООО РОМАШКА', '2000-01-01', '2099-12-31');
-- Для ИП
INSERT INTO subj_org_idl.subj_indidfn (subj_sk, subj_dp_code, family_name, first_name, father_name, start_dt, end_dt) VALUES 
(300, 'TDP', 'Иванов', 'Иван', 'Иванович', '2000-01-01', '2099-12-31');

-- 9. Документы КНО
INSERT INTO subj_org_idl.subj_org_doc_type (subj_org_doc_type_sk, subj_org_doc_type_code, deleted_flag) VALUES 
(1, '48', false),
(2, '99', false); -- невалидный тип

INSERT INTO subj_org_idl.subj_org_doc (sid, subj_sk, subj_org_doc_org_issue_code, subj_org_doc_type_sk, deleted_flag) VALUES 
(1001, 100, '7701', 1, false), -- документ 1
(1002, 100, '7799', 1, false), -- документ 2 (макс sid - должен быть выбран этот код)
(1003, 100, '0000', 2, false); -- не тот тип документа
