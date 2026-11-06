#ifndef CHAT_OPENMLS_H
#define CHAT_OPENMLS_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

void chat_openmls_free_string(char *value);

char *chat_openmls_create_key_package_json(const char *request_json, char **error_out);

char *chat_openmls_identity_json(const char *request_json, char **error_out);

char *chat_openmls_store_json(const char *request_json, char **error_out);

char *chat_openmls_group_create_json(const char *request_json, char **error_out);

char *chat_openmls_group_add_members_json(const char *request_json, char **error_out);

char *chat_openmls_group_remove_members_json(const char *request_json, char **error_out);

char *chat_openmls_group_create_message_json(const char *request_json, char **error_out);

char *chat_openmls_group_process_json(const char *request_json, char **error_out);

char *chat_openmls_group_state_json(const char *request_json, char **error_out);

#ifdef __cplusplus
}
#endif

#endif
