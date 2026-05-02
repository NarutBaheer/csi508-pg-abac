-- benchmark/abac_query.sql
-- ABAC/RLS query executed as bench_user.

SET ROLE bench_user;

SELECT COUNT(*)
FROM bench_employees;

RESET ROLE;
