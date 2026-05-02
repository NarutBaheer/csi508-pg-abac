-- demo/demo.sql
-- Demonstration script for pg_abac.
-- This script shows how the ABAC policy engine uses PostgreSQL Row-Level Security.

DROP TABLE IF EXISTS employees CASCADE;
DROP OWNED BY employee_user;
DROP ROLE IF EXISTS employee_user;

-- Create a sample protected table.
CREATE TABLE employees (
    employee_id serial PRIMARY KEY,
    employee_name text NOT NULL,
    department text NOT NULL,
    region text NOT NULL,
    clearance_level int NOT NULL
);

INSERT INTO employees (employee_name, department, region, clearance_level)
VALUES
('John Smith', 'Finance', 'NY', 2),
('Maria Lopez', 'HR', 'NY', 1),
('David Chen', 'Finance', 'CA', 3),
('Aisha Khan', 'Finance', 'NY', 1);

-- Create a normal user for RLS testing.
CREATE ROLE employee_user LOGIN;

-- Assign subject/user attributes.
SELECT abac_set_user_attribute('employee_user', 'department', 'Finance');
SELECT abac_set_user_attribute('employee_user', 'region', 'NY');
SELECT abac_set_user_attribute('employee_user', 'status', 'active');

-- Define ABAC rules for the employees table.
-- Rule 1: user.department must equal row.department.
SELECT abac_add_policy_rule('employees', 'department', 'department', '=');

-- Rule 2: user.region must equal row.region.
SELECT abac_add_policy_rule('employees', 'region', 'region', '=');

-- Rule 3: user.status must equal the constant value 'active'.
SELECT abac_add_policy_rule('employees', NULL, 'status', '=', 'active', true);

-- Enable and force Row-Level Security.
ALTER TABLE employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE employees FORCE ROW LEVEL SECURITY;

CREATE POLICY employees_abac_policy
ON employees
FOR SELECT
USING (abac_check_access('employees', to_jsonb(employees)));

-- Grant required permissions.
GRANT USAGE ON SCHEMA public TO employee_user;
GRANT SELECT ON employees TO employee_user;
GRANT SELECT ON abac_user_attributes TO employee_user;
GRANT SELECT ON abac_policy_rules TO employee_user;
GRANT EXECUTE ON FUNCTION abac_check_access(text, jsonb) TO employee_user;
GRANT EXECUTE ON FUNCTION abac_text_eq(text, text) TO employee_user;

-- Show all rows as the owner.
SELECT 'All rows as owner' AS test_case;
SELECT * FROM employees;

-- Show filtered rows as the normal user.
SET ROLE employee_user;

SELECT 'Rows visible to employee_user through ABAC/RLS' AS test_case;
SELECT current_user;
SELECT * FROM employees;

RESET ROLE;
