#ifndef MLS_H
#define MLS_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

void mls_free_string(char *value);


char *mls_identity_json(const char *request_json, char **error_out);








#ifdef __cplusplus
}
#endif

#endif
