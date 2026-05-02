-- pg_abac--1.0.sql
--
-- Attribute-Based Access Control (ABAC) extension for PostgreSQL.
-- This file is loaded by running:
--     CREATE EXTENSION pg_abac;

\echo Use "CREATE EXTENSION pg_abac" to load this file. \quit

-- ============================================================
-- 1. Metadata table for user attributes
-- ============================================================

CREATE TABLE abac_user_attributes (
    username text NOT NULL,
    attribute_name text NOT NULL,
    attribute_value text NOT NULL,
    PRIMARY KEY (username, attribute_name)
);

COMMENT ON TABLE abac_user_attributes IS
'Stores subject/user attributes used by the ABAC policy engine.';

-- ============================================================
-- 2. Metadata table for policy rules
-- ============================================================

CREATE TABLE abac_policy_rules (
    policy_id bigserial PRIMARY KEY,
    table_name text NOT NULL,
    column_name text,
    attribute_name text NOT NULL,
    operator text NOT NULL DEFAULT '=',
    constant_value text,
    is_constant_check boolean NOT NULL DEFAULT false,
    CHECK (operator IN ('=')),
    CHECK (
        (is_constant_check = true AND constant_value IS NOT NULL)
        OR
        (is_constant_check = false AND column_name IS NOT NULL)
    )
);

COMMENT ON TABLE abac_policy_rules IS
'Stores ABAC rules that compare user attributes to row columns or constant values.';

-- ============================================================
-- 3. C helper function
-- ============================================================
-- This function will be implemented in pg_abac.c.
-- It compares two text values for equality.

CREATE FUNCTION abac_text_eq(left_value text, right_value text)
RETURNS boolean
LANGUAGE C
IMMUTABLE
STRICT
AS '$libdir/pg_abac', 'abac_text_eq';

COMMENT ON FUNCTION abac_text_eq(text, text) IS
'C helper function that compares two text values for equality.';

-- ============================================================
-- 4. Helper function to set or update user attributes
-- ============================================================

CREATE FUNCTION abac_set_user_attribute(
    p_username text,
    p_attribute_name text,
    p_attribute_value text
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO abac_user_attributes(username, attribute_name, attribute_value)
    VALUES (p_username, p_attribute_name, p_attribute_value)
    ON CONFLICT (username, attribute_name)
    DO UPDATE SET attribute_value = EXCLUDED.attribute_value;
END;
$$;

COMMENT ON FUNCTION abac_set_user_attribute(text, text, text) IS
'Adds or updates an attribute for a database user.';

-- ============================================================
-- 5. Helper function to add ABAC policy rules
-- ============================================================

CREATE FUNCTION abac_add_policy_rule(
    p_table_name text,
    p_column_name text,
    p_attribute_name text,
    p_operator text DEFAULT '=',
    p_constant_value text DEFAULT NULL,
    p_is_constant_check boolean DEFAULT false
)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO abac_policy_rules(
        table_name,
        column_name,
        attribute_name,
        operator,
        constant_value,
        is_constant_check
    )
    VALUES (
        p_table_name,
        p_column_name,
        p_attribute_name,
        p_operator,
        p_constant_value,
        p_is_constant_check
    );
END;
$$;

COMMENT ON FUNCTION abac_add_policy_rule(text, text, text, text, text, boolean) IS
'Adds an ABAC policy rule for a protected table.';

-- ============================================================
-- 6. Main ABAC access-checking function
-- ============================================================
-- This function is intended to be used inside a Row-Level Security policy.
--
-- Example:
-- CREATE POLICY employees_abac_policy
-- ON employees
-- USING (abac_check_access('employees', to_jsonb(employees)));

CREATE FUNCTION abac_check_access(
    p_table_name text,
    p_row_data jsonb
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    rule_record record;
    user_attribute_value text;
    row_column_value text;
BEGIN
    FOR rule_record IN
        SELECT *
        FROM abac_policy_rules
        WHERE table_name = p_table_name
        ORDER BY policy_id
    LOOP
        SELECT attribute_value
        INTO user_attribute_value
        FROM abac_user_attributes
        WHERE username = current_user
          AND attribute_name = rule_record.attribute_name;

        IF user_attribute_value IS NULL THEN
            RETURN false;
        END IF;

        IF rule_record.is_constant_check THEN
            IF NOT abac_text_eq(user_attribute_value, rule_record.constant_value) THEN
                RETURN false;
            END IF;
        ELSE
            row_column_value := p_row_data ->> rule_record.column_name;

            IF row_column_value IS NULL THEN
                RETURN false;
            END IF;

            IF NOT abac_text_eq(user_attribute_value, row_column_value) THEN
                RETURN false;
            END IF;
        END IF;
    END LOOP;

    RETURN true;
END;
$$;

COMMENT ON FUNCTION abac_check_access(text, jsonb) IS
'Checks whether the current user satisfies all ABAC rules for a row. Multiple rules are combined using AND logic.';
