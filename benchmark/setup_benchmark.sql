-- benchmark/setup_benchmark.sql
-- Creates benchmark data for pg_abac performance testing.

DROP TABLE IF EXISTS bench_employees CASCADE;

DELETE FROM abac_policy_rules
WHERE table_name = 'bench_employees';

DELETE FROM abac_user_attributes
WHERE username = 'bench_user';

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'bench_user') THEN
        EXECUTE 'DROP OWNED BY bench_user';
        EXECUTE 'DROP ROLE bench_user';
    END IF;
END;
$$;

CREATE TABLE bench_employees (
    employee_id serial PRIMARY KEY,
    employee_name text NOT NULL,
    department text NOT NULL,
    region text NOT NULL,
    clearance_level int NOT NULL
);

INSERT INTO bench_employees (employee_name, department, region, clearance_level)
SELECT
    'Employee ' || gs,
    CASE WHEN gs % 2 = 0 THEN 'Finance' ELSE 'HR' END,
    CASE WHEN gs % 3 = 0 THEN 'NY' ELSE 'CA' END,
    (gs % 5) + 1
FROM generate_series(1, 100000) AS gs;

CREATE ROLE bench_user LOGIN;

SELECT abac_set_user_attribute('bench_user', 'department', 'Finance');
SELECT abac_set_user_attribute('bench_user', 'region', 'NY');
SELECT abac_set_user_attribute('bench_user', 'status', 'active');

SELECT abac_add_policy_rule('bench_employees', 'department', 'department', '=');
SELECT abac_add_policy_rule('bench_employees', 'region', 'region', '=');
SELECT abac_add_policy_rule('bench_employees', NULL, 'status', '=', 'active', true);

ALTER TABLE bench_employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE bench_employees FORCE ROW LEVEL SECURITY;

CREATE POLICY bench_employees_abac_policy
ON bench_employees
FOR SELECT
USING (abac_check_access('bench_employees', to_jsonb(bench_employees)));

GRANT USAGE ON SCHEMA public TO bench_user;
GRANT SELECT ON bench_employees TO bench_user;
GRANT SELECT ON abac_user_attributes TO bench_user;
GRANT SELECT ON abac_policy_rules TO bench_user;
GRANT EXECUTE ON FUNCTION abac_check_access(text, jsonb) TO bench_user;
GRANT EXECUTE ON FUNCTION abac_text_eq(text, text) TO bench_user;

SELECT COUNT(*) AS total_rows FROM bench_employees;
