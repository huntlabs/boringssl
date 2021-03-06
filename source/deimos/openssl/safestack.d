/* ====================================================================
 * Copyright (c) 1999 The OpenSSL Project.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1. Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in
 *   the documentation and/or other materials provided with the
 *   distribution.
 *
 * 3. All advertising materials mentioning features or use of this
 *   software must display the following acknowledgment:
 *   "This product includes software developed by the OpenSSL Project
 *   for use in the OpenSSL Toolkit. (http://www.openssl.org/)"
 *
 * 4. The names "OpenSSL Toolkit" and "OpenSSL Project" must not be used to
 *   endorse or promote products derived from this software without
 *   prior written permission. For written permission, please contact
 *   openssl-core@openssl.org.
 *
 * 5. Products derived from this software may not be called "OpenSSL"
 *   nor may "OpenSSL" appear in their names without prior written
 *   permission of the OpenSSL Project.
 *
 * 6. Redistributions of any form whatsoever must retain the following
 *   acknowledgment:
 *   "This product includes software developed by the OpenSSL Project
 *   for use in the OpenSSL Toolkit (http://www.openssl.org/)"
 *
 * THIS SOFTWARE IS PROVIDED BY THE OpenSSL PROJECT ``AS IS'' AND ANY
 * EXPRESSED OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE OpenSSL PROJECT OR
 * ITS CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
 * ====================================================================
 *
 * This product includes cryptographic software written by Eric Young
 * (eay@cryptsoft.com).  This product includes software written by Tim
 * Hudson (tjh@cryptsoft.com).
 *
 */

module deimos.openssl.safestack;

import deimos.openssl._d_util;

// Needed for types stacks are defined for.
import deimos.openssl.cms;
import deimos.openssl.srp;
import deimos.openssl.x509v3;

public import deimos.openssl.stack;

import std.format;


void* CHECKED_PTR_OF(type)(type* p) { return cast(void*) (1 ? p : null); }

/* In C++ we get problems because an explicit cast is needed from (void*)
 * we use CHECKED_STACK_OF to ensure the correct type is passed in the macros
 * below.
 */

_STACK* CHECKED_STACK_OF (type)(STACK_OF!type* p) { return cast(_STACK*) (1 ? p : null); }

ExternC!(void function(void*)) CHECKED_SK_FREE_FUNC(type)(ExternC!(void function(type*)) p) {
	return cast(typeof(return))(1 ? p : null);
}

ExternC!(void function(void*)) CHECKED_SK_FREE_FUNC2(type)(ExternC!(void function(type)) p) {
	return cast(typeof(return))(1 ? p : null);
}

ExternC!(void function(const(void)*, const(void)*)) CHECKED_SK_CMP_FUNC(type)(ExternC!(int function(const(type*)*, const(type*)*)) p) {
	return cast(typeof(return))(1 ? p : null);
}

// struct STACK_OF(type = void) { // void is an arbitrary default value for STACK_OF!()
//     _STACK stack;
// }

// Empty because we use STACK_OF directly as a struct.
mixin template PREDECLARE_STACK_OF(string type) {}
mixin template DECLARE_STACK_OF(T = void) {}
mixin template DECLARE_SPECIAL_STACK_OF(T, U) {}

// mixin template IMPLEMENT_STACK_OF(string type) {} /* nada (obsolete in new safestack approach)*/

alias stack_cmp_func = extern(C) int function(const void **a, const void **b);

alias STACK_OF(T = void) = _STACK;

string BORINGSSL_DEFINE_STACK_OF_IMPL(string name)() {
	string formatStr = `
	alias stack_%1$s_cmp_func = int function(const %1$s* *a, const %1$s* *b);

	STACK_OF!(%1$s) * sk_%1$s_new(stack_%1$s_cmp_func comp) {
		 return cast(STACK_OF!(%1$s) *)sk_new(cast(stack_cmp_func)comp);
	}

	STACK_OF!(%1$s) * sk_%1$s_new_null() {
		 return cast(STACK_OF!(%1$s) *)sk_new_null();
	}	
	`;

	return format(formatStr, name);
}


// DEFINE_STACK_OF defines |STACK_OF(type)| to be a stack whose elements are
// |type| *.
mixin template DEFINE_STACK_OF(T = void, string name = T.stringof ) {
	// mixin BORINGSSL_DEFINE_STACK_OF_IMPL!(name, T);
	enum str = BORINGSSL_DEFINE_STACK_OF_IMPL!(name); 
	mixin(str);
	
	// BORINGSSL_DEFINE_STACK_TRAITS(name, type, false)
}


/* Strings are special: normally an lhash entry will point to a single
 * (somewhat) mutable object. In the case of strings:
 *
 * a) Instead of a single char, there is an array of chars, NUL-terminated.
 * b) The string may have be immutable.
 *
 * So, they need their own declarations. Especially important for
 * type-checking tools, such as Deputy.
 *
 * In practice, however, it appears to be hard to have a const
 * string. For now, I'm settling for dealing with the fact it is a
 * string at all.
 */
alias char* OPENSSL_STRING;

alias const(char)* OPENSSL_CSTRING;

/* Confusingly, LHASH_OF!(STRING) deals with char** throughout, but
 * STACK_OF!(STRING) is really more like STACK_OF!(char), only, as
 * mentioned above, instead of a single char each entry is a
 * NUL-terminated array of chars. So, we have to implement STRING
 * specially for STACK_OF. This is dealt with in the autogenerated
 * macros below.
 */

mixin DECLARE_SPECIAL_STACK_OF!(OPENSSL_STRING, char);
/* Similarly, we sometimes use a block of characters, NOT
 * nul-terminated. These should also be distinguished from "normal"
 * stacks. */

alias void* OPENSSL_BLOCK;
mixin DECLARE_SPECIAL_STACK_OF!(OPENSSL_BLOCK, void);
/* SKM_sk_... stack macros are internal to safestack.h:
 * never use them directly, use sk_<type>_... instead */
template SKM_sk_new(type) { STACK_OF!type* SKM_sk_new()(ExternC!(int function(const(type*)*, const(type*)*)) cmp)
	{ return cast(STACK_OF!type*)sk_new(CHECKED_SK_CMP_FUNC(cmp)); }}
template SKM_sk_new_null(type) { STACK_OF!type* SKM_sk_new_null()()
	{ return cast(STACK_OF!type*)sk_new_null(); }}
template SKM_sk_free(type) { void SKM_sk_free()(STACK_OF!type* st)
	{ sk_free(CHECKED_STACK_OF!type(st)); }}
template SKM_sk_num(type) { int SKM_sk_num()(STACK_OF!type* st)
	{ return sk_num(CHECKED_STACK_OF!type(st)); }}
template SKM_sk_value(type) { type* SKM_sk_value()(STACK_OF!type* st, int i)
	{ return cast(type*)sk_value(CHECKED_STACK_OF!type(st), i); }}
template SKM_sk_set(type) { type* SKM_sk_set()(STACK_OF!type* st, int i, type* val)
	{ return cast(type*)sk_set(CHECKED_STACK_OF!type(st), i, CHECKED_PTR_OF(val)); }}
template SKM_sk_zero(type) { void SKM_sk_zero()(STACK_OF!type* st)
	{ sk_zero(CHECKED_STACK_OF!type(st)); }}
template SKM_sk_push(type) { int SKM_sk_push()(STACK_OF!type* st, type* val)
	{ return sk_push(CHECKED_STACK_OF!type(st), CHECKED_PTR_OF(val)); }}
template SKM_sk_unshift(type) { int SKM_sk_unshift()(STACK_OF!type* st, type* val)
	{ return sk_unshift(CHECKED_STACK_OF!type(st), CHECKED_PTR_OF(val)); }}
template SKM_sk_find(type) { int SKM_sk_find()(STACK_OF!type* st, type* val)
	{ return sk_find(CHECKED_STACK_OF!type(st), CHECKED_PTR_OF!type(val)); }}
template SKM_sk_find_ex(type) { int SKM_sk_find_ex()(STACK_OF!type* st, type* val)
	{ return sk_find_ex(CHECKED_STACK_OF!type(st), CHECKED_PTR_OF!type(val)); }}
template SKM_sk_delete(type) { type* SKM_sk_delete()(STACK_OF!type* st, int i)
	{ return cast(type*)sk_delete(CHECKED_STACK_OF!type(st), i); }}
template SKM_sk_delete_ptr(type) { type* SKM_sk_delete_ptr()(STACK_OF!type* st, type* ptr)
	{ return cast(type*)sk_delete_ptr(CHECKED_STACK_OF!type(st), CHECKED_PTR_OF!type(ptr)); }}
template SKM_sk_insert(type) { int SKM_sk_insert()(STACK_OF!type* st,type* val, int i)
	{ return sk_insert(CHECKED_STACK_OF!type(st), CHECKED_PTR_OF!type(val), i); }}
template SKM_sk_set_cmp_func(type) { ExternC!(int function(const(type*)*, const(type*)*)) SKM_sk_set_cmp_func(type)(STACK_OF!type* st, int function(const(type*)*, const(type*)*) cmp)
	{ return cast(typeof(return))sk_set_cmp_func(CHECKED_STACK_OF!type(st), CHECKED_SK_CMP_FUNC(cmp)); }}
template SKM_sk_dup(type) { STACK_OF!type* SKM_sk_dup()(STACK_OF!type* st)
	{ return cast(STACK_OF!type*)sk_dup(CHECKED_STACK_OF!type(st)); }}
template SKM_sk_pop_free(type) { void SKM_sk_pop_free()(STACK_OF!type* st, ExternC!(void function(type*)) free_func)
	{ return sk_pop_free(CHECKED_STACK_OF!type(st), CHECKED_SK_FREE_FUNC!type(free_func)); }}
template SKM_sk_shift(type) { type* SKM_sk_shift()(STACK_OF!type* st)
	{ return cast(type*)sk_shift(CHECKED_STACK_OF!type(st)); }}
template SKM_sk_pop(type) { type* SKM_sk_pop()(STACK_OF!type* st)
	{ return cast(type*)sk_pop(CHECKED_STACK_OF!type(st)); }}
template SKM_sk_sort(type) { void SKM_sk_sort()(STACK_OF!type* st)
	{ sk_sort(CHECKED_STACK_OF!type(st)); }}
template SKM_sk_is_sorted(type) { int SKM_sk_is_sorted()(STACK_OF!type* st)
	{ return sk_is_sorted(CHECKED_STACK_OF!type(st)); }}

template SKM_ASN1_SET_OF_d2i(type) {
	STACK_OF!type* SKM_ASN1_SET_OF_d2i()(STACK_OF!type** st,
		const(ubyte)** pp, c_long length, D2I_OF!type d2i_func,
		ExternC!(void function(type*)) free_func, int ex_tag, int ex_class
	) {
		return cast(STACK_OF!type*)d2i_ASN1_SET(
			cast(STACK_OF!OPENSSL_BLOCK**)CHECKED_PTR_OF!(STACK_OF!type*)(st),
			pp, length,
			CHECKED_D2I_OF!type(d2i_func),
			CHECKED_SK_FREE_FUNC!type(free_func),
			ex_tag, ex_class
		);
	}
}
template SKM_ASN1_SET_OF_i2d(type) {
	auto SKM_ASN1_SET_OF_i2d()(STACK_OF!(type)* st, ubyte** pp,
		 I2D_OF!type i2d_func, int ex_tag, int ex_class, int is_set
	) {
		return i2d_ASN1_SET(cast(STACK_OF!OPENSSL_BLOCK*)CHECKED_STACK_OF!type(st),
			pp, CHECKED_I2D_OF!type(i2d_func), ex_tag, ex_class, is_set);
	}
}
template SKM_ASN1_seq_pack(type) {
	ubyte* SKM_ASN1_seq_pack()(STACK_OF!type* st, I2D_OF!type i2d_func,
		ubyte** buf, int* len
	) {
		return ASN1_seq_pack(cast(STACK_OF!OPENSSL_BLOCK*)CHECKED_STACK_OF!type(st),
			CHECKED_I2D_OF!type(i2d_func), buf, len);
	}
}
template SKM_ASN1_seq_unpack(type) {
	STACK_OF!(type)* SKM_ASN1_seq_unpack()(const(ubyte)* buf, int len,
		D2I_OF!type d2i, ExternC!(void function(type*)) free_func
	) {
		return cast(STACK_OF!(type)*)ASN1_seq_unpack(buf, len,
			CHECKED_D2I_OF!type(d2i), CHECKED_SK_FREE_FUNC!type(free_func));
	}
}

// FIXME: This looks like a bug in the original headers, PKCS12_decrypt_d2i
// does not exist.
// #define SKM_PKCS12_decrypt_d2i(type, algor, d2i_func, free_func, pass, passlen, oct, seq) \
//	(STACK_OF!(type) *)PKCS12_decrypt_d2i(algor, \
//				CHECKED_D2I_OF(type, d2i_func), \
//				CHECKED_SK_FREE_FUNC(type, free_func), \
//				pass, passlen, oct, seq)

/* This block of defines is updated by util/mkstack.pl, please do not touch! */
alias SKM_sk_new!ACCESS_DESCRIPTION sk_ACCESS_DESCRIPTION_new;
alias SKM_sk_new_null!ACCESS_DESCRIPTION sk_ACCESS_DESCRIPTION_new_null;
alias SKM_sk_free!ACCESS_DESCRIPTION sk_ACCESS_DESCRIPTION_free;
alias SKM_sk_num!ACCESS_DESCRIPTION sk_ACCESS_DESCRIPTION_num;
alias SKM_sk_value!ACCESS_DESCRIPTION sk_ACCESS_DESCRIPTION_value;
alias SKM_sk_set!ACCESS_DESCRIPTION sk_ACCESS_DESCRIPTION_set;
alias SKM_sk_zero!ACCESS_DESCRIPTION sk_ACCESS_DESCRIPTION_zero;
alias SKM_sk_push!ACCESS_DESCRIPTION sk_ACCESS_DESCRIPTION_push;
alias SKM_sk_unshift!ACCESS_DESCRIPTION sk_ACCESS_DESCRIPTION_unshift;
alias SKM_sk_find!ACCESS_DESCRIPTION sk_ACCESS_DESCRIPTION_find;
alias SKM_sk_find_ex!ACCESS_DESCRIPTION sk_ACCESS_DESCRIPTION_find_ex;
alias SKM_sk_delete!ACCESS_DESCRIPTION sk_ACCESS_DESCRIPTION_delete;
alias SKM_sk_delete_ptr!ACCESS_DESCRIPTION sk_ACCESS_DESCRIPTION_delete_ptr;
alias SKM_sk_insert!ACCESS_DESCRIPTION sk_ACCESS_DESCRIPTION_insert;
alias SKM_sk_set_cmp_func!ACCESS_DESCRIPTION sk_ACCESS_DESCRIPTION_set_cmp_func;
alias SKM_sk_dup!ACCESS_DESCRIPTION sk_ACCESS_DESCRIPTION_dup;
alias SKM_sk_pop_free!ACCESS_DESCRIPTION sk_ACCESS_DESCRIPTION_pop_free;
alias SKM_sk_shift!ACCESS_DESCRIPTION sk_ACCESS_DESCRIPTION_shift;
alias SKM_sk_pop!ACCESS_DESCRIPTION sk_ACCESS_DESCRIPTION_pop;
alias SKM_sk_sort!ACCESS_DESCRIPTION sk_ACCESS_DESCRIPTION_sort;
alias SKM_sk_is_sorted!ACCESS_DESCRIPTION sk_ACCESS_DESCRIPTION_is_sorted;

alias SKM_sk_new!ASIdOrRange sk_ASIdOrRange_new;
alias SKM_sk_new_null!ASIdOrRange sk_ASIdOrRange_new_null;
alias SKM_sk_free!ASIdOrRange sk_ASIdOrRange_free;
alias SKM_sk_num!ASIdOrRange sk_ASIdOrRange_num;
alias SKM_sk_value!ASIdOrRange sk_ASIdOrRange_value;
alias SKM_sk_set!ASIdOrRange sk_ASIdOrRange_set;
alias SKM_sk_zero!ASIdOrRange sk_ASIdOrRange_zero;
alias SKM_sk_push!ASIdOrRange sk_ASIdOrRange_push;
alias SKM_sk_unshift!ASIdOrRange sk_ASIdOrRange_unshift;
alias SKM_sk_find!ASIdOrRange sk_ASIdOrRange_find;
alias SKM_sk_find_ex!ASIdOrRange sk_ASIdOrRange_find_ex;
alias SKM_sk_delete!ASIdOrRange sk_ASIdOrRange_delete;
alias SKM_sk_delete_ptr!ASIdOrRange sk_ASIdOrRange_delete_ptr;
alias SKM_sk_insert!ASIdOrRange sk_ASIdOrRange_insert;
alias SKM_sk_set_cmp_func!ASIdOrRange sk_ASIdOrRange_set_cmp_func;
alias SKM_sk_dup!ASIdOrRange sk_ASIdOrRange_dup;
alias SKM_sk_pop_free!ASIdOrRange sk_ASIdOrRange_pop_free;
alias SKM_sk_shift!ASIdOrRange sk_ASIdOrRange_shift;
alias SKM_sk_pop!ASIdOrRange sk_ASIdOrRange_pop;
alias SKM_sk_sort!ASIdOrRange sk_ASIdOrRange_sort;
alias SKM_sk_is_sorted!ASIdOrRange sk_ASIdOrRange_is_sorted;

alias SKM_sk_new!ASN1_GENERALSTRING sk_ASN1_GENERALSTRING_new;
alias SKM_sk_new_null!ASN1_GENERALSTRING sk_ASN1_GENERALSTRING_new_null;
alias SKM_sk_free!ASN1_GENERALSTRING sk_ASN1_GENERALSTRING_free;
alias SKM_sk_num!ASN1_GENERALSTRING sk_ASN1_GENERALSTRING_num;
alias SKM_sk_value!ASN1_GENERALSTRING sk_ASN1_GENERALSTRING_value;
alias SKM_sk_set!ASN1_GENERALSTRING sk_ASN1_GENERALSTRING_set;
alias SKM_sk_zero!ASN1_GENERALSTRING sk_ASN1_GENERALSTRING_zero;
alias SKM_sk_push!ASN1_GENERALSTRING sk_ASN1_GENERALSTRING_push;
alias SKM_sk_unshift!ASN1_GENERALSTRING sk_ASN1_GENERALSTRING_unshift;
alias SKM_sk_find!ASN1_GENERALSTRING sk_ASN1_GENERALSTRING_find;
alias SKM_sk_find_ex!ASN1_GENERALSTRING sk_ASN1_GENERALSTRING_find_ex;
alias SKM_sk_delete!ASN1_GENERALSTRING sk_ASN1_GENERALSTRING_delete;
alias SKM_sk_delete_ptr!ASN1_GENERALSTRING sk_ASN1_GENERALSTRING_delete_ptr;
alias SKM_sk_insert!ASN1_GENERALSTRING sk_ASN1_GENERALSTRING_insert;
alias SKM_sk_set_cmp_func!ASN1_GENERALSTRING sk_ASN1_GENERALSTRING_set_cmp_func;
alias SKM_sk_dup!ASN1_GENERALSTRING sk_ASN1_GENERALSTRING_dup;
alias SKM_sk_pop_free!ASN1_GENERALSTRING sk_ASN1_GENERALSTRING_pop_free;
alias SKM_sk_shift!ASN1_GENERALSTRING sk_ASN1_GENERALSTRING_shift;
alias SKM_sk_pop!ASN1_GENERALSTRING sk_ASN1_GENERALSTRING_pop;
alias SKM_sk_sort!ASN1_GENERALSTRING sk_ASN1_GENERALSTRING_sort;
alias SKM_sk_is_sorted!ASN1_GENERALSTRING sk_ASN1_GENERALSTRING_is_sorted;

alias SKM_sk_new!ASN1_INTEGER sk_ASN1_INTEGER_new;
alias SKM_sk_new_null!ASN1_INTEGER sk_ASN1_INTEGER_new_null;
alias SKM_sk_free!ASN1_INTEGER sk_ASN1_INTEGER_free;
alias SKM_sk_num!ASN1_INTEGER sk_ASN1_INTEGER_num;
alias SKM_sk_value!ASN1_INTEGER sk_ASN1_INTEGER_value;
alias SKM_sk_set!ASN1_INTEGER sk_ASN1_INTEGER_set;
alias SKM_sk_zero!ASN1_INTEGER sk_ASN1_INTEGER_zero;
alias SKM_sk_push!ASN1_INTEGER sk_ASN1_INTEGER_push;
alias SKM_sk_unshift!ASN1_INTEGER sk_ASN1_INTEGER_unshift;
alias SKM_sk_find!ASN1_INTEGER sk_ASN1_INTEGER_find;
alias SKM_sk_find_ex!ASN1_INTEGER sk_ASN1_INTEGER_find_ex;
alias SKM_sk_delete!ASN1_INTEGER sk_ASN1_INTEGER_delete;
alias SKM_sk_delete_ptr!ASN1_INTEGER sk_ASN1_INTEGER_delete_ptr;
alias SKM_sk_insert!ASN1_INTEGER sk_ASN1_INTEGER_insert;
alias SKM_sk_set_cmp_func!ASN1_INTEGER sk_ASN1_INTEGER_set_cmp_func;
alias SKM_sk_dup!ASN1_INTEGER sk_ASN1_INTEGER_dup;
alias SKM_sk_pop_free!ASN1_INTEGER sk_ASN1_INTEGER_pop_free;
alias SKM_sk_shift!ASN1_INTEGER sk_ASN1_INTEGER_shift;
alias SKM_sk_pop!ASN1_INTEGER sk_ASN1_INTEGER_pop;
alias SKM_sk_sort!ASN1_INTEGER sk_ASN1_INTEGER_sort;
alias SKM_sk_is_sorted!ASN1_INTEGER sk_ASN1_INTEGER_is_sorted;

alias SKM_sk_new!ASN1_OBJECT sk_ASN1_OBJECT_new;
alias SKM_sk_new_null!ASN1_OBJECT sk_ASN1_OBJECT_new_null;
alias SKM_sk_free!ASN1_OBJECT sk_ASN1_OBJECT_free;
alias SKM_sk_num!ASN1_OBJECT sk_ASN1_OBJECT_num;
alias SKM_sk_value!ASN1_OBJECT sk_ASN1_OBJECT_value;
alias SKM_sk_set!ASN1_OBJECT sk_ASN1_OBJECT_set;
alias SKM_sk_zero!ASN1_OBJECT sk_ASN1_OBJECT_zero;
alias SKM_sk_push!ASN1_OBJECT sk_ASN1_OBJECT_push;
alias SKM_sk_unshift!ASN1_OBJECT sk_ASN1_OBJECT_unshift;
alias SKM_sk_find!ASN1_OBJECT sk_ASN1_OBJECT_find;
alias SKM_sk_find_ex!ASN1_OBJECT sk_ASN1_OBJECT_find_ex;
alias SKM_sk_delete!ASN1_OBJECT sk_ASN1_OBJECT_delete;
alias SKM_sk_delete_ptr!ASN1_OBJECT sk_ASN1_OBJECT_delete_ptr;
alias SKM_sk_insert!ASN1_OBJECT sk_ASN1_OBJECT_insert;
alias SKM_sk_set_cmp_func!ASN1_OBJECT sk_ASN1_OBJECT_set_cmp_func;
alias SKM_sk_dup!ASN1_OBJECT sk_ASN1_OBJECT_dup;
alias SKM_sk_pop_free!ASN1_OBJECT sk_ASN1_OBJECT_pop_free;
alias SKM_sk_shift!ASN1_OBJECT sk_ASN1_OBJECT_shift;
alias SKM_sk_pop!ASN1_OBJECT sk_ASN1_OBJECT_pop;
alias SKM_sk_sort!ASN1_OBJECT sk_ASN1_OBJECT_sort;
alias SKM_sk_is_sorted!ASN1_OBJECT sk_ASN1_OBJECT_is_sorted;

alias SKM_sk_new!ASN1_STRING_TABLE sk_ASN1_STRING_TABLE_new;
alias SKM_sk_new_null!ASN1_STRING_TABLE sk_ASN1_STRING_TABLE_new_null;
alias SKM_sk_free!ASN1_STRING_TABLE sk_ASN1_STRING_TABLE_free;
alias SKM_sk_num!ASN1_STRING_TABLE sk_ASN1_STRING_TABLE_num;
alias SKM_sk_value!ASN1_STRING_TABLE sk_ASN1_STRING_TABLE_value;
alias SKM_sk_set!ASN1_STRING_TABLE sk_ASN1_STRING_TABLE_set;
alias SKM_sk_zero!ASN1_STRING_TABLE sk_ASN1_STRING_TABLE_zero;
alias SKM_sk_push!ASN1_STRING_TABLE sk_ASN1_STRING_TABLE_push;
alias SKM_sk_unshift!ASN1_STRING_TABLE sk_ASN1_STRING_TABLE_unshift;
alias SKM_sk_find!ASN1_STRING_TABLE sk_ASN1_STRING_TABLE_find;
alias SKM_sk_find_ex!ASN1_STRING_TABLE sk_ASN1_STRING_TABLE_find_ex;
alias SKM_sk_delete!ASN1_STRING_TABLE sk_ASN1_STRING_TABLE_delete;
alias SKM_sk_delete_ptr!ASN1_STRING_TABLE sk_ASN1_STRING_TABLE_delete_ptr;
alias SKM_sk_insert!ASN1_STRING_TABLE sk_ASN1_STRING_TABLE_insert;
alias SKM_sk_set_cmp_func!ASN1_STRING_TABLE sk_ASN1_STRING_TABLE_set_cmp_func;
alias SKM_sk_dup!ASN1_STRING_TABLE sk_ASN1_STRING_TABLE_dup;
alias SKM_sk_pop_free!ASN1_STRING_TABLE sk_ASN1_STRING_TABLE_pop_free;
alias SKM_sk_shift!ASN1_STRING_TABLE sk_ASN1_STRING_TABLE_shift;
alias SKM_sk_pop!ASN1_STRING_TABLE sk_ASN1_STRING_TABLE_pop;
alias SKM_sk_sort!ASN1_STRING_TABLE sk_ASN1_STRING_TABLE_sort;
alias SKM_sk_is_sorted!ASN1_STRING_TABLE sk_ASN1_STRING_TABLE_is_sorted;

alias SKM_sk_new!ASN1_TYPE sk_ASN1_TYPE_new;
alias SKM_sk_new_null!ASN1_TYPE sk_ASN1_TYPE_new_null;
alias SKM_sk_free!ASN1_TYPE sk_ASN1_TYPE_free;
alias SKM_sk_num!ASN1_TYPE sk_ASN1_TYPE_num;
alias SKM_sk_value!ASN1_TYPE sk_ASN1_TYPE_value;
alias SKM_sk_set!ASN1_TYPE sk_ASN1_TYPE_set;
alias SKM_sk_zero!ASN1_TYPE sk_ASN1_TYPE_zero;
alias SKM_sk_push!ASN1_TYPE sk_ASN1_TYPE_push;
alias SKM_sk_unshift!ASN1_TYPE sk_ASN1_TYPE_unshift;
alias SKM_sk_find!ASN1_TYPE sk_ASN1_TYPE_find;
alias SKM_sk_find_ex!ASN1_TYPE sk_ASN1_TYPE_find_ex;
alias SKM_sk_delete!ASN1_TYPE sk_ASN1_TYPE_delete;
alias SKM_sk_delete_ptr!ASN1_TYPE sk_ASN1_TYPE_delete_ptr;
alias SKM_sk_insert!ASN1_TYPE sk_ASN1_TYPE_insert;
alias SKM_sk_set_cmp_func!ASN1_TYPE sk_ASN1_TYPE_set_cmp_func;
alias SKM_sk_dup!ASN1_TYPE sk_ASN1_TYPE_dup;
alias SKM_sk_pop_free!ASN1_TYPE sk_ASN1_TYPE_pop_free;
alias SKM_sk_shift!ASN1_TYPE sk_ASN1_TYPE_shift;
alias SKM_sk_pop!ASN1_TYPE sk_ASN1_TYPE_pop;
alias SKM_sk_sort!ASN1_TYPE sk_ASN1_TYPE_sort;
alias SKM_sk_is_sorted!ASN1_TYPE sk_ASN1_TYPE_is_sorted;

alias SKM_sk_new!ASN1_UTF8STRING sk_ASN1_UTF8STRING_new;
alias SKM_sk_new_null!ASN1_UTF8STRING sk_ASN1_UTF8STRING_new_null;
alias SKM_sk_free!ASN1_UTF8STRING sk_ASN1_UTF8STRING_free;
alias SKM_sk_num!ASN1_UTF8STRING sk_ASN1_UTF8STRING_num;
alias SKM_sk_value!ASN1_UTF8STRING sk_ASN1_UTF8STRING_value;
alias SKM_sk_set!ASN1_UTF8STRING sk_ASN1_UTF8STRING_set;
alias SKM_sk_zero!ASN1_UTF8STRING sk_ASN1_UTF8STRING_zero;
alias SKM_sk_push!ASN1_UTF8STRING sk_ASN1_UTF8STRING_push;
alias SKM_sk_unshift!ASN1_UTF8STRING sk_ASN1_UTF8STRING_unshift;
alias SKM_sk_find!ASN1_UTF8STRING sk_ASN1_UTF8STRING_find;
alias SKM_sk_find_ex!ASN1_UTF8STRING sk_ASN1_UTF8STRING_find_ex;
alias SKM_sk_delete!ASN1_UTF8STRING sk_ASN1_UTF8STRING_delete;
alias SKM_sk_delete_ptr!ASN1_UTF8STRING sk_ASN1_UTF8STRING_delete_ptr;
alias SKM_sk_insert!ASN1_UTF8STRING sk_ASN1_UTF8STRING_insert;
alias SKM_sk_set_cmp_func!ASN1_UTF8STRING sk_ASN1_UTF8STRING_set_cmp_func;
alias SKM_sk_dup!ASN1_UTF8STRING sk_ASN1_UTF8STRING_dup;
alias SKM_sk_pop_free!ASN1_UTF8STRING sk_ASN1_UTF8STRING_pop_free;
alias SKM_sk_shift!ASN1_UTF8STRING sk_ASN1_UTF8STRING_shift;
alias SKM_sk_pop!ASN1_UTF8STRING sk_ASN1_UTF8STRING_pop;
alias SKM_sk_sort!ASN1_UTF8STRING sk_ASN1_UTF8STRING_sort;
alias SKM_sk_is_sorted!ASN1_UTF8STRING sk_ASN1_UTF8STRING_is_sorted;

alias SKM_sk_new!ASN1_VALUE sk_ASN1_VALUE_new;
alias SKM_sk_new_null!ASN1_VALUE sk_ASN1_VALUE_new_null;
alias SKM_sk_free!ASN1_VALUE sk_ASN1_VALUE_free;
alias SKM_sk_num!ASN1_VALUE sk_ASN1_VALUE_num;
alias SKM_sk_value!ASN1_VALUE sk_ASN1_VALUE_value;
alias SKM_sk_set!ASN1_VALUE sk_ASN1_VALUE_set;
alias SKM_sk_zero!ASN1_VALUE sk_ASN1_VALUE_zero;
alias SKM_sk_push!ASN1_VALUE sk_ASN1_VALUE_push;
alias SKM_sk_unshift!ASN1_VALUE sk_ASN1_VALUE_unshift;
alias SKM_sk_find!ASN1_VALUE sk_ASN1_VALUE_find;
alias SKM_sk_find_ex!ASN1_VALUE sk_ASN1_VALUE_find_ex;
alias SKM_sk_delete!ASN1_VALUE sk_ASN1_VALUE_delete;
alias SKM_sk_delete_ptr!ASN1_VALUE sk_ASN1_VALUE_delete_ptr;
alias SKM_sk_insert!ASN1_VALUE sk_ASN1_VALUE_insert;
alias SKM_sk_set_cmp_func!ASN1_VALUE sk_ASN1_VALUE_set_cmp_func;
alias SKM_sk_dup!ASN1_VALUE sk_ASN1_VALUE_dup;
alias SKM_sk_pop_free!ASN1_VALUE sk_ASN1_VALUE_pop_free;
alias SKM_sk_shift!ASN1_VALUE sk_ASN1_VALUE_shift;
alias SKM_sk_pop!ASN1_VALUE sk_ASN1_VALUE_pop;
alias SKM_sk_sort!ASN1_VALUE sk_ASN1_VALUE_sort;
alias SKM_sk_is_sorted!ASN1_VALUE sk_ASN1_VALUE_is_sorted;

alias SKM_sk_new!BIO sk_BIO_new;
alias SKM_sk_new_null!BIO sk_BIO_new_null;
alias SKM_sk_free!BIO sk_BIO_free;
alias SKM_sk_num!BIO sk_BIO_num;
alias SKM_sk_value!BIO sk_BIO_value;
alias SKM_sk_set!BIO sk_BIO_set;
alias SKM_sk_zero!BIO sk_BIO_zero;
alias SKM_sk_push!BIO sk_BIO_push;
alias SKM_sk_unshift!BIO sk_BIO_unshift;
alias SKM_sk_find!BIO sk_BIO_find;
alias SKM_sk_find_ex!BIO sk_BIO_find_ex;
alias SKM_sk_delete!BIO sk_BIO_delete;
alias SKM_sk_delete_ptr!BIO sk_BIO_delete_ptr;
alias SKM_sk_insert!BIO sk_BIO_insert;
alias SKM_sk_set_cmp_func!BIO sk_BIO_set_cmp_func;
alias SKM_sk_dup!BIO sk_BIO_dup;
alias SKM_sk_pop_free!BIO sk_BIO_pop_free;
alias SKM_sk_shift!BIO sk_BIO_shift;
alias SKM_sk_pop!BIO sk_BIO_pop;
alias SKM_sk_sort!BIO sk_BIO_sort;
alias SKM_sk_is_sorted!BIO sk_BIO_is_sorted;

/+ Internal crypto types, not exposed.
alias SKM_sk_new!BY_DIR_ENTRY sk_BY_DIR_ENTRY_new;
alias SKM_sk_new_null!BY_DIR_ENTRY sk_BY_DIR_ENTRY_new_null;
alias SKM_sk_free!BY_DIR_ENTRY sk_BY_DIR_ENTRY_free;
alias SKM_sk_num!BY_DIR_ENTRY sk_BY_DIR_ENTRY_num;
alias SKM_sk_value!BY_DIR_ENTRY sk_BY_DIR_ENTRY_value;
alias SKM_sk_set!BY_DIR_ENTRY sk_BY_DIR_ENTRY_set;
alias SKM_sk_zero!BY_DIR_ENTRY sk_BY_DIR_ENTRY_zero;
alias SKM_sk_push!BY_DIR_ENTRY sk_BY_DIR_ENTRY_push;
alias SKM_sk_unshift!BY_DIR_ENTRY sk_BY_DIR_ENTRY_unshift;
alias SKM_sk_find!BY_DIR_ENTRY sk_BY_DIR_ENTRY_find;
alias SKM_sk_find_ex!BY_DIR_ENTRY sk_BY_DIR_ENTRY_find_ex;
alias SKM_sk_delete!BY_DIR_ENTRY sk_BY_DIR_ENTRY_delete;
alias SKM_sk_delete_ptr!BY_DIR_ENTRY sk_BY_DIR_ENTRY_delete_ptr;
alias SKM_sk_insert!BY_DIR_ENTRY sk_BY_DIR_ENTRY_insert;
alias SKM_sk_set_cmp_func!BY_DIR_ENTRY sk_BY_DIR_ENTRY_set_cmp_func;
alias SKM_sk_dup!BY_DIR_ENTRY sk_BY_DIR_ENTRY_dup;
alias SKM_sk_pop_free!BY_DIR_ENTRY sk_BY_DIR_ENTRY_pop_free;
alias SKM_sk_shift!BY_DIR_ENTRY sk_BY_DIR_ENTRY_shift;
alias SKM_sk_pop!BY_DIR_ENTRY sk_BY_DIR_ENTRY_pop;
alias SKM_sk_sort!BY_DIR_ENTRY sk_BY_DIR_ENTRY_sort;
alias SKM_sk_is_sorted!BY_DIR_ENTRY sk_BY_DIR_ENTRY_is_sorted;

alias SKM_sk_new!BY_DIR_HASH sk_BY_DIR_HASH_new;
alias SKM_sk_new_null!BY_DIR_HASH sk_BY_DIR_HASH_new_null;
alias SKM_sk_free!BY_DIR_HASH sk_BY_DIR_HASH_free;
alias SKM_sk_num!BY_DIR_HASH sk_BY_DIR_HASH_num;
alias SKM_sk_value!BY_DIR_HASH sk_BY_DIR_HASH_value;
alias SKM_sk_set!BY_DIR_HASH sk_BY_DIR_HASH_set;
alias SKM_sk_zero!BY_DIR_HASH sk_BY_DIR_HASH_zero;
alias SKM_sk_push!BY_DIR_HASH sk_BY_DIR_HASH_push;
alias SKM_sk_unshift!BY_DIR_HASH sk_BY_DIR_HASH_unshift;
alias SKM_sk_find!BY_DIR_HASH sk_BY_DIR_HASH_find;
alias SKM_sk_find_ex!BY_DIR_HASH sk_BY_DIR_HASH_find_ex;
alias SKM_sk_delete!BY_DIR_HASH sk_BY_DIR_HASH_delete;
alias SKM_sk_delete_ptr!BY_DIR_HASH sk_BY_DIR_HASH_delete_ptr;
alias SKM_sk_insert!BY_DIR_HASH sk_BY_DIR_HASH_insert;
alias SKM_sk_set_cmp_func!BY_DIR_HASH sk_BY_DIR_HASH_set_cmp_func;
alias SKM_sk_dup!BY_DIR_HASH sk_BY_DIR_HASH_dup;
alias SKM_sk_pop_free!BY_DIR_HASH sk_BY_DIR_HASH_pop_free;
alias SKM_sk_shift!BY_DIR_HASH sk_BY_DIR_HASH_shift;
alias SKM_sk_pop!BY_DIR_HASH sk_BY_DIR_HASH_pop;
alias SKM_sk_sort!BY_DIR_HASH sk_BY_DIR_HASH_sort;
alias SKM_sk_is_sorted!BY_DIR_HASH sk_BY_DIR_HASH_is_sorted;
+/

alias SKM_sk_new!CMS_CertificateChoices sk_CMS_CertificateChoices_new;
alias SKM_sk_new_null!CMS_CertificateChoices sk_CMS_CertificateChoices_new_null;
alias SKM_sk_free!CMS_CertificateChoices sk_CMS_CertificateChoices_free;
alias SKM_sk_num!CMS_CertificateChoices sk_CMS_CertificateChoices_num;
alias SKM_sk_value!CMS_CertificateChoices sk_CMS_CertificateChoices_value;
alias SKM_sk_set!CMS_CertificateChoices sk_CMS_CertificateChoices_set;
alias SKM_sk_zero!CMS_CertificateChoices sk_CMS_CertificateChoices_zero;
alias SKM_sk_push!CMS_CertificateChoices sk_CMS_CertificateChoices_push;
alias SKM_sk_unshift!CMS_CertificateChoices sk_CMS_CertificateChoices_unshift;
alias SKM_sk_find!CMS_CertificateChoices sk_CMS_CertificateChoices_find;
alias SKM_sk_find_ex!CMS_CertificateChoices sk_CMS_CertificateChoices_find_ex;
alias SKM_sk_delete!CMS_CertificateChoices sk_CMS_CertificateChoices_delete;
alias SKM_sk_delete_ptr!CMS_CertificateChoices sk_CMS_CertificateChoices_delete_ptr;
alias SKM_sk_insert!CMS_CertificateChoices sk_CMS_CertificateChoices_insert;
alias SKM_sk_set_cmp_func!CMS_CertificateChoices sk_CMS_CertificateChoices_set_cmp_func;
alias SKM_sk_dup!CMS_CertificateChoices sk_CMS_CertificateChoices_dup;
alias SKM_sk_pop_free!CMS_CertificateChoices sk_CMS_CertificateChoices_pop_free;
alias SKM_sk_shift!CMS_CertificateChoices sk_CMS_CertificateChoices_shift;
alias SKM_sk_pop!CMS_CertificateChoices sk_CMS_CertificateChoices_pop;
alias SKM_sk_sort!CMS_CertificateChoices sk_CMS_CertificateChoices_sort;
alias SKM_sk_is_sorted!CMS_CertificateChoices sk_CMS_CertificateChoices_is_sorted;

alias SKM_sk_new!CMS_RecipientInfo sk_CMS_RecipientInfo_new;
alias SKM_sk_new_null!CMS_RecipientInfo sk_CMS_RecipientInfo_new_null;
alias SKM_sk_free!CMS_RecipientInfo sk_CMS_RecipientInfo_free;
alias SKM_sk_num!CMS_RecipientInfo sk_CMS_RecipientInfo_num;
alias SKM_sk_value!CMS_RecipientInfo sk_CMS_RecipientInfo_value;
alias SKM_sk_set!CMS_RecipientInfo sk_CMS_RecipientInfo_set;
alias SKM_sk_zero!CMS_RecipientInfo sk_CMS_RecipientInfo_zero;
alias SKM_sk_push!CMS_RecipientInfo sk_CMS_RecipientInfo_push;
alias SKM_sk_unshift!CMS_RecipientInfo sk_CMS_RecipientInfo_unshift;
alias SKM_sk_find!CMS_RecipientInfo sk_CMS_RecipientInfo_find;
alias SKM_sk_find_ex!CMS_RecipientInfo sk_CMS_RecipientInfo_find_ex;
alias SKM_sk_delete!CMS_RecipientInfo sk_CMS_RecipientInfo_delete;
alias SKM_sk_delete_ptr!CMS_RecipientInfo sk_CMS_RecipientInfo_delete_ptr;
alias SKM_sk_insert!CMS_RecipientInfo sk_CMS_RecipientInfo_insert;
alias SKM_sk_set_cmp_func!CMS_RecipientInfo sk_CMS_RecipientInfo_set_cmp_func;
alias SKM_sk_dup!CMS_RecipientInfo sk_CMS_RecipientInfo_dup;
alias SKM_sk_pop_free!CMS_RecipientInfo sk_CMS_RecipientInfo_pop_free;
alias SKM_sk_shift!CMS_RecipientInfo sk_CMS_RecipientInfo_shift;
alias SKM_sk_pop!CMS_RecipientInfo sk_CMS_RecipientInfo_pop;
alias SKM_sk_sort!CMS_RecipientInfo sk_CMS_RecipientInfo_sort;
alias SKM_sk_is_sorted!CMS_RecipientInfo sk_CMS_RecipientInfo_is_sorted;

alias SKM_sk_new!CMS_RevocationInfoChoice sk_CMS_RevocationInfoChoice_new;
alias SKM_sk_new_null!CMS_RevocationInfoChoice sk_CMS_RevocationInfoChoice_new_null;
alias SKM_sk_free!CMS_RevocationInfoChoice sk_CMS_RevocationInfoChoice_free;
alias SKM_sk_num!CMS_RevocationInfoChoice sk_CMS_RevocationInfoChoice_num;
alias SKM_sk_value!CMS_RevocationInfoChoice sk_CMS_RevocationInfoChoice_value;
alias SKM_sk_set!CMS_RevocationInfoChoice sk_CMS_RevocationInfoChoice_set;
alias SKM_sk_zero!CMS_RevocationInfoChoice sk_CMS_RevocationInfoChoice_zero;
alias SKM_sk_push!CMS_RevocationInfoChoice sk_CMS_RevocationInfoChoice_push;
alias SKM_sk_unshift!CMS_RevocationInfoChoice sk_CMS_RevocationInfoChoice_unshift;
alias SKM_sk_find!CMS_RevocationInfoChoice sk_CMS_RevocationInfoChoice_find;
alias SKM_sk_find_ex!CMS_RevocationInfoChoice sk_CMS_RevocationInfoChoice_find_ex;
alias SKM_sk_delete!CMS_RevocationInfoChoice sk_CMS_RevocationInfoChoice_delete;
alias SKM_sk_delete_ptr!CMS_RevocationInfoChoice sk_CMS_RevocationInfoChoice_delete_ptr;
alias SKM_sk_insert!CMS_RevocationInfoChoice sk_CMS_RevocationInfoChoice_insert;
alias SKM_sk_set_cmp_func!CMS_RevocationInfoChoice sk_CMS_RevocationInfoChoice_set_cmp_func;
alias SKM_sk_dup!CMS_RevocationInfoChoice sk_CMS_RevocationInfoChoice_dup;
alias SKM_sk_pop_free!CMS_RevocationInfoChoice sk_CMS_RevocationInfoChoice_pop_free;
alias SKM_sk_shift!CMS_RevocationInfoChoice sk_CMS_RevocationInfoChoice_shift;
alias SKM_sk_pop!CMS_RevocationInfoChoice sk_CMS_RevocationInfoChoice_pop;
alias SKM_sk_sort!CMS_RevocationInfoChoice sk_CMS_RevocationInfoChoice_sort;
alias SKM_sk_is_sorted!CMS_RevocationInfoChoice sk_CMS_RevocationInfoChoice_is_sorted;

alias SKM_sk_new!CMS_SignerInfo sk_CMS_SignerInfo_new;
alias SKM_sk_new_null!CMS_SignerInfo sk_CMS_SignerInfo_new_null;
alias SKM_sk_free!CMS_SignerInfo sk_CMS_SignerInfo_free;
alias SKM_sk_num!CMS_SignerInfo sk_CMS_SignerInfo_num;
alias SKM_sk_value!CMS_SignerInfo sk_CMS_SignerInfo_value;
alias SKM_sk_set!CMS_SignerInfo sk_CMS_SignerInfo_set;
alias SKM_sk_zero!CMS_SignerInfo sk_CMS_SignerInfo_zero;
alias SKM_sk_push!CMS_SignerInfo sk_CMS_SignerInfo_push;
alias SKM_sk_unshift!CMS_SignerInfo sk_CMS_SignerInfo_unshift;
alias SKM_sk_find!CMS_SignerInfo sk_CMS_SignerInfo_find;
alias SKM_sk_find_ex!CMS_SignerInfo sk_CMS_SignerInfo_find_ex;
alias SKM_sk_delete!CMS_SignerInfo sk_CMS_SignerInfo_delete;
alias SKM_sk_delete_ptr!CMS_SignerInfo sk_CMS_SignerInfo_delete_ptr;
alias SKM_sk_insert!CMS_SignerInfo sk_CMS_SignerInfo_insert;
alias SKM_sk_set_cmp_func!CMS_SignerInfo sk_CMS_SignerInfo_set_cmp_func;
alias SKM_sk_dup!CMS_SignerInfo sk_CMS_SignerInfo_dup;
alias SKM_sk_pop_free!CMS_SignerInfo sk_CMS_SignerInfo_pop_free;
alias SKM_sk_shift!CMS_SignerInfo sk_CMS_SignerInfo_shift;
alias SKM_sk_pop!CMS_SignerInfo sk_CMS_SignerInfo_pop;
alias SKM_sk_sort!CMS_SignerInfo sk_CMS_SignerInfo_sort;
alias SKM_sk_is_sorted!CMS_SignerInfo sk_CMS_SignerInfo_is_sorted;

alias SKM_sk_new!CONF_IMODULE sk_CONF_IMODULE_new;
alias SKM_sk_new_null!CONF_IMODULE sk_CONF_IMODULE_new_null;
alias SKM_sk_free!CONF_IMODULE sk_CONF_IMODULE_free;
alias SKM_sk_num!CONF_IMODULE sk_CONF_IMODULE_num;
alias SKM_sk_value!CONF_IMODULE sk_CONF_IMODULE_value;
alias SKM_sk_set!CONF_IMODULE sk_CONF_IMODULE_set;
alias SKM_sk_zero!CONF_IMODULE sk_CONF_IMODULE_zero;
alias SKM_sk_push!CONF_IMODULE sk_CONF_IMODULE_push;
alias SKM_sk_unshift!CONF_IMODULE sk_CONF_IMODULE_unshift;
alias SKM_sk_find!CONF_IMODULE sk_CONF_IMODULE_find;
alias SKM_sk_find_ex!CONF_IMODULE sk_CONF_IMODULE_find_ex;
alias SKM_sk_delete!CONF_IMODULE sk_CONF_IMODULE_delete;
alias SKM_sk_delete_ptr!CONF_IMODULE sk_CONF_IMODULE_delete_ptr;
alias SKM_sk_insert!CONF_IMODULE sk_CONF_IMODULE_insert;
alias SKM_sk_set_cmp_func!CONF_IMODULE sk_CONF_IMODULE_set_cmp_func;
alias SKM_sk_dup!CONF_IMODULE sk_CONF_IMODULE_dup;
alias SKM_sk_pop_free!CONF_IMODULE sk_CONF_IMODULE_pop_free;
alias SKM_sk_shift!CONF_IMODULE sk_CONF_IMODULE_shift;
alias SKM_sk_pop!CONF_IMODULE sk_CONF_IMODULE_pop;
alias SKM_sk_sort!CONF_IMODULE sk_CONF_IMODULE_sort;
alias SKM_sk_is_sorted!CONF_IMODULE sk_CONF_IMODULE_is_sorted;

alias SKM_sk_new!CONF_MODULE sk_CONF_MODULE_new;
alias SKM_sk_new_null!CONF_MODULE sk_CONF_MODULE_new_null;
alias SKM_sk_free!CONF_MODULE sk_CONF_MODULE_free;
alias SKM_sk_num!CONF_MODULE sk_CONF_MODULE_num;
alias SKM_sk_value!CONF_MODULE sk_CONF_MODULE_value;
alias SKM_sk_set!CONF_MODULE sk_CONF_MODULE_set;
alias SKM_sk_zero!CONF_MODULE sk_CONF_MODULE_zero;
alias SKM_sk_push!CONF_MODULE sk_CONF_MODULE_push;
alias SKM_sk_unshift!CONF_MODULE sk_CONF_MODULE_unshift;
alias SKM_sk_find!CONF_MODULE sk_CONF_MODULE_find;
alias SKM_sk_find_ex!CONF_MODULE sk_CONF_MODULE_find_ex;
alias SKM_sk_delete!CONF_MODULE sk_CONF_MODULE_delete;
alias SKM_sk_delete_ptr!CONF_MODULE sk_CONF_MODULE_delete_ptr;
alias SKM_sk_insert!CONF_MODULE sk_CONF_MODULE_insert;
alias SKM_sk_set_cmp_func!CONF_MODULE sk_CONF_MODULE_set_cmp_func;
alias SKM_sk_dup!CONF_MODULE sk_CONF_MODULE_dup;
alias SKM_sk_pop_free!CONF_MODULE sk_CONF_MODULE_pop_free;
alias SKM_sk_shift!CONF_MODULE sk_CONF_MODULE_shift;
alias SKM_sk_pop!CONF_MODULE sk_CONF_MODULE_pop;
alias SKM_sk_sort!CONF_MODULE sk_CONF_MODULE_sort;
alias SKM_sk_is_sorted!CONF_MODULE sk_CONF_MODULE_is_sorted;

alias SKM_sk_new!CONF_VALUE sk_CONF_VALUE_new;
alias SKM_sk_new_null!CONF_VALUE sk_CONF_VALUE_new_null;
alias SKM_sk_free!CONF_VALUE sk_CONF_VALUE_free;
alias SKM_sk_num!CONF_VALUE sk_CONF_VALUE_num;
alias SKM_sk_value!CONF_VALUE sk_CONF_VALUE_value;
alias SKM_sk_set!CONF_VALUE sk_CONF_VALUE_set;
alias SKM_sk_zero!CONF_VALUE sk_CONF_VALUE_zero;
alias SKM_sk_push!CONF_VALUE sk_CONF_VALUE_push;
alias SKM_sk_unshift!CONF_VALUE sk_CONF_VALUE_unshift;
alias SKM_sk_find!CONF_VALUE sk_CONF_VALUE_find;
alias SKM_sk_find_ex!CONF_VALUE sk_CONF_VALUE_find_ex;
alias SKM_sk_delete!CONF_VALUE sk_CONF_VALUE_delete;
alias SKM_sk_delete_ptr!CONF_VALUE sk_CONF_VALUE_delete_ptr;
alias SKM_sk_insert!CONF_VALUE sk_CONF_VALUE_insert;
alias SKM_sk_set_cmp_func!CONF_VALUE sk_CONF_VALUE_set_cmp_func;
alias SKM_sk_dup!CONF_VALUE sk_CONF_VALUE_dup;
alias SKM_sk_pop_free!CONF_VALUE sk_CONF_VALUE_pop_free;
alias SKM_sk_shift!CONF_VALUE sk_CONF_VALUE_shift;
alias SKM_sk_pop!CONF_VALUE sk_CONF_VALUE_pop;
alias SKM_sk_sort!CONF_VALUE sk_CONF_VALUE_sort;
alias SKM_sk_is_sorted!CONF_VALUE sk_CONF_VALUE_is_sorted;

alias SKM_sk_new!CRYPTO_EX_DATA_FUNCS sk_CRYPTO_EX_DATA_FUNCS_new;
alias SKM_sk_new_null!CRYPTO_EX_DATA_FUNCS sk_CRYPTO_EX_DATA_FUNCS_new_null;
alias SKM_sk_free!CRYPTO_EX_DATA_FUNCS sk_CRYPTO_EX_DATA_FUNCS_free;
alias SKM_sk_num!CRYPTO_EX_DATA_FUNCS sk_CRYPTO_EX_DATA_FUNCS_num;
alias SKM_sk_value!CRYPTO_EX_DATA_FUNCS sk_CRYPTO_EX_DATA_FUNCS_value;
alias SKM_sk_set!CRYPTO_EX_DATA_FUNCS sk_CRYPTO_EX_DATA_FUNCS_set;
alias SKM_sk_zero!CRYPTO_EX_DATA_FUNCS sk_CRYPTO_EX_DATA_FUNCS_zero;
alias SKM_sk_push!CRYPTO_EX_DATA_FUNCS sk_CRYPTO_EX_DATA_FUNCS_push;
alias SKM_sk_unshift!CRYPTO_EX_DATA_FUNCS sk_CRYPTO_EX_DATA_FUNCS_unshift;
alias SKM_sk_find!CRYPTO_EX_DATA_FUNCS sk_CRYPTO_EX_DATA_FUNCS_find;
alias SKM_sk_find_ex!CRYPTO_EX_DATA_FUNCS sk_CRYPTO_EX_DATA_FUNCS_find_ex;
alias SKM_sk_delete!CRYPTO_EX_DATA_FUNCS sk_CRYPTO_EX_DATA_FUNCS_delete;
alias SKM_sk_delete_ptr!CRYPTO_EX_DATA_FUNCS sk_CRYPTO_EX_DATA_FUNCS_delete_ptr;
alias SKM_sk_insert!CRYPTO_EX_DATA_FUNCS sk_CRYPTO_EX_DATA_FUNCS_insert;
alias SKM_sk_set_cmp_func!CRYPTO_EX_DATA_FUNCS sk_CRYPTO_EX_DATA_FUNCS_set_cmp_func;
alias SKM_sk_dup!CRYPTO_EX_DATA_FUNCS sk_CRYPTO_EX_DATA_FUNCS_dup;
alias SKM_sk_pop_free!CRYPTO_EX_DATA_FUNCS sk_CRYPTO_EX_DATA_FUNCS_pop_free;
alias SKM_sk_shift!CRYPTO_EX_DATA_FUNCS sk_CRYPTO_EX_DATA_FUNCS_shift;
alias SKM_sk_pop!CRYPTO_EX_DATA_FUNCS sk_CRYPTO_EX_DATA_FUNCS_pop;
alias SKM_sk_sort!CRYPTO_EX_DATA_FUNCS sk_CRYPTO_EX_DATA_FUNCS_sort;
alias SKM_sk_is_sorted!CRYPTO_EX_DATA_FUNCS sk_CRYPTO_EX_DATA_FUNCS_is_sorted;

alias SKM_sk_new!CRYPTO_dynlock sk_CRYPTO_dynlock_new;
alias SKM_sk_new_null!CRYPTO_dynlock sk_CRYPTO_dynlock_new_null;
alias SKM_sk_free!CRYPTO_dynlock sk_CRYPTO_dynlock_free;
alias SKM_sk_num!CRYPTO_dynlock sk_CRYPTO_dynlock_num;
alias SKM_sk_value!CRYPTO_dynlock sk_CRYPTO_dynlock_value;
alias SKM_sk_set!CRYPTO_dynlock sk_CRYPTO_dynlock_set;
alias SKM_sk_zero!CRYPTO_dynlock sk_CRYPTO_dynlock_zero;
alias SKM_sk_push!CRYPTO_dynlock sk_CRYPTO_dynlock_push;
alias SKM_sk_unshift!CRYPTO_dynlock sk_CRYPTO_dynlock_unshift;
alias SKM_sk_find!CRYPTO_dynlock sk_CRYPTO_dynlock_find;
alias SKM_sk_find_ex!CRYPTO_dynlock sk_CRYPTO_dynlock_find_ex;
alias SKM_sk_delete!CRYPTO_dynlock sk_CRYPTO_dynlock_delete;
alias SKM_sk_delete_ptr!CRYPTO_dynlock sk_CRYPTO_dynlock_delete_ptr;
alias SKM_sk_insert!CRYPTO_dynlock sk_CRYPTO_dynlock_insert;
alias SKM_sk_set_cmp_func!CRYPTO_dynlock sk_CRYPTO_dynlock_set_cmp_func;
alias SKM_sk_dup!CRYPTO_dynlock sk_CRYPTO_dynlock_dup;
alias SKM_sk_pop_free!CRYPTO_dynlock sk_CRYPTO_dynlock_pop_free;
alias SKM_sk_shift!CRYPTO_dynlock sk_CRYPTO_dynlock_shift;
alias SKM_sk_pop!CRYPTO_dynlock sk_CRYPTO_dynlock_pop;
alias SKM_sk_sort!CRYPTO_dynlock sk_CRYPTO_dynlock_sort;
alias SKM_sk_is_sorted!CRYPTO_dynlock sk_CRYPTO_dynlock_is_sorted;

alias SKM_sk_new!DIST_POINT sk_DIST_POINT_new;
alias SKM_sk_new_null!DIST_POINT sk_DIST_POINT_new_null;
alias SKM_sk_free!DIST_POINT sk_DIST_POINT_free;
alias SKM_sk_num!DIST_POINT sk_DIST_POINT_num;
alias SKM_sk_value!DIST_POINT sk_DIST_POINT_value;
alias SKM_sk_set!DIST_POINT sk_DIST_POINT_set;
alias SKM_sk_zero!DIST_POINT sk_DIST_POINT_zero;
alias SKM_sk_push!DIST_POINT sk_DIST_POINT_push;
alias SKM_sk_unshift!DIST_POINT sk_DIST_POINT_unshift;
alias SKM_sk_find!DIST_POINT sk_DIST_POINT_find;
alias SKM_sk_find_ex!DIST_POINT sk_DIST_POINT_find_ex;
alias SKM_sk_delete!DIST_POINT sk_DIST_POINT_delete;
alias SKM_sk_delete_ptr!DIST_POINT sk_DIST_POINT_delete_ptr;
alias SKM_sk_insert!DIST_POINT sk_DIST_POINT_insert;
alias SKM_sk_set_cmp_func!DIST_POINT sk_DIST_POINT_set_cmp_func;
alias SKM_sk_dup!DIST_POINT sk_DIST_POINT_dup;
alias SKM_sk_pop_free!DIST_POINT sk_DIST_POINT_pop_free;
alias SKM_sk_shift!DIST_POINT sk_DIST_POINT_shift;
alias SKM_sk_pop!DIST_POINT sk_DIST_POINT_pop;
alias SKM_sk_sort!DIST_POINT sk_DIST_POINT_sort;
alias SKM_sk_is_sorted!DIST_POINT sk_DIST_POINT_is_sorted;

alias SKM_sk_new!ENGINE sk_ENGINE_new;
alias SKM_sk_new_null!ENGINE sk_ENGINE_new_null;
alias SKM_sk_free!ENGINE sk_ENGINE_free;
alias SKM_sk_num!ENGINE sk_ENGINE_num;
alias SKM_sk_value!ENGINE sk_ENGINE_value;
alias SKM_sk_set!ENGINE sk_ENGINE_set;
alias SKM_sk_zero!ENGINE sk_ENGINE_zero;
alias SKM_sk_push!ENGINE sk_ENGINE_push;
alias SKM_sk_unshift!ENGINE sk_ENGINE_unshift;
alias SKM_sk_find!ENGINE sk_ENGINE_find;
alias SKM_sk_find_ex!ENGINE sk_ENGINE_find_ex;
alias SKM_sk_delete!ENGINE sk_ENGINE_delete;
alias SKM_sk_delete_ptr!ENGINE sk_ENGINE_delete_ptr;
alias SKM_sk_insert!ENGINE sk_ENGINE_insert;
alias SKM_sk_set_cmp_func!ENGINE sk_ENGINE_set_cmp_func;
alias SKM_sk_dup!ENGINE sk_ENGINE_dup;
alias SKM_sk_pop_free!ENGINE sk_ENGINE_pop_free;
alias SKM_sk_shift!ENGINE sk_ENGINE_shift;
alias SKM_sk_pop!ENGINE sk_ENGINE_pop;
alias SKM_sk_sort!ENGINE sk_ENGINE_sort;
alias SKM_sk_is_sorted!ENGINE sk_ENGINE_is_sorted;

/+ Internal crypto type.
alias SKM_sk_new!ENGINE_CLEANUP_ITEM sk_ENGINE_CLEANUP_ITEM_new;
alias SKM_sk_new_null!ENGINE_CLEANUP_ITEM sk_ENGINE_CLEANUP_ITEM_new_null;
alias SKM_sk_free!ENGINE_CLEANUP_ITEM sk_ENGINE_CLEANUP_ITEM_free;
alias SKM_sk_num!ENGINE_CLEANUP_ITEM sk_ENGINE_CLEANUP_ITEM_num;
alias SKM_sk_value!ENGINE_CLEANUP_ITEM sk_ENGINE_CLEANUP_ITEM_value;
alias SKM_sk_set!ENGINE_CLEANUP_ITEM sk_ENGINE_CLEANUP_ITEM_set;
alias SKM_sk_zero!ENGINE_CLEANUP_ITEM sk_ENGINE_CLEANUP_ITEM_zero;
alias SKM_sk_push!ENGINE_CLEANUP_ITEM sk_ENGINE_CLEANUP_ITEM_push;
alias SKM_sk_unshift!ENGINE_CLEANUP_ITEM sk_ENGINE_CLEANUP_ITEM_unshift;
alias SKM_sk_find!ENGINE_CLEANUP_ITEM sk_ENGINE_CLEANUP_ITEM_find;
alias SKM_sk_find_ex!ENGINE_CLEANUP_ITEM sk_ENGINE_CLEANUP_ITEM_find_ex;
alias SKM_sk_delete!ENGINE_CLEANUP_ITEM sk_ENGINE_CLEANUP_ITEM_delete;
alias SKM_sk_delete_ptr!ENGINE_CLEANUP_ITEM sk_ENGINE_CLEANUP_ITEM_delete_ptr;
alias SKM_sk_insert!ENGINE_CLEANUP_ITEM sk_ENGINE_CLEANUP_ITEM_insert;
alias SKM_sk_set_cmp_func!ENGINE_CLEANUP_ITEM sk_ENGINE_CLEANUP_ITEM_set_cmp_func;
alias SKM_sk_dup!ENGINE_CLEANUP_ITEM sk_ENGINE_CLEANUP_ITEM_dup;
alias SKM_sk_pop_free!ENGINE_CLEANUP_ITEM sk_ENGINE_CLEANUP_ITEM_pop_free;
alias SKM_sk_shift!ENGINE_CLEANUP_ITEM sk_ENGINE_CLEANUP_ITEM_shift;
alias SKM_sk_pop!ENGINE_CLEANUP_ITEM sk_ENGINE_CLEANUP_ITEM_pop;
alias SKM_sk_sort!ENGINE_CLEANUP_ITEM sk_ENGINE_CLEANUP_ITEM_sort;
alias SKM_sk_is_sorted!ENGINE_CLEANUP_ITEM sk_ENGINE_CLEANUP_ITEM_is_sorted;
+/

import deimos.openssl.ts;
alias SKM_sk_new!ESS_CERT_ID sk_ESS_CERT_ID_new;
alias SKM_sk_new_null!ESS_CERT_ID sk_ESS_CERT_ID_new_null;
alias SKM_sk_free!ESS_CERT_ID sk_ESS_CERT_ID_free;
alias SKM_sk_num!ESS_CERT_ID sk_ESS_CERT_ID_num;
alias SKM_sk_value!ESS_CERT_ID sk_ESS_CERT_ID_value;
alias SKM_sk_set!ESS_CERT_ID sk_ESS_CERT_ID_set;
alias SKM_sk_zero!ESS_CERT_ID sk_ESS_CERT_ID_zero;
alias SKM_sk_push!ESS_CERT_ID sk_ESS_CERT_ID_push;
alias SKM_sk_unshift!ESS_CERT_ID sk_ESS_CERT_ID_unshift;
alias SKM_sk_find!ESS_CERT_ID sk_ESS_CERT_ID_find;
alias SKM_sk_find_ex!ESS_CERT_ID sk_ESS_CERT_ID_find_ex;
alias SKM_sk_delete!ESS_CERT_ID sk_ESS_CERT_ID_delete;
alias SKM_sk_delete_ptr!ESS_CERT_ID sk_ESS_CERT_ID_delete_ptr;
alias SKM_sk_insert!ESS_CERT_ID sk_ESS_CERT_ID_insert;
alias SKM_sk_set_cmp_func!ESS_CERT_ID sk_ESS_CERT_ID_set_cmp_func;
alias SKM_sk_dup!ESS_CERT_ID sk_ESS_CERT_ID_dup;
alias SKM_sk_pop_free!ESS_CERT_ID sk_ESS_CERT_ID_pop_free;
alias SKM_sk_shift!ESS_CERT_ID sk_ESS_CERT_ID_shift;
alias SKM_sk_pop!ESS_CERT_ID sk_ESS_CERT_ID_pop;
alias SKM_sk_sort!ESS_CERT_ID sk_ESS_CERT_ID_sort;
alias SKM_sk_is_sorted!ESS_CERT_ID sk_ESS_CERT_ID_is_sorted;

alias SKM_sk_new!EVP_MD sk_EVP_MD_new;
alias SKM_sk_new_null!EVP_MD sk_EVP_MD_new_null;
alias SKM_sk_free!EVP_MD sk_EVP_MD_free;
alias SKM_sk_num!EVP_MD sk_EVP_MD_num;
alias SKM_sk_value!EVP_MD sk_EVP_MD_value;
alias SKM_sk_set!EVP_MD sk_EVP_MD_set;
alias SKM_sk_zero!EVP_MD sk_EVP_MD_zero;
alias SKM_sk_push!EVP_MD sk_EVP_MD_push;
alias SKM_sk_unshift!EVP_MD sk_EVP_MD_unshift;
alias SKM_sk_find!EVP_MD sk_EVP_MD_find;
alias SKM_sk_find_ex!EVP_MD sk_EVP_MD_find_ex;
alias SKM_sk_delete!EVP_MD sk_EVP_MD_delete;
alias SKM_sk_delete_ptr!EVP_MD sk_EVP_MD_delete_ptr;
alias SKM_sk_insert!EVP_MD sk_EVP_MD_insert;
alias SKM_sk_set_cmp_func!EVP_MD sk_EVP_MD_set_cmp_func;
alias SKM_sk_dup!EVP_MD sk_EVP_MD_dup;
alias SKM_sk_pop_free!EVP_MD sk_EVP_MD_pop_free;
alias SKM_sk_shift!EVP_MD sk_EVP_MD_shift;
alias SKM_sk_pop!EVP_MD sk_EVP_MD_pop;
alias SKM_sk_sort!EVP_MD sk_EVP_MD_sort;
alias SKM_sk_is_sorted!EVP_MD sk_EVP_MD_is_sorted;

/+ Internal crypto type.
alias SKM_sk_new!EVP_PBE_CTL sk_EVP_PBE_CTL_new;
alias SKM_sk_new_null!EVP_PBE_CTL sk_EVP_PBE_CTL_new_null;
alias SKM_sk_free!EVP_PBE_CTL sk_EVP_PBE_CTL_free;
alias SKM_sk_num!EVP_PBE_CTL sk_EVP_PBE_CTL_num;
alias SKM_sk_value!EVP_PBE_CTL sk_EVP_PBE_CTL_value;
alias SKM_sk_set!EVP_PBE_CTL sk_EVP_PBE_CTL_set;
alias SKM_sk_zero!EVP_PBE_CTL sk_EVP_PBE_CTL_zero;
alias SKM_sk_push!EVP_PBE_CTL sk_EVP_PBE_CTL_push;
alias SKM_sk_unshift!EVP_PBE_CTL sk_EVP_PBE_CTL_unshift;
alias SKM_sk_find!EVP_PBE_CTL sk_EVP_PBE_CTL_find;
alias SKM_sk_find_ex!EVP_PBE_CTL sk_EVP_PBE_CTL_find_ex;
alias SKM_sk_delete!EVP_PBE_CTL sk_EVP_PBE_CTL_delete;
alias SKM_sk_delete_ptr!EVP_PBE_CTL sk_EVP_PBE_CTL_delete_ptr;
alias SKM_sk_insert!EVP_PBE_CTL sk_EVP_PBE_CTL_insert;
alias SKM_sk_set_cmp_func!EVP_PBE_CTL sk_EVP_PBE_CTL_set_cmp_func;
alias SKM_sk_dup!EVP_PBE_CTL sk_EVP_PBE_CTL_dup;
alias SKM_sk_pop_free!EVP_PBE_CTL sk_EVP_PBE_CTL_pop_free;
alias SKM_sk_shift!EVP_PBE_CTL sk_EVP_PBE_CTL_shift;
alias SKM_sk_pop!EVP_PBE_CTL sk_EVP_PBE_CTL_pop;
alias SKM_sk_sort!EVP_PBE_CTL sk_EVP_PBE_CTL_sort;
alias SKM_sk_is_sorted!EVP_PBE_CTL sk_EVP_PBE_CTL_is_sorted;
+/

alias SKM_sk_new!EVP_PKEY_ASN1_METHOD sk_EVP_PKEY_ASN1_METHOD_new;
alias SKM_sk_new_null!EVP_PKEY_ASN1_METHOD sk_EVP_PKEY_ASN1_METHOD_new_null;
alias SKM_sk_free!EVP_PKEY_ASN1_METHOD sk_EVP_PKEY_ASN1_METHOD_free;
alias SKM_sk_num!EVP_PKEY_ASN1_METHOD sk_EVP_PKEY_ASN1_METHOD_num;
alias SKM_sk_value!EVP_PKEY_ASN1_METHOD sk_EVP_PKEY_ASN1_METHOD_value;
alias SKM_sk_set!EVP_PKEY_ASN1_METHOD sk_EVP_PKEY_ASN1_METHOD_set;
alias SKM_sk_zero!EVP_PKEY_ASN1_METHOD sk_EVP_PKEY_ASN1_METHOD_zero;
alias SKM_sk_push!EVP_PKEY_ASN1_METHOD sk_EVP_PKEY_ASN1_METHOD_push;
alias SKM_sk_unshift!EVP_PKEY_ASN1_METHOD sk_EVP_PKEY_ASN1_METHOD_unshift;
alias SKM_sk_find!EVP_PKEY_ASN1_METHOD sk_EVP_PKEY_ASN1_METHOD_find;
alias SKM_sk_find_ex!EVP_PKEY_ASN1_METHOD sk_EVP_PKEY_ASN1_METHOD_find_ex;
alias SKM_sk_delete!EVP_PKEY_ASN1_METHOD sk_EVP_PKEY_ASN1_METHOD_delete;
alias SKM_sk_delete_ptr!EVP_PKEY_ASN1_METHOD sk_EVP_PKEY_ASN1_METHOD_delete_ptr;
alias SKM_sk_insert!EVP_PKEY_ASN1_METHOD sk_EVP_PKEY_ASN1_METHOD_insert;
alias SKM_sk_set_cmp_func!EVP_PKEY_ASN1_METHOD sk_EVP_PKEY_ASN1_METHOD_set_cmp_func;
alias SKM_sk_dup!EVP_PKEY_ASN1_METHOD sk_EVP_PKEY_ASN1_METHOD_dup;
alias SKM_sk_pop_free!EVP_PKEY_ASN1_METHOD sk_EVP_PKEY_ASN1_METHOD_pop_free;
alias SKM_sk_shift!EVP_PKEY_ASN1_METHOD sk_EVP_PKEY_ASN1_METHOD_shift;
alias SKM_sk_pop!EVP_PKEY_ASN1_METHOD sk_EVP_PKEY_ASN1_METHOD_pop;
alias SKM_sk_sort!EVP_PKEY_ASN1_METHOD sk_EVP_PKEY_ASN1_METHOD_sort;
alias SKM_sk_is_sorted!EVP_PKEY_ASN1_METHOD sk_EVP_PKEY_ASN1_METHOD_is_sorted;

alias SKM_sk_new!EVP_PKEY_METHOD sk_EVP_PKEY_METHOD_new;
alias SKM_sk_new_null!EVP_PKEY_METHOD sk_EVP_PKEY_METHOD_new_null;
alias SKM_sk_free!EVP_PKEY_METHOD sk_EVP_PKEY_METHOD_free;
alias SKM_sk_num!EVP_PKEY_METHOD sk_EVP_PKEY_METHOD_num;
alias SKM_sk_value!EVP_PKEY_METHOD sk_EVP_PKEY_METHOD_value;
alias SKM_sk_set!EVP_PKEY_METHOD sk_EVP_PKEY_METHOD_set;
alias SKM_sk_zero!EVP_PKEY_METHOD sk_EVP_PKEY_METHOD_zero;
alias SKM_sk_push!EVP_PKEY_METHOD sk_EVP_PKEY_METHOD_push;
alias SKM_sk_unshift!EVP_PKEY_METHOD sk_EVP_PKEY_METHOD_unshift;
alias SKM_sk_find!EVP_PKEY_METHOD sk_EVP_PKEY_METHOD_find;
alias SKM_sk_find_ex!EVP_PKEY_METHOD sk_EVP_PKEY_METHOD_find_ex;
alias SKM_sk_delete!EVP_PKEY_METHOD sk_EVP_PKEY_METHOD_delete;
alias SKM_sk_delete_ptr!EVP_PKEY_METHOD sk_EVP_PKEY_METHOD_delete_ptr;
alias SKM_sk_insert!EVP_PKEY_METHOD sk_EVP_PKEY_METHOD_insert;
alias SKM_sk_set_cmp_func!EVP_PKEY_METHOD sk_EVP_PKEY_METHOD_set_cmp_func;
alias SKM_sk_dup!EVP_PKEY_METHOD sk_EVP_PKEY_METHOD_dup;
alias SKM_sk_pop_free!EVP_PKEY_METHOD sk_EVP_PKEY_METHOD_pop_free;
alias SKM_sk_shift!EVP_PKEY_METHOD sk_EVP_PKEY_METHOD_shift;
alias SKM_sk_pop!EVP_PKEY_METHOD sk_EVP_PKEY_METHOD_pop;
alias SKM_sk_sort!EVP_PKEY_METHOD sk_EVP_PKEY_METHOD_sort;
alias SKM_sk_is_sorted!EVP_PKEY_METHOD sk_EVP_PKEY_METHOD_is_sorted;

alias SKM_sk_new!GENERAL_NAME sk_GENERAL_NAME_new;
alias SKM_sk_new_null!GENERAL_NAME sk_GENERAL_NAME_new_null;
alias SKM_sk_free!GENERAL_NAME sk_GENERAL_NAME_free;
alias SKM_sk_num!GENERAL_NAME sk_GENERAL_NAME_num;
alias SKM_sk_value!GENERAL_NAME sk_GENERAL_NAME_value;
alias SKM_sk_set!GENERAL_NAME sk_GENERAL_NAME_set;
alias SKM_sk_zero!GENERAL_NAME sk_GENERAL_NAME_zero;
alias SKM_sk_push!GENERAL_NAME sk_GENERAL_NAME_push;
alias SKM_sk_unshift!GENERAL_NAME sk_GENERAL_NAME_unshift;
alias SKM_sk_find!GENERAL_NAME sk_GENERAL_NAME_find;
alias SKM_sk_find_ex!GENERAL_NAME sk_GENERAL_NAME_find_ex;
alias SKM_sk_delete!GENERAL_NAME sk_GENERAL_NAME_delete;
alias SKM_sk_delete_ptr!GENERAL_NAME sk_GENERAL_NAME_delete_ptr;
alias SKM_sk_insert!GENERAL_NAME sk_GENERAL_NAME_insert;
alias SKM_sk_set_cmp_func!GENERAL_NAME sk_GENERAL_NAME_set_cmp_func;
alias SKM_sk_dup!GENERAL_NAME sk_GENERAL_NAME_dup;
alias SKM_sk_pop_free!GENERAL_NAME sk_GENERAL_NAME_pop_free;
alias SKM_sk_shift!GENERAL_NAME sk_GENERAL_NAME_shift;
alias SKM_sk_pop!GENERAL_NAME sk_GENERAL_NAME_pop;
alias SKM_sk_sort!GENERAL_NAME sk_GENERAL_NAME_sort;
alias SKM_sk_is_sorted!GENERAL_NAME sk_GENERAL_NAME_is_sorted;

alias SKM_sk_new!GENERAL_NAMES sk_GENERAL_NAMES_new;
alias SKM_sk_new_null!GENERAL_NAMES sk_GENERAL_NAMES_new_null;
alias SKM_sk_free!GENERAL_NAMES sk_GENERAL_NAMES_free;
alias SKM_sk_num!GENERAL_NAMES sk_GENERAL_NAMES_num;
alias SKM_sk_value!GENERAL_NAMES sk_GENERAL_NAMES_value;
alias SKM_sk_set!GENERAL_NAMES sk_GENERAL_NAMES_set;
alias SKM_sk_zero!GENERAL_NAMES sk_GENERAL_NAMES_zero;
alias SKM_sk_push!GENERAL_NAMES sk_GENERAL_NAMES_push;
alias SKM_sk_unshift!GENERAL_NAMES sk_GENERAL_NAMES_unshift;
alias SKM_sk_find!GENERAL_NAMES sk_GENERAL_NAMES_find;
alias SKM_sk_find_ex!GENERAL_NAMES sk_GENERAL_NAMES_find_ex;
alias SKM_sk_delete!GENERAL_NAMES sk_GENERAL_NAMES_delete;
alias SKM_sk_delete_ptr!GENERAL_NAMES sk_GENERAL_NAMES_delete_ptr;
alias SKM_sk_insert!GENERAL_NAMES sk_GENERAL_NAMES_insert;
alias SKM_sk_set_cmp_func!GENERAL_NAMES sk_GENERAL_NAMES_set_cmp_func;
alias SKM_sk_dup!GENERAL_NAMES sk_GENERAL_NAMES_dup;
alias SKM_sk_pop_free!GENERAL_NAMES sk_GENERAL_NAMES_pop_free;
alias SKM_sk_shift!GENERAL_NAMES sk_GENERAL_NAMES_shift;
alias SKM_sk_pop!GENERAL_NAMES sk_GENERAL_NAMES_pop;
alias SKM_sk_sort!GENERAL_NAMES sk_GENERAL_NAMES_sort;
alias SKM_sk_is_sorted!GENERAL_NAMES sk_GENERAL_NAMES_is_sorted;

alias SKM_sk_new!GENERAL_SUBTREE sk_GENERAL_SUBTREE_new;
alias SKM_sk_new_null!GENERAL_SUBTREE sk_GENERAL_SUBTREE_new_null;
alias SKM_sk_free!GENERAL_SUBTREE sk_GENERAL_SUBTREE_free;
alias SKM_sk_num!GENERAL_SUBTREE sk_GENERAL_SUBTREE_num;
alias SKM_sk_value!GENERAL_SUBTREE sk_GENERAL_SUBTREE_value;
alias SKM_sk_set!GENERAL_SUBTREE sk_GENERAL_SUBTREE_set;
alias SKM_sk_zero!GENERAL_SUBTREE sk_GENERAL_SUBTREE_zero;
alias SKM_sk_push!GENERAL_SUBTREE sk_GENERAL_SUBTREE_push;
alias SKM_sk_unshift!GENERAL_SUBTREE sk_GENERAL_SUBTREE_unshift;
alias SKM_sk_find!GENERAL_SUBTREE sk_GENERAL_SUBTREE_find;
alias SKM_sk_find_ex!GENERAL_SUBTREE sk_GENERAL_SUBTREE_find_ex;
alias SKM_sk_delete!GENERAL_SUBTREE sk_GENERAL_SUBTREE_delete;
alias SKM_sk_delete_ptr!GENERAL_SUBTREE sk_GENERAL_SUBTREE_delete_ptr;
alias SKM_sk_insert!GENERAL_SUBTREE sk_GENERAL_SUBTREE_insert;
alias SKM_sk_set_cmp_func!GENERAL_SUBTREE sk_GENERAL_SUBTREE_set_cmp_func;
alias SKM_sk_dup!GENERAL_SUBTREE sk_GENERAL_SUBTREE_dup;
alias SKM_sk_pop_free!GENERAL_SUBTREE sk_GENERAL_SUBTREE_pop_free;
alias SKM_sk_shift!GENERAL_SUBTREE sk_GENERAL_SUBTREE_shift;
alias SKM_sk_pop!GENERAL_SUBTREE sk_GENERAL_SUBTREE_pop;
alias SKM_sk_sort!GENERAL_SUBTREE sk_GENERAL_SUBTREE_sort;
alias SKM_sk_is_sorted!GENERAL_SUBTREE sk_GENERAL_SUBTREE_is_sorted;

alias SKM_sk_new!IPAddressFamily sk_IPAddressFamily_new;
alias SKM_sk_new_null!IPAddressFamily sk_IPAddressFamily_new_null;
alias SKM_sk_free!IPAddressFamily sk_IPAddressFamily_free;
alias SKM_sk_num!IPAddressFamily sk_IPAddressFamily_num;
alias SKM_sk_value!IPAddressFamily sk_IPAddressFamily_value;
alias SKM_sk_set!IPAddressFamily sk_IPAddressFamily_set;
alias SKM_sk_zero!IPAddressFamily sk_IPAddressFamily_zero;
alias SKM_sk_push!IPAddressFamily sk_IPAddressFamily_push;
alias SKM_sk_unshift!IPAddressFamily sk_IPAddressFamily_unshift;
alias SKM_sk_find!IPAddressFamily sk_IPAddressFamily_find;
alias SKM_sk_find_ex!IPAddressFamily sk_IPAddressFamily_find_ex;
alias SKM_sk_delete!IPAddressFamily sk_IPAddressFamily_delete;
alias SKM_sk_delete_ptr!IPAddressFamily sk_IPAddressFamily_delete_ptr;
alias SKM_sk_insert!IPAddressFamily sk_IPAddressFamily_insert;
alias SKM_sk_set_cmp_func!IPAddressFamily sk_IPAddressFamily_set_cmp_func;
alias SKM_sk_dup!IPAddressFamily sk_IPAddressFamily_dup;
alias SKM_sk_pop_free!IPAddressFamily sk_IPAddressFamily_pop_free;
alias SKM_sk_shift!IPAddressFamily sk_IPAddressFamily_shift;
alias SKM_sk_pop!IPAddressFamily sk_IPAddressFamily_pop;
alias SKM_sk_sort!IPAddressFamily sk_IPAddressFamily_sort;
alias SKM_sk_is_sorted!IPAddressFamily sk_IPAddressFamily_is_sorted;

alias SKM_sk_new!IPAddressOrRange sk_IPAddressOrRange_new;
alias SKM_sk_new_null!IPAddressOrRange sk_IPAddressOrRange_new_null;
alias SKM_sk_free!IPAddressOrRange sk_IPAddressOrRange_free;
alias SKM_sk_num!IPAddressOrRange sk_IPAddressOrRange_num;
alias SKM_sk_value!IPAddressOrRange sk_IPAddressOrRange_value;
alias SKM_sk_set!IPAddressOrRange sk_IPAddressOrRange_set;
alias SKM_sk_zero!IPAddressOrRange sk_IPAddressOrRange_zero;
alias SKM_sk_push!IPAddressOrRange sk_IPAddressOrRange_push;
alias SKM_sk_unshift!IPAddressOrRange sk_IPAddressOrRange_unshift;
alias SKM_sk_find!IPAddressOrRange sk_IPAddressOrRange_find;
alias SKM_sk_find_ex!IPAddressOrRange sk_IPAddressOrRange_find_ex;
alias SKM_sk_delete!IPAddressOrRange sk_IPAddressOrRange_delete;
alias SKM_sk_delete_ptr!IPAddressOrRange sk_IPAddressOrRange_delete_ptr;
alias SKM_sk_insert!IPAddressOrRange sk_IPAddressOrRange_insert;
alias SKM_sk_set_cmp_func!IPAddressOrRange sk_IPAddressOrRange_set_cmp_func;
alias SKM_sk_dup!IPAddressOrRange sk_IPAddressOrRange_dup;
alias SKM_sk_pop_free!IPAddressOrRange sk_IPAddressOrRange_pop_free;
alias SKM_sk_shift!IPAddressOrRange sk_IPAddressOrRange_shift;
alias SKM_sk_pop!IPAddressOrRange sk_IPAddressOrRange_pop;
alias SKM_sk_sort!IPAddressOrRange sk_IPAddressOrRange_sort;
alias SKM_sk_is_sorted!IPAddressOrRange sk_IPAddressOrRange_is_sorted;

import deimos.openssl.krb5_asn;
alias SKM_sk_new!KRB5_APREQBODY sk_KRB5_APREQBODY_new;
alias SKM_sk_new_null!KRB5_APREQBODY sk_KRB5_APREQBODY_new_null;
alias SKM_sk_free!KRB5_APREQBODY sk_KRB5_APREQBODY_free;
alias SKM_sk_num!KRB5_APREQBODY sk_KRB5_APREQBODY_num;
alias SKM_sk_value!KRB5_APREQBODY sk_KRB5_APREQBODY_value;
alias SKM_sk_set!KRB5_APREQBODY sk_KRB5_APREQBODY_set;
alias SKM_sk_zero!KRB5_APREQBODY sk_KRB5_APREQBODY_zero;
alias SKM_sk_push!KRB5_APREQBODY sk_KRB5_APREQBODY_push;
alias SKM_sk_unshift!KRB5_APREQBODY sk_KRB5_APREQBODY_unshift;
alias SKM_sk_find!KRB5_APREQBODY sk_KRB5_APREQBODY_find;
alias SKM_sk_find_ex!KRB5_APREQBODY sk_KRB5_APREQBODY_find_ex;
alias SKM_sk_delete!KRB5_APREQBODY sk_KRB5_APREQBODY_delete;
alias SKM_sk_delete_ptr!KRB5_APREQBODY sk_KRB5_APREQBODY_delete_ptr;
alias SKM_sk_insert!KRB5_APREQBODY sk_KRB5_APREQBODY_insert;
alias SKM_sk_set_cmp_func!KRB5_APREQBODY sk_KRB5_APREQBODY_set_cmp_func;
alias SKM_sk_dup!KRB5_APREQBODY sk_KRB5_APREQBODY_dup;
alias SKM_sk_pop_free!KRB5_APREQBODY sk_KRB5_APREQBODY_pop_free;
alias SKM_sk_shift!KRB5_APREQBODY sk_KRB5_APREQBODY_shift;
alias SKM_sk_pop!KRB5_APREQBODY sk_KRB5_APREQBODY_pop;
alias SKM_sk_sort!KRB5_APREQBODY sk_KRB5_APREQBODY_sort;
alias SKM_sk_is_sorted!KRB5_APREQBODY sk_KRB5_APREQBODY_is_sorted;

alias SKM_sk_new!KRB5_AUTHDATA sk_KRB5_AUTHDATA_new;
alias SKM_sk_new_null!KRB5_AUTHDATA sk_KRB5_AUTHDATA_new_null;
alias SKM_sk_free!KRB5_AUTHDATA sk_KRB5_AUTHDATA_free;
alias SKM_sk_num!KRB5_AUTHDATA sk_KRB5_AUTHDATA_num;
alias SKM_sk_value!KRB5_AUTHDATA sk_KRB5_AUTHDATA_value;
alias SKM_sk_set!KRB5_AUTHDATA sk_KRB5_AUTHDATA_set;
alias SKM_sk_zero!KRB5_AUTHDATA sk_KRB5_AUTHDATA_zero;
alias SKM_sk_push!KRB5_AUTHDATA sk_KRB5_AUTHDATA_push;
alias SKM_sk_unshift!KRB5_AUTHDATA sk_KRB5_AUTHDATA_unshift;
alias SKM_sk_find!KRB5_AUTHDATA sk_KRB5_AUTHDATA_find;
alias SKM_sk_find_ex!KRB5_AUTHDATA sk_KRB5_AUTHDATA_find_ex;
alias SKM_sk_delete!KRB5_AUTHDATA sk_KRB5_AUTHDATA_delete;
alias SKM_sk_delete_ptr!KRB5_AUTHDATA sk_KRB5_AUTHDATA_delete_ptr;
alias SKM_sk_insert!KRB5_AUTHDATA sk_KRB5_AUTHDATA_insert;
alias SKM_sk_set_cmp_func!KRB5_AUTHDATA sk_KRB5_AUTHDATA_set_cmp_func;
alias SKM_sk_dup!KRB5_AUTHDATA sk_KRB5_AUTHDATA_dup;
alias SKM_sk_pop_free!KRB5_AUTHDATA sk_KRB5_AUTHDATA_pop_free;
alias SKM_sk_shift!KRB5_AUTHDATA sk_KRB5_AUTHDATA_shift;
alias SKM_sk_pop!KRB5_AUTHDATA sk_KRB5_AUTHDATA_pop;
alias SKM_sk_sort!KRB5_AUTHDATA sk_KRB5_AUTHDATA_sort;
alias SKM_sk_is_sorted!KRB5_AUTHDATA sk_KRB5_AUTHDATA_is_sorted;

alias SKM_sk_new!KRB5_AUTHENTBODY sk_KRB5_AUTHENTBODY_new;
alias SKM_sk_new_null!KRB5_AUTHENTBODY sk_KRB5_AUTHENTBODY_new_null;
alias SKM_sk_free!KRB5_AUTHENTBODY sk_KRB5_AUTHENTBODY_free;
alias SKM_sk_num!KRB5_AUTHENTBODY sk_KRB5_AUTHENTBODY_num;
alias SKM_sk_value!KRB5_AUTHENTBODY sk_KRB5_AUTHENTBODY_value;
alias SKM_sk_set!KRB5_AUTHENTBODY sk_KRB5_AUTHENTBODY_set;
alias SKM_sk_zero!KRB5_AUTHENTBODY sk_KRB5_AUTHENTBODY_zero;
alias SKM_sk_push!KRB5_AUTHENTBODY sk_KRB5_AUTHENTBODY_push;
alias SKM_sk_unshift!KRB5_AUTHENTBODY sk_KRB5_AUTHENTBODY_unshift;
alias SKM_sk_find!KRB5_AUTHENTBODY sk_KRB5_AUTHENTBODY_find;
alias SKM_sk_find_ex!KRB5_AUTHENTBODY sk_KRB5_AUTHENTBODY_find_ex;
alias SKM_sk_delete!KRB5_AUTHENTBODY sk_KRB5_AUTHENTBODY_delete;
alias SKM_sk_delete_ptr!KRB5_AUTHENTBODY sk_KRB5_AUTHENTBODY_delete_ptr;
alias SKM_sk_insert!KRB5_AUTHENTBODY sk_KRB5_AUTHENTBODY_insert;
alias SKM_sk_set_cmp_func!KRB5_AUTHENTBODY sk_KRB5_AUTHENTBODY_set_cmp_func;
alias SKM_sk_dup!KRB5_AUTHENTBODY sk_KRB5_AUTHENTBODY_dup;
alias SKM_sk_pop_free!KRB5_AUTHENTBODY sk_KRB5_AUTHENTBODY_pop_free;
alias SKM_sk_shift!KRB5_AUTHENTBODY sk_KRB5_AUTHENTBODY_shift;
alias SKM_sk_pop!KRB5_AUTHENTBODY sk_KRB5_AUTHENTBODY_pop;
alias SKM_sk_sort!KRB5_AUTHENTBODY sk_KRB5_AUTHENTBODY_sort;
alias SKM_sk_is_sorted!KRB5_AUTHENTBODY sk_KRB5_AUTHENTBODY_is_sorted;

alias SKM_sk_new!KRB5_CHECKSUM sk_KRB5_CHECKSUM_new;
alias SKM_sk_new_null!KRB5_CHECKSUM sk_KRB5_CHECKSUM_new_null;
alias SKM_sk_free!KRB5_CHECKSUM sk_KRB5_CHECKSUM_free;
alias SKM_sk_num!KRB5_CHECKSUM sk_KRB5_CHECKSUM_num;
alias SKM_sk_value!KRB5_CHECKSUM sk_KRB5_CHECKSUM_value;
alias SKM_sk_set!KRB5_CHECKSUM sk_KRB5_CHECKSUM_set;
alias SKM_sk_zero!KRB5_CHECKSUM sk_KRB5_CHECKSUM_zero;
alias SKM_sk_push!KRB5_CHECKSUM sk_KRB5_CHECKSUM_push;
alias SKM_sk_unshift!KRB5_CHECKSUM sk_KRB5_CHECKSUM_unshift;
alias SKM_sk_find!KRB5_CHECKSUM sk_KRB5_CHECKSUM_find;
alias SKM_sk_find_ex!KRB5_CHECKSUM sk_KRB5_CHECKSUM_find_ex;
alias SKM_sk_delete!KRB5_CHECKSUM sk_KRB5_CHECKSUM_delete;
alias SKM_sk_delete_ptr!KRB5_CHECKSUM sk_KRB5_CHECKSUM_delete_ptr;
alias SKM_sk_insert!KRB5_CHECKSUM sk_KRB5_CHECKSUM_insert;
alias SKM_sk_set_cmp_func!KRB5_CHECKSUM sk_KRB5_CHECKSUM_set_cmp_func;
alias SKM_sk_dup!KRB5_CHECKSUM sk_KRB5_CHECKSUM_dup;
alias SKM_sk_pop_free!KRB5_CHECKSUM sk_KRB5_CHECKSUM_pop_free;
alias SKM_sk_shift!KRB5_CHECKSUM sk_KRB5_CHECKSUM_shift;
alias SKM_sk_pop!KRB5_CHECKSUM sk_KRB5_CHECKSUM_pop;
alias SKM_sk_sort!KRB5_CHECKSUM sk_KRB5_CHECKSUM_sort;
alias SKM_sk_is_sorted!KRB5_CHECKSUM sk_KRB5_CHECKSUM_is_sorted;

alias SKM_sk_new!KRB5_ENCDATA sk_KRB5_ENCDATA_new;
alias SKM_sk_new_null!KRB5_ENCDATA sk_KRB5_ENCDATA_new_null;
alias SKM_sk_free!KRB5_ENCDATA sk_KRB5_ENCDATA_free;
alias SKM_sk_num!KRB5_ENCDATA sk_KRB5_ENCDATA_num;
alias SKM_sk_value!KRB5_ENCDATA sk_KRB5_ENCDATA_value;
alias SKM_sk_set!KRB5_ENCDATA sk_KRB5_ENCDATA_set;
alias SKM_sk_zero!KRB5_ENCDATA sk_KRB5_ENCDATA_zero;
alias SKM_sk_push!KRB5_ENCDATA sk_KRB5_ENCDATA_push;
alias SKM_sk_unshift!KRB5_ENCDATA sk_KRB5_ENCDATA_unshift;
alias SKM_sk_find!KRB5_ENCDATA sk_KRB5_ENCDATA_find;
alias SKM_sk_find_ex!KRB5_ENCDATA sk_KRB5_ENCDATA_find_ex;
alias SKM_sk_delete!KRB5_ENCDATA sk_KRB5_ENCDATA_delete;
alias SKM_sk_delete_ptr!KRB5_ENCDATA sk_KRB5_ENCDATA_delete_ptr;
alias SKM_sk_insert!KRB5_ENCDATA sk_KRB5_ENCDATA_insert;
alias SKM_sk_set_cmp_func!KRB5_ENCDATA sk_KRB5_ENCDATA_set_cmp_func;
alias SKM_sk_dup!KRB5_ENCDATA sk_KRB5_ENCDATA_dup;
alias SKM_sk_pop_free!KRB5_ENCDATA sk_KRB5_ENCDATA_pop_free;
alias SKM_sk_shift!KRB5_ENCDATA sk_KRB5_ENCDATA_shift;
alias SKM_sk_pop!KRB5_ENCDATA sk_KRB5_ENCDATA_pop;
alias SKM_sk_sort!KRB5_ENCDATA sk_KRB5_ENCDATA_sort;
alias SKM_sk_is_sorted!KRB5_ENCDATA sk_KRB5_ENCDATA_is_sorted;

alias SKM_sk_new!KRB5_ENCKEY sk_KRB5_ENCKEY_new;
alias SKM_sk_new_null!KRB5_ENCKEY sk_KRB5_ENCKEY_new_null;
alias SKM_sk_free!KRB5_ENCKEY sk_KRB5_ENCKEY_free;
alias SKM_sk_num!KRB5_ENCKEY sk_KRB5_ENCKEY_num;
alias SKM_sk_value!KRB5_ENCKEY sk_KRB5_ENCKEY_value;
alias SKM_sk_set!KRB5_ENCKEY sk_KRB5_ENCKEY_set;
alias SKM_sk_zero!KRB5_ENCKEY sk_KRB5_ENCKEY_zero;
alias SKM_sk_push!KRB5_ENCKEY sk_KRB5_ENCKEY_push;
alias SKM_sk_unshift!KRB5_ENCKEY sk_KRB5_ENCKEY_unshift;
alias SKM_sk_find!KRB5_ENCKEY sk_KRB5_ENCKEY_find;
alias SKM_sk_find_ex!KRB5_ENCKEY sk_KRB5_ENCKEY_find_ex;
alias SKM_sk_delete!KRB5_ENCKEY sk_KRB5_ENCKEY_delete;
alias SKM_sk_delete_ptr!KRB5_ENCKEY sk_KRB5_ENCKEY_delete_ptr;
alias SKM_sk_insert!KRB5_ENCKEY sk_KRB5_ENCKEY_insert;
alias SKM_sk_set_cmp_func!KRB5_ENCKEY sk_KRB5_ENCKEY_set_cmp_func;
alias SKM_sk_dup!KRB5_ENCKEY sk_KRB5_ENCKEY_dup;
alias SKM_sk_pop_free!KRB5_ENCKEY sk_KRB5_ENCKEY_pop_free;
alias SKM_sk_shift!KRB5_ENCKEY sk_KRB5_ENCKEY_shift;
alias SKM_sk_pop!KRB5_ENCKEY sk_KRB5_ENCKEY_pop;
alias SKM_sk_sort!KRB5_ENCKEY sk_KRB5_ENCKEY_sort;
alias SKM_sk_is_sorted!KRB5_ENCKEY sk_KRB5_ENCKEY_is_sorted;

alias SKM_sk_new!KRB5_PRINCNAME sk_KRB5_PRINCNAME_new;
alias SKM_sk_new_null!KRB5_PRINCNAME sk_KRB5_PRINCNAME_new_null;
alias SKM_sk_free!KRB5_PRINCNAME sk_KRB5_PRINCNAME_free;
alias SKM_sk_num!KRB5_PRINCNAME sk_KRB5_PRINCNAME_num;
alias SKM_sk_value!KRB5_PRINCNAME sk_KRB5_PRINCNAME_value;
alias SKM_sk_set!KRB5_PRINCNAME sk_KRB5_PRINCNAME_set;
alias SKM_sk_zero!KRB5_PRINCNAME sk_KRB5_PRINCNAME_zero;
alias SKM_sk_push!KRB5_PRINCNAME sk_KRB5_PRINCNAME_push;
alias SKM_sk_unshift!KRB5_PRINCNAME sk_KRB5_PRINCNAME_unshift;
alias SKM_sk_find!KRB5_PRINCNAME sk_KRB5_PRINCNAME_find;
alias SKM_sk_find_ex!KRB5_PRINCNAME sk_KRB5_PRINCNAME_find_ex;
alias SKM_sk_delete!KRB5_PRINCNAME sk_KRB5_PRINCNAME_delete;
alias SKM_sk_delete_ptr!KRB5_PRINCNAME sk_KRB5_PRINCNAME_delete_ptr;
alias SKM_sk_insert!KRB5_PRINCNAME sk_KRB5_PRINCNAME_insert;
alias SKM_sk_set_cmp_func!KRB5_PRINCNAME sk_KRB5_PRINCNAME_set_cmp_func;
alias SKM_sk_dup!KRB5_PRINCNAME sk_KRB5_PRINCNAME_dup;
alias SKM_sk_pop_free!KRB5_PRINCNAME sk_KRB5_PRINCNAME_pop_free;
alias SKM_sk_shift!KRB5_PRINCNAME sk_KRB5_PRINCNAME_shift;
alias SKM_sk_pop!KRB5_PRINCNAME sk_KRB5_PRINCNAME_pop;
alias SKM_sk_sort!KRB5_PRINCNAME sk_KRB5_PRINCNAME_sort;
alias SKM_sk_is_sorted!KRB5_PRINCNAME sk_KRB5_PRINCNAME_is_sorted;

alias SKM_sk_new!KRB5_TKTBODY sk_KRB5_TKTBODY_new;
alias SKM_sk_new_null!KRB5_TKTBODY sk_KRB5_TKTBODY_new_null;
alias SKM_sk_free!KRB5_TKTBODY sk_KRB5_TKTBODY_free;
alias SKM_sk_num!KRB5_TKTBODY sk_KRB5_TKTBODY_num;
alias SKM_sk_value!KRB5_TKTBODY sk_KRB5_TKTBODY_value;
alias SKM_sk_set!KRB5_TKTBODY sk_KRB5_TKTBODY_set;
alias SKM_sk_zero!KRB5_TKTBODY sk_KRB5_TKTBODY_zero;
alias SKM_sk_push!KRB5_TKTBODY sk_KRB5_TKTBODY_push;
alias SKM_sk_unshift!KRB5_TKTBODY sk_KRB5_TKTBODY_unshift;
alias SKM_sk_find!KRB5_TKTBODY sk_KRB5_TKTBODY_find;
alias SKM_sk_find_ex!KRB5_TKTBODY sk_KRB5_TKTBODY_find_ex;
alias SKM_sk_delete!KRB5_TKTBODY sk_KRB5_TKTBODY_delete;
alias SKM_sk_delete_ptr!KRB5_TKTBODY sk_KRB5_TKTBODY_delete_ptr;
alias SKM_sk_insert!KRB5_TKTBODY sk_KRB5_TKTBODY_insert;
alias SKM_sk_set_cmp_func!KRB5_TKTBODY sk_KRB5_TKTBODY_set_cmp_func;
alias SKM_sk_dup!KRB5_TKTBODY sk_KRB5_TKTBODY_dup;
alias SKM_sk_pop_free!KRB5_TKTBODY sk_KRB5_TKTBODY_pop_free;
alias SKM_sk_shift!KRB5_TKTBODY sk_KRB5_TKTBODY_shift;
alias SKM_sk_pop!KRB5_TKTBODY sk_KRB5_TKTBODY_pop;
alias SKM_sk_sort!KRB5_TKTBODY sk_KRB5_TKTBODY_sort;
alias SKM_sk_is_sorted!KRB5_TKTBODY sk_KRB5_TKTBODY_is_sorted;

/+ Internal crypto types.
alias SKM_sk_new!MEM_OBJECT_DATA sk_MEM_OBJECT_DATA_new;
alias SKM_sk_new_null!MEM_OBJECT_DATA sk_MEM_OBJECT_DATA_new_null;
alias SKM_sk_free!MEM_OBJECT_DATA sk_MEM_OBJECT_DATA_free;
alias SKM_sk_num!MEM_OBJECT_DATA sk_MEM_OBJECT_DATA_num;
alias SKM_sk_value!MEM_OBJECT_DATA sk_MEM_OBJECT_DATA_value;
alias SKM_sk_set!MEM_OBJECT_DATA sk_MEM_OBJECT_DATA_set;
alias SKM_sk_zero!MEM_OBJECT_DATA sk_MEM_OBJECT_DATA_zero;
alias SKM_sk_push!MEM_OBJECT_DATA sk_MEM_OBJECT_DATA_push;
alias SKM_sk_unshift!MEM_OBJECT_DATA sk_MEM_OBJECT_DATA_unshift;
alias SKM_sk_find!MEM_OBJECT_DATA sk_MEM_OBJECT_DATA_find;
alias SKM_sk_find_ex!MEM_OBJECT_DATA sk_MEM_OBJECT_DATA_find_ex;
alias SKM_sk_delete!MEM_OBJECT_DATA sk_MEM_OBJECT_DATA_delete;
alias SKM_sk_delete_ptr!MEM_OBJECT_DATA sk_MEM_OBJECT_DATA_delete_ptr;
alias SKM_sk_insert!MEM_OBJECT_DATA sk_MEM_OBJECT_DATA_insert;
alias SKM_sk_set_cmp_func!MEM_OBJECT_DATA sk_MEM_OBJECT_DATA_set_cmp_func;
alias SKM_sk_dup!MEM_OBJECT_DATA sk_MEM_OBJECT_DATA_dup;
alias SKM_sk_pop_free!MEM_OBJECT_DATA sk_MEM_OBJECT_DATA_pop_free;
alias SKM_sk_shift!MEM_OBJECT_DATA sk_MEM_OBJECT_DATA_shift;
alias SKM_sk_pop!MEM_OBJECT_DATA sk_MEM_OBJECT_DATA_pop;
alias SKM_sk_sort!MEM_OBJECT_DATA sk_MEM_OBJECT_DATA_sort;
alias SKM_sk_is_sorted!MEM_OBJECT_DATA sk_MEM_OBJECT_DATA_is_sorted;

alias SKM_sk_new!MIME_HEADER sk_MIME_HEADER_new;
alias SKM_sk_new_null!MIME_HEADER sk_MIME_HEADER_new_null;
alias SKM_sk_free!MIME_HEADER sk_MIME_HEADER_free;
alias SKM_sk_num!MIME_HEADER sk_MIME_HEADER_num;
alias SKM_sk_value!MIME_HEADER sk_MIME_HEADER_value;
alias SKM_sk_set!MIME_HEADER sk_MIME_HEADER_set;
alias SKM_sk_zero!MIME_HEADER sk_MIME_HEADER_zero;
alias SKM_sk_push!MIME_HEADER sk_MIME_HEADER_push;
alias SKM_sk_unshift!MIME_HEADER sk_MIME_HEADER_unshift;
alias SKM_sk_find!MIME_HEADER sk_MIME_HEADER_find;
alias SKM_sk_find_ex!MIME_HEADER sk_MIME_HEADER_find_ex;
alias SKM_sk_delete!MIME_HEADER sk_MIME_HEADER_delete;
alias SKM_sk_delete_ptr!MIME_HEADER sk_MIME_HEADER_delete_ptr;
alias SKM_sk_insert!MIME_HEADER sk_MIME_HEADER_insert;
alias SKM_sk_set_cmp_func!MIME_HEADER sk_MIME_HEADER_set_cmp_func;
alias SKM_sk_dup!MIME_HEADER sk_MIME_HEADER_dup;
alias SKM_sk_pop_free!MIME_HEADER sk_MIME_HEADER_pop_free;
alias SKM_sk_shift!MIME_HEADER sk_MIME_HEADER_shift;
alias SKM_sk_pop!MIME_HEADER sk_MIME_HEADER_pop;
alias SKM_sk_sort!MIME_HEADER sk_MIME_HEADER_sort;
alias SKM_sk_is_sorted!MIME_HEADER sk_MIME_HEADER_is_sorted;

alias SKM_sk_new!MIME_PARAM sk_MIME_PARAM_new;
alias SKM_sk_new_null!MIME_PARAM sk_MIME_PARAM_new_null;
alias SKM_sk_free!MIME_PARAM sk_MIME_PARAM_free;
alias SKM_sk_num!MIME_PARAM sk_MIME_PARAM_num;
alias SKM_sk_value!MIME_PARAM sk_MIME_PARAM_value;
alias SKM_sk_set!MIME_PARAM sk_MIME_PARAM_set;
alias SKM_sk_zero!MIME_PARAM sk_MIME_PARAM_zero;
alias SKM_sk_push!MIME_PARAM sk_MIME_PARAM_push;
alias SKM_sk_unshift!MIME_PARAM sk_MIME_PARAM_unshift;
alias SKM_sk_find!MIME_PARAM sk_MIME_PARAM_find;
alias SKM_sk_find_ex!MIME_PARAM sk_MIME_PARAM_find_ex;
alias SKM_sk_delete!MIME_PARAM sk_MIME_PARAM_delete;
alias SKM_sk_delete_ptr!MIME_PARAM sk_MIME_PARAM_delete_ptr;
alias SKM_sk_insert!MIME_PARAM sk_MIME_PARAM_insert;
alias SKM_sk_set_cmp_func!MIME_PARAM sk_MIME_PARAM_set_cmp_func;
alias SKM_sk_dup!MIME_PARAM sk_MIME_PARAM_dup;
alias SKM_sk_pop_free!MIME_PARAM sk_MIME_PARAM_pop_free;
alias SKM_sk_shift!MIME_PARAM sk_MIME_PARAM_shift;
alias SKM_sk_pop!MIME_PARAM sk_MIME_PARAM_pop;
alias SKM_sk_sort!MIME_PARAM sk_MIME_PARAM_sort;
alias SKM_sk_is_sorted!MIME_PARAM sk_MIME_PARAM_is_sorted;

alias SKM_sk_new!NAME_FUNCS sk_NAME_FUNCS_new;
alias SKM_sk_new_null!NAME_FUNCS sk_NAME_FUNCS_new_null;
alias SKM_sk_free!NAME_FUNCS sk_NAME_FUNCS_free;
alias SKM_sk_num!NAME_FUNCS sk_NAME_FUNCS_num;
alias SKM_sk_value!NAME_FUNCS sk_NAME_FUNCS_value;
alias SKM_sk_set!NAME_FUNCS sk_NAME_FUNCS_set;
alias SKM_sk_zero!NAME_FUNCS sk_NAME_FUNCS_zero;
alias SKM_sk_push!NAME_FUNCS sk_NAME_FUNCS_push;
alias SKM_sk_unshift!NAME_FUNCS sk_NAME_FUNCS_unshift;
alias SKM_sk_find!NAME_FUNCS sk_NAME_FUNCS_find;
alias SKM_sk_find_ex!NAME_FUNCS sk_NAME_FUNCS_find_ex;
alias SKM_sk_delete!NAME_FUNCS sk_NAME_FUNCS_delete;
alias SKM_sk_delete_ptr!NAME_FUNCS sk_NAME_FUNCS_delete_ptr;
alias SKM_sk_insert!NAME_FUNCS sk_NAME_FUNCS_insert;
alias SKM_sk_set_cmp_func!NAME_FUNCS sk_NAME_FUNCS_set_cmp_func;
alias SKM_sk_dup!NAME_FUNCS sk_NAME_FUNCS_dup;
alias SKM_sk_pop_free!NAME_FUNCS sk_NAME_FUNCS_pop_free;
alias SKM_sk_shift!NAME_FUNCS sk_NAME_FUNCS_shift;
alias SKM_sk_pop!NAME_FUNCS sk_NAME_FUNCS_pop;
alias SKM_sk_sort!NAME_FUNCS sk_NAME_FUNCS_sort;
alias SKM_sk_is_sorted!NAME_FUNCS sk_NAME_FUNCS_is_sorted;
+/

import deimos.openssl.ocsp;
alias SKM_sk_new!OCSP_CERTID sk_OCSP_CERTID_new;
alias SKM_sk_new_null!OCSP_CERTID sk_OCSP_CERTID_new_null;
alias SKM_sk_free!OCSP_CERTID sk_OCSP_CERTID_free;
alias SKM_sk_num!OCSP_CERTID sk_OCSP_CERTID_num;
alias SKM_sk_value!OCSP_CERTID sk_OCSP_CERTID_value;
alias SKM_sk_set!OCSP_CERTID sk_OCSP_CERTID_set;
alias SKM_sk_zero!OCSP_CERTID sk_OCSP_CERTID_zero;
alias SKM_sk_push!OCSP_CERTID sk_OCSP_CERTID_push;
alias SKM_sk_unshift!OCSP_CERTID sk_OCSP_CERTID_unshift;
alias SKM_sk_find!OCSP_CERTID sk_OCSP_CERTID_find;
alias SKM_sk_find_ex!OCSP_CERTID sk_OCSP_CERTID_find_ex;
alias SKM_sk_delete!OCSP_CERTID sk_OCSP_CERTID_delete;
alias SKM_sk_delete_ptr!OCSP_CERTID sk_OCSP_CERTID_delete_ptr;
alias SKM_sk_insert!OCSP_CERTID sk_OCSP_CERTID_insert;
alias SKM_sk_set_cmp_func!OCSP_CERTID sk_OCSP_CERTID_set_cmp_func;
alias SKM_sk_dup!OCSP_CERTID sk_OCSP_CERTID_dup;
alias SKM_sk_pop_free!OCSP_CERTID sk_OCSP_CERTID_pop_free;
alias SKM_sk_shift!OCSP_CERTID sk_OCSP_CERTID_shift;
alias SKM_sk_pop!OCSP_CERTID sk_OCSP_CERTID_pop;
alias SKM_sk_sort!OCSP_CERTID sk_OCSP_CERTID_sort;
alias SKM_sk_is_sorted!OCSP_CERTID sk_OCSP_CERTID_is_sorted;

alias SKM_sk_new!OCSP_ONEREQ sk_OCSP_ONEREQ_new;
alias SKM_sk_new_null!OCSP_ONEREQ sk_OCSP_ONEREQ_new_null;
alias SKM_sk_free!OCSP_ONEREQ sk_OCSP_ONEREQ_free;
alias SKM_sk_num!OCSP_ONEREQ sk_OCSP_ONEREQ_num;
alias SKM_sk_value!OCSP_ONEREQ sk_OCSP_ONEREQ_value;
alias SKM_sk_set!OCSP_ONEREQ sk_OCSP_ONEREQ_set;
alias SKM_sk_zero!OCSP_ONEREQ sk_OCSP_ONEREQ_zero;
alias SKM_sk_push!OCSP_ONEREQ sk_OCSP_ONEREQ_push;
alias SKM_sk_unshift!OCSP_ONEREQ sk_OCSP_ONEREQ_unshift;
alias SKM_sk_find!OCSP_ONEREQ sk_OCSP_ONEREQ_find;
alias SKM_sk_find_ex!OCSP_ONEREQ sk_OCSP_ONEREQ_find_ex;
alias SKM_sk_delete!OCSP_ONEREQ sk_OCSP_ONEREQ_delete;
alias SKM_sk_delete_ptr!OCSP_ONEREQ sk_OCSP_ONEREQ_delete_ptr;
alias SKM_sk_insert!OCSP_ONEREQ sk_OCSP_ONEREQ_insert;
alias SKM_sk_set_cmp_func!OCSP_ONEREQ sk_OCSP_ONEREQ_set_cmp_func;
alias SKM_sk_dup!OCSP_ONEREQ sk_OCSP_ONEREQ_dup;
alias SKM_sk_pop_free!OCSP_ONEREQ sk_OCSP_ONEREQ_pop_free;
alias SKM_sk_shift!OCSP_ONEREQ sk_OCSP_ONEREQ_shift;
alias SKM_sk_pop!OCSP_ONEREQ sk_OCSP_ONEREQ_pop;
alias SKM_sk_sort!OCSP_ONEREQ sk_OCSP_ONEREQ_sort;
alias SKM_sk_is_sorted!OCSP_ONEREQ sk_OCSP_ONEREQ_is_sorted;

alias SKM_sk_new!OCSP_RESPID sk_OCSP_RESPID_new;
alias SKM_sk_new_null!OCSP_RESPID sk_OCSP_RESPID_new_null;
alias SKM_sk_free!OCSP_RESPID sk_OCSP_RESPID_free;
alias SKM_sk_num!OCSP_RESPID sk_OCSP_RESPID_num;
alias SKM_sk_value!OCSP_RESPID sk_OCSP_RESPID_value;
alias SKM_sk_set!OCSP_RESPID sk_OCSP_RESPID_set;
alias SKM_sk_zero!OCSP_RESPID sk_OCSP_RESPID_zero;
alias SKM_sk_push!OCSP_RESPID sk_OCSP_RESPID_push;
alias SKM_sk_unshift!OCSP_RESPID sk_OCSP_RESPID_unshift;
alias SKM_sk_find!OCSP_RESPID sk_OCSP_RESPID_find;
alias SKM_sk_find_ex!OCSP_RESPID sk_OCSP_RESPID_find_ex;
alias SKM_sk_delete!OCSP_RESPID sk_OCSP_RESPID_delete;
alias SKM_sk_delete_ptr!OCSP_RESPID sk_OCSP_RESPID_delete_ptr;
alias SKM_sk_insert!OCSP_RESPID sk_OCSP_RESPID_insert;
alias SKM_sk_set_cmp_func!OCSP_RESPID sk_OCSP_RESPID_set_cmp_func;
alias SKM_sk_dup!OCSP_RESPID sk_OCSP_RESPID_dup;
alias SKM_sk_pop_free!OCSP_RESPID sk_OCSP_RESPID_pop_free;
alias SKM_sk_shift!OCSP_RESPID sk_OCSP_RESPID_shift;
alias SKM_sk_pop!OCSP_RESPID sk_OCSP_RESPID_pop;
alias SKM_sk_sort!OCSP_RESPID sk_OCSP_RESPID_sort;
alias SKM_sk_is_sorted!OCSP_RESPID sk_OCSP_RESPID_is_sorted;

alias SKM_sk_new!OCSP_SINGLERESP sk_OCSP_SINGLERESP_new;
alias SKM_sk_new_null!OCSP_SINGLERESP sk_OCSP_SINGLERESP_new_null;
alias SKM_sk_free!OCSP_SINGLERESP sk_OCSP_SINGLERESP_free;
alias SKM_sk_num!OCSP_SINGLERESP sk_OCSP_SINGLERESP_num;
alias SKM_sk_value!OCSP_SINGLERESP sk_OCSP_SINGLERESP_value;
alias SKM_sk_set!OCSP_SINGLERESP sk_OCSP_SINGLERESP_set;
alias SKM_sk_zero!OCSP_SINGLERESP sk_OCSP_SINGLERESP_zero;
alias SKM_sk_push!OCSP_SINGLERESP sk_OCSP_SINGLERESP_push;
alias SKM_sk_unshift!OCSP_SINGLERESP sk_OCSP_SINGLERESP_unshift;
alias SKM_sk_find!OCSP_SINGLERESP sk_OCSP_SINGLERESP_find;
alias SKM_sk_find_ex!OCSP_SINGLERESP sk_OCSP_SINGLERESP_find_ex;
alias SKM_sk_delete!OCSP_SINGLERESP sk_OCSP_SINGLERESP_delete;
alias SKM_sk_delete_ptr!OCSP_SINGLERESP sk_OCSP_SINGLERESP_delete_ptr;
alias SKM_sk_insert!OCSP_SINGLERESP sk_OCSP_SINGLERESP_insert;
alias SKM_sk_set_cmp_func!OCSP_SINGLERESP sk_OCSP_SINGLERESP_set_cmp_func;
alias SKM_sk_dup!OCSP_SINGLERESP sk_OCSP_SINGLERESP_dup;
alias SKM_sk_pop_free!OCSP_SINGLERESP sk_OCSP_SINGLERESP_pop_free;
alias SKM_sk_shift!OCSP_SINGLERESP sk_OCSP_SINGLERESP_shift;
alias SKM_sk_pop!OCSP_SINGLERESP sk_OCSP_SINGLERESP_pop;
alias SKM_sk_sort!OCSP_SINGLERESP sk_OCSP_SINGLERESP_sort;
alias SKM_sk_is_sorted!OCSP_SINGLERESP sk_OCSP_SINGLERESP_is_sorted;

import deimos.openssl.pkcs12;
alias SKM_sk_new!PKCS12_SAFEBAG sk_PKCS12_SAFEBAG_new;
alias SKM_sk_new_null!PKCS12_SAFEBAG sk_PKCS12_SAFEBAG_new_null;
alias SKM_sk_free!PKCS12_SAFEBAG sk_PKCS12_SAFEBAG_free;
alias SKM_sk_num!PKCS12_SAFEBAG sk_PKCS12_SAFEBAG_num;
alias SKM_sk_value!PKCS12_SAFEBAG sk_PKCS12_SAFEBAG_value;
alias SKM_sk_set!PKCS12_SAFEBAG sk_PKCS12_SAFEBAG_set;
alias SKM_sk_zero!PKCS12_SAFEBAG sk_PKCS12_SAFEBAG_zero;
alias SKM_sk_push!PKCS12_SAFEBAG sk_PKCS12_SAFEBAG_push;
alias SKM_sk_unshift!PKCS12_SAFEBAG sk_PKCS12_SAFEBAG_unshift;
alias SKM_sk_find!PKCS12_SAFEBAG sk_PKCS12_SAFEBAG_find;
alias SKM_sk_find_ex!PKCS12_SAFEBAG sk_PKCS12_SAFEBAG_find_ex;
alias SKM_sk_delete!PKCS12_SAFEBAG sk_PKCS12_SAFEBAG_delete;
alias SKM_sk_delete_ptr!PKCS12_SAFEBAG sk_PKCS12_SAFEBAG_delete_ptr;
alias SKM_sk_insert!PKCS12_SAFEBAG sk_PKCS12_SAFEBAG_insert;
alias SKM_sk_set_cmp_func!PKCS12_SAFEBAG sk_PKCS12_SAFEBAG_set_cmp_func;
alias SKM_sk_dup!PKCS12_SAFEBAG sk_PKCS12_SAFEBAG_dup;
alias SKM_sk_pop_free!PKCS12_SAFEBAG sk_PKCS12_SAFEBAG_pop_free;
alias SKM_sk_shift!PKCS12_SAFEBAG sk_PKCS12_SAFEBAG_shift;
alias SKM_sk_pop!PKCS12_SAFEBAG sk_PKCS12_SAFEBAG_pop;
alias SKM_sk_sort!PKCS12_SAFEBAG sk_PKCS12_SAFEBAG_sort;
alias SKM_sk_is_sorted!PKCS12_SAFEBAG sk_PKCS12_SAFEBAG_is_sorted;

import deimos.openssl.pkcs7;
alias SKM_sk_new!PKCS7 sk_PKCS7_new;
alias SKM_sk_new_null!PKCS7 sk_PKCS7_new_null;
alias SKM_sk_free!PKCS7 sk_PKCS7_free;
alias SKM_sk_num!PKCS7 sk_PKCS7_num;
alias SKM_sk_value!PKCS7 sk_PKCS7_value;
alias SKM_sk_set!PKCS7 sk_PKCS7_set;
alias SKM_sk_zero!PKCS7 sk_PKCS7_zero;
alias SKM_sk_push!PKCS7 sk_PKCS7_push;
alias SKM_sk_unshift!PKCS7 sk_PKCS7_unshift;
alias SKM_sk_find!PKCS7 sk_PKCS7_find;
alias SKM_sk_find_ex!PKCS7 sk_PKCS7_find_ex;
alias SKM_sk_delete!PKCS7 sk_PKCS7_delete;
alias SKM_sk_delete_ptr!PKCS7 sk_PKCS7_delete_ptr;
alias SKM_sk_insert!PKCS7 sk_PKCS7_insert;
alias SKM_sk_set_cmp_func!PKCS7 sk_PKCS7_set_cmp_func;
alias SKM_sk_dup!PKCS7 sk_PKCS7_dup;
alias SKM_sk_pop_free!PKCS7 sk_PKCS7_pop_free;
alias SKM_sk_shift!PKCS7 sk_PKCS7_shift;
alias SKM_sk_pop!PKCS7 sk_PKCS7_pop;
alias SKM_sk_sort!PKCS7 sk_PKCS7_sort;
alias SKM_sk_is_sorted!PKCS7 sk_PKCS7_is_sorted;

alias SKM_sk_new!PKCS7_RECIP_INFO sk_PKCS7_RECIP_INFO_new;
alias SKM_sk_new_null!PKCS7_RECIP_INFO sk_PKCS7_RECIP_INFO_new_null;
alias SKM_sk_free!PKCS7_RECIP_INFO sk_PKCS7_RECIP_INFO_free;
alias SKM_sk_num!PKCS7_RECIP_INFO sk_PKCS7_RECIP_INFO_num;
alias SKM_sk_value!PKCS7_RECIP_INFO sk_PKCS7_RECIP_INFO_value;
alias SKM_sk_set!PKCS7_RECIP_INFO sk_PKCS7_RECIP_INFO_set;
alias SKM_sk_zero!PKCS7_RECIP_INFO sk_PKCS7_RECIP_INFO_zero;
alias SKM_sk_push!PKCS7_RECIP_INFO sk_PKCS7_RECIP_INFO_push;
alias SKM_sk_unshift!PKCS7_RECIP_INFO sk_PKCS7_RECIP_INFO_unshift;
alias SKM_sk_find!PKCS7_RECIP_INFO sk_PKCS7_RECIP_INFO_find;
alias SKM_sk_find_ex!PKCS7_RECIP_INFO sk_PKCS7_RECIP_INFO_find_ex;
alias SKM_sk_delete!PKCS7_RECIP_INFO sk_PKCS7_RECIP_INFO_delete;
alias SKM_sk_delete_ptr!PKCS7_RECIP_INFO sk_PKCS7_RECIP_INFO_delete_ptr;
alias SKM_sk_insert!PKCS7_RECIP_INFO sk_PKCS7_RECIP_INFO_insert;
alias SKM_sk_set_cmp_func!PKCS7_RECIP_INFO sk_PKCS7_RECIP_INFO_set_cmp_func;
alias SKM_sk_dup!PKCS7_RECIP_INFO sk_PKCS7_RECIP_INFO_dup;
alias SKM_sk_pop_free!PKCS7_RECIP_INFO sk_PKCS7_RECIP_INFO_pop_free;
alias SKM_sk_shift!PKCS7_RECIP_INFO sk_PKCS7_RECIP_INFO_shift;
alias SKM_sk_pop!PKCS7_RECIP_INFO sk_PKCS7_RECIP_INFO_pop;
alias SKM_sk_sort!PKCS7_RECIP_INFO sk_PKCS7_RECIP_INFO_sort;
alias SKM_sk_is_sorted!PKCS7_RECIP_INFO sk_PKCS7_RECIP_INFO_is_sorted;

alias SKM_sk_new!PKCS7_SIGNER_INFO sk_PKCS7_SIGNER_INFO_new;
alias SKM_sk_new_null!PKCS7_SIGNER_INFO sk_PKCS7_SIGNER_INFO_new_null;
alias SKM_sk_free!PKCS7_SIGNER_INFO sk_PKCS7_SIGNER_INFO_free;
alias SKM_sk_num!PKCS7_SIGNER_INFO sk_PKCS7_SIGNER_INFO_num;
alias SKM_sk_value!PKCS7_SIGNER_INFO sk_PKCS7_SIGNER_INFO_value;
alias SKM_sk_set!PKCS7_SIGNER_INFO sk_PKCS7_SIGNER_INFO_set;
alias SKM_sk_zero!PKCS7_SIGNER_INFO sk_PKCS7_SIGNER_INFO_zero;
alias SKM_sk_push!PKCS7_SIGNER_INFO sk_PKCS7_SIGNER_INFO_push;
alias SKM_sk_unshift!PKCS7_SIGNER_INFO sk_PKCS7_SIGNER_INFO_unshift;
alias SKM_sk_find!PKCS7_SIGNER_INFO sk_PKCS7_SIGNER_INFO_find;
alias SKM_sk_find_ex!PKCS7_SIGNER_INFO sk_PKCS7_SIGNER_INFO_find_ex;
alias SKM_sk_delete!PKCS7_SIGNER_INFO sk_PKCS7_SIGNER_INFO_delete;
alias SKM_sk_delete_ptr!PKCS7_SIGNER_INFO sk_PKCS7_SIGNER_INFO_delete_ptr;
alias SKM_sk_insert!PKCS7_SIGNER_INFO sk_PKCS7_SIGNER_INFO_insert;
alias SKM_sk_set_cmp_func!PKCS7_SIGNER_INFO sk_PKCS7_SIGNER_INFO_set_cmp_func;
alias SKM_sk_dup!PKCS7_SIGNER_INFO sk_PKCS7_SIGNER_INFO_dup;
alias SKM_sk_pop_free!PKCS7_SIGNER_INFO sk_PKCS7_SIGNER_INFO_pop_free;
alias SKM_sk_shift!PKCS7_SIGNER_INFO sk_PKCS7_SIGNER_INFO_shift;
alias SKM_sk_pop!PKCS7_SIGNER_INFO sk_PKCS7_SIGNER_INFO_pop;
alias SKM_sk_sort!PKCS7_SIGNER_INFO sk_PKCS7_SIGNER_INFO_sort;
alias SKM_sk_is_sorted!PKCS7_SIGNER_INFO sk_PKCS7_SIGNER_INFO_is_sorted;

alias SKM_sk_new!POLICYINFO sk_POLICYINFO_new;
alias SKM_sk_new_null!POLICYINFO sk_POLICYINFO_new_null;
alias SKM_sk_free!POLICYINFO sk_POLICYINFO_free;
alias SKM_sk_num!POLICYINFO sk_POLICYINFO_num;
alias SKM_sk_value!POLICYINFO sk_POLICYINFO_value;
alias SKM_sk_set!POLICYINFO sk_POLICYINFO_set;
alias SKM_sk_zero!POLICYINFO sk_POLICYINFO_zero;
alias SKM_sk_push!POLICYINFO sk_POLICYINFO_push;
alias SKM_sk_unshift!POLICYINFO sk_POLICYINFO_unshift;
alias SKM_sk_find!POLICYINFO sk_POLICYINFO_find;
alias SKM_sk_find_ex!POLICYINFO sk_POLICYINFO_find_ex;
alias SKM_sk_delete!POLICYINFO sk_POLICYINFO_delete;
alias SKM_sk_delete_ptr!POLICYINFO sk_POLICYINFO_delete_ptr;
alias SKM_sk_insert!POLICYINFO sk_POLICYINFO_insert;
alias SKM_sk_set_cmp_func!POLICYINFO sk_POLICYINFO_set_cmp_func;
alias SKM_sk_dup!POLICYINFO sk_POLICYINFO_dup;
alias SKM_sk_pop_free!POLICYINFO sk_POLICYINFO_pop_free;
alias SKM_sk_shift!POLICYINFO sk_POLICYINFO_shift;
alias SKM_sk_pop!POLICYINFO sk_POLICYINFO_pop;
alias SKM_sk_sort!POLICYINFO sk_POLICYINFO_sort;
alias SKM_sk_is_sorted!POLICYINFO sk_POLICYINFO_is_sorted;

alias SKM_sk_new!POLICYQUALINFO sk_POLICYQUALINFO_new;
alias SKM_sk_new_null!POLICYQUALINFO sk_POLICYQUALINFO_new_null;
alias SKM_sk_free!POLICYQUALINFO sk_POLICYQUALINFO_free;
alias SKM_sk_num!POLICYQUALINFO sk_POLICYQUALINFO_num;
alias SKM_sk_value!POLICYQUALINFO sk_POLICYQUALINFO_value;
alias SKM_sk_set!POLICYQUALINFO sk_POLICYQUALINFO_set;
alias SKM_sk_zero!POLICYQUALINFO sk_POLICYQUALINFO_zero;
alias SKM_sk_push!POLICYQUALINFO sk_POLICYQUALINFO_push;
alias SKM_sk_unshift!POLICYQUALINFO sk_POLICYQUALINFO_unshift;
alias SKM_sk_find!POLICYQUALINFO sk_POLICYQUALINFO_find;
alias SKM_sk_find_ex!POLICYQUALINFO sk_POLICYQUALINFO_find_ex;
alias SKM_sk_delete!POLICYQUALINFO sk_POLICYQUALINFO_delete;
alias SKM_sk_delete_ptr!POLICYQUALINFO sk_POLICYQUALINFO_delete_ptr;
alias SKM_sk_insert!POLICYQUALINFO sk_POLICYQUALINFO_insert;
alias SKM_sk_set_cmp_func!POLICYQUALINFO sk_POLICYQUALINFO_set_cmp_func;
alias SKM_sk_dup!POLICYQUALINFO sk_POLICYQUALINFO_dup;
alias SKM_sk_pop_free!POLICYQUALINFO sk_POLICYQUALINFO_pop_free;
alias SKM_sk_shift!POLICYQUALINFO sk_POLICYQUALINFO_shift;
alias SKM_sk_pop!POLICYQUALINFO sk_POLICYQUALINFO_pop;
alias SKM_sk_sort!POLICYQUALINFO sk_POLICYQUALINFO_sort;
alias SKM_sk_is_sorted!POLICYQUALINFO sk_POLICYQUALINFO_is_sorted;

alias SKM_sk_new!POLICY_MAPPING sk_POLICY_MAPPING_new;
alias SKM_sk_new_null!POLICY_MAPPING sk_POLICY_MAPPING_new_null;
alias SKM_sk_free!POLICY_MAPPING sk_POLICY_MAPPING_free;
alias SKM_sk_num!POLICY_MAPPING sk_POLICY_MAPPING_num;
alias SKM_sk_value!POLICY_MAPPING sk_POLICY_MAPPING_value;
alias SKM_sk_set!POLICY_MAPPING sk_POLICY_MAPPING_set;
alias SKM_sk_zero!POLICY_MAPPING sk_POLICY_MAPPING_zero;
alias SKM_sk_push!POLICY_MAPPING sk_POLICY_MAPPING_push;
alias SKM_sk_unshift!POLICY_MAPPING sk_POLICY_MAPPING_unshift;
alias SKM_sk_find!POLICY_MAPPING sk_POLICY_MAPPING_find;
alias SKM_sk_find_ex!POLICY_MAPPING sk_POLICY_MAPPING_find_ex;
alias SKM_sk_delete!POLICY_MAPPING sk_POLICY_MAPPING_delete;
alias SKM_sk_delete_ptr!POLICY_MAPPING sk_POLICY_MAPPING_delete_ptr;
alias SKM_sk_insert!POLICY_MAPPING sk_POLICY_MAPPING_insert;
alias SKM_sk_set_cmp_func!POLICY_MAPPING sk_POLICY_MAPPING_set_cmp_func;
alias SKM_sk_dup!POLICY_MAPPING sk_POLICY_MAPPING_dup;
alias SKM_sk_pop_free!POLICY_MAPPING sk_POLICY_MAPPING_pop_free;
alias SKM_sk_shift!POLICY_MAPPING sk_POLICY_MAPPING_shift;
alias SKM_sk_pop!POLICY_MAPPING sk_POLICY_MAPPING_pop;
alias SKM_sk_sort!POLICY_MAPPING sk_POLICY_MAPPING_sort;
alias SKM_sk_is_sorted!POLICY_MAPPING sk_POLICY_MAPPING_is_sorted;

alias sk_SRP_gN_new = SKM_sk_new!SRP_gN;
alias sk_SRP_gN_new_null = SKM_sk_new_null!SRP_gN;
alias sk_SRP_gN_free = SKM_sk_free!SRP_gN;
alias sk_SRP_gN_num = SKM_sk_num!SRP_gN;
alias sk_SRP_gN_value = SKM_sk_value!SRP_gN;
alias sk_SRP_gN_set = SKM_sk_set!SRP_gN;
alias sk_SRP_gN_zero = SKM_sk_zero!SRP_gN;
alias sk_SRP_gN_push = SKM_sk_push!SRP_gN;
alias sk_SRP_gN_unshift = SKM_sk_unshift!SRP_gN;
alias sk_SRP_gN_find = SKM_sk_find!SRP_gN;
alias sk_SRP_gN_find_ex = SKM_sk_find_ex!SRP_gN;
alias sk_SRP_gN_delete = SKM_sk_delete!SRP_gN;
alias sk_SRP_gN_delete_ptr = SKM_sk_delete_ptr!SRP_gN;
alias sk_SRP_gN_insert = SKM_sk_insert!SRP_gN;
alias sk_SRP_gN_set_cmp_func = SKM_sk_set_cmp_func!SRP_gN;
alias sk_SRP_gN_dup = SKM_sk_dup!SRP_gN;
alias sk_SRP_gN_pop_free = SKM_sk_pop_free!SRP_gN;
alias sk_SRP_gN_shift = SKM_sk_shift!SRP_gN;
alias sk_SRP_gN_pop = SKM_sk_pop!SRP_gN;
alias sk_SRP_gN_sort = SKM_sk_sort!SRP_gN;
alias sk_SRP_gN_is_sorted = SKM_sk_is_sorted!SRP_gN;

alias sk_SRP_gN_cache_new = SKM_sk_new!SRP_gN_cache;
alias sk_SRP_gN_cache_new_null = SKM_sk_new_null!SRP_gN_cache;
alias sk_SRP_gN_cache_free = SKM_sk_free!SRP_gN_cache;
alias sk_SRP_gN_cache_num = SKM_sk_num!SRP_gN_cache;
alias sk_SRP_gN_cache_value = SKM_sk_value!SRP_gN_cache;
alias sk_SRP_gN_cache_set = SKM_sk_set!SRP_gN_cache;
alias sk_SRP_gN_cache_zero = SKM_sk_zero!SRP_gN_cache;
alias sk_SRP_gN_cache_push = SKM_sk_push!SRP_gN_cache;
alias sk_SRP_gN_cache_unshift = SKM_sk_unshift!SRP_gN_cache;
alias sk_SRP_gN_cache_find = SKM_sk_find!SRP_gN_cache;
alias sk_SRP_gN_cache_find_ex = SKM_sk_find_ex!SRP_gN_cache;
alias sk_SRP_gN_cache_delete = SKM_sk_delete!SRP_gN_cache;
alias sk_SRP_gN_cache_delete_ptr = SKM_sk_delete_ptr!SRP_gN_cache;
alias sk_SRP_gN_cache_insert = SKM_sk_insert!SRP_gN_cache;
alias sk_SRP_gN_cache_set_cmp_func = SKM_sk_set_cmp_func!SRP_gN_cache;
alias sk_SRP_gN_cache_dup = SKM_sk_dup!SRP_gN_cache;
alias sk_SRP_gN_cache_pop_free = SKM_sk_pop_free!SRP_gN_cache;
alias sk_SRP_gN_cache_shift = SKM_sk_shift!SRP_gN_cache;
alias sk_SRP_gN_cache_pop = SKM_sk_pop!SRP_gN_cache;
alias sk_SRP_gN_cache_sort = SKM_sk_sort!SRP_gN_cache;
alias sk_SRP_gN_cache_is_sorted = SKM_sk_is_sorted!SRP_gN_cache;

alias sk_SRP_user_pwd_new = SKM_sk_new!SRP_user_pwd;
alias sk_SRP_user_pwd_new_null = SKM_sk_new_null!SRP_user_pwd;
alias sk_SRP_user_pwd_free = SKM_sk_free!SRP_user_pwd;
alias sk_SRP_user_pwd_num = SKM_sk_num!SRP_user_pwd;
alias sk_SRP_user_pwd_value = SKM_sk_value!SRP_user_pwd;
alias sk_SRP_user_pwd_set = SKM_sk_set!SRP_user_pwd;
alias sk_SRP_user_pwd_zero = SKM_sk_zero!SRP_user_pwd;
alias sk_SRP_user_pwd_push = SKM_sk_push!SRP_user_pwd;
alias sk_SRP_user_pwd_unshift = SKM_sk_unshift!SRP_user_pwd;
alias sk_SRP_user_pwd_find = SKM_sk_find!SRP_user_pwd;
alias sk_SRP_user_pwd_find_ex = SKM_sk_find_ex!SRP_user_pwd;
alias sk_SRP_user_pwd_delete = SKM_sk_delete!SRP_user_pwd;
alias sk_SRP_user_pwd_delete_ptr = SKM_sk_delete_ptr!SRP_user_pwd;
alias sk_SRP_user_pwd_insert = SKM_sk_insert!SRP_user_pwd;
alias sk_SRP_user_pwd_set_cmp_func = SKM_sk_set_cmp_func!SRP_user_pwd;
alias sk_SRP_user_pwd_dup = SKM_sk_dup!SRP_user_pwd;
alias sk_SRP_user_pwd_pop_free = SKM_sk_pop_free!SRP_user_pwd;
alias sk_SRP_user_pwd_shift = SKM_sk_shift!SRP_user_pwd;
alias sk_SRP_user_pwd_pop = SKM_sk_pop!SRP_user_pwd;
alias sk_SRP_user_pwd_sort = SKM_sk_sort!SRP_user_pwd;
alias sk_SRP_user_pwd_is_sorted = SKM_sk_is_sorted!SRP_user_pwd;

alias sk_SRTP_PROTECTION_PROFILE_new = SKM_sk_new!SRTP_PROTECTION_PROFILE;
alias sk_SRTP_PROTECTION_PROFILE_new_null = SKM_sk_new_null!SRTP_PROTECTION_PROFILE;
alias sk_SRTP_PROTECTION_PROFILE_free = SKM_sk_free!SRTP_PROTECTION_PROFILE;
alias sk_SRTP_PROTECTION_PROFILE_num = SKM_sk_num!SRTP_PROTECTION_PROFILE;
alias sk_SRTP_PROTECTION_PROFILE_value = SKM_sk_value!SRTP_PROTECTION_PROFILE;
alias sk_SRTP_PROTECTION_PROFILE_set = SKM_sk_set!SRTP_PROTECTION_PROFILE;
alias sk_SRTP_PROTECTION_PROFILE_zero = SKM_sk_zero!SRTP_PROTECTION_PROFILE;
alias sk_SRTP_PROTECTION_PROFILE_push = SKM_sk_push!SRTP_PROTECTION_PROFILE;
alias sk_SRTP_PROTECTION_PROFILE_unshift = SKM_sk_unshift!SRTP_PROTECTION_PROFILE;
alias sk_SRTP_PROTECTION_PROFILE_find = SKM_sk_find!SRTP_PROTECTION_PROFILE;
alias sk_SRTP_PROTECTION_PROFILE_find_ex = SKM_sk_find_ex!SRTP_PROTECTION_PROFILE;
alias sk_SRTP_PROTECTION_PROFILE_delete = SKM_sk_delete!SRTP_PROTECTION_PROFILE;
alias sk_SRTP_PROTECTION_PROFILE_delete_ptr = SKM_sk_delete_ptr!SRTP_PROTECTION_PROFILE;
alias sk_SRTP_PROTECTION_PROFILE_insert = SKM_sk_insert!SRTP_PROTECTION_PROFILE;
alias sk_SRTP_PROTECTION_PROFILE_set_cmp_func = SKM_sk_set_cmp_func!SRTP_PROTECTION_PROFILE;
alias sk_SRTP_PROTECTION_PROFILE_dup = SKM_sk_dup!SRTP_PROTECTION_PROFILE;
alias sk_SRTP_PROTECTION_PROFILE_pop_free = SKM_sk_pop_free!SRTP_PROTECTION_PROFILE;
alias sk_SRTP_PROTECTION_PROFILE_shift = SKM_sk_shift!SRTP_PROTECTION_PROFILE;
alias sk_SRTP_PROTECTION_PROFILE_pop = SKM_sk_pop!SRTP_PROTECTION_PROFILE;
alias sk_SRTP_PROTECTION_PROFILE_sort = SKM_sk_sort!SRTP_PROTECTION_PROFILE;
alias sk_SRTP_PROTECTION_PROFILE_is_sorted = SKM_sk_is_sorted!SRTP_PROTECTION_PROFILE;

import deimos.openssl.ssl;
alias SKM_sk_new!SSL_CIPHER sk_SSL_CIPHER_new;
alias SKM_sk_new_null!SSL_CIPHER sk_SSL_CIPHER_new_null;
alias SKM_sk_free!SSL_CIPHER sk_SSL_CIPHER_free;
alias SKM_sk_num!SSL_CIPHER sk_SSL_CIPHER_num;
alias SKM_sk_value!SSL_CIPHER sk_SSL_CIPHER_value;
alias SKM_sk_set!SSL_CIPHER sk_SSL_CIPHER_set;
alias SKM_sk_zero!SSL_CIPHER sk_SSL_CIPHER_zero;
alias SKM_sk_push!SSL_CIPHER sk_SSL_CIPHER_push;
alias SKM_sk_unshift!SSL_CIPHER sk_SSL_CIPHER_unshift;
alias SKM_sk_find!SSL_CIPHER sk_SSL_CIPHER_find;
alias SKM_sk_find_ex!SSL_CIPHER sk_SSL_CIPHER_find_ex;
alias SKM_sk_delete!SSL_CIPHER sk_SSL_CIPHER_delete;
alias SKM_sk_delete_ptr!SSL_CIPHER sk_SSL_CIPHER_delete_ptr;
alias SKM_sk_insert!SSL_CIPHER sk_SSL_CIPHER_insert;
alias SKM_sk_set_cmp_func!SSL_CIPHER sk_SSL_CIPHER_set_cmp_func;
alias SKM_sk_dup!SSL_CIPHER sk_SSL_CIPHER_dup;
alias SKM_sk_pop_free!SSL_CIPHER sk_SSL_CIPHER_pop_free;
alias SKM_sk_shift!SSL_CIPHER sk_SSL_CIPHER_shift;
alias SKM_sk_pop!SSL_CIPHER sk_SSL_CIPHER_pop;
alias SKM_sk_sort!SSL_CIPHER sk_SSL_CIPHER_sort;
alias SKM_sk_is_sorted!SSL_CIPHER sk_SSL_CIPHER_is_sorted;

alias SKM_sk_new!SSL_COMP sk_SSL_COMP_new;
alias SKM_sk_new_null!SSL_COMP sk_SSL_COMP_new_null;
alias SKM_sk_free!SSL_COMP sk_SSL_COMP_free;
alias SKM_sk_num!SSL_COMP sk_SSL_COMP_num;
alias SKM_sk_value!SSL_COMP sk_SSL_COMP_value;
alias SKM_sk_set!SSL_COMP sk_SSL_COMP_set;
alias SKM_sk_zero!SSL_COMP sk_SSL_COMP_zero;
alias SKM_sk_push!SSL_COMP sk_SSL_COMP_push;
alias SKM_sk_unshift!SSL_COMP sk_SSL_COMP_unshift;
alias SKM_sk_find!SSL_COMP sk_SSL_COMP_find;
alias SKM_sk_find_ex!SSL_COMP sk_SSL_COMP_find_ex;
alias SKM_sk_delete!SSL_COMP sk_SSL_COMP_delete;
alias SKM_sk_delete_ptr!SSL_COMP sk_SSL_COMP_delete_ptr;
alias SKM_sk_insert!SSL_COMP sk_SSL_COMP_insert;
alias SKM_sk_set_cmp_func!SSL_COMP sk_SSL_COMP_set_cmp_func;
alias SKM_sk_dup!SSL_COMP sk_SSL_COMP_dup;
alias SKM_sk_pop_free!SSL_COMP sk_SSL_COMP_pop_free;
alias SKM_sk_shift!SSL_COMP sk_SSL_COMP_shift;
alias SKM_sk_pop!SSL_COMP sk_SSL_COMP_pop;
alias SKM_sk_sort!SSL_COMP sk_SSL_COMP_sort;
alias SKM_sk_is_sorted!SSL_COMP sk_SSL_COMP_is_sorted;

/+ Oversight (?) in the original headers: STACK_OF_X509_NAME_ENTRY does not exist.
alias SKM_sk_new!STACK_OF_X509_NAME_ENTRY sk_STACK_OF_X509_NAME_ENTRY_new;
alias SKM_sk_new_null!STACK_OF_X509_NAME_ENTRY sk_STACK_OF_X509_NAME_ENTRY_new_null;
alias SKM_sk_free!STACK_OF_X509_NAME_ENTRY sk_STACK_OF_X509_NAME_ENTRY_free;
alias SKM_sk_num!STACK_OF_X509_NAME_ENTRY sk_STACK_OF_X509_NAME_ENTRY_num;
alias SKM_sk_value!STACK_OF_X509_NAME_ENTRY sk_STACK_OF_X509_NAME_ENTRY_value;
alias SKM_sk_set!STACK_OF_X509_NAME_ENTRY sk_STACK_OF_X509_NAME_ENTRY_set;
alias SKM_sk_zero!STACK_OF_X509_NAME_ENTRY sk_STACK_OF_X509_NAME_ENTRY_zero;
alias SKM_sk_push!STACK_OF_X509_NAME_ENTRY sk_STACK_OF_X509_NAME_ENTRY_push;
alias SKM_sk_unshift!STACK_OF_X509_NAME_ENTRY sk_STACK_OF_X509_NAME_ENTRY_unshift;
alias SKM_sk_find!STACK_OF_X509_NAME_ENTRY sk_STACK_OF_X509_NAME_ENTRY_find;
alias SKM_sk_find_ex!STACK_OF_X509_NAME_ENTRY sk_STACK_OF_X509_NAME_ENTRY_find_ex;
alias SKM_sk_delete!STACK_OF_X509_NAME_ENTRY sk_STACK_OF_X509_NAME_ENTRY_delete;
alias SKM_sk_delete_ptr!STACK_OF_X509_NAME_ENTRY sk_STACK_OF_X509_NAME_ENTRY_delete_ptr;
alias SKM_sk_insert!STACK_OF_X509_NAME_ENTRY sk_STACK_OF_X509_NAME_ENTRY_insert;
alias SKM_sk_set_cmp_func!STACK_OF_X509_NAME_ENTRY sk_STACK_OF_X509_NAME_ENTRY_set_cmp_func;
alias SKM_sk_dup!STACK_OF_X509_NAME_ENTRY sk_STACK_OF_X509_NAME_ENTRY_dup;
alias SKM_sk_pop_free!STACK_OF_X509_NAME_ENTRY sk_STACK_OF_X509_NAME_ENTRY_pop_free;
alias SKM_sk_shift!STACK_OF_X509_NAME_ENTRY sk_STACK_OF_X509_NAME_ENTRY_shift;
alias SKM_sk_pop!STACK_OF_X509_NAME_ENTRY sk_STACK_OF_X509_NAME_ENTRY_pop;
alias SKM_sk_sort!STACK_OF_X509_NAME_ENTRY sk_STACK_OF_X509_NAME_ENTRY_sort;
alias SKM_sk_is_sorted!STACK_OF_X509_NAME_ENTRY sk_STACK_OF_X509_NAME_ENTRY_is_sorted;
+/

/+ Internal store types.
alias SKM_sk_new!STORE_ATTR_INFO sk_STORE_ATTR_INFO_new;
alias SKM_sk_new_null!STORE_ATTR_INFO sk_STORE_ATTR_INFO_new_null;
alias SKM_sk_free!STORE_ATTR_INFO sk_STORE_ATTR_INFO_free;
alias SKM_sk_num!STORE_ATTR_INFO sk_STORE_ATTR_INFO_num;
alias SKM_sk_value!STORE_ATTR_INFO sk_STORE_ATTR_INFO_value;
alias SKM_sk_set!STORE_ATTR_INFO sk_STORE_ATTR_INFO_set;
alias SKM_sk_zero!STORE_ATTR_INFO sk_STORE_ATTR_INFO_zero;
alias SKM_sk_push!STORE_ATTR_INFO sk_STORE_ATTR_INFO_push;
alias SKM_sk_unshift!STORE_ATTR_INFO sk_STORE_ATTR_INFO_unshift;
alias SKM_sk_find!STORE_ATTR_INFO sk_STORE_ATTR_INFO_find;
alias SKM_sk_find_ex!STORE_ATTR_INFO sk_STORE_ATTR_INFO_find_ex;
alias SKM_sk_delete!STORE_ATTR_INFO sk_STORE_ATTR_INFO_delete;
alias SKM_sk_delete_ptr!STORE_ATTR_INFO sk_STORE_ATTR_INFO_delete_ptr;
alias SKM_sk_insert!STORE_ATTR_INFO sk_STORE_ATTR_INFO_insert;
alias SKM_sk_set_cmp_func!STORE_ATTR_INFO sk_STORE_ATTR_INFO_set_cmp_func;
alias SKM_sk_dup!STORE_ATTR_INFO sk_STORE_ATTR_INFO_dup;
alias SKM_sk_pop_free!STORE_ATTR_INFO sk_STORE_ATTR_INFO_pop_free;
alias SKM_sk_shift!STORE_ATTR_INFO sk_STORE_ATTR_INFO_shift;
alias SKM_sk_pop!STORE_ATTR_INFO sk_STORE_ATTR_INFO_pop;
alias SKM_sk_sort!STORE_ATTR_INFO sk_STORE_ATTR_INFO_sort;
alias SKM_sk_is_sorted!STORE_ATTR_INFO sk_STORE_ATTR_INFO_is_sorted;

alias SKM_sk_new!STORE_OBJECT sk_STORE_OBJECT_new;
alias SKM_sk_new_null!STORE_OBJECT sk_STORE_OBJECT_new_null;
alias SKM_sk_free!STORE_OBJECT sk_STORE_OBJECT_free;
alias SKM_sk_num!STORE_OBJECT sk_STORE_OBJECT_num;
alias SKM_sk_value!STORE_OBJECT sk_STORE_OBJECT_value;
alias SKM_sk_set!STORE_OBJECT sk_STORE_OBJECT_set;
alias SKM_sk_zero!STORE_OBJECT sk_STORE_OBJECT_zero;
alias SKM_sk_push!STORE_OBJECT sk_STORE_OBJECT_push;
alias SKM_sk_unshift!STORE_OBJECT sk_STORE_OBJECT_unshift;
alias SKM_sk_find!STORE_OBJECT sk_STORE_OBJECT_find;
alias SKM_sk_find_ex!STORE_OBJECT sk_STORE_OBJECT_find_ex;
alias SKM_sk_delete!STORE_OBJECT sk_STORE_OBJECT_delete;
alias SKM_sk_delete_ptr!STORE_OBJECT sk_STORE_OBJECT_delete_ptr;
alias SKM_sk_insert!STORE_OBJECT sk_STORE_OBJECT_insert;
alias SKM_sk_set_cmp_func!STORE_OBJECT sk_STORE_OBJECT_set_cmp_func;
alias SKM_sk_dup!STORE_OBJECT sk_STORE_OBJECT_dup;
alias SKM_sk_pop_free!STORE_OBJECT sk_STORE_OBJECT_pop_free;
alias SKM_sk_shift!STORE_OBJECT sk_STORE_OBJECT_shift;
alias SKM_sk_pop!STORE_OBJECT sk_STORE_OBJECT_pop;
alias SKM_sk_sort!STORE_OBJECT sk_STORE_OBJECT_sort;
alias SKM_sk_is_sorted!STORE_OBJECT sk_STORE_OBJECT_is_sorted;
+/

alias SKM_sk_new!SXNETID sk_SXNETID_new;
alias SKM_sk_new_null!SXNETID sk_SXNETID_new_null;
alias SKM_sk_free!SXNETID sk_SXNETID_free;
alias SKM_sk_num!SXNETID sk_SXNETID_num;
alias SKM_sk_value!SXNETID sk_SXNETID_value;
alias SKM_sk_set!SXNETID sk_SXNETID_set;
alias SKM_sk_zero!SXNETID sk_SXNETID_zero;
alias SKM_sk_push!SXNETID sk_SXNETID_push;
alias SKM_sk_unshift!SXNETID sk_SXNETID_unshift;
alias SKM_sk_find!SXNETID sk_SXNETID_find;
alias SKM_sk_find_ex!SXNETID sk_SXNETID_find_ex;
alias SKM_sk_delete!SXNETID sk_SXNETID_delete;
alias SKM_sk_delete_ptr!SXNETID sk_SXNETID_delete_ptr;
alias SKM_sk_insert!SXNETID sk_SXNETID_insert;
alias SKM_sk_set_cmp_func!SXNETID sk_SXNETID_set_cmp_func;
alias SKM_sk_dup!SXNETID sk_SXNETID_dup;
alias SKM_sk_pop_free!SXNETID sk_SXNETID_pop_free;
alias SKM_sk_shift!SXNETID sk_SXNETID_shift;
alias SKM_sk_pop!SXNETID sk_SXNETID_pop;
alias SKM_sk_sort!SXNETID sk_SXNETID_sort;
alias SKM_sk_is_sorted!SXNETID sk_SXNETID_is_sorted;

import deimos.openssl.ui;
alias SKM_sk_new!UI_STRING sk_UI_STRING_new;
alias SKM_sk_new_null!UI_STRING sk_UI_STRING_new_null;
alias SKM_sk_free!UI_STRING sk_UI_STRING_free;
alias SKM_sk_num!UI_STRING sk_UI_STRING_num;
alias SKM_sk_value!UI_STRING sk_UI_STRING_value;
alias SKM_sk_set!UI_STRING sk_UI_STRING_set;
alias SKM_sk_zero!UI_STRING sk_UI_STRING_zero;
alias SKM_sk_push!UI_STRING sk_UI_STRING_push;
alias SKM_sk_unshift!UI_STRING sk_UI_STRING_unshift;
alias SKM_sk_find!UI_STRING sk_UI_STRING_find;
alias SKM_sk_find_ex!UI_STRING sk_UI_STRING_find_ex;
alias SKM_sk_delete!UI_STRING sk_UI_STRING_delete;
alias SKM_sk_delete_ptr!UI_STRING sk_UI_STRING_delete_ptr;
alias SKM_sk_insert!UI_STRING sk_UI_STRING_insert;
alias SKM_sk_set_cmp_func!UI_STRING sk_UI_STRING_set_cmp_func;
alias SKM_sk_dup!UI_STRING sk_UI_STRING_dup;
alias SKM_sk_pop_free!UI_STRING sk_UI_STRING_pop_free;
alias SKM_sk_shift!UI_STRING sk_UI_STRING_shift;
alias SKM_sk_pop!UI_STRING sk_UI_STRING_pop;
alias SKM_sk_sort!UI_STRING sk_UI_STRING_sort;
alias SKM_sk_is_sorted!UI_STRING sk_UI_STRING_is_sorted;

alias SKM_sk_new!X509 sk_X509_new;
alias SKM_sk_new_null!X509 sk_X509_new_null;
alias SKM_sk_free!X509 sk_X509_free;
alias SKM_sk_num!X509 sk_X509_num;
alias SKM_sk_value!X509 sk_X509_value;
alias SKM_sk_set!X509 sk_X509_set;
alias SKM_sk_zero!X509 sk_X509_zero;
alias SKM_sk_push!X509 sk_X509_push;
alias SKM_sk_unshift!X509 sk_X509_unshift;
alias SKM_sk_find!X509 sk_X509_find;
alias SKM_sk_find_ex!X509 sk_X509_find_ex;
alias SKM_sk_delete!X509 sk_X509_delete;
alias SKM_sk_delete_ptr!X509 sk_X509_delete_ptr;
alias SKM_sk_insert!X509 sk_X509_insert;
alias SKM_sk_set_cmp_func!X509 sk_X509_set_cmp_func;
alias SKM_sk_dup!X509 sk_X509_dup;
alias SKM_sk_pop_free!X509 sk_X509_pop_free;
alias SKM_sk_shift!X509 sk_X509_shift;
alias SKM_sk_pop!X509 sk_X509_pop;
alias SKM_sk_sort!X509 sk_X509_sort;
alias SKM_sk_is_sorted!X509 sk_X509_is_sorted;

alias SKM_sk_new!X509V3_EXT_METHOD sk_X509V3_EXT_METHOD_new;
alias SKM_sk_new_null!X509V3_EXT_METHOD sk_X509V3_EXT_METHOD_new_null;
alias SKM_sk_free!X509V3_EXT_METHOD sk_X509V3_EXT_METHOD_free;
alias SKM_sk_num!X509V3_EXT_METHOD sk_X509V3_EXT_METHOD_num;
alias SKM_sk_value!X509V3_EXT_METHOD sk_X509V3_EXT_METHOD_value;
alias SKM_sk_set!X509V3_EXT_METHOD sk_X509V3_EXT_METHOD_set;
alias SKM_sk_zero!X509V3_EXT_METHOD sk_X509V3_EXT_METHOD_zero;
alias SKM_sk_push!X509V3_EXT_METHOD sk_X509V3_EXT_METHOD_push;
alias SKM_sk_unshift!X509V3_EXT_METHOD sk_X509V3_EXT_METHOD_unshift;
alias SKM_sk_find!X509V3_EXT_METHOD sk_X509V3_EXT_METHOD_find;
alias SKM_sk_find_ex!X509V3_EXT_METHOD sk_X509V3_EXT_METHOD_find_ex;
alias SKM_sk_delete!X509V3_EXT_METHOD sk_X509V3_EXT_METHOD_delete;
alias SKM_sk_delete_ptr!X509V3_EXT_METHOD sk_X509V3_EXT_METHOD_delete_ptr;
alias SKM_sk_insert!X509V3_EXT_METHOD sk_X509V3_EXT_METHOD_insert;
alias SKM_sk_set_cmp_func!X509V3_EXT_METHOD sk_X509V3_EXT_METHOD_set_cmp_func;
alias SKM_sk_dup!X509V3_EXT_METHOD sk_X509V3_EXT_METHOD_dup;
alias SKM_sk_pop_free!X509V3_EXT_METHOD sk_X509V3_EXT_METHOD_pop_free;
alias SKM_sk_shift!X509V3_EXT_METHOD sk_X509V3_EXT_METHOD_shift;
alias SKM_sk_pop!X509V3_EXT_METHOD sk_X509V3_EXT_METHOD_pop;
alias SKM_sk_sort!X509V3_EXT_METHOD sk_X509V3_EXT_METHOD_sort;
alias SKM_sk_is_sorted!X509V3_EXT_METHOD sk_X509V3_EXT_METHOD_is_sorted;

alias SKM_sk_new!X509_ALGOR sk_X509_ALGOR_new;
alias SKM_sk_new_null!X509_ALGOR sk_X509_ALGOR_new_null;
alias SKM_sk_free!X509_ALGOR sk_X509_ALGOR_free;
alias SKM_sk_num!X509_ALGOR sk_X509_ALGOR_num;
alias SKM_sk_value!X509_ALGOR sk_X509_ALGOR_value;
alias SKM_sk_set!X509_ALGOR sk_X509_ALGOR_set;
alias SKM_sk_zero!X509_ALGOR sk_X509_ALGOR_zero;
alias SKM_sk_push!X509_ALGOR sk_X509_ALGOR_push;
alias SKM_sk_unshift!X509_ALGOR sk_X509_ALGOR_unshift;
alias SKM_sk_find!X509_ALGOR sk_X509_ALGOR_find;
alias SKM_sk_find_ex!X509_ALGOR sk_X509_ALGOR_find_ex;
alias SKM_sk_delete!X509_ALGOR sk_X509_ALGOR_delete;
alias SKM_sk_delete_ptr!X509_ALGOR sk_X509_ALGOR_delete_ptr;
alias SKM_sk_insert!X509_ALGOR sk_X509_ALGOR_insert;
alias SKM_sk_set_cmp_func!X509_ALGOR sk_X509_ALGOR_set_cmp_func;
alias SKM_sk_dup!X509_ALGOR sk_X509_ALGOR_dup;
alias SKM_sk_pop_free!X509_ALGOR sk_X509_ALGOR_pop_free;
alias SKM_sk_shift!X509_ALGOR sk_X509_ALGOR_shift;
alias SKM_sk_pop!X509_ALGOR sk_X509_ALGOR_pop;
alias SKM_sk_sort!X509_ALGOR sk_X509_ALGOR_sort;
alias SKM_sk_is_sorted!X509_ALGOR sk_X509_ALGOR_is_sorted;

alias SKM_sk_new!X509_ATTRIBUTE sk_X509_ATTRIBUTE_new;
alias SKM_sk_new_null!X509_ATTRIBUTE sk_X509_ATTRIBUTE_new_null;
alias SKM_sk_free!X509_ATTRIBUTE sk_X509_ATTRIBUTE_free;
alias SKM_sk_num!X509_ATTRIBUTE sk_X509_ATTRIBUTE_num;
alias SKM_sk_value!X509_ATTRIBUTE sk_X509_ATTRIBUTE_value;
alias SKM_sk_set!X509_ATTRIBUTE sk_X509_ATTRIBUTE_set;
alias SKM_sk_zero!X509_ATTRIBUTE sk_X509_ATTRIBUTE_zero;
alias SKM_sk_push!X509_ATTRIBUTE sk_X509_ATTRIBUTE_push;
alias SKM_sk_unshift!X509_ATTRIBUTE sk_X509_ATTRIBUTE_unshift;
alias SKM_sk_find!X509_ATTRIBUTE sk_X509_ATTRIBUTE_find;
alias SKM_sk_find_ex!X509_ATTRIBUTE sk_X509_ATTRIBUTE_find_ex;
alias SKM_sk_delete!X509_ATTRIBUTE sk_X509_ATTRIBUTE_delete;
alias SKM_sk_delete_ptr!X509_ATTRIBUTE sk_X509_ATTRIBUTE_delete_ptr;
alias SKM_sk_insert!X509_ATTRIBUTE sk_X509_ATTRIBUTE_insert;
alias SKM_sk_set_cmp_func!X509_ATTRIBUTE sk_X509_ATTRIBUTE_set_cmp_func;
alias SKM_sk_dup!X509_ATTRIBUTE sk_X509_ATTRIBUTE_dup;
alias SKM_sk_pop_free!X509_ATTRIBUTE sk_X509_ATTRIBUTE_pop_free;
alias SKM_sk_shift!X509_ATTRIBUTE sk_X509_ATTRIBUTE_shift;
alias SKM_sk_pop!X509_ATTRIBUTE sk_X509_ATTRIBUTE_pop;
alias SKM_sk_sort!X509_ATTRIBUTE sk_X509_ATTRIBUTE_sort;
alias SKM_sk_is_sorted!X509_ATTRIBUTE sk_X509_ATTRIBUTE_is_sorted;

alias SKM_sk_new!X509_CRL sk_X509_CRL_new;
alias SKM_sk_new_null!X509_CRL sk_X509_CRL_new_null;
alias SKM_sk_free!X509_CRL sk_X509_CRL_free;
alias SKM_sk_num!X509_CRL sk_X509_CRL_num;
alias SKM_sk_value!X509_CRL sk_X509_CRL_value;
alias SKM_sk_set!X509_CRL sk_X509_CRL_set;
alias SKM_sk_zero!X509_CRL sk_X509_CRL_zero;
alias SKM_sk_push!X509_CRL sk_X509_CRL_push;
alias SKM_sk_unshift!X509_CRL sk_X509_CRL_unshift;
alias SKM_sk_find!X509_CRL sk_X509_CRL_find;
alias SKM_sk_find_ex!X509_CRL sk_X509_CRL_find_ex;
alias SKM_sk_delete!X509_CRL sk_X509_CRL_delete;
alias SKM_sk_delete_ptr!X509_CRL sk_X509_CRL_delete_ptr;
alias SKM_sk_insert!X509_CRL sk_X509_CRL_insert;
alias SKM_sk_set_cmp_func!X509_CRL sk_X509_CRL_set_cmp_func;
alias SKM_sk_dup!X509_CRL sk_X509_CRL_dup;
alias SKM_sk_pop_free!X509_CRL sk_X509_CRL_pop_free;
alias SKM_sk_shift!X509_CRL sk_X509_CRL_shift;
alias SKM_sk_pop!X509_CRL sk_X509_CRL_pop;
alias SKM_sk_sort!X509_CRL sk_X509_CRL_sort;
alias SKM_sk_is_sorted!X509_CRL sk_X509_CRL_is_sorted;

alias SKM_sk_new!X509_EXTENSION sk_X509_EXTENSION_new;
alias SKM_sk_new_null!X509_EXTENSION sk_X509_EXTENSION_new_null;
alias SKM_sk_free!X509_EXTENSION sk_X509_EXTENSION_free;
alias SKM_sk_num!X509_EXTENSION sk_X509_EXTENSION_num;
alias SKM_sk_value!X509_EXTENSION sk_X509_EXTENSION_value;
alias SKM_sk_set!X509_EXTENSION sk_X509_EXTENSION_set;
alias SKM_sk_zero!X509_EXTENSION sk_X509_EXTENSION_zero;
alias SKM_sk_push!X509_EXTENSION sk_X509_EXTENSION_push;
alias SKM_sk_unshift!X509_EXTENSION sk_X509_EXTENSION_unshift;
alias SKM_sk_find!X509_EXTENSION sk_X509_EXTENSION_find;
alias SKM_sk_find_ex!X509_EXTENSION sk_X509_EXTENSION_find_ex;
alias SKM_sk_delete!X509_EXTENSION sk_X509_EXTENSION_delete;
alias SKM_sk_delete_ptr!X509_EXTENSION sk_X509_EXTENSION_delete_ptr;
alias SKM_sk_insert!X509_EXTENSION sk_X509_EXTENSION_insert;
alias SKM_sk_set_cmp_func!X509_EXTENSION sk_X509_EXTENSION_set_cmp_func;
alias SKM_sk_dup!X509_EXTENSION sk_X509_EXTENSION_dup;
alias SKM_sk_pop_free!X509_EXTENSION sk_X509_EXTENSION_pop_free;
alias SKM_sk_shift!X509_EXTENSION sk_X509_EXTENSION_shift;
alias SKM_sk_pop!X509_EXTENSION sk_X509_EXTENSION_pop;
alias SKM_sk_sort!X509_EXTENSION sk_X509_EXTENSION_sort;
alias SKM_sk_is_sorted!X509_EXTENSION sk_X509_EXTENSION_is_sorted;

alias SKM_sk_new!X509_INFO sk_X509_INFO_new;
alias SKM_sk_new_null!X509_INFO sk_X509_INFO_new_null;
alias SKM_sk_free!X509_INFO sk_X509_INFO_free;
alias SKM_sk_num!X509_INFO sk_X509_INFO_num;
alias SKM_sk_value!X509_INFO sk_X509_INFO_value;
alias SKM_sk_set!X509_INFO sk_X509_INFO_set;
alias SKM_sk_zero!X509_INFO sk_X509_INFO_zero;
alias SKM_sk_push!X509_INFO sk_X509_INFO_push;
alias SKM_sk_unshift!X509_INFO sk_X509_INFO_unshift;
alias SKM_sk_find!X509_INFO sk_X509_INFO_find;
alias SKM_sk_find_ex!X509_INFO sk_X509_INFO_find_ex;
alias SKM_sk_delete!X509_INFO sk_X509_INFO_delete;
alias SKM_sk_delete_ptr!X509_INFO sk_X509_INFO_delete_ptr;
alias SKM_sk_insert!X509_INFO sk_X509_INFO_insert;
alias SKM_sk_set_cmp_func!X509_INFO sk_X509_INFO_set_cmp_func;
alias SKM_sk_dup!X509_INFO sk_X509_INFO_dup;
alias SKM_sk_pop_free!X509_INFO sk_X509_INFO_pop_free;
alias SKM_sk_shift!X509_INFO sk_X509_INFO_shift;
alias SKM_sk_pop!X509_INFO sk_X509_INFO_pop;
alias SKM_sk_sort!X509_INFO sk_X509_INFO_sort;
alias SKM_sk_is_sorted!X509_INFO sk_X509_INFO_is_sorted;

import deimos.openssl.x509_vfy;
alias SKM_sk_new!X509_LOOKUP sk_X509_LOOKUP_new;
alias SKM_sk_new_null!X509_LOOKUP sk_X509_LOOKUP_new_null;
alias SKM_sk_free!X509_LOOKUP sk_X509_LOOKUP_free;
alias SKM_sk_num!X509_LOOKUP sk_X509_LOOKUP_num;
alias SKM_sk_value!X509_LOOKUP sk_X509_LOOKUP_value;
alias SKM_sk_set!X509_LOOKUP sk_X509_LOOKUP_set;
alias SKM_sk_zero!X509_LOOKUP sk_X509_LOOKUP_zero;
alias SKM_sk_push!X509_LOOKUP sk_X509_LOOKUP_push;
alias SKM_sk_unshift!X509_LOOKUP sk_X509_LOOKUP_unshift;
alias SKM_sk_find!X509_LOOKUP sk_X509_LOOKUP_find;
alias SKM_sk_find_ex!X509_LOOKUP sk_X509_LOOKUP_find_ex;
alias SKM_sk_delete!X509_LOOKUP sk_X509_LOOKUP_delete;
alias SKM_sk_delete_ptr!X509_LOOKUP sk_X509_LOOKUP_delete_ptr;
alias SKM_sk_insert!X509_LOOKUP sk_X509_LOOKUP_insert;
alias SKM_sk_set_cmp_func!X509_LOOKUP sk_X509_LOOKUP_set_cmp_func;
alias SKM_sk_dup!X509_LOOKUP sk_X509_LOOKUP_dup;
alias SKM_sk_pop_free!X509_LOOKUP sk_X509_LOOKUP_pop_free;
alias SKM_sk_shift!X509_LOOKUP sk_X509_LOOKUP_shift;
alias SKM_sk_pop!X509_LOOKUP sk_X509_LOOKUP_pop;
alias SKM_sk_sort!X509_LOOKUP sk_X509_LOOKUP_sort;
alias SKM_sk_is_sorted!X509_LOOKUP sk_X509_LOOKUP_is_sorted;

alias SKM_sk_new!X509_NAME sk_X509_NAME_new;
alias SKM_sk_new_null!X509_NAME sk_X509_NAME_new_null;
alias SKM_sk_free!X509_NAME sk_X509_NAME_free;
alias SKM_sk_num!X509_NAME sk_X509_NAME_num;
alias SKM_sk_value!X509_NAME sk_X509_NAME_value;
alias SKM_sk_set!X509_NAME sk_X509_NAME_set;
alias SKM_sk_zero!X509_NAME sk_X509_NAME_zero;
alias SKM_sk_push!X509_NAME sk_X509_NAME_push;
alias SKM_sk_unshift!X509_NAME sk_X509_NAME_unshift;
alias SKM_sk_find!X509_NAME sk_X509_NAME_find;
alias SKM_sk_find_ex!X509_NAME sk_X509_NAME_find_ex;
alias SKM_sk_delete!X509_NAME sk_X509_NAME_delete;
alias SKM_sk_delete_ptr!X509_NAME sk_X509_NAME_delete_ptr;
alias SKM_sk_insert!X509_NAME sk_X509_NAME_insert;
alias SKM_sk_set_cmp_func!X509_NAME sk_X509_NAME_set_cmp_func;
alias SKM_sk_dup!X509_NAME sk_X509_NAME_dup;
alias SKM_sk_pop_free!X509_NAME sk_X509_NAME_pop_free;
alias SKM_sk_shift!X509_NAME sk_X509_NAME_shift;
alias SKM_sk_pop!X509_NAME sk_X509_NAME_pop;
alias SKM_sk_sort!X509_NAME sk_X509_NAME_sort;
alias SKM_sk_is_sorted!X509_NAME sk_X509_NAME_is_sorted;

alias SKM_sk_new!X509_NAME_ENTRY sk_X509_NAME_ENTRY_new;
alias SKM_sk_new_null!X509_NAME_ENTRY sk_X509_NAME_ENTRY_new_null;
alias SKM_sk_free!X509_NAME_ENTRY sk_X509_NAME_ENTRY_free;
alias SKM_sk_num!X509_NAME_ENTRY sk_X509_NAME_ENTRY_num;
alias SKM_sk_value!X509_NAME_ENTRY sk_X509_NAME_ENTRY_value;
alias SKM_sk_set!X509_NAME_ENTRY sk_X509_NAME_ENTRY_set;
alias SKM_sk_zero!X509_NAME_ENTRY sk_X509_NAME_ENTRY_zero;
alias SKM_sk_push!X509_NAME_ENTRY sk_X509_NAME_ENTRY_push;
alias SKM_sk_unshift!X509_NAME_ENTRY sk_X509_NAME_ENTRY_unshift;
alias SKM_sk_find!X509_NAME_ENTRY sk_X509_NAME_ENTRY_find;
alias SKM_sk_find_ex!X509_NAME_ENTRY sk_X509_NAME_ENTRY_find_ex;
alias SKM_sk_delete!X509_NAME_ENTRY sk_X509_NAME_ENTRY_delete;
alias SKM_sk_delete_ptr!X509_NAME_ENTRY sk_X509_NAME_ENTRY_delete_ptr;
alias SKM_sk_insert!X509_NAME_ENTRY sk_X509_NAME_ENTRY_insert;
alias SKM_sk_set_cmp_func!X509_NAME_ENTRY sk_X509_NAME_ENTRY_set_cmp_func;
alias SKM_sk_dup!X509_NAME_ENTRY sk_X509_NAME_ENTRY_dup;
alias SKM_sk_pop_free!X509_NAME_ENTRY sk_X509_NAME_ENTRY_pop_free;
alias SKM_sk_shift!X509_NAME_ENTRY sk_X509_NAME_ENTRY_shift;
alias SKM_sk_pop!X509_NAME_ENTRY sk_X509_NAME_ENTRY_pop;
alias SKM_sk_sort!X509_NAME_ENTRY sk_X509_NAME_ENTRY_sort;
alias SKM_sk_is_sorted!X509_NAME_ENTRY sk_X509_NAME_ENTRY_is_sorted;

alias SKM_sk_new!X509_OBJECT sk_X509_OBJECT_new;
alias SKM_sk_new_null!X509_OBJECT sk_X509_OBJECT_new_null;
alias SKM_sk_free!X509_OBJECT sk_X509_OBJECT_free;
alias SKM_sk_num!X509_OBJECT sk_X509_OBJECT_num;
alias SKM_sk_value!X509_OBJECT sk_X509_OBJECT_value;
alias SKM_sk_set!X509_OBJECT sk_X509_OBJECT_set;
alias SKM_sk_zero!X509_OBJECT sk_X509_OBJECT_zero;
alias SKM_sk_push!X509_OBJECT sk_X509_OBJECT_push;
alias SKM_sk_unshift!X509_OBJECT sk_X509_OBJECT_unshift;
alias SKM_sk_find!X509_OBJECT sk_X509_OBJECT_find;
alias SKM_sk_find_ex!X509_OBJECT sk_X509_OBJECT_find_ex;
alias SKM_sk_delete!X509_OBJECT sk_X509_OBJECT_delete;
alias SKM_sk_delete_ptr!X509_OBJECT sk_X509_OBJECT_delete_ptr;
alias SKM_sk_insert!X509_OBJECT sk_X509_OBJECT_insert;
alias SKM_sk_set_cmp_func!X509_OBJECT sk_X509_OBJECT_set_cmp_func;
alias SKM_sk_dup!X509_OBJECT sk_X509_OBJECT_dup;
alias SKM_sk_pop_free!X509_OBJECT sk_X509_OBJECT_pop_free;
alias SKM_sk_shift!X509_OBJECT sk_X509_OBJECT_shift;
alias SKM_sk_pop!X509_OBJECT sk_X509_OBJECT_pop;
alias SKM_sk_sort!X509_OBJECT sk_X509_OBJECT_sort;
alias SKM_sk_is_sorted!X509_OBJECT sk_X509_OBJECT_is_sorted;

/+ Internal crypto types.
alias SKM_sk_new!X509_POLICY_DATA sk_X509_POLICY_DATA_new;
alias SKM_sk_new_null!X509_POLICY_DATA sk_X509_POLICY_DATA_new_null;
alias SKM_sk_free!X509_POLICY_DATA sk_X509_POLICY_DATA_free;
alias SKM_sk_num!X509_POLICY_DATA sk_X509_POLICY_DATA_num;
alias SKM_sk_value!X509_POLICY_DATA sk_X509_POLICY_DATA_value;
alias SKM_sk_set!X509_POLICY_DATA sk_X509_POLICY_DATA_set;
alias SKM_sk_zero!X509_POLICY_DATA sk_X509_POLICY_DATA_zero;
alias SKM_sk_push!X509_POLICY_DATA sk_X509_POLICY_DATA_push;
alias SKM_sk_unshift!X509_POLICY_DATA sk_X509_POLICY_DATA_unshift;
alias SKM_sk_find!X509_POLICY_DATA sk_X509_POLICY_DATA_find;
alias SKM_sk_find_ex!X509_POLICY_DATA sk_X509_POLICY_DATA_find_ex;
alias SKM_sk_delete!X509_POLICY_DATA sk_X509_POLICY_DATA_delete;
alias SKM_sk_delete_ptr!X509_POLICY_DATA sk_X509_POLICY_DATA_delete_ptr;
alias SKM_sk_insert!X509_POLICY_DATA sk_X509_POLICY_DATA_insert;
alias SKM_sk_set_cmp_func!X509_POLICY_DATA sk_X509_POLICY_DATA_set_cmp_func;
alias SKM_sk_dup!X509_POLICY_DATA sk_X509_POLICY_DATA_dup;
alias SKM_sk_pop_free!X509_POLICY_DATA sk_X509_POLICY_DATA_pop_free;
alias SKM_sk_shift!X509_POLICY_DATA sk_X509_POLICY_DATA_shift;
alias SKM_sk_pop!X509_POLICY_DATA sk_X509_POLICY_DATA_pop;
alias SKM_sk_sort!X509_POLICY_DATA sk_X509_POLICY_DATA_sort;
alias SKM_sk_is_sorted!X509_POLICY_DATA sk_X509_POLICY_DATA_is_sorted;
+/

alias SKM_sk_new!X509_POLICY_NODE sk_X509_POLICY_NODE_new;
alias SKM_sk_new_null!X509_POLICY_NODE sk_X509_POLICY_NODE_new_null;
alias SKM_sk_free!X509_POLICY_NODE sk_X509_POLICY_NODE_free;
alias SKM_sk_num!X509_POLICY_NODE sk_X509_POLICY_NODE_num;
alias SKM_sk_value!X509_POLICY_NODE sk_X509_POLICY_NODE_value;
alias SKM_sk_set!X509_POLICY_NODE sk_X509_POLICY_NODE_set;
alias SKM_sk_zero!X509_POLICY_NODE sk_X509_POLICY_NODE_zero;
alias SKM_sk_push!X509_POLICY_NODE sk_X509_POLICY_NODE_push;
alias SKM_sk_unshift!X509_POLICY_NODE sk_X509_POLICY_NODE_unshift;
alias SKM_sk_find!X509_POLICY_NODE sk_X509_POLICY_NODE_find;
alias SKM_sk_find_ex!X509_POLICY_NODE sk_X509_POLICY_NODE_find_ex;
alias SKM_sk_delete!X509_POLICY_NODE sk_X509_POLICY_NODE_delete;
alias SKM_sk_delete_ptr!X509_POLICY_NODE sk_X509_POLICY_NODE_delete_ptr;
alias SKM_sk_insert!X509_POLICY_NODE sk_X509_POLICY_NODE_insert;
alias SKM_sk_set_cmp_func!X509_POLICY_NODE sk_X509_POLICY_NODE_set_cmp_func;
alias SKM_sk_dup!X509_POLICY_NODE sk_X509_POLICY_NODE_dup;
alias SKM_sk_pop_free!X509_POLICY_NODE sk_X509_POLICY_NODE_pop_free;
alias SKM_sk_shift!X509_POLICY_NODE sk_X509_POLICY_NODE_shift;
alias SKM_sk_pop!X509_POLICY_NODE sk_X509_POLICY_NODE_pop;
alias SKM_sk_sort!X509_POLICY_NODE sk_X509_POLICY_NODE_sort;
alias SKM_sk_is_sorted!X509_POLICY_NODE sk_X509_POLICY_NODE_is_sorted;

alias SKM_sk_new!X509_PURPOSE sk_X509_PURPOSE_new;
alias SKM_sk_new_null!X509_PURPOSE sk_X509_PURPOSE_new_null;
alias SKM_sk_free!X509_PURPOSE sk_X509_PURPOSE_free;
alias SKM_sk_num!X509_PURPOSE sk_X509_PURPOSE_num;
alias SKM_sk_value!X509_PURPOSE sk_X509_PURPOSE_value;
alias SKM_sk_set!X509_PURPOSE sk_X509_PURPOSE_set;
alias SKM_sk_zero!X509_PURPOSE sk_X509_PURPOSE_zero;
alias SKM_sk_push!X509_PURPOSE sk_X509_PURPOSE_push;
alias SKM_sk_unshift!X509_PURPOSE sk_X509_PURPOSE_unshift;
alias SKM_sk_find!X509_PURPOSE sk_X509_PURPOSE_find;
alias SKM_sk_find_ex!X509_PURPOSE sk_X509_PURPOSE_find_ex;
alias SKM_sk_delete!X509_PURPOSE sk_X509_PURPOSE_delete;
alias SKM_sk_delete_ptr!X509_PURPOSE sk_X509_PURPOSE_delete_ptr;
alias SKM_sk_insert!X509_PURPOSE sk_X509_PURPOSE_insert;
alias SKM_sk_set_cmp_func!X509_PURPOSE sk_X509_PURPOSE_set_cmp_func;
alias SKM_sk_dup!X509_PURPOSE sk_X509_PURPOSE_dup;
alias SKM_sk_pop_free!X509_PURPOSE sk_X509_PURPOSE_pop_free;
alias SKM_sk_shift!X509_PURPOSE sk_X509_PURPOSE_shift;
alias SKM_sk_pop!X509_PURPOSE sk_X509_PURPOSE_pop;
alias SKM_sk_sort!X509_PURPOSE sk_X509_PURPOSE_sort;
alias SKM_sk_is_sorted!X509_PURPOSE sk_X509_PURPOSE_is_sorted;

alias SKM_sk_new!X509_REVOKED sk_X509_REVOKED_new;
alias SKM_sk_new_null!X509_REVOKED sk_X509_REVOKED_new_null;
alias SKM_sk_free!X509_REVOKED sk_X509_REVOKED_free;
alias SKM_sk_num!X509_REVOKED sk_X509_REVOKED_num;
alias SKM_sk_value!X509_REVOKED sk_X509_REVOKED_value;
alias SKM_sk_set!X509_REVOKED sk_X509_REVOKED_set;
alias SKM_sk_zero!X509_REVOKED sk_X509_REVOKED_zero;
alias SKM_sk_push!X509_REVOKED sk_X509_REVOKED_push;
alias SKM_sk_unshift!X509_REVOKED sk_X509_REVOKED_unshift;
alias SKM_sk_find!X509_REVOKED sk_X509_REVOKED_find;
alias SKM_sk_find_ex!X509_REVOKED sk_X509_REVOKED_find_ex;
alias SKM_sk_delete!X509_REVOKED sk_X509_REVOKED_delete;
alias SKM_sk_delete_ptr!X509_REVOKED sk_X509_REVOKED_delete_ptr;
alias SKM_sk_insert!X509_REVOKED sk_X509_REVOKED_insert;
alias SKM_sk_set_cmp_func!X509_REVOKED sk_X509_REVOKED_set_cmp_func;
alias SKM_sk_dup!X509_REVOKED sk_X509_REVOKED_dup;
alias SKM_sk_pop_free!X509_REVOKED sk_X509_REVOKED_pop_free;
alias SKM_sk_shift!X509_REVOKED sk_X509_REVOKED_shift;
alias SKM_sk_pop!X509_REVOKED sk_X509_REVOKED_pop;
alias SKM_sk_sort!X509_REVOKED sk_X509_REVOKED_sort;
alias SKM_sk_is_sorted!X509_REVOKED sk_X509_REVOKED_is_sorted;

alias SKM_sk_new!X509_TRUST sk_X509_TRUST_new;
alias SKM_sk_new_null!X509_TRUST sk_X509_TRUST_new_null;
alias SKM_sk_free!X509_TRUST sk_X509_TRUST_free;
alias SKM_sk_num!X509_TRUST sk_X509_TRUST_num;
alias SKM_sk_value!X509_TRUST sk_X509_TRUST_value;
alias SKM_sk_set!X509_TRUST sk_X509_TRUST_set;
alias SKM_sk_zero!X509_TRUST sk_X509_TRUST_zero;
alias SKM_sk_push!X509_TRUST sk_X509_TRUST_push;
alias SKM_sk_unshift!X509_TRUST sk_X509_TRUST_unshift;
alias SKM_sk_find!X509_TRUST sk_X509_TRUST_find;
alias SKM_sk_find_ex!X509_TRUST sk_X509_TRUST_find_ex;
alias SKM_sk_delete!X509_TRUST sk_X509_TRUST_delete;
alias SKM_sk_delete_ptr!X509_TRUST sk_X509_TRUST_delete_ptr;
alias SKM_sk_insert!X509_TRUST sk_X509_TRUST_insert;
alias SKM_sk_set_cmp_func!X509_TRUST sk_X509_TRUST_set_cmp_func;
alias SKM_sk_dup!X509_TRUST sk_X509_TRUST_dup;
alias SKM_sk_pop_free!X509_TRUST sk_X509_TRUST_pop_free;
alias SKM_sk_shift!X509_TRUST sk_X509_TRUST_shift;
alias SKM_sk_pop!X509_TRUST sk_X509_TRUST_pop;
alias SKM_sk_sort!X509_TRUST sk_X509_TRUST_sort;
alias SKM_sk_is_sorted!X509_TRUST sk_X509_TRUST_is_sorted;

alias SKM_sk_new!X509_VERIFY_PARAM sk_X509_VERIFY_PARAM_new;
alias SKM_sk_new_null!X509_VERIFY_PARAM sk_X509_VERIFY_PARAM_new_null;
alias SKM_sk_free!X509_VERIFY_PARAM sk_X509_VERIFY_PARAM_free;
alias SKM_sk_num!X509_VERIFY_PARAM sk_X509_VERIFY_PARAM_num;
alias SKM_sk_value!X509_VERIFY_PARAM sk_X509_VERIFY_PARAM_value;
alias SKM_sk_set!X509_VERIFY_PARAM sk_X509_VERIFY_PARAM_set;
alias SKM_sk_zero!X509_VERIFY_PARAM sk_X509_VERIFY_PARAM_zero;
alias SKM_sk_push!X509_VERIFY_PARAM sk_X509_VERIFY_PARAM_push;
alias SKM_sk_unshift!X509_VERIFY_PARAM sk_X509_VERIFY_PARAM_unshift;
alias SKM_sk_find!X509_VERIFY_PARAM sk_X509_VERIFY_PARAM_find;
alias SKM_sk_find_ex!X509_VERIFY_PARAM sk_X509_VERIFY_PARAM_find_ex;
alias SKM_sk_delete!X509_VERIFY_PARAM sk_X509_VERIFY_PARAM_delete;
alias SKM_sk_delete_ptr!X509_VERIFY_PARAM sk_X509_VERIFY_PARAM_delete_ptr;
alias SKM_sk_insert!X509_VERIFY_PARAM sk_X509_VERIFY_PARAM_insert;
alias SKM_sk_set_cmp_func!X509_VERIFY_PARAM sk_X509_VERIFY_PARAM_set_cmp_func;
alias SKM_sk_dup!X509_VERIFY_PARAM sk_X509_VERIFY_PARAM_dup;
alias SKM_sk_pop_free!X509_VERIFY_PARAM sk_X509_VERIFY_PARAM_pop_free;
alias SKM_sk_shift!X509_VERIFY_PARAM sk_X509_VERIFY_PARAM_shift;
alias SKM_sk_pop!X509_VERIFY_PARAM sk_X509_VERIFY_PARAM_pop;
alias SKM_sk_sort!X509_VERIFY_PARAM sk_X509_VERIFY_PARAM_sort;
alias SKM_sk_is_sorted!X509_VERIFY_PARAM sk_X509_VERIFY_PARAM_is_sorted;

/+ Internal type.
alias SKM_sk_new!nid_triple sk_nid_triple_new;
alias SKM_sk_new_null!nid_triple sk_nid_triple_new_null;
alias SKM_sk_free!nid_triple sk_nid_triple_free;
alias SKM_sk_num!nid_triple sk_nid_triple_num;
alias SKM_sk_value!nid_triple sk_nid_triple_value;
alias SKM_sk_set!nid_triple sk_nid_triple_set;
alias SKM_sk_zero!nid_triple sk_nid_triple_zero;
alias SKM_sk_push!nid_triple sk_nid_triple_push;
alias SKM_sk_unshift!nid_triple sk_nid_triple_unshift;
alias SKM_sk_find!nid_triple sk_nid_triple_find;
alias SKM_sk_find_ex!nid_triple sk_nid_triple_find_ex;
alias SKM_sk_delete!nid_triple sk_nid_triple_delete;
alias SKM_sk_delete_ptr!nid_triple sk_nid_triple_delete_ptr;
alias SKM_sk_insert!nid_triple sk_nid_triple_insert;
alias SKM_sk_set_cmp_func!nid_triple sk_nid_triple_set_cmp_func;
alias SKM_sk_dup!nid_triple sk_nid_triple_dup;
alias SKM_sk_pop_free!nid_triple sk_nid_triple_pop_free;
alias SKM_sk_shift!nid_triple sk_nid_triple_shift;
alias SKM_sk_pop!nid_triple sk_nid_triple_pop;
alias SKM_sk_sort!nid_triple sk_nid_triple_sort;
alias SKM_sk_is_sorted!nid_triple sk_nid_triple_is_sorted;
+/

alias SKM_sk_new!void sk_void_new;
alias SKM_sk_new_null!void sk_void_new_null;
alias SKM_sk_free!void sk_void_free;
alias SKM_sk_num!void sk_void_num;
alias SKM_sk_value!void sk_void_value;
alias SKM_sk_set!void sk_void_set;
alias SKM_sk_zero!void sk_void_zero;
alias SKM_sk_push!void sk_void_push;
alias SKM_sk_unshift!void sk_void_unshift;
alias SKM_sk_find!void sk_void_find;
alias SKM_sk_find_ex!void sk_void_find_ex;
alias SKM_sk_delete!void sk_void_delete;
alias SKM_sk_delete_ptr!void sk_void_delete_ptr;
alias SKM_sk_insert!void sk_void_insert;
alias SKM_sk_set_cmp_func!void sk_void_set_cmp_func;
alias SKM_sk_dup!void sk_void_dup;
alias SKM_sk_pop_free!void sk_void_pop_free;
alias SKM_sk_shift!void sk_void_shift;
alias SKM_sk_pop!void sk_void_pop;
alias SKM_sk_sort!void sk_void_sort;
alias SKM_sk_is_sorted!void sk_void_is_sorted;

alias SKM_sk_new!OPENSSL_STRING sk_OPENSSL_STRING_new;
alias SKM_sk_new_null!OPENSSL_STRING sk_OPENSSL_STRING_new_null;
alias SKM_sk_push!OPENSSL_STRING sk_OPENSSL_STRING_push;
alias SKM_sk_find!OPENSSL_STRING sk_OPENSSL_STRING_find;
alias SKM_sk_value!OPENSSL_STRING sk_OPENSSL_STRING_value;
alias SKM_sk_num!OPENSSL_STRING sk_OPENSSL_STRING_num;
alias SKM_sk_pop_free!OPENSSL_STRING sk_OPENSSL_STRING_pop_free;
alias SKM_sk_insert!OPENSSL_STRING sk_OPENSSL_STRING_insert;
alias SKM_sk_free!OPENSSL_STRING sk_OPENSSL_STRING_free;
alias SKM_sk_set!OPENSSL_STRING sk_OPENSSL_STRING_set;
alias SKM_sk_zero!OPENSSL_STRING sk_OPENSSL_STRING_zero;
alias SKM_sk_unshift!OPENSSL_STRING sk_OPENSSL_STRING_unshift;
alias SKM_sk_find_ex!OPENSSL_STRING sk_OPENSSL_STRING_find_ex;
alias SKM_sk_delete!OPENSSL_STRING sk_OPENSSL_STRING_delete;
alias SKM_sk_delete_ptr!OPENSSL_STRING sk_OPENSSL_STRING_delete_ptr;
alias SKM_sk_set_cmp_func!OPENSSL_STRING sk_OPENSSL_STRING_set_cmp_func;
alias SKM_sk_dup!OPENSSL_STRING sk_OPENSSL_STRING_dup;
alias SKM_sk_shift!OPENSSL_STRING sk_OPENSSL_STRING_shift;
alias SKM_sk_pop!OPENSSL_STRING sk_OPENSSL_STRING_pop;
alias SKM_sk_sort!OPENSSL_STRING sk_OPENSSL_STRING_sort;
alias SKM_sk_is_sorted!OPENSSL_STRING sk_OPENSSL_STRING_is_sorted;

alias SKM_sk_new!OPENSSL_BLOCK sk_OPENSSL_BLOCK_new;
alias SKM_sk_new_null!OPENSSL_BLOCK sk_OPENSSL_BLOCK_new_null;
alias SKM_sk_push!OPENSSL_BLOCK sk_OPENSSL_BLOCK_push;
alias SKM_sk_find!OPENSSL_BLOCK sk_OPENSSL_BLOCK_find;
alias SKM_sk_value!OPENSSL_BLOCK sk_OPENSSL_BLOCK_value;
alias SKM_sk_num!OPENSSL_BLOCK sk_OPENSSL_BLOCK_num;
alias SKM_sk_pop_free!OPENSSL_BLOCK sk_OPENSSL_BLOCK_pop_free;
alias SKM_sk_insert!OPENSSL_BLOCK sk_OPENSSL_BLOCK_insert;
alias SKM_sk_free!OPENSSL_BLOCK sk_OPENSSL_BLOCK_free;
alias SKM_sk_set!OPENSSL_BLOCK sk_OPENSSL_BLOCK_set;
alias SKM_sk_zero!OPENSSL_BLOCK sk_OPENSSL_BLOCK_zero;
alias SKM_sk_unshift!OPENSSL_BLOCK sk_OPENSSL_BLOCK_unshift;
alias SKM_sk_find_ex!OPENSSL_BLOCK sk_OPENSSL_BLOCK_find_ex;
alias SKM_sk_delete!OPENSSL_BLOCK sk_OPENSSL_BLOCK_delete;
alias SKM_sk_delete_ptr!OPENSSL_BLOCK sk_OPENSSL_BLOCK_delete_ptr;
alias SKM_sk_set_cmp_func!OPENSSL_BLOCK sk_OPENSSL_BLOCK_set_cmp_func;
alias SKM_sk_dup!OPENSSL_BLOCK sk_OPENSSL_BLOCK_dup;
alias SKM_sk_shift!OPENSSL_BLOCK sk_OPENSSL_BLOCK_shift;
alias SKM_sk_pop!OPENSSL_BLOCK sk_OPENSSL_BLOCK_pop;
alias SKM_sk_sort!OPENSSL_BLOCK sk_OPENSSL_BLOCK_sort;
alias SKM_sk_is_sorted!OPENSSL_BLOCK sk_OPENSSL_BLOCK_is_sorted;

/+ TODO
#define sk_OPENSSL_PSTRING_new(cmp) ((STACK_OF(OPENSSL_PSTRING) *)sk_new(CHECKED_SK_CMP_FUNC(OPENSSL_STRING, cmp)))
#define sk_OPENSSL_PSTRING_new_null() ((STACK_OF(OPENSSL_PSTRING) *)sk_new_null())
#define sk_OPENSSL_PSTRING_push(st, val) sk_push(CHECKED_STACK_OF(OPENSSL_PSTRING, st), CHECKED_PTR_OF(OPENSSL_STRING, val))
#define sk_OPENSSL_PSTRING_find(st, val) sk_find(CHECKED_STACK_OF(OPENSSL_PSTRING, st), CHECKED_PTR_OF(OPENSSL_STRING, val))
#define sk_OPENSSL_PSTRING_value(st, i) ((OPENSSL_PSTRING)sk_value(CHECKED_STACK_OF(OPENSSL_PSTRING, st), i))
#define sk_OPENSSL_PSTRING_num(st) SKM_sk_num(OPENSSL_PSTRING, st)
#define sk_OPENSSL_PSTRING_pop_free(st, free_func) sk_pop_free(CHECKED_STACK_OF(OPENSSL_PSTRING, st), CHECKED_SK_FREE_FUNC2(OPENSSL_PSTRING, free_func))
#define sk_OPENSSL_PSTRING_insert(st, val, i) sk_insert(CHECKED_STACK_OF(OPENSSL_PSTRING, st), CHECKED_PTR_OF(OPENSSL_STRING, val), i)
#define sk_OPENSSL_PSTRING_free(st) SKM_sk_free(OPENSSL_PSTRING, st)
#define sk_OPENSSL_PSTRING_set(st, i, val) sk_set(CHECKED_STACK_OF(OPENSSL_PSTRING, st), i, CHECKED_PTR_OF(OPENSSL_STRING, val))
#define sk_OPENSSL_PSTRING_zero(st) SKM_sk_zero(OPENSSL_PSTRING, (st))
#define sk_OPENSSL_PSTRING_unshift(st, val) sk_unshift(CHECKED_STACK_OF(OPENSSL_PSTRING, st), CHECKED_PTR_OF(OPENSSL_STRING, val))
#define sk_OPENSSL_PSTRING_find_ex(st, val) sk_find_ex((_STACK *)CHECKED_CONST_PTR_OF(STACK_OF(OPENSSL_PSTRING), st), CHECKED_CONST_PTR_OF(OPENSSL_STRING, val))
#define sk_OPENSSL_PSTRING_delete(st, i) SKM_sk_delete(OPENSSL_PSTRING, (st), (i))
#define sk_OPENSSL_PSTRING_delete_ptr(st, ptr) (OPENSSL_PSTRING *)sk_delete_ptr(CHECKED_STACK_OF(OPENSSL_PSTRING, st), CHECKED_PTR_OF(OPENSSL_STRING, ptr))
#define sk_OPENSSL_PSTRING_set_cmp_func(st, cmp)  \
	((int (*)(const OPENSSL_STRING * const *,const OPENSSL_STRING * const *)) \
	sk_set_cmp_func(CHECKED_STACK_OF(OPENSSL_PSTRING, st), CHECKED_SK_CMP_FUNC(OPENSSL_STRING, cmp)))
#define sk_OPENSSL_PSTRING_dup(st) SKM_sk_dup(OPENSSL_PSTRING, st)
#define sk_OPENSSL_PSTRING_shift(st) SKM_sk_shift(OPENSSL_PSTRING, (st))
#define sk_OPENSSL_PSTRING_pop(st) (OPENSSL_STRING *)sk_pop(CHECKED_STACK_OF(OPENSSL_PSTRING, st))
#define sk_OPENSSL_PSTRING_sort(st) SKM_sk_sort(OPENSSL_PSTRING, (st))
#define sk_OPENSSL_PSTRING_is_sorted(st) SKM_sk_is_sorted(OPENSSL_PSTRING, (st))
+/

alias SKM_ASN1_SET_OF_d2i!ACCESS_DESCRIPTION d2i_ASN1_SET_OF_ACCESS_DESCRIPTION;
alias SKM_ASN1_SET_OF_i2d!ACCESS_DESCRIPTION i2d_ASN1_SET_OF_ACCESS_DESCRIPTION;
alias SKM_ASN1_seq_pack!ACCESS_DESCRIPTION ASN1_seq_pack_ACCESS_DESCRIPTION;
alias SKM_ASN1_seq_unpack!ACCESS_DESCRIPTION ASN1_seq_unpack_ACCESS_DESCRIPTION;

alias SKM_ASN1_SET_OF_d2i!ASN1_INTEGER d2i_ASN1_SET_OF_ASN1_INTEGER;
alias SKM_ASN1_SET_OF_i2d!ASN1_INTEGER i2d_ASN1_SET_OF_ASN1_INTEGER;
alias SKM_ASN1_seq_pack!ASN1_INTEGER ASN1_seq_pack_ASN1_INTEGER;
alias SKM_ASN1_seq_unpack!ASN1_INTEGER ASN1_seq_unpack_ASN1_INTEGER;

alias SKM_ASN1_SET_OF_d2i!ASN1_OBJECT d2i_ASN1_SET_OF_ASN1_OBJECT;
alias SKM_ASN1_SET_OF_i2d!ASN1_OBJECT i2d_ASN1_SET_OF_ASN1_OBJECT;
alias SKM_ASN1_seq_pack!ASN1_OBJECT ASN1_seq_pack_ASN1_OBJECT;
alias SKM_ASN1_seq_unpack!ASN1_OBJECT ASN1_seq_unpack_ASN1_OBJECT;

alias SKM_ASN1_SET_OF_d2i!ASN1_TYPE d2i_ASN1_SET_OF_ASN1_TYPE;
alias SKM_ASN1_SET_OF_i2d!ASN1_TYPE i2d_ASN1_SET_OF_ASN1_TYPE;
alias SKM_ASN1_seq_pack!ASN1_TYPE ASN1_seq_pack_ASN1_TYPE;
alias SKM_ASN1_seq_unpack!ASN1_TYPE ASN1_seq_unpack_ASN1_TYPE;

alias SKM_ASN1_SET_OF_d2i!ASN1_UTF8STRING d2i_ASN1_SET_OF_ASN1_UTF8STRING;
alias SKM_ASN1_SET_OF_i2d!ASN1_UTF8STRING i2d_ASN1_SET_OF_ASN1_UTF8STRING;
alias SKM_ASN1_seq_pack!ASN1_UTF8STRING ASN1_seq_pack_ASN1_UTF8STRING;
alias SKM_ASN1_seq_unpack!ASN1_UTF8STRING ASN1_seq_unpack_ASN1_UTF8STRING;

alias SKM_ASN1_SET_OF_d2i!DIST_POINT d2i_ASN1_SET_OF_DIST_POINT;
alias SKM_ASN1_SET_OF_i2d!DIST_POINT i2d_ASN1_SET_OF_DIST_POINT;
alias SKM_ASN1_seq_pack!DIST_POINT ASN1_seq_pack_DIST_POINT;
alias SKM_ASN1_seq_unpack!DIST_POINT ASN1_seq_unpack_DIST_POINT;

alias SKM_ASN1_SET_OF_d2i!ESS_CERT_ID d2i_ASN1_SET_OF_ESS_CERT_ID;
alias SKM_ASN1_SET_OF_i2d!ESS_CERT_ID i2d_ASN1_SET_OF_ESS_CERT_ID;
alias SKM_ASN1_seq_pack!ESS_CERT_ID ASN1_seq_pack_ESS_CERT_ID;
alias SKM_ASN1_seq_unpack!ESS_CERT_ID ASN1_seq_unpack_ESS_CERT_ID;

alias SKM_ASN1_SET_OF_d2i!EVP_MD d2i_ASN1_SET_OF_EVP_MD;
alias SKM_ASN1_SET_OF_i2d!EVP_MD i2d_ASN1_SET_OF_EVP_MD;
alias SKM_ASN1_seq_pack!EVP_MD ASN1_seq_pack_EVP_MD;
alias SKM_ASN1_seq_unpack!EVP_MD ASN1_seq_unpack_EVP_MD;

alias SKM_ASN1_SET_OF_d2i!GENERAL_NAME d2i_ASN1_SET_OF_GENERAL_NAME;
alias SKM_ASN1_SET_OF_i2d!GENERAL_NAME i2d_ASN1_SET_OF_GENERAL_NAME;
alias SKM_ASN1_seq_pack!GENERAL_NAME ASN1_seq_pack_GENERAL_NAME;
alias SKM_ASN1_seq_unpack!GENERAL_NAME ASN1_seq_unpack_GENERAL_NAME;

alias SKM_ASN1_SET_OF_d2i!OCSP_ONEREQ d2i_ASN1_SET_OF_OCSP_ONEREQ;
alias SKM_ASN1_SET_OF_i2d!OCSP_ONEREQ i2d_ASN1_SET_OF_OCSP_ONEREQ;
alias SKM_ASN1_seq_pack!OCSP_ONEREQ ASN1_seq_pack_OCSP_ONEREQ;
alias SKM_ASN1_seq_unpack!OCSP_ONEREQ ASN1_seq_unpack_OCSP_ONEREQ;

alias SKM_ASN1_SET_OF_d2i!OCSP_SINGLERESP d2i_ASN1_SET_OF_OCSP_SINGLERESP;
alias SKM_ASN1_SET_OF_i2d!OCSP_SINGLERESP i2d_ASN1_SET_OF_OCSP_SINGLERESP;
alias SKM_ASN1_seq_pack!OCSP_SINGLERESP ASN1_seq_pack_OCSP_SINGLERESP;
alias SKM_ASN1_seq_unpack!OCSP_SINGLERESP ASN1_seq_unpack_OCSP_SINGLERESP;

alias SKM_ASN1_SET_OF_d2i!PKCS12_SAFEBAG d2i_ASN1_SET_OF_PKCS12_SAFEBAG;
alias SKM_ASN1_SET_OF_i2d!PKCS12_SAFEBAG i2d_ASN1_SET_OF_PKCS12_SAFEBAG;
alias SKM_ASN1_seq_pack!PKCS12_SAFEBAG ASN1_seq_pack_PKCS12_SAFEBAG;
alias SKM_ASN1_seq_unpack!PKCS12_SAFEBAG ASN1_seq_unpack_PKCS12_SAFEBAG;

alias SKM_ASN1_SET_OF_d2i!PKCS7 d2i_ASN1_SET_OF_PKCS7;
alias SKM_ASN1_SET_OF_i2d!PKCS7 i2d_ASN1_SET_OF_PKCS7;
alias SKM_ASN1_seq_pack!PKCS7 ASN1_seq_pack_PKCS7;
alias SKM_ASN1_seq_unpack!PKCS7 ASN1_seq_unpack_PKCS7;

alias SKM_ASN1_SET_OF_d2i!PKCS7_RECIP_INFO d2i_ASN1_SET_OF_PKCS7_RECIP_INFO;
alias SKM_ASN1_SET_OF_i2d!PKCS7_RECIP_INFO i2d_ASN1_SET_OF_PKCS7_RECIP_INFO;
alias SKM_ASN1_seq_pack!PKCS7_RECIP_INFO ASN1_seq_pack_PKCS7_RECIP_INFO;
alias SKM_ASN1_seq_unpack!PKCS7_RECIP_INFO ASN1_seq_unpack_PKCS7_RECIP_INFO;

alias SKM_ASN1_SET_OF_d2i!PKCS7_SIGNER_INFO d2i_ASN1_SET_OF_PKCS7_SIGNER_INFO;
alias SKM_ASN1_SET_OF_i2d!PKCS7_SIGNER_INFO i2d_ASN1_SET_OF_PKCS7_SIGNER_INFO;
alias SKM_ASN1_seq_pack!PKCS7_SIGNER_INFO ASN1_seq_pack_PKCS7_SIGNER_INFO;
alias SKM_ASN1_seq_unpack!PKCS7_SIGNER_INFO ASN1_seq_unpack_PKCS7_SIGNER_INFO;

alias SKM_ASN1_SET_OF_d2i!POLICYINFO d2i_ASN1_SET_OF_POLICYINFO;
alias SKM_ASN1_SET_OF_i2d!POLICYINFO i2d_ASN1_SET_OF_POLICYINFO;
alias SKM_ASN1_seq_pack!POLICYINFO ASN1_seq_pack_POLICYINFO;
alias SKM_ASN1_seq_unpack!POLICYINFO ASN1_seq_unpack_POLICYINFO;

alias SKM_ASN1_SET_OF_d2i!POLICYQUALINFO d2i_ASN1_SET_OF_POLICYQUALINFO;
alias SKM_ASN1_SET_OF_i2d!POLICYQUALINFO i2d_ASN1_SET_OF_POLICYQUALINFO;
alias SKM_ASN1_seq_pack!POLICYQUALINFO ASN1_seq_pack_POLICYQUALINFO;
alias SKM_ASN1_seq_unpack!POLICYQUALINFO ASN1_seq_unpack_POLICYQUALINFO;

alias SKM_ASN1_SET_OF_d2i!SXNETID d2i_ASN1_SET_OF_SXNETID;
alias SKM_ASN1_SET_OF_i2d!SXNETID i2d_ASN1_SET_OF_SXNETID;
alias SKM_ASN1_seq_pack!SXNETID ASN1_seq_pack_SXNETID;
alias SKM_ASN1_seq_unpack!SXNETID ASN1_seq_unpack_SXNETID;

alias SKM_ASN1_SET_OF_d2i!X509 d2i_ASN1_SET_OF_X509;
alias SKM_ASN1_SET_OF_i2d!X509 i2d_ASN1_SET_OF_X509;
alias SKM_ASN1_seq_pack!X509 ASN1_seq_pack_X509;
alias SKM_ASN1_seq_unpack!X509 ASN1_seq_unpack_X509;

alias SKM_ASN1_SET_OF_d2i!X509_ALGOR d2i_ASN1_SET_OF_X509_ALGOR;
alias SKM_ASN1_SET_OF_i2d!X509_ALGOR i2d_ASN1_SET_OF_X509_ALGOR;
alias SKM_ASN1_seq_pack!X509_ALGOR ASN1_seq_pack_X509_ALGOR;
alias SKM_ASN1_seq_unpack!X509_ALGOR ASN1_seq_unpack_X509_ALGOR;

alias SKM_ASN1_SET_OF_d2i!X509_ATTRIBUTE d2i_ASN1_SET_OF_X509_ATTRIBUTE;
alias SKM_ASN1_SET_OF_i2d!X509_ATTRIBUTE i2d_ASN1_SET_OF_X509_ATTRIBUTE;
alias SKM_ASN1_seq_pack!X509_ATTRIBUTE ASN1_seq_pack_X509_ATTRIBUTE;
alias SKM_ASN1_seq_unpack!X509_ATTRIBUTE ASN1_seq_unpack_X509_ATTRIBUTE;

alias SKM_ASN1_SET_OF_d2i!X509_CRL d2i_ASN1_SET_OF_X509_CRL;
alias SKM_ASN1_SET_OF_i2d!X509_CRL i2d_ASN1_SET_OF_X509_CRL;
alias SKM_ASN1_seq_pack!X509_CRL ASN1_seq_pack_X509_CRL;
alias SKM_ASN1_seq_unpack!X509_CRL ASN1_seq_unpack_X509_CRL;

alias SKM_ASN1_SET_OF_d2i!X509_EXTENSION d2i_ASN1_SET_OF_X509_EXTENSION;
alias SKM_ASN1_SET_OF_i2d!X509_EXTENSION i2d_ASN1_SET_OF_X509_EXTENSION;
alias SKM_ASN1_seq_pack!X509_EXTENSION ASN1_seq_pack_X509_EXTENSION;
alias SKM_ASN1_seq_unpack!X509_EXTENSION ASN1_seq_unpack_X509_EXTENSION;

alias SKM_ASN1_SET_OF_d2i!X509_NAME_ENTRY d2i_ASN1_SET_OF_X509_NAME_ENTRY;
alias SKM_ASN1_SET_OF_i2d!X509_NAME_ENTRY i2d_ASN1_SET_OF_X509_NAME_ENTRY;
alias SKM_ASN1_seq_pack!X509_NAME_ENTRY ASN1_seq_pack_X509_NAME_ENTRY;
alias SKM_ASN1_seq_unpack!X509_NAME_ENTRY ASN1_seq_unpack_X509_NAME_ENTRY;

alias SKM_ASN1_SET_OF_d2i!X509_REVOKED d2i_ASN1_SET_OF_X509_REVOKED;
alias SKM_ASN1_SET_OF_i2d!X509_REVOKED i2d_ASN1_SET_OF_X509_REVOKED;
alias SKM_ASN1_seq_pack!X509_REVOKED ASN1_seq_pack_X509_REVOKED;
alias SKM_ASN1_seq_unpack!X509_REVOKED ASN1_seq_unpack_X509_REVOKED;

// FIXME: See definition of SKM_PKCS12_decrypt_d2i.
//#define PKCS12_decrypt_d2i_PKCS12_SAFEBAG(algor, d2i_func, free_func, pass, passlen, oct, seq) \
//	SKM_PKCS12_decrypt_d2i(PKCS12_SAFEBAG, (algor), (d2i_func), (free_func), (pass), (passlen), (oct), (seq))
//
//#define PKCS12_decrypt_d2i_PKCS7(algor, d2i_func, free_func, pass, passlen, oct, seq) \
//	SKM_PKCS12_decrypt_d2i(PKCS7, (algor), (d2i_func), (free_func), (pass), (passlen), (oct), (seq))

/+ FIXME: Not yet ported.
#define lh_ADDED_OBJ_new() LHM_lh_new(ADDED_OBJ,added_obj)
#define lh_ADDED_OBJ_insert(lh,inst) LHM_lh_insert(ADDED_OBJ,lh,inst)
#define lh_ADDED_OBJ_retrieve(lh,inst) LHM_lh_retrieve(ADDED_OBJ,lh,inst)
#define lh_ADDED_OBJ_delete(lh,inst) LHM_lh_delete(ADDED_OBJ,lh,inst)
#define lh_ADDED_OBJ_doall(lh,fn) LHM_lh_doall(ADDED_OBJ,lh,fn)
#define lh_ADDED_OBJ_doall_arg(lh,fn,arg_type,arg) \
  LHM_lh_doall_arg(ADDED_OBJ,lh,fn,arg_type,arg)
#define lh_ADDED_OBJ_error(lh) LHM_lh_error(ADDED_OBJ,lh)
#define lh_ADDED_OBJ_num_items(lh) LHM_lh_num_items(ADDED_OBJ,lh)
#define lh_ADDED_OBJ_down_load(lh) LHM_lh_down_load(ADDED_OBJ,lh)
#define lh_ADDED_OBJ_node_stats_bio(lh,out) \
  LHM_lh_node_stats_bio(ADDED_OBJ,lh,out)
#define lh_ADDED_OBJ_node_usage_stats_bio(lh,out) \
  LHM_lh_node_usage_stats_bio(ADDED_OBJ,lh,out)
#define lh_ADDED_OBJ_stats_bio(lh,out) \
  LHM_lh_stats_bio(ADDED_OBJ,lh,out)
#define lh_ADDED_OBJ_free(lh) LHM_lh_free(ADDED_OBJ,lh)

#define lh_APP_INFO_new() LHM_lh_new(APP_INFO,app_info)
#define lh_APP_INFO_insert(lh,inst) LHM_lh_insert(APP_INFO,lh,inst)
#define lh_APP_INFO_retrieve(lh,inst) LHM_lh_retrieve(APP_INFO,lh,inst)
#define lh_APP_INFO_delete(lh,inst) LHM_lh_delete(APP_INFO,lh,inst)
#define lh_APP_INFO_doall(lh,fn) LHM_lh_doall(APP_INFO,lh,fn)
#define lh_APP_INFO_doall_arg(lh,fn,arg_type,arg) \
  LHM_lh_doall_arg(APP_INFO,lh,fn,arg_type,arg)
#define lh_APP_INFO_error(lh) LHM_lh_error(APP_INFO,lh)
#define lh_APP_INFO_num_items(lh) LHM_lh_num_items(APP_INFO,lh)
#define lh_APP_INFO_down_load(lh) LHM_lh_down_load(APP_INFO,lh)
#define lh_APP_INFO_node_stats_bio(lh,out) \
  LHM_lh_node_stats_bio(APP_INFO,lh,out)
#define lh_APP_INFO_node_usage_stats_bio(lh,out) \
  LHM_lh_node_usage_stats_bio(APP_INFO,lh,out)
#define lh_APP_INFO_stats_bio(lh,out) \
  LHM_lh_stats_bio(APP_INFO,lh,out)
#define lh_APP_INFO_free(lh) LHM_lh_free(APP_INFO,lh)

#define lh_CONF_VALUE_new() LHM_lh_new(CONF_VALUE,conf_value)
#define lh_CONF_VALUE_insert(lh,inst) LHM_lh_insert(CONF_VALUE,lh,inst)
#define lh_CONF_VALUE_retrieve(lh,inst) LHM_lh_retrieve(CONF_VALUE,lh,inst)
#define lh_CONF_VALUE_delete(lh,inst) LHM_lh_delete(CONF_VALUE,lh,inst)
#define lh_CONF_VALUE_doall(lh,fn) LHM_lh_doall(CONF_VALUE,lh,fn)
#define lh_CONF_VALUE_doall_arg(lh,fn,arg_type,arg) \
  LHM_lh_doall_arg(CONF_VALUE,lh,fn,arg_type,arg)
#define lh_CONF_VALUE_error(lh) LHM_lh_error(CONF_VALUE,lh)
#define lh_CONF_VALUE_num_items(lh) LHM_lh_num_items(CONF_VALUE,lh)
#define lh_CONF_VALUE_down_load(lh) LHM_lh_down_load(CONF_VALUE,lh)
#define lh_CONF_VALUE_node_stats_bio(lh,out) \
  LHM_lh_node_stats_bio(CONF_VALUE,lh,out)
#define lh_CONF_VALUE_node_usage_stats_bio(lh,out) \
  LHM_lh_node_usage_stats_bio(CONF_VALUE,lh,out)
#define lh_CONF_VALUE_stats_bio(lh,out) \
  LHM_lh_stats_bio(CONF_VALUE,lh,out)
#define lh_CONF_VALUE_free(lh) LHM_lh_free(CONF_VALUE,lh)

#define lh_ENGINE_PILE_new() LHM_lh_new(ENGINE_PILE,engine_pile)
#define lh_ENGINE_PILE_insert(lh,inst) LHM_lh_insert(ENGINE_PILE,lh,inst)
#define lh_ENGINE_PILE_retrieve(lh,inst) LHM_lh_retrieve(ENGINE_PILE,lh,inst)
#define lh_ENGINE_PILE_delete(lh,inst) LHM_lh_delete(ENGINE_PILE,lh,inst)
#define lh_ENGINE_PILE_doall(lh,fn) LHM_lh_doall(ENGINE_PILE,lh,fn)
#define lh_ENGINE_PILE_doall_arg(lh,fn,arg_type,arg) \
  LHM_lh_doall_arg(ENGINE_PILE,lh,fn,arg_type,arg)
#define lh_ENGINE_PILE_error(lh) LHM_lh_error(ENGINE_PILE,lh)
#define lh_ENGINE_PILE_num_items(lh) LHM_lh_num_items(ENGINE_PILE,lh)
#define lh_ENGINE_PILE_down_load(lh) LHM_lh_down_load(ENGINE_PILE,lh)
#define lh_ENGINE_PILE_node_stats_bio(lh,out) \
  LHM_lh_node_stats_bio(ENGINE_PILE,lh,out)
#define lh_ENGINE_PILE_node_usage_stats_bio(lh,out) \
  LHM_lh_node_usage_stats_bio(ENGINE_PILE,lh,out)
#define lh_ENGINE_PILE_stats_bio(lh,out) \
  LHM_lh_stats_bio(ENGINE_PILE,lh,out)
#define lh_ENGINE_PILE_free(lh) LHM_lh_free(ENGINE_PILE,lh)

#define lh_ERR_STATE_new() LHM_lh_new(ERR_STATE,err_state)
#define lh_ERR_STATE_insert(lh,inst) LHM_lh_insert(ERR_STATE,lh,inst)
#define lh_ERR_STATE_retrieve(lh,inst) LHM_lh_retrieve(ERR_STATE,lh,inst)
#define lh_ERR_STATE_delete(lh,inst) LHM_lh_delete(ERR_STATE,lh,inst)
#define lh_ERR_STATE_doall(lh,fn) LHM_lh_doall(ERR_STATE,lh,fn)
#define lh_ERR_STATE_doall_arg(lh,fn,arg_type,arg) \
  LHM_lh_doall_arg(ERR_STATE,lh,fn,arg_type,arg)
#define lh_ERR_STATE_error(lh) LHM_lh_error(ERR_STATE,lh)
#define lh_ERR_STATE_num_items(lh) LHM_lh_num_items(ERR_STATE,lh)
#define lh_ERR_STATE_down_load(lh) LHM_lh_down_load(ERR_STATE,lh)
#define lh_ERR_STATE_node_stats_bio(lh,out) \
  LHM_lh_node_stats_bio(ERR_STATE,lh,out)
#define lh_ERR_STATE_node_usage_stats_bio(lh,out) \
  LHM_lh_node_usage_stats_bio(ERR_STATE,lh,out)
#define lh_ERR_STATE_stats_bio(lh,out) \
  LHM_lh_stats_bio(ERR_STATE,lh,out)
#define lh_ERR_STATE_free(lh) LHM_lh_free(ERR_STATE,lh)

#define lh_ERR_STRING_DATA_new() LHM_lh_new(ERR_STRING_DATA,err_string_data)
#define lh_ERR_STRING_DATA_insert(lh,inst) LHM_lh_insert(ERR_STRING_DATA,lh,inst)
#define lh_ERR_STRING_DATA_retrieve(lh,inst) LHM_lh_retrieve(ERR_STRING_DATA,lh,inst)
#define lh_ERR_STRING_DATA_delete(lh,inst) LHM_lh_delete(ERR_STRING_DATA,lh,inst)
#define lh_ERR_STRING_DATA_doall(lh,fn) LHM_lh_doall(ERR_STRING_DATA,lh,fn)
#define lh_ERR_STRING_DATA_doall_arg(lh,fn,arg_type,arg) \
  LHM_lh_doall_arg(ERR_STRING_DATA,lh,fn,arg_type,arg)
#define lh_ERR_STRING_DATA_error(lh) LHM_lh_error(ERR_STRING_DATA,lh)
#define lh_ERR_STRING_DATA_num_items(lh) LHM_lh_num_items(ERR_STRING_DATA,lh)
#define lh_ERR_STRING_DATA_down_load(lh) LHM_lh_down_load(ERR_STRING_DATA,lh)
#define lh_ERR_STRING_DATA_node_stats_bio(lh,out) \
  LHM_lh_node_stats_bio(ERR_STRING_DATA,lh,out)
#define lh_ERR_STRING_DATA_node_usage_stats_bio(lh,out) \
  LHM_lh_node_usage_stats_bio(ERR_STRING_DATA,lh,out)
#define lh_ERR_STRING_DATA_stats_bio(lh,out) \
  LHM_lh_stats_bio(ERR_STRING_DATA,lh,out)
#define lh_ERR_STRING_DATA_free(lh) LHM_lh_free(ERR_STRING_DATA,lh)

#define lh_EX_CLASS_ITEM_new() LHM_lh_new(EX_CLASS_ITEM,ex_class_item)
#define lh_EX_CLASS_ITEM_insert(lh,inst) LHM_lh_insert(EX_CLASS_ITEM,lh,inst)
#define lh_EX_CLASS_ITEM_retrieve(lh,inst) LHM_lh_retrieve(EX_CLASS_ITEM,lh,inst)
#define lh_EX_CLASS_ITEM_delete(lh,inst) LHM_lh_delete(EX_CLASS_ITEM,lh,inst)
#define lh_EX_CLASS_ITEM_doall(lh,fn) LHM_lh_doall(EX_CLASS_ITEM,lh,fn)
#define lh_EX_CLASS_ITEM_doall_arg(lh,fn,arg_type,arg) \
  LHM_lh_doall_arg(EX_CLASS_ITEM,lh,fn,arg_type,arg)
#define lh_EX_CLASS_ITEM_error(lh) LHM_lh_error(EX_CLASS_ITEM,lh)
#define lh_EX_CLASS_ITEM_num_items(lh) LHM_lh_num_items(EX_CLASS_ITEM,lh)
#define lh_EX_CLASS_ITEM_down_load(lh) LHM_lh_down_load(EX_CLASS_ITEM,lh)
#define lh_EX_CLASS_ITEM_node_stats_bio(lh,out) \
  LHM_lh_node_stats_bio(EX_CLASS_ITEM,lh,out)
#define lh_EX_CLASS_ITEM_node_usage_stats_bio(lh,out) \
  LHM_lh_node_usage_stats_bio(EX_CLASS_ITEM,lh,out)
#define lh_EX_CLASS_ITEM_stats_bio(lh,out) \
  LHM_lh_stats_bio(EX_CLASS_ITEM,lh,out)
#define lh_EX_CLASS_ITEM_free(lh) LHM_lh_free(EX_CLASS_ITEM,lh)

#define lh_FUNCTION_new() LHM_lh_new(FUNCTION,function)
#define lh_FUNCTION_insert(lh,inst) LHM_lh_insert(FUNCTION,lh,inst)
#define lh_FUNCTION_retrieve(lh,inst) LHM_lh_retrieve(FUNCTION,lh,inst)
#define lh_FUNCTION_delete(lh,inst) LHM_lh_delete(FUNCTION,lh,inst)
#define lh_FUNCTION_doall(lh,fn) LHM_lh_doall(FUNCTION,lh,fn)
#define lh_FUNCTION_doall_arg(lh,fn,arg_type,arg) \
  LHM_lh_doall_arg(FUNCTION,lh,fn,arg_type,arg)
#define lh_FUNCTION_error(lh) LHM_lh_error(FUNCTION,lh)
#define lh_FUNCTION_num_items(lh) LHM_lh_num_items(FUNCTION,lh)
#define lh_FUNCTION_down_load(lh) LHM_lh_down_load(FUNCTION,lh)
#define lh_FUNCTION_node_stats_bio(lh,out) \
  LHM_lh_node_stats_bio(FUNCTION,lh,out)
#define lh_FUNCTION_node_usage_stats_bio(lh,out) \
  LHM_lh_node_usage_stats_bio(FUNCTION,lh,out)
#define lh_FUNCTION_stats_bio(lh,out) \
  LHM_lh_stats_bio(FUNCTION,lh,out)
#define lh_FUNCTION_free(lh) LHM_lh_free(FUNCTION,lh)

#define lh_MEM_new() LHM_lh_new(MEM,mem)
#define lh_MEM_insert(lh,inst) LHM_lh_insert(MEM,lh,inst)
#define lh_MEM_retrieve(lh,inst) LHM_lh_retrieve(MEM,lh,inst)
#define lh_MEM_delete(lh,inst) LHM_lh_delete(MEM,lh,inst)
#define lh_MEM_doall(lh,fn) LHM_lh_doall(MEM,lh,fn)
#define lh_MEM_doall_arg(lh,fn,arg_type,arg) \
  LHM_lh_doall_arg(MEM,lh,fn,arg_type,arg)
#define lh_MEM_error(lh) LHM_lh_error(MEM,lh)
#define lh_MEM_num_items(lh) LHM_lh_num_items(MEM,lh)
#define lh_MEM_down_load(lh) LHM_lh_down_load(MEM,lh)
#define lh_MEM_node_stats_bio(lh,out) \
  LHM_lh_node_stats_bio(MEM,lh,out)
#define lh_MEM_node_usage_stats_bio(lh,out) \
  LHM_lh_node_usage_stats_bio(MEM,lh,out)
#define lh_MEM_stats_bio(lh,out) \
  LHM_lh_stats_bio(MEM,lh,out)
#define lh_MEM_free(lh) LHM_lh_free(MEM,lh)

#define lh_OBJ_NAME_new() LHM_lh_new(OBJ_NAME,obj_name)
#define lh_OBJ_NAME_insert(lh,inst) LHM_lh_insert(OBJ_NAME,lh,inst)
#define lh_OBJ_NAME_retrieve(lh,inst) LHM_lh_retrieve(OBJ_NAME,lh,inst)
#define lh_OBJ_NAME_delete(lh,inst) LHM_lh_delete(OBJ_NAME,lh,inst)
#define lh_OBJ_NAME_doall(lh,fn) LHM_lh_doall(OBJ_NAME,lh,fn)
#define lh_OBJ_NAME_doall_arg(lh,fn,arg_type,arg) \
  LHM_lh_doall_arg(OBJ_NAME,lh,fn,arg_type,arg)
#define lh_OBJ_NAME_error(lh) LHM_lh_error(OBJ_NAME,lh)
#define lh_OBJ_NAME_num_items(lh) LHM_lh_num_items(OBJ_NAME,lh)
#define lh_OBJ_NAME_down_load(lh) LHM_lh_down_load(OBJ_NAME,lh)
#define lh_OBJ_NAME_node_stats_bio(lh,out) \
  LHM_lh_node_stats_bio(OBJ_NAME,lh,out)
#define lh_OBJ_NAME_node_usage_stats_bio(lh,out) \
  LHM_lh_node_usage_stats_bio(OBJ_NAME,lh,out)
#define lh_OBJ_NAME_stats_bio(lh,out) \
  LHM_lh_stats_bio(OBJ_NAME,lh,out)
#define lh_OBJ_NAME_free(lh) LHM_lh_free(OBJ_NAME,lh)

#define lh_OPENSSL_CSTRING_new() LHM_lh_new(OPENSSL_CSTRING,openssl_cstring)
#define lh_OPENSSL_CSTRING_insert(lh,inst) LHM_lh_insert(OPENSSL_CSTRING,lh,inst)
#define lh_OPENSSL_CSTRING_retrieve(lh,inst) LHM_lh_retrieve(OPENSSL_CSTRING,lh,inst)
#define lh_OPENSSL_CSTRING_delete(lh,inst) LHM_lh_delete(OPENSSL_CSTRING,lh,inst)
#define lh_OPENSSL_CSTRING_doall(lh,fn) LHM_lh_doall(OPENSSL_CSTRING,lh,fn)
#define lh_OPENSSL_CSTRING_doall_arg(lh,fn,arg_type,arg) \
  LHM_lh_doall_arg(OPENSSL_CSTRING,lh,fn,arg_type,arg)
#define lh_OPENSSL_CSTRING_error(lh) LHM_lh_error(OPENSSL_CSTRING,lh)
#define lh_OPENSSL_CSTRING_num_items(lh) LHM_lh_num_items(OPENSSL_CSTRING,lh)
#define lh_OPENSSL_CSTRING_down_load(lh) LHM_lh_down_load(OPENSSL_CSTRING,lh)
#define lh_OPENSSL_CSTRING_node_stats_bio(lh,out) \
  LHM_lh_node_stats_bio(OPENSSL_CSTRING,lh,out)
#define lh_OPENSSL_CSTRING_node_usage_stats_bio(lh,out) \
  LHM_lh_node_usage_stats_bio(OPENSSL_CSTRING,lh,out)
#define lh_OPENSSL_CSTRING_stats_bio(lh,out) \
  LHM_lh_stats_bio(OPENSSL_CSTRING,lh,out)
#define lh_OPENSSL_CSTRING_free(lh) LHM_lh_free(OPENSSL_CSTRING,lh)

#define lh_OPENSSL_STRING_new() LHM_lh_new(OPENSSL_STRING,openssl_string)
#define lh_OPENSSL_STRING_insert(lh,inst) LHM_lh_insert(OPENSSL_STRING,lh,inst)
#define lh_OPENSSL_STRING_retrieve(lh,inst) LHM_lh_retrieve(OPENSSL_STRING,lh,inst)
#define lh_OPENSSL_STRING_delete(lh,inst) LHM_lh_delete(OPENSSL_STRING,lh,inst)
#define lh_OPENSSL_STRING_doall(lh,fn) LHM_lh_doall(OPENSSL_STRING,lh,fn)
#define lh_OPENSSL_STRING_doall_arg(lh,fn,arg_type,arg) \
  LHM_lh_doall_arg(OPENSSL_STRING,lh,fn,arg_type,arg)
#define lh_OPENSSL_STRING_error(lh) LHM_lh_error(OPENSSL_STRING,lh)
#define lh_OPENSSL_STRING_num_items(lh) LHM_lh_num_items(OPENSSL_STRING,lh)
#define lh_OPENSSL_STRING_down_load(lh) LHM_lh_down_load(OPENSSL_STRING,lh)
#define lh_OPENSSL_STRING_node_stats_bio(lh,out) \
  LHM_lh_node_stats_bio(OPENSSL_STRING,lh,out)
#define lh_OPENSSL_STRING_node_usage_stats_bio(lh,out) \
  LHM_lh_node_usage_stats_bio(OPENSSL_STRING,lh,out)
#define lh_OPENSSL_STRING_stats_bio(lh,out) \
  LHM_lh_stats_bio(OPENSSL_STRING,lh,out)
#define lh_OPENSSL_STRING_free(lh) LHM_lh_free(OPENSSL_STRING,lh)

#define lh_SSL_SESSION_new() LHM_lh_new(SSL_SESSION,ssl_session)
#define lh_SSL_SESSION_insert(lh,inst) LHM_lh_insert(SSL_SESSION,lh,inst)
#define lh_SSL_SESSION_retrieve(lh,inst) LHM_lh_retrieve(SSL_SESSION,lh,inst)
#define lh_SSL_SESSION_delete(lh,inst) LHM_lh_delete(SSL_SESSION,lh,inst)
#define lh_SSL_SESSION_doall(lh,fn) LHM_lh_doall(SSL_SESSION,lh,fn)
#define lh_SSL_SESSION_doall_arg(lh,fn,arg_type,arg) \
  LHM_lh_doall_arg(SSL_SESSION,lh,fn,arg_type,arg)
#define lh_SSL_SESSION_error(lh) LHM_lh_error(SSL_SESSION,lh)
#define lh_SSL_SESSION_num_items(lh) LHM_lh_num_items(SSL_SESSION,lh)
#define lh_SSL_SESSION_down_load(lh) LHM_lh_down_load(SSL_SESSION,lh)
#define lh_SSL_SESSION_node_stats_bio(lh,out) \
  LHM_lh_node_stats_bio(SSL_SESSION,lh,out)
#define lh_SSL_SESSION_node_usage_stats_bio(lh,out) \
  LHM_lh_node_usage_stats_bio(SSL_SESSION,lh,out)
#define lh_SSL_SESSION_stats_bio(lh,out) \
  LHM_lh_stats_bio(SSL_SESSION,lh,out)
#define lh_SSL_SESSION_free(lh) LHM_lh_free(SSL_SESSION,lh)
+/
/* End of util/mkstack.pl block, you may now edit :-) */

import deimos.openssl.crypto;

alias SKM_sk_new!CRYPTO_BUFFER sk_CRYPTO_BUFFER_new;
alias SKM_sk_new_null!CRYPTO_BUFFER sk_CRYPTO_BUFFER_new_null;
alias SKM_sk_push!CRYPTO_BUFFER sk_CRYPTO_BUFFER_push;
alias SKM_sk_find!CRYPTO_BUFFER sk_CRYPTO_BUFFER_find;
alias SKM_sk_value!CRYPTO_BUFFER sk_CRYPTO_BUFFER_value;
alias SKM_sk_num!CRYPTO_BUFFER sk_CRYPTO_BUFFER_num;
// alias SKM_sk_pop_free!CRYPTO_BUFFER sk_CRYPTO_BUFFER_pop_free;
// alias SKM_sk_insert!CRYPTO_BUFFER sk_CRYPTO_BUFFER_insert;
// alias SKM_sk_free!CRYPTO_BUFFER sk_CRYPTO_BUFFER_free;
// alias SKM_sk_set!CRYPTO_BUFFER sk_CRYPTO_BUFFER_set;
// alias SKM_sk_zero!CRYPTO_BUFFER sk_CRYPTO_BUFFER_zero;
// alias SKM_sk_unshift!CRYPTO_BUFFER sk_CRYPTO_BUFFER_unshift;
// alias SKM_sk_find_ex!CRYPTO_BUFFER sk_CRYPTO_BUFFER_find_ex;
// alias SKM_sk_delete!CRYPTO_BUFFER sk_CRYPTO_BUFFER_delete;
// alias SKM_sk_delete_ptr!CRYPTO_BUFFER sk_CRYPTO_BUFFER_delete_ptr;
// alias SKM_sk_set_cmp_func!CRYPTO_BUFFER sk_CRYPTO_BUFFER_set_cmp_func;
// alias SKM_sk_dup!CRYPTO_BUFFER sk_CRYPTO_BUFFER_dup;
// alias SKM_sk_shift!CRYPTO_BUFFER sk_CRYPTO_BUFFER_shift;
// alias SKM_sk_pop!CRYPTO_BUFFER sk_CRYPTO_BUFFER_pop;
// alias SKM_sk_sort!CRYPTO_BUFFER sk_CRYPTO_BUFFER_sort;
// alias SKM_sk_is_sorted!CRYPTO_BUFFER sk_CRYPTO_BUFFER_is_sorted;