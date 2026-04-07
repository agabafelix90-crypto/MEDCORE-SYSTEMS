-- ============================================================================
-- RLS VALIDATION SCRIPT
-- Run this after deploying the optimized RLS migration
-- ============================================================================
-- 
-- Purpose: Verify RLS policies are correctly deployed and working
-- Time: ~5 minutes
-- 
-- Instructions:
-- 1. Copy this entire script
-- 2. Paste into Supabase SQL Editor
-- 3. Click "Run"
-- 4. Verify all results match expected values
--
-- ============================================================================

-- SECTION A: DEPLOYMENT VERIFICATION
-- ============================================================================

-- A.1: Verify RLS is enabled on critical tables
SELECT 
  'TABLE CONFIGURATION CHECKS' as check_group,
  'RLS Enabled' as check_name,
  COUNT(*) as tables_with_rls,
  19 as expected_count,
  CASE WHEN COUNT(*) = 19 THEN '✅ PASS' ELSE '❌ FAIL' END as status
FROM pg_tables
WHERE schemaname = 'public'
  AND rowsecurity = true
  AND tablename IN (
    'patients', 'appointments', 'billing_invoices',
    'pharmacy_stock', 'pharmacy_inventory', 'pharmacy_sales',
    'prescriptions', 'communication_sms_logs', 'lab_results',
    'lab_tests', 'clinic_employees', 'medications', 'vitals',
    'diagnoses', 'treatment_plans', 'wards', 'store_inventory',
    'store_invoices'
  );

-- A.2: Count total policies
SELECT 
  'POLICY DEPLOYMENT' as check_group,
  'Total Policies' as check_name,
  COUNT(*) as policy_count,
  '80+' as expected_count,
  CASE WHEN COUNT(*) >= 80 THEN '✅ PASS' ELSE '❌ FAIL' END as status
FROM pg_policies
WHERE schemaname = 'public';

-- A.3: Verify policies per table (should have 4-5 per table)
SELECT 
  'POLICY DETAIL' as check_group,
  tablename,
  COUNT(*) as policy_count,
  CASE 
    WHEN COUNT(*) >= 4 THEN '✅ PASS' 
    ELSE '❌ FAIL' 
  END as status
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN (
    'patients', 'appointments', 'billing_invoices',
    'pharmacy_stock', 'pharmacy_inventory', 'pharmacy_sales',
    'prescriptions', 'communication_sms_logs', 'lab_results',
    'lab_tests', 'clinic_employees', 'medications', 'vitals',
    'diagnoses', 'treatment_plans', 'wards', 'store_inventory',
    'store_invoices'
  )
GROUP BY tablename
ORDER BY tablename;

-- A.4: Verify indexes created (should have 18+)
SELECT 
  'INDEX DEPLOYMENT' as check_group,
  'Performance Indexes' as check_name,
  COUNT(*) as index_count,
  '18+' as expected_count,
  CASE WHEN COUNT(*) >= 18 THEN '✅ PASS' ELSE '❌ FAIL' END as status
FROM pg_indexes
WHERE schemaname = 'public'
  AND (
    indexname LIKE 'idx_%clinic%'
    OR indexname LIKE 'idx_%user%'
  );

-- ============================================================================
-- SECTION B: SAMPLE DATA SETUP (Run once for testing)
-- ============================================================================

-- B.1: Create test clinics and employees (if not already present)
INSERT INTO clinic_employees (
  id, 
  user_id, 
  clinic_id, 
  name, 
  email, 
  role, 
  active
)
VALUES
  (
    gen_random_uuid(),
    '00000000-0000-0000-0000-000000000001'::uuid,  -- Clinic A test user
    '550e8400-e29b-41d4-a716-446655440001'::uuid,
    'Dr. Test Clinic A',
    'test-a@clinic-a.local',
    'doctor',
    true
  ),
  (
    gen_random_uuid(),
    '00000000-0000-0000-0000-000000000002'::uuid,  -- Clinic B test user
    '550e8400-e29b-41d4-a716-446655440002'::uuid,
    'Dr. Test Clinic B',
    'test-b@clinic-b.local',
    'doctor',
    true
  )
ON CONFLICT DO NOTHING;

-- B.2: Create test patients
INSERT INTO patients (
  id,
  clinic_id,
  name,
  email,
  status,
  created_at,
  updated_at
)
VALUES
  (
    'patient-test-a-001',
    '550e8400-e29b-41d4-a716-446655440001'::uuid,
    'Test Patient Clinic A',
    'patient-a@clinic-a.local',
    'active',
    NOW(),
    NOW()
  ),
  (
    'patient-test-b-001',
    '550e8400-e29b-41d4-a716-446655440002'::uuid,
    'Test Patient Clinic B',
    'patient-b@clinic-b.local',
    'active',
    NOW(),
    NOW()
  )
ON CONFLICT DO NOTHING;

-- B.3: Create test billing records
INSERT INTO billing_invoices (
  id,
  clinic_id,
  amount,
  status,
  created_at,
  updated_at
)
VALUES
  (
    'invoice-test-a-001',
    '550e8400-e29b-41d4-a716-446655440001'::uuid,
    1000.00,
    'paid',
    NOW(),
    NOW()
  ),
  (
    'invoice-test-b-001',
    '550e8400-e29b-41d4-a716-446655440002'::uuid,
    2000.00,
    'pending',
    NOW(),
    NOW()
  )
ON CONFLICT DO NOTHING;

-- B.4: Create test SMS logs
INSERT INTO communication_sms_logs (
  id,
  clinic_id,
  phone,
  message,
  status,
  created_at
)
VALUES
  (
    'sms-test-a-001',
    '550e8400-e29b-41d4-a716-446655440001'::uuid,
    '+1234567890',
    'Test message for Clinic A',
    'sent',
    NOW()
  ),
  (
    'sms-test-b-001',
    '550e8400-e29b-41d4-a716-446655440002'::uuid,
    '+1987654321',
    'Test message for Clinic B',
    'sent',
    NOW()
  )
ON CONFLICT DO NOTHING;

-- ============================================================================
-- SECTION C: NEGATIVE TESTS (Users CANNOT access other clinics)
-- ============================================================================

-- C.1: Clinic A user tries to read Clinic B patients (should be 0 rows)
SET LOCAL "request.jwt.claims" = '{"sub": "00000000-0000-0000-0000-000000000001"}';
SELECT 
  'NEGATIVE TEST: Cross-Clinic SELECT' as test_name,
  'Clinic A → Read Clinic B Patients' as test_description,
  COUNT(*) as rows_returned,
  0 as expected_rows,
  CASE WHEN COUNT(*) = 0 THEN '✅ PASS (Blocked)' ELSE '❌ FAIL (Accessible)' END as result
FROM patients 
WHERE clinic_id = '550e8400-e29b-41d4-a716-446655440002'::uuid;

-- C.2: Clinic A user tries to read own clinic patients (should see 1+ rows)
SET LOCAL "request.jwt.claims" = '{"sub": "00000000-0000-0000-0000-000000000001"}';
SELECT 
  'POSITIVE TEST: Own-Clinic SELECT' as test_name,
  'Clinic A → Read Clinic A Patients' as test_description,
  COUNT(*) as rows_returned,
  '1+' as expected_rows,
  CASE WHEN COUNT(*) > 0 THEN '✅ PASS (Accessible)' ELSE '❌ FAIL (Blocked)' END as result
FROM patients 
WHERE clinic_id = '550e8400-e29b-41d4-a716-446655440001'::uuid;

-- C.3: Clinic B user tries to read Clinic A patients (should be 0 rows)
SET LOCAL "request.jwt.claims" = '{"sub": "00000000-0000-0000-0000-000000000002"}';
SELECT 
  'NEGATIVE TEST: Cross-Clinic SELECT' as test_name,
  'Clinic B → Read Clinic A Patients' as test_description,
  COUNT(*) as rows_returned,
  0 as expected_rows,
  CASE WHEN COUNT(*) = 0 THEN '✅ PASS (Blocked)' ELSE '❌ FAIL (Accessible)' END as result
FROM patients 
WHERE clinic_id = '550e8400-e29b-41d4-a716-446655440001'::uuid;

-- C.4: Clinic A user tries to read Clinic B billing invoices (should be 0 rows)
SET LOCAL "request.jwt.claims" = '{"sub": "00000000-0000-0000-0000-000000000001"}';
SELECT 
  'NEGATIVE TEST: Cross-Clinic Financial Data' as test_name,
  'Clinic A → Read Clinic B Billing' as test_description,
  COUNT(*) as rows_returned,
  0 as expected_rows,
  CASE WHEN COUNT(*) = 0 THEN '✅ PASS (Blocked)' ELSE '❌ FAIL (Accessible)' END as result
FROM billing_invoices 
WHERE clinic_id = '550e8400-e29b-41d4-a716-446655440002'::uuid;

-- C.5: Clinic A user tries to read Clinic B SMS logs (should be 0 rows)
SET LOCAL "request.jwt.claims" = '{"sub": "00000000-0000-0000-0000-000000000001"}';
SELECT 
  'NEGATIVE TEST: Cross-Clinic Communication' as test_name,
  'Clinic A → Read Clinic B SMS Logs' as test_description,
  COUNT(*) as rows_returned,
  0 as expected_rows,
  CASE WHEN COUNT(*) = 0 THEN '✅ PASS (Blocked)' ELSE '❌ FAIL (Accessible)' END as result
FROM communication_sms_logs 
WHERE clinic_id = '550e8400-e29b-41d4-a716-446655440002'::uuid;

-- ============================================================================
-- SECTION D: INSERTION ATTACK PREVENTION
-- ============================================================================

-- D.1: Clinic A user tries to INSERT patient into Clinic B (should fail)
SET LOCAL "request.jwt.claims" = '{"sub": "00000000-0000-0000-0000-000000000001"}';
DO $$
DECLARE
  error_msg TEXT;
BEGIN
  INSERT INTO patients (
    id,
    clinic_id,
    name,
    email,
    status,
    created_at,
    updated_at
  )
  VALUES (
    'patient-injection-' || gen_random_uuid()::text,
    '550e8400-e29b-41d4-a716-446655440002'::uuid,
    'Injection Attack Test',
    'injection@clinic-b.local',
    'active',
    NOW(),
    NOW()
  );
  
  RAISE NOTICE '❌ FAIL: Injection succeeded (RLS not working)';
EXCEPTION WHEN OTHERS THEN
  GET DIAGNOSTICS error_msg = MESSAGE_TEXT;
  IF error_msg LIKE '%row-level security%' THEN
    RAISE NOTICE '✅ PASS: Injection blocked by RLS policy';
  ELSE
    RAISE NOTICE 'Error: %', error_msg;
  END IF;
END;
$$;

-- ============================================================================
-- SECTION E: PERFORMANCE ANALYSIS
-- ============================================================================

-- E.1: Check index usage for RLS policy evaluation
EXPLAIN (ANALYZE, BUFFERS)
SELECT COUNT(*) 
FROM patients 
WHERE clinic_id = '550e8400-e29b-41d4-a716-446655440001'::uuid;

-- E.2: Check index on clinic_id exists and is used
SELECT 
  'PERFORMANCE CHECK' as check_group,
  'clinic_id Index' as check_name,
  indexname,
  idx_scan as times_used,
  'Should exist and be used' as note
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
  AND indexname LIKE 'idx_patients_clinic%'
ORDER BY idx_scan DESC;

-- E.3: Summary of all indexes
SELECT 
  'INDEX SUMMARY' as check_group,
  COUNT(*) as total_indexes,
  'Should be 18+' as expected
FROM pg_indexes
WHERE schemaname = 'public'
  AND (
    indexname LIKE 'idx_%clinic%'
    OR indexname LIKE 'idx_%user%'
  );

-- ============================================================================
-- SECTION F: CONFIGURATION CHECK
-- ============================================================================

-- F.1: Verify RLS is not completely disabled globally
SELECT 
  'CONFIGURATION CHECK' as check_group,
  'RLS Global Config' as check_name,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM pg_class 
      WHERE relname = 'patients' AND relrowsecurity = true
    ) THEN 'RLS Enabled on patients' 
    ELSE 'RLS Disabled' 
  END as status;

-- F.2: List all policies with their conditions
SELECT 
  'POLICY AUDIT' as check_group,
  tablename,
  policyname,
  cmd as operation,
  permissive,
  CASE WHEN qual IS NOT NULL THEN 'Has USING clause' ELSE 'Missing USING' END as has_condition
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('patients', 'billing_invoices', 'clinic_employees')
ORDER BY tablename, cmd;

-- ============================================================================
-- SECTION G: RESULTS SUMMARY
-- ============================================================================

-- G.1: Summary report
WITH check_results AS (
  SELECT 'RLS Enabled on 19 tables' as check_item, 'System Dependent' as result
  UNION ALL
  SELECT 'Policies Created (80+)', CASE WHEN (
    SELECT COUNT(*) FROM pg_policies WHERE schemaname = 'public'
  ) >= 80 THEN '✅ PASS' ELSE '❌ FAIL' END
  UNION ALL
  SELECT 'Indexes Created (18+)', CASE WHEN (
    SELECT COUNT(*) FROM pg_indexes 
    WHERE schemaname = 'public' AND (indexname LIKE 'idx_%clinic%' OR indexname LIKE 'idx_%user%')
  ) >= 18 THEN '✅ PASS' ELSE '❌ FAIL' END
  UNION ALL
  SELECT 'Cross-Clinic SELECT Blocked', '✅ PASS (if Test C.1 returned 0 rows)'
  UNION ALL
  SELECT 'Cross-Clinic INSERT Blocked', '✅ PASS (if INSERT raised RLS error)'
  UNION ALL
  SELECT 'Own-Clinic Access Works', '✅ PASS (if Test C.2 returned >0 rows)'
  UNION ALL
  SELECT 'Index Performance <5ms', 'Check EXPLAIN ANALYZE output (timing)'
)
SELECT 
  'VALIDATION SUMMARY' as section,
  check_item,
  result
FROM check_results
ORDER BY check_item;

-- ============================================================================
-- CLEANUP (Optional after testing)
-- ============================================================================

-- D.1: Remove test patient (comment out if you want to keep test data)
-- DELETE FROM patients WHERE id LIKE 'patient-test%';
-- DELETE FROM billing_invoices WHERE id LIKE 'invoice-test%';
-- DELETE FROM communication_sms_logs WHERE id LIKE 'sms-test%';

-- ============================================================================
-- FINAL CHECKLIST
-- ============================================================================
-- 
-- After running this script, verify:
--
-- ✅ DEPLOYMENT VERIFICATION (Section A):
--    [ ] A.1: RLS enabled on 19 tables → Shows row count = 19
--    [ ] A.2: Total policies >= 80
--    [ ] A.3: Each critical table has 4+ policies
--    [ ] A.4: Performance indexes >= 18
--
-- ✅ NEGATIVE TESTS (Section C):
--    [ ] C.1: Clinic A → Clinic B patients = 0 rows
--    [ ] C.2: Clinic A → Clinic A patients = 1+ rows
--    [ ] C.3: Clinic B → Clinic A patients = 0 rows
--    [ ] C.4: Clinic A → Clinic B billing = 0 rows
--    [ ] C.5: Clinic A → Clinic B SMS = 0 rows
--
-- ✅ INSERTION TEST (Section D):
--    [ ] D.1: Cross-clinic INSERT raises RLS error
--
-- ✅ PERFORMANCE (Section E):
--    [ ] E.1: EXPLAIN ANALYZE shows <5ms execution (or <10ms for large tables)
--    [ ] E.2: Index is being used (idx_scan > 0)
--    [ ] E.3: 18+ indexes exist
--
-- ✅ CONFIGURATION (Section F):
--    [ ] F.1: RLS is enabled
--    [ ] F.2: Policies have conditions (USING clause)
--
-- If all checks pass: ✅ RLS IS WORKING CORRECTLY
-- If any check fails: ❌ Review troubleshooting section
--
-- ============================================================================

