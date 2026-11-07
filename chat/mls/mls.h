#ifndef MLS_H
#define MLS_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

void mls_free_string(char *value);

char *mls_create_key_package_json(const char *request_json, char **error_out);

char *mls_identity_json(const char *request_json, char **error_out);

char *mls_store_json(const char *request_json, char **error_out);

char *mls_group_create_json(const char *request_json, char **error_out);

char *mls_group_add_members_json(const char *request_json, char **error_out);

char *mls_group_remove_members_json(const char *request_json, char **error_out);

char *mls_group_create_message_json(const char *request_json, char **error_out);

char *mls_group_process_json(const char *request_json, char **error_out);

char *mls_group_state_json(const char *request_json, char **error_out);

#ifdef __cplusplus
}
#endif

#endif
