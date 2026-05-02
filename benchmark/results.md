# pg_abac Benchmark Results

## Benchmark Setup

The benchmark used a table named `bench_employees` with 100,000 rows. Each row contains employee information, including department, region, and clearance level.

The ABAC policy allowed access only when:

- user.department = row.department
- user.region = row.region
- user.status = 'active'

The benchmark compared two approaches:

1. **Baseline SQL query:** A direct SQL query using a normal `WHERE` clause.
2. **ABAC/RLS query:** A query executed as a restricted user, where PostgreSQL Row-Level Security calls the `abac_check_access()` function for each row.

## Environment

- PostgreSQL version: 16.13
- Database: abac_test
- Port: 5433
- Benchmark tool: pgbench
- Duration: 10 seconds per benchmark
- Clients: 1
- Threads: 1

## Results

| Test Case | Transactions Processed | Average Latency | TPS |
|---|---:|---:|---:|
| Baseline SQL Query | 2,384 | 4.196 ms | 238.305464 |
| ABAC/RLS Query | 15 | 701.166 ms | 1.426195 |

## Analysis

The baseline query was much faster because it used a simple SQL `WHERE` clause directly on the table columns.

The ABAC/RLS query was slower because PostgreSQL had to evaluate the row-level security policy for each row. The policy calls `abac_check_access()`, which checks metadata tables and compares user attributes against row values. This adds overhead, but it provides a flexible and dynamic access-control mechanism.

The result shows the tradeoff between security flexibility and query performance. The extension successfully enforces dynamic ABAC rules, but future optimization could improve performance by caching user attributes or reducing repeated metadata lookups.
