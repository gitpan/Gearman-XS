/* Gearman Perl front end
 * Copyright (C) 2009 Dennis Schoen
 * All rights reserved.
 *
 * This library is free software; you can redistribute it and/or modify
 * it under the same terms as Perl itself, either Perl version 5.8.9 or,
 * at your option, any later version of Perl 5 you may have available.
 */

#include "gearman_xs.h"

SV *_bless(const char *class, void *obj) {
  SV * ret = newSViv(0);
  XS_STRUCT2OBJ(ret, class, obj);
  return ret;
}

void _perl_free(void *ptr, void *arg)
{
  Safefree(ptr);
}

void *_perl_malloc(size_t size, void *arg)
{
  return safemalloc(size);
}

// We need these declarations with "C" linkage

#ifdef __cplusplus
extern "C" {
#endif
  XS(boot_Gearman__XS__Const);
  XS(boot_Gearman__XS__Worker);
  XS(boot_Gearman__XS__Task);
  XS(boot_Gearman__XS__Client);
  XS(boot_Gearman__XS__Job);
  XS(boot_Gearman__XS__Server);
#ifdef __cplusplus
}
#endif

MODULE = Gearman::XS    PACKAGE = Gearman::XS

PROTOTYPES: ENABLE

BOOT:
  /* call other *.xs modules */
  CALL_BOOT(boot_Gearman__XS__Const);
  CALL_BOOT(boot_Gearman__XS__Worker);
  CALL_BOOT(boot_Gearman__XS__Task);
  CALL_BOOT(boot_Gearman__XS__Client);
  CALL_BOOT(boot_Gearman__XS__Job);
  CALL_BOOT(boot_Gearman__XS__Server);