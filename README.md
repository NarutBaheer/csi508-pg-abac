# pg_abac: Attribute-Based Access Control Policy Engine for PostgreSQL

## Course Information

**Course:** ICSI508 – Database Systems I  
**Project Topic:** Attribute-Based Access Control (ABAC) Policy Engine  
**Team Members:**

- Baheer Noori
- Schuyler E. Deno

## Project Overview

`pg_abac` is a PostgreSQL extension that implements a simple Attribute-Based Access Control (ABAC) policy engine using PostgreSQL Row-Level Security (RLS).

The extension allows database administrators to define access-control rules based on user attributes and row attributes. Instead of hardcoding access rules directly into every query, the system stores policies in metadata tables and applies them dynamically through an RLS policy.

For example, a user may only see employee rows where:

```text
user.department = row.department
AND user.region = row.region
AND user.status = 'active'
```

This project demonstrates how PostgreSQL extensions, C functions, metadata-driven authorization, and Row-Level Security can work together to enforce dynamic access-control policies.

## Core Features

- Stores user/subject attributes such as department, region, and status.
- Stores ABAC policy rules in a metadata table.
- Supports equality comparison using a C helper function.
- Supports row-column rules such as `user.department = row.department`.
- Supports constant-value rules such as `user.status = 'active'`.
- Supports multiple rules per table using logical AND behavior.
- Uses PostgreSQL Row-Level Security to filter visible rows.
- Includes a test suite for correctness.
- Includes a pgbench benchmark for performance evaluation.

## Project Structure

```text
pg_abac/
├── Makefile
├── pg_abac.control
├── pg_abac.c
├── README.md
├── sql/
│   └── pg_abac--1.0.sql
├── test/
│   └── test.sql
├── demo/
│   └── demo.sql
└── benchmark/
    ├── setup_benchmark.sql
    ├── baseline.sql
    ├── abac_query.sql
    ├── run_benchmark.sh
    └── results.md
```

## Main Database Objects

### `abac_user_attributes`

Stores attributes for database users.

```sql
CREATE TABLE abac_user_attributes (
    username text NOT NULL,
    attribute_name text NOT NULL,
    attribute_value text NOT NULL,
    PRIMARY KEY (username, attribute_name)
);
```

Example:

```sql
SELECT abac_set_user_attribute('employee_user', 'department', 'Finance');
SELECT abac_set_user_attribute('employee_user', 'region', 'NY');
SELECT abac_set_user_attribute('employee_user', 'status', 'active');
```

### `abac_policy_rules`

Stores policy rules for protected tables.

```sql
CREATE TABLE abac_policy_rules (
    policy_id bigserial PRIMARY KEY,
    table_name text NOT NULL,
    column_name text,
    attribute_name text NOT NULL,
    operator text NOT NULL DEFAULT '=',
    constant_value text,
    is_constant_check boolean NOT NULL DEFAULT false
);
```

Example row-column rule:

```sql
SELECT abac_add_policy_rule('employees', 'department', 'department', '=');
```

This means:

```text
user.department = row.department
```

Example constant-value rule:

```sql
SELECT abac_add_policy_rule('employees', NULL, 'status', '=', 'active', true);
```

This means:

```text
user.status = 'active'
```

## C Helper Function

The extension includes one C helper function:

```sql
abac_text_eq(left_value text, right_value text)
```

This function compares two text values and returns `true` if they are equal.

Example:

```sql
SELECT abac_text_eq('Finance', 'Finance');
-- returns true

SELECT abac_text_eq('Finance', 'HR');
-- returns false
```

The C code is located in:

```text
pg_abac.c
```

## Main ABAC Function

The main policy-checking function is:

```sql
abac_check_access(p_table_name text, p_row_data jsonb)
```

This function checks all policy rules for a table. If every rule is satisfied, it returns `true`. If any rule fails, it returns `false`.

Multiple rules are combined using logical AND behavior.

Example RLS policy:

```sql
CREATE POLICY employees_abac_policy
ON employees
FOR SELECT
USING (abac_check_access('employees', to_jsonb(employees)));
```

## Installation Guide

### 1. Build the extension

From the project directory:

```bash
make PG_CONFIG=/opt/homebrew/opt/postgresql@16/bin/pg_config
```

### 2. Install the extension

```bash
make install PG_CONFIG=/opt/homebrew/opt/postgresql@16/bin/pg_config
```

### 3. Start PostgreSQL

For this project, PostgreSQL was run on port `5433` to avoid conflict with another local PostgreSQL server:

```bash
/opt/homebrew/opt/postgresql@16/bin/pg_ctl \
-D /opt/homebrew/var/postgresql@16 \
-o "-p 5433" \
-l /opt/homebrew/var/postgresql@16/server.log start
```

### 4. Create a database

```bash
/opt/homebrew/opt/postgresql@16/bin/createdb -p 5433 abac_test
```

### 5. Open the database

```bash
/opt/homebrew/opt/postgresql@16/bin/psql -p 5433 abac_test
```

### 6. Create the extension

Inside `psql`:

```sql
CREATE EXTENSION pg_abac;
```

Check that it installed:

```sql
\dx
```

## Usage Example

Create a protected table:

```sql
CREATE TABLE employees (
    employee_id serial PRIMARY KEY,
    employee_name text NOT NULL,
    department text NOT NULL,
    region text NOT NULL,
    clearance_level int NOT NULL
);
```

Insert sample data:

```sql
INSERT INTO employees (employee_name, department, region, clearance_level)
VALUES
('John Smith', 'Finance', 'NY', 2),
('Maria Lopez', 'HR', 'NY', 1),
('David Chen', 'Finance', 'CA', 3),
('Aisha Khan', 'Finance', 'NY', 1);
```

Create a normal user:

```sql
CREATE ROLE employee_user LOGIN;
```

Assign user attributes:

```sql
SELECT abac_set_user_attribute('employee_user', 'department', 'Finance');
SELECT abac_set_user_attribute('employee_user', 'region', 'NY');
SELECT abac_set_user_attribute('employee_user', 'status', 'active');
```

Create ABAC policy rules:

```sql
SELECT abac_add_policy_rule('employees', 'department', 'department', '=');
SELECT abac_add_policy_rule('employees', 'region', 'region', '=');
SELECT abac_add_policy_rule('employees', NULL, 'status', '=', 'active', true);
```

Enable RLS:

```sql
ALTER TABLE employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE employees FORCE ROW LEVEL SECURITY;

CREATE POLICY employees_abac_policy
ON employees
FOR SELECT
USING (abac_check_access('employees', to_jsonb(employees)));
```

Grant permissions:

```sql
GRANT USAGE ON SCHEMA public TO employee_user;
GRANT SELECT ON employees TO employee_user;
GRANT SELECT ON abac_user_attributes TO employee_user;
GRANT SELECT ON abac_policy_rules TO employee_user;
GRANT EXECUTE ON FUNCTION abac_check_access(text, jsonb) TO employee_user;
GRANT EXECUTE ON FUNCTION abac_text_eq(text, text) TO employee_user;
```

Test as the restricted user:

```sql
SET ROLE employee_user;
SELECT * FROM employees;
RESET ROLE;
```

Expected visible rows:

```text
John Smith    Finance    NY
Aisha Khan    Finance    NY
```

The user cannot see rows from other departments or regions.

## Demo Script

The demo script is located at:

```text
demo/demo.sql
```

Run it with:

```bash
/opt/homebrew/opt/postgresql@16/bin/psql -p 5433 abac_test -f demo/demo.sql
```

The demo shows:

1. The owner can see all rows.
2. The restricted user only sees rows allowed by ABAC/RLS.

## Test Suite

The test suite is located at:

```text
test/test.sql
```

Run it with:

```bash
/opt/homebrew/opt/postgresql@16/bin/psql -p 5433 abac_test -f test/test.sql
```

The test suite checks:

- extension loading,
- C helper function behavior,
- table creation,
- user attribute storage,
- policy rule storage,
- ABAC access evaluation,
- RLS filtering for a matching user,
- RLS filtering for a blocked user.

A successful test run shows `result = t` for all major tests.

## Benchmark Methodology

The benchmark compares two approaches:

1. **Baseline SQL query:** A normal SQL query using a direct `WHERE` clause.
2. **ABAC/RLS query:** A query executed as a restricted user where PostgreSQL RLS calls `abac_check_access()` for each row.

The benchmark table contains 100,000 rows.

Benchmark setup file:

```text
benchmark/setup_benchmark.sql
```

Baseline query:

```text
benchmark/baseline.sql
```

ABAC/RLS query:

```text
benchmark/abac_query.sql
```

Benchmark runner:

```text
benchmark/run_benchmark.sh
```

Run the benchmark:

```bash
./benchmark/run_benchmark.sh
```

## Benchmark Results

The benchmark was run using PostgreSQL 16.13 and `pgbench`.

| Test Case | Transactions Processed | Average Latency | TPS |
|---|---:|---:|---:|
| Baseline SQL Query | 2,384 | 4.196 ms | 238.305464 |
| ABAC/RLS Query | 15 | 701.166 ms | 1.426195 |

## Benchmark Analysis

The baseline SQL query was much faster because it used a direct `WHERE` condition on table columns.

The ABAC/RLS query was slower because PostgreSQL had to evaluate the row-level security policy for each row. The policy calls `abac_check_access()`, which checks metadata tables and compares user attributes against row values.

This result shows the tradeoff between flexibility and performance. The ABAC approach is more dynamic and easier to manage through metadata, but it introduces additional query overhead.

Possible future improvements include:

- caching user attributes,
- reducing repeated metadata lookups,
- precomputing active policies,
- adding indexes on metadata tables,
- implementing more logic in C.

## Limitations

This version focuses on a clear and manageable ABAC design. Current limitations include:

- only equality comparison is supported,
- policies are evaluated row by row,
- metadata lookups are repeated during query execution,
- no support yet for operators such as `<`, `>`, `LIKE`, or `IN`,
- no caching layer is implemented.

## Future Work

Future versions could add:

- ordered comparisons such as `<` and `>`,
- pattern matching using `LIKE`,
- set membership using `IN`,
- C-based caching for user attributes,
- better indexing strategies,
- administrative functions for deleting or updating policy rules,
- support for multiple logical groups beyond simple AND logic.

## AI Disclosure

AI assistance was used as a collaborative tool during the design, debugging, and documentation process. It helped with project planning, generating initial SQL/C code structure, debugging build errors, creating test scripts, and drafting documentation.

All generated code was reviewed, compiled, installed, and tested manually. The project team remains responsible for understanding and explaining every file, function, SQL statement, and design choice in the final repository.
