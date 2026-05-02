#!/bin/bash

# benchmark/run_benchmark.sh
# Runs pgbench benchmarks for pg_abac.

DB_NAME="abac_test"
PORT="5433"
PG_BIN="/opt/homebrew/opt/postgresql@16/bin"

echo "Setting up benchmark data..."
$PG_BIN/psql -p $PORT $DB_NAME -f benchmark/setup_benchmark.sql

echo ""
echo "Running baseline benchmark..."
$PG_BIN/pgbench -p $PORT -n -T 10 -f benchmark/baseline.sql $DB_NAME

echo ""
echo "Running ABAC/RLS benchmark..."
$PG_BIN/pgbench -p $PORT -n -T 10 -f benchmark/abac_query.sql $DB_NAME
