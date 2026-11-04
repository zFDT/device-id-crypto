#include "device_encrypt_optimized.h"
#include <string.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <openssl/aes.h>
#include <openssl/evp.h>
#include <time.h>

// Base64URL编码表
static const char base64url_chars[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";

// 获取2024年UTC基准时间戳
static uint32_t get_base_timestamp_2024() {
    struct tm base_tm = {0};
    base_tm.tm_year = 2024 - 1900;
    base_tm.tm_mon = 0;
    base_tm.tm_mday = 1;
    base_tm.tm_hour = 0;
    base_tm.tm_min = 0;
    base_tm.tm_sec = 0;
    base_tm.tm_isdst = 0;
    time_t t = timegm(&base_tm);
    return (uint32_t)t;
}

// 生成时间戳字节（8字节，前4字节为0，后4字节为相对时间戳）
static void get_time_bytes(uint32_t timestamp, uint8_t *out8) {
    uint32_t base = get_base_timestamp_2024();
    uint32_t rel = timestamp - base;
    memset(out8, 0, 4);
    out8[4] = (rel >> 24) & 0xFF;
    out8[5] = (rel >> 16) & 0xFF;
    out8[6] = (rel >> 8) & 0xFF;
    out8[7] = rel & 0xFF;
}

// 解析时间戳字节
static uint32_t parse_time_bytes(const uint8_t *in8) {
    uint32_t rel = (in8[4] << 24) | (in8[5] << 16) | (in8[6] << 8) | in8[7];
    return get_base_timestamp_2024() + rel;
}

// Base64URL编码
static int base64url_encode(const uint8_t *src, size_t len, char *dst, size_t dst_size) {
    EVP_ENCODE_CTX *ctx = EVP_ENCODE_CTX_new();
    int outlen = 0, tmplen = 0;
    if (!ctx) return ENCRYPT_ERROR_ENCODE_FAILED;
    EVP_EncodeInit(ctx);
    EVP_EncodeUpdate(ctx, (unsigned char*)dst, &outlen, src, (int)len);
    EVP_EncodeFinal(ctx, (unsigned char*)dst + outlen, &tmplen);
    outlen += tmplen;
    EVP_ENCODE_CTX_free(ctx);
    // 去除换行并替换为URL安全字符
    int j = 0;
    for (int i = 0; i < outlen; ++i) {
        if (dst[i] == '+') dst[j++] = '-';
        else if (dst[i] == '/') dst[j++] = '_';
        else if (dst[i] == '=') break;
        else if (dst[i] != '\n' && dst[i] != '\r') dst[j++] = dst[i];
    }
    dst[j] = '\0';
    return j;
}

// Base64URL解码
static int base64url_decode(const char *src, uint8_t *dst, size_t dst_size) {
    size_t len = strlen(src);
    char *tmp = (char*)malloc(len + 5);
    if (!tmp) return ENCRYPT_ERROR_DECODE_FAILED;
    for (size_t i = 0; i < len; ++i) {
        if (src[i] == '-') tmp[i] = '+';
        else if (src[i] == '_') tmp[i] = '/';
        else tmp[i] = src[i];
    }
    // 填充
    size_t pad = (4 - (len % 4)) % 4;
    for (size_t i = 0; i < pad; ++i) tmp[len + i] = '=';
    tmp[len + pad] = '\0';
    EVP_ENCODE_CTX *ctx = EVP_ENCODE_CTX_new();
    int outlen = 0, tmplen = 0;
    EVP_DecodeInit(ctx);
    EVP_DecodeUpdate(ctx, dst, &outlen, (unsigned char*)tmp, (int)(len + pad));
    EVP_DecodeFinal(ctx, dst + outlen, &tmplen);
    outlen += tmplen;
    EVP_ENCODE_CTX_free(ctx);
    free(tmp);
    return outlen;
}

// 设备加密
int encrypt_device(const char *device_id, uint32_t timestamp, const uint8_t *key,
                  char *out_token, size_t out_token_size) {
    if (!device_id || !key || !out_token) return ENCRYPT_ERROR_INVALID_PARAM;
    uint8_t plain[32] = {0};
    size_t devlen = strlen(device_id);
    if (devlen > 16) return ENCRYPT_ERROR_INVALID_PARAM;
    memcpy(plain, device_id, devlen);
    get_time_bytes(timestamp, plain + 16);
    // AES-128-ECB加密
    uint8_t cipher[32] = {0};
    AES_KEY aes_key;
    if (AES_set_encrypt_key(key, 128, &aes_key) < 0) return ENCRYPT_ERROR_AES_FAILED;
    AES_ecb_encrypt(plain, cipher, &aes_key, AES_ENCRYPT);
    // Base64URL编码
    int enclen = base64url_encode(cipher, 32, out_token, out_token_size);
    if (enclen <= 0) return ENCRYPT_ERROR_ENCODE_FAILED;
    return ENCRYPT_SUCCESS;
}

// 设备解密
int decrypt_device(const char *token, const uint8_t *key,
                  char *out_device_id, size_t out_device_id_size,
                  uint32_t *out_timestamp) {
    if (!token || !key || !out_device_id || !out_timestamp) return ENCRYPT_ERROR_INVALID_PARAM;
    uint8_t cipher[32] = {0};
    int cipherlen = base64url_decode(token, cipher, sizeof(cipher));
    if (cipherlen != 32) return ENCRYPT_ERROR_DECODE_FAILED;
    uint8_t plain[32] = {0};
    AES_KEY aes_key;
    if (AES_set_decrypt_key(key, 128, &aes_key) < 0) return ENCRYPT_ERROR_AES_FAILED;
    AES_ecb_encrypt(cipher, plain, &aes_key, AES_DECRYPT);
    memcpy(out_device_id, plain, 16);
    out_device_id[15] = '\0';
    *out_timestamp = parse_time_bytes(plain + 16);
    return ENCRYPT_SUCCESS;
}