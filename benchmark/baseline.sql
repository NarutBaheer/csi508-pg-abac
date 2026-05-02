-- benchmark/baseline.sql
-- Baseline query without using the ABAC policy function.

SELECT COUNT(*)
FROM bench_employees
WHERE department = 'Finance'
  AND region = 'NY';
