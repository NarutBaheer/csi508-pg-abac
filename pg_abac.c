/*
 * pg_abac.c
 *
 * C helper functions for the pg_abac PostgreSQL extension.
 */

#include "postgres.h"
#include "fmgr.h"
#include "utils/builtins.h"

#include <string.h>

PG_MODULE_MAGIC;

PG_FUNCTION_INFO_V1(abac_text_eq);

/*
 * abac_text_eq(left_value text, right_value text)
 *
 * Returns true if two PostgreSQL text values are exactly equal.
 */
Datum
abac_text_eq(PG_FUNCTION_ARGS)
{
    text *left_text;
    text *right_text;
    char *left_value;
    char *right_value;
    bool result;

    left_text = PG_GETARG_TEXT_PP(0);
    right_text = PG_GETARG_TEXT_PP(1);

    left_value = text_to_cstring(left_text);
    right_value = text_to_cstring(right_text);

    result = (strcmp(left_value, right_value) == 0);

    PG_RETURN_BOOL(result);
}
