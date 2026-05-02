# Makefile
#
# PostgreSQL extensions use PGXS — a build system that ships with PostgreSQL.
# It handles compiler flags, include paths, and install locations for you.
# You just declare what to build and where to find pg_config.

# MODULE_big: the name of the shared library to produce (pg_abac.so / .dylib)
MODULE_big  = pg_abac

# OBJS: the .o files to compile and link into the shared library.
# Add more files here if you split your C code across multiple files:
#   OBJS = pg_abac.o utils.o type_support.o
OBJS        = pg_abac.o

# EXTENSION: the name used in CREATE EXTENSION. Must match *.control filename.
EXTENSION   = pg_abac

# DATA: the SQL install script(s). PGXS will install these into the right place.
# Format: <extension>--<version>.sql
# For upgrades you also add:  pg_abac--1.0--1.1.sql
DATA        = sql/pg_abac--1.0.sql

# PGFILEDESC: optional human-readable description embedded in the library.
PGFILEDESC  = "pg_abac - Attribute-Based Access Control policy engine"

# ─── PGXS boilerplate — do not change these two lines ───────────────────────
# pg_config tells us where PostgreSQL is installed and how it was compiled.
# Override on the command line if pg_config is not in your PATH:
#   make PG_CONFIG=/usr/lib/postgresql/16/bin/pg_config
PG_CONFIG  ?= pg_config
PGXS       := $(shell $(PG_CONFIG) --pgxs)

# Disable LLVM bitcode generation
override with_llvm = no

include $(PGXS)
# ─────────────────────────────────────────────────────────────────────────────

# Common make targets (provided automatically by PGXS):
#
#   make              — compile pg_abac.so
#   make install      — install .so and SQL files into PostgreSQL's directories
#   make uninstall    — remove installed files
#   make clean        — delete compiled objects
