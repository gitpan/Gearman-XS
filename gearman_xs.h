#ifndef __GEARMAN_XS_H__
#define __GEARMAN_XS_H__

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#define NEED_newCONSTSUB
#define NEED_sv_2pv_flags
#include "ppport.h"

#include <libgearman/gearman.h>

#define XS_STATE(type, x) (INT2PTR(type, SvROK(x) ? SvIV(SvRV(x)) : SvIV(x)))

#define XS_STRUCT2OBJ(sv, class, obj) if (obj == NULL) {  sv_setsv(sv, &PL_sv_undef); } else {  sv_setref_pv(sv, class, (void *) obj);  }

static void
call_XS ( pTHX_ void (*subaddr) (pTHX_ CV *), CV * cv, SV ** mark )
{
  dSP;
  PUSHMARK (mark);
  (*subaddr) (aTHX_ cv);
  PUTBACK;
}

#define CALL_BOOT(name)	call_XS (aTHX_ name, cv, mark)

SV *_bless(const char *class, void *obj);
void _perl_free(void *ptr, void *arg);
void *_perl_malloc(size_t size, void *arg);

#endif /* __GEARMAN_XS_H__ */
