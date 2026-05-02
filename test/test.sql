-- test/test.sql
-- Test suite for pg_abac.
-- This script checks the extension, helper function, metadata tables,
-- ABAC rule evaluation, and Row-Level Security behavior.

CREATE EXTENSION IF NOT EXISTS pg_abac;

-- ============================================================
-- Cleanup from previous test runs
-- ============================================================

DROP TABLE IF EXISTS test_employees CASCADE;

DELETE FROM abac_policy_rules
WHERE table_name = 'test_employees';

DELETE FROM abac_user_attributes
WHERE username IN ('abac_test_user', 'abac_blocked_user');

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'abac_test_user') THEN
        EXECUTE 'DROP OWNED BY abac_test_user';
        EXECUTE 'DROP ROLE abac_test_user';
    END IF;

    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'abac_blocked_user') THEN
        EXECUTE 'DROP OWNED BY abac_blocked_user';
        EXECUTE 'DROP ROLE abac_blocked_user';
    END IF;
END;
$$;

-- ============================================================
-- Test 1: C helper function
-- ============================================================

SELECT 'Test 1A: abac_text_eq should return true' AS test_name,
       abac_text_eq('Finance', 'Finance') AS result;

SELECT 'Test 1B: abac_text_eq should return false' AS test_name,
       NOT abac_text_eq('Finance', 'HR') AS result;

-- ============================================================
-- Test 2: Create sample table
-- ============================================================

CREATE TABLE test_employees (
    employee_id serial PRIMARY KEY,
    employee_name text NOT NULL,
    department text NOT NULL,
    region text NOT NULL,
    clearance_level int NOT NULL
);

INSERT INTO test_employees (employee_name, department, region, clearance_level)
VALUES
('John Smith', 'Finance', 'NY', 2),
('Maria Lopez', 'HR', 'NY', 1),
('David Chen', 'Finance', 'CA', 3),
('Aisha Khan', 'Finance', 'NY', 1);

SELECT 'Test 2: table should contain 4 rows' AS test_name,
       COUNT(*) = 4 AS result
FROM test_employees;

-- ============================================================
-- Test 3: Attribute management
-- ============================================================

CREATE ROLE abac_test_user LOGIN;
CREATE ROLE abac_blocked_user LOGIN;

SELECT abac_set_user_attribute('abac_test_user', 'department', 'Finance');
SELECT abac_set_user_attribute('abac_test_user', 'region', 'NY');
SELECT abac_set_user_attribute('abac_test_user', 'status', 'active');

SELECT abac_set_user_attribute('abac_blocked_user', 'department', 'HR');
SELECT abac_set_user_attribute('abac_blocked_user', 'region', 'CA');
SELECT abac_set_user_attribute('abac_blocked_user', 'status', 'inactive');

SELECT 'Test 3: attributes should be stored' AS test_name,
       COUNT(*) = 6 AS result
FROM abac_user_attributes
WHERE username IN ('abac_test_user', 'abac_blocked_user');

-- ============================================================
-- Test 4: Policy rule management
-- ============================================================

SELECT abac_add_policy_rule('test_employees', 'department', 'department', '=');
SELECT abac_add_policy_rule('test_employees', 'region', 'region', '=');
SELECT abac_add_policy_rule('test_employees', NULL, 'status', '=', 'active', true);

SELECT 'Test 4: policy rules should be stored' AS test_name,
       COUNT(*) = 3 AS result
FROM abac_policy_rules
WHERE table_name = 'test_employees';

GRANT USAGE ON SCHEMA public TO abac_test_user;
GRANT SELECT ON test_employees TO abac_test_user;
GRANT SELECT ON abac_user_attributes TO abac_test_user;
GRANT SELECT ON abac_policy_rules TO abac_test_user;
GRANT EXECUTE ON FUNCTION abac_check_access(text, jsonb) TO abac_test_user;
GRANT EXECUTE ON FUNCTION abac_text_eq(text, text) TO abac_test_user;

GRANT USAGE ON SCHEMA public TO abac_blocked_user;
GRANT SELECT ON test_employees TO abac_blocked_user;
GRANT SELECT ON abac_user_attributes TO abac_blocked_user;
GRANT SELECT ON abac_policy_rules TO abac_blocked_user;
GRANT EXECUTE ON FUNCTION abac_check_access(text, jsonb) TO abac_blocked_user;
GRANT EXECUTE ON FUNCTION abac_text_eq(text, text) TO abac_blocked_user;

-- ============================================================
-- Test 5: ABAC function result before RLS
-- ============================================================

SET ROLE abac_test_user;

SELECT 'Test 5: matching rows should be allowed before RLS' AS test_name,
       COUNT(*) = 2 AS result
FROM test_employees
WHERE abac_check_access('test_employees', to_jsonb(test_employees));

RESET ROLE;

-- ============================================================
-- Test 6: RLS behavior
-- ============================================================

ALTER TABLE test_employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE test_employees FORCE ROW LEVEL SECURITY;

CREATE POLICY test_employees_abac_policy
ON test_employees
FOR SELECT
USING (abac_check_access('test_employees', to_jsonb(test_employees)));

GRANT USAGE ON SCHEMA public TO abac_test_user;
GRANT SELECT ON test_employees TO abac_test_user;
GRANT SELECT ON abac_user_attributes TO abac_test_user;
GRANT SELECT ON abac_policy_rules TO abac_test_user;
GRANT EXECUTE ON FUNCTION abac_check_access(text, jsonb) TO abac_test_user;
GRANT EXECUTE ON FUNCTION abac_text_eq(text, text) TO abac_test_user;

GRANT USAGE ON SCHEMA public TO abac_blocked_user;
GRANT SELECT ON test_employees TO abac_blocked_user;
GRANT SELECT ON abac_user_attributes TO abac_blocked_user;
GRANT SELECT ON abac_policy_rules TO abac_blocked_user;
GRANT EXECUTE ON FUNCTION abac_check_access(text, jsonb) TO abac_blocked_user;
GRANT EXECUTE ON FUNCTION abac_text_eq(text, text) TO abac_blocked_user;

SET ROLE abac_test_user;

SELECT 'Test 6A: abac_test_user should see 2 rows through RLS' AS test_name,
       COUNT(*) = 2 AS result
FROM test_employees;

RESET ROLE;

SET ROLE abac_blocked_user;

SELECT 'Test 6B: abac_blocked_user should see 0 rows through RLS' AS test_name,
       COUNT(*) = 0 AS result
FROM test_employees;

RESET ROLE;

-- ============================================================
-- Final visible result
-- ============================================================

SELECT 'All pg_abac tests completed' AS status;
