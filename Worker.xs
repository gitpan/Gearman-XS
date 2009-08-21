/* Gearman Perl front end
 * Copyright (C) 2009 Dennis Schoen
 * All rights reserved.
 *
 * This library is free software; you can redistribute it and/or modify
 * it under the same terms as Perl itself, either Perl version 5.8.9 or,
 * at your option, any later version of Perl 5 you may have available.
 */

#include "gearman_xs.h"

typedef struct gearman_worker_st gearman_xs_worker;

/* worker cb_arg to pass our actual perl function */
typedef struct
{
  SV * func;
  const char *cb_arg;
} gearman_worker_cb;


SV* _create_worker() {
  gearman_worker_st *self;

  self= gearman_worker_create(NULL);
  if (self == NULL) {
      Perl_croak(aTHX_ "gearman_worker_create:NULL\n");
  }

  gearman_worker_set_workload_free(self, _perl_free, NULL);
  gearman_worker_set_workload_malloc(self, _perl_malloc, NULL);

  return _bless("Gearman::XS::Worker", self);
}

/* wrapper function to call our actual perl function,
   passed in through cb_arg */
void *_perl_worker_function_callback(gearman_job_st *job,
                                     void *cb_arg,
                                     size_t *result_size,
                                     gearman_return_t *ret_ptr)
{
  gearman_worker_cb *worker_cb;
  int count;
  char *result= NULL;
  SV * result_sv;

  dSP;

  ENTER;
  SAVETMPS;

  worker_cb= (gearman_worker_cb *)cb_arg;

  PUSHMARK(SP);
  XPUSHs(_bless("Gearman::XS::Job", job));
  if (worker_cb->cb_arg != NULL)
  {
    XPUSHs(sv_2mortal(newSVpv(worker_cb->cb_arg, strlen(worker_cb->cb_arg))));
  }
  PUTBACK;

  count= call_sv(worker_cb->func, G_EVAL|G_SCALAR);

  SPAGAIN;

  if (SvTRUE(ERRSV))
  {
    STRLEN n_a;
    fprintf(stderr, "Job: '%s' died with: %s",
            gearman_job_function_name(job), SvPV(ERRSV, n_a));
    *ret_ptr= GEARMAN_WORK_FAIL;
    POPs;
  }
  else
  {
    if (count != 1)
      croak("Invalid number of return values.\n");

    result_sv= POPs;
    if (SvOK(result_sv))
    {
      result=savesvpv(result_sv);
      *result_size= SvCUR(result_sv);
    }

    *ret_ptr= GEARMAN_SUCCESS;
  }

  PUTBACK;
  FREETMPS;
  LEAVE;

  return result;
}

MODULE = Gearman::XS::Worker    PACKAGE = Gearman::XS::Worker

PROTOTYPES: ENABLE

SV*
Gearman::XS::WORKER::new()
  CODE:
    PERL_UNUSED_VAR(CLASS);
    RETVAL = _create_worker();
  OUTPUT:
    RETVAL

gearman_return_t
add_server(self, ...)
    gearman_xs_worker *self
  PREINIT:
    const char *host= NULL;
    in_port_t port= 0;
  CODE:
    if( items > 1 )
    {
      host= (char *)SvPV(ST(1), PL_na);

      if ( items > 2)
        port= (in_port_t)SvIV(ST(2));
    }
    RETVAL= gearman_worker_add_server(self, host, port);
  OUTPUT:
    RETVAL

gearman_return_t
add_servers(self, servers)
    gearman_xs_worker *self
    const char *servers
  CODE:
    RETVAL= gearman_worker_add_servers(self, servers);
  OUTPUT:
    RETVAL

gearman_return_t
echo(self, workload)
    gearman_xs_worker *self
    SV * workload
  CODE:
    RETVAL= gearman_worker_echo(self, SvPV_nolen(workload), SvCUR(workload));
  OUTPUT:
    RETVAL

gearman_return_t
add_function(self, function_name, timeout, worker_fn, fn_arg)
    gearman_xs_worker *self
    const char *function_name
    uint32_t timeout
    SV * worker_fn
    const char *fn_arg
  INIT:
    gearman_worker_cb *worker_cb;
  CODE:
    Newxz(worker_cb, 1, gearman_worker_cb);
    worker_cb->func= newSVsv(worker_fn);
    worker_cb->cb_arg= fn_arg;
    RETVAL= gearman_worker_add_function(self, function_name, timeout,
                                        _perl_worker_function_callback,
                                        (void *)worker_cb );
  OUTPUT:
    RETVAL

gearman_return_t
work(self)
    gearman_xs_worker *self
  CODE:
    RETVAL= gearman_worker_work(self);
  OUTPUT:
    RETVAL

const char *
error(self)
    gearman_xs_worker *self
  CODE:
    RETVAL= gearman_worker_error(self);
  OUTPUT:
    RETVAL

void
set_options(self, options, data)
    gearman_xs_worker *self
    gearman_worker_options_t options
    uint32_t data
  CODE:
    gearman_worker_set_options(self, options, data);

void
grab_job(self)
    gearman_xs_worker *self
  PREINIT:
    gearman_return_t ret;
  PPCODE:
    (void)gearman_worker_grab_job(self, &(self->work_job), &ret);
    XPUSHs(sv_2mortal(newSViv(ret)));
    if (ret == GEARMAN_SUCCESS)
      XPUSHs(_bless("Gearman::XS::Job", &(self->work_job)));
    else
      XPUSHs(&PL_sv_undef);

void
DESTROY(self)
    gearman_xs_worker *self
  CODE:
    gearman_worker_free(self);