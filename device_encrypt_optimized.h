#ifndef DEVICE_ENCRYPT_OPTIMIZED_H
#define DEVICE_ENCRYPT_OPTIMIZED_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

#define ENCRYPT_SUCCESS 0
#define ENCRYPT_ERROR_INVALID_PARAM -1
#define ENCRYPT_ERROR_AES_FAILED -2
#define ENCRYPT_ERROR_ENCODE_FAILED -3
#define ENCRYPT_ERROR_DECODE_FAILED -4

// 设备加密
int encrypt_device(const char *device_id, uint32_t timestamp, const uint8_t *key,
                  char *out_token, size_t out_token_size);

// 设备解密
int decrypt_device(const char *token, const uint8_t *key,
                  char *out_device_id, size_t out_device_id_size,
                  uint32_t *out_timestamp);

#ifdef __cplusplus
}
#endif

#endif // DEVICE_ENCRYPT_OPTIMIZED_H