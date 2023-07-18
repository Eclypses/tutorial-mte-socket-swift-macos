/*******************************************************************************
 * The MIT License (MIT)
 *
 * Copyright (c) Eclypses, Inc.
 *
 * All rights reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *******************************************************************************/
#ifndef MTESUPPORT_WRAP_ECDH_H
#define MTESUPPORT_WRAP_ECDH_H

#include "platform.h"

#include <stddef.h>
#include <stdint.h>

#include "mtesupport_ecdh.h"



#ifdef __cplusplus
extern "C" {
#endif



/****************************************************************************
 * Wrapper function for:
 * typedef int(*ecdh_p256_get_entropy)
              (void *context, byte_array entropy_bytes);
 ****************************************************************************/
typedef int32_t(*ecdh_p256_wrap_get_entropy)(void *context,
                                             uint8_t *entropy_data,
                                             uint32_t entropy_size);



/****************************************************************************
 * Wrapper function for:
 * ecdh_p256_create_keypair(byte_array *private_key,
                            byte_array *public_key,
                            ecdh_p256_get_entropy entropy_cb,
                            void *entropy_context);
 ****************************************************************************/
extern ATTR_SHARED int32_t ecdh_p256_wrap_create_keypair
                           (uint8_t *private_key_data,
                            uint32_t *private_key_size,
                            uint8_t *public_key_data,
                            uint32_t *public_key_size,
                            ecdh_p256_wrap_get_entropy entropy_cb,
                            void *entropy_context);



/****************************************************************************
 * Wrapper function for:
 * ecdh_p256_create_secret(const byte_array private_key,
 *                         const byte_array peer_public_key,
 *                         byte_array *secret);
 ****************************************************************************/
extern ATTR_SHARED int32_t ecdh_p256_wrap_create_secret
                           (const uint8_t *private_key_data,
                            uint32_t private_key_size,
                            const uint8_t *peer_public_key_data,
                            uint32_t peer_public_key_size,
                            uint8_t *secret_data, uint32_t *secret_size);



/****************************************************************************
 * Wrapper function for:
 * void ecdh_p256_zeroize(void *s, size_t n);
 ****************************************************************************/
extern ATTR_SHARED void ecdh_p256_wrap_zeroize(void *s, uint32_t n);



/****************************************************************************
 * Wrapper function for:
 * ecdh_p256_random(byte_array output);
 ****************************************************************************/
extern ATTR_SHARED int32_t ecdh_p256_wrap_random(uint8_t *output_data,
                                                 uint32_t output_size);



#ifdef __cplusplus
}
#endif

#endif /* MTESUPPORT_WRAP_ECDH_H */
