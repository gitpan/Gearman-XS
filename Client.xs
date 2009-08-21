/* Gearman Perl front end
 * Copyright (C) 2009 Dennis Schoen
 * All rights reserved.
 *
 * This library is free software; you can redistribute it and/or modify
 * it under the same terms as Perl itself, either Perl version 5.8.9 or,
 * at your option, any later version of Perl 5 you may have available.
 */

#include "gearman_xs.h"

typedef enum {
  TASK_FN_ARG_CREATED= (1 << 0)
} gearman_task_fn_arg_st_flags;

typedef struct gearman_xs_client {
  gearman_client_st *client;
  /* used for keeping track of task interface callbacks */
  SV * created_fn;
  SV * data_fn;
  SV * complete_fn;
  SV * fail_fn;
  SV * status_fn;
  SV * warning_fn;
} gearman_xs_client;

/* client task fn_arg */
typedef struct
{
  gearman_task_fn_arg_st_flags flags;
  gearman_client_st *client;
  const char *workload;
} gearman_task_fn_arg_st;


/* fn_arg free function to free() the workload */
void _perl_task_free(gearman_task_st *task, void *fn_arg)
{
  gearman_task_fn_arg_st *fn_arg_st= (gearman_task_fn_arg_st *)fn_arg;
  if (fn_arg_st->flags == TASK_FN_ARG_CREATED)
  {
    Safefree(fn_arg_st->workload);
    Safefree(fn_arg_st);
  }
}

static gearman_return_t _perl_task_callback(SV * fn, gearman_task_st *task)
{
  int count;
  gearman_return_t ret;

  dSP;

  ENTER;
  SAVETMPS;

  PUSHMARK(SP);
  XPUSHs(_bless("Gearman::XS::Task", task));
  PUTBACK;

  count= call_sv(fn, G_SCALAR);
  if (count != 1)
    croak("Invalid number of return values.\n");

  SPAGAIN;

  ret= POPi;

  PUTBACK;
  FREETMPS;
  LEAVE;

  return ret;
}

static gearman_return_t _perl_task_complete_fn(gearman_task_st *task)
{
  gearman_task_fn_arg_st *fn_arg_st;
  gearman_xs_client *self;

  fn_arg_st= (gearman_task_fn_arg_st *)gearman_task_fn_arg(task);
  self= (gearman_xs_client *)gearman_client_data(fn_arg_st->client);

  return _perl_task_callback(self->complete_fn, task);
}

static gearman_return_t _perl_task_fail_fn(gearman_task_st *task)
{
  gearman_task_fn_arg_st *fn_arg_st;
  gearman_xs_client *self;

  fn_arg_st= (gearman_task_fn_arg_st *)gearman_task_fn_arg(task);
  self= (gearman_xs_client *)gearman_client_data(fn_arg_st->client);

  return _perl_task_callback(self->fail_fn, task);
}

static gearman_return_t _perl_task_status_fn(gearman_task_st *task)
{
  gearman_task_fn_arg_st *fn_arg_st;
  gearman_xs_client *self;

  fn_arg_st= (gearman_task_fn_arg_st *)gearman_task_fn_arg(task);
  self= (gearman_xs_client *)gearman_client_data(fn_arg_st->client);

  return _perl_task_callback(self->status_fn, task);
}

static gearman_return_t _perl_task_created_fn(gearman_task_st *task)
{
  gearman_task_fn_arg_st *fn_arg_st;
  gearman_xs_client *self;

  fn_arg_st= (gearman_task_fn_arg_st *)gearman_task_fn_arg(task);
  self= (gearman_xs_client *)gearman_client_data(fn_arg_st->client);

  return _perl_task_callback(self->created_fn, task);
}

static gearman_return_t _perl_task_data_fn(gearman_task_st *task)
{
  gearman_task_fn_arg_st *fn_arg_st;
  gearman_xs_client *self;

  fn_arg_st= (gearman_task_fn_arg_st *)gearman_task_fn_arg(task);
  self= (gearman_xs_client *)gearman_client_data(fn_arg_st->client);

  return _perl_task_callback(self->data_fn, task);
}

static gearman_return_t _perl_task_warning_fn(gearman_task_st *task)
{
  gearman_task_fn_arg_st *fn_arg_st;
  gearman_xs_client *self;

  fn_arg_st= (gearman_task_fn_arg_st *)gearman_task_fn_arg(task);
  self= (gearman_xs_client *)gearman_client_data(fn_arg_st->client);

  return _perl_task_callback(self->warning_fn, task);
}

SV* _create_client() {
  gearman_xs_client *self;

  Newxz(self, 1, gearman_xs_client);
  self->client= gearman_client_create(NULL);
  if (self->client == NULL) {
      Perl_croak(aTHX_ "gearman_client_create:NULL\n");
  }

  gearman_client_set_data(self->client, self);
  gearman_client_set_options(self->client, GEARMAN_CLIENT_FREE_TASKS, 1);
  gearman_client_set_workload_malloc(self->client, _perl_malloc, NULL);
  gearman_client_set_workload_free(self->client, _perl_free, NULL);
  gearman_client_set_task_fn_arg_free(self->client, _perl_task_free);

  return _bless("Gearman::XS::Client", self);
}

MODULE = Gearman::XS::Client    PACKAGE = Gearman::XS::Client

PROTOTYPES: ENABLE

SV*
Gearman::XS::Client::new()
  CODE:
    PERL_UNUSED_VAR(CLASS);
    RETVAL = _create_client();
  OUTPUT:
    RETVAL

gearman_return_t
add_server(self, ...)
    gearman_xs_client *self
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
    RETVAL= gearman_client_add_server(self->client, host, port);
  OUTPUT:
    RETVAL

gearman_return_t
add_servers(self, servers)
    gearman_xs_client *self
    const char *servers
  CODE:
    RETVAL= gearman_client_add_servers(self->client, servers);
  OUTPUT:
    RETVAL

gearman_return_t
echo(self, workload)
    gearman_xs_client *self
    SV * workload
  CODE:
    RETVAL= gearman_client_echo(self->client, SvPV_nolen(workload), SvCUR(workload));
  OUTPUT:
    RETVAL

void
do(self, function_name, workload, ...)
    gearman_xs_client *self
    const char *function_name
    SV * workload
  PREINIT:
    const char *unique= NULL;
    gearman_return_t ret;
    void *result;
    size_t result_size;
  PPCODE:
    if (items > 3)
      unique= (char *)SvPV(ST(3), PL_na);
    result= gearman_client_do(self->client, function_name, unique, SvPV_nolen(workload),
                              SvCUR(workload), &result_size, &ret);
    XPUSHs(sv_2mortal(newSViv(ret)));
    if ((ret == GEARMAN_WORK_DATA) || (ret == GEARMAN_SUCCESS) || (ret == GEARMAN_WORK_WARNING))
    {
      XPUSHs(sv_2mortal(newSVpvn(result, result_size)));
      Safefree(result);
    }
    else
      XPUSHs(&PL_sv_undef);

void
do_high(self, function_name, workload, ...)
    gearman_xs_client *self
    const char *function_name
    SV * workload
  PREINIT:
    const char *unique= NULL;
    gearman_return_t ret;
    char *result;
    size_t result_size;
  PPCODE:
    if (items > 3)
      unique= (char *)SvPV(ST(3), PL_na);
    result= (char *)gearman_client_do_high(self->client, function_name, unique,
                                           SvPV_nolen(workload),
                                           SvCUR(workload),
                                           &result_size, &ret);
    XPUSHs(sv_2mortal(newSViv(ret)));
    if ((ret == GEARMAN_WORK_DATA) || (ret == GEARMAN_SUCCESS) || (ret == GEARMAN_WORK_WARNING))
    {
      XPUSHs(sv_2mortal(newSVpvn(result, result_size)));
      Safefree(result);
    }
    else
      XPUSHs(&PL_sv_undef);

void
do_low(self, function_name, workload, ...)
    gearman_xs_client *self
    const char *function_name
    SV * workload
  PREINIT:
    const char *unique= NULL;
    gearman_return_t ret;
    char *result;
    size_t result_size;
  PPCODE:
    if (items > 3)
      unique= (char *)SvPV(ST(3), PL_na);
    result= (char *)gearman_client_do_low(self->client, function_name, unique,
                                          SvPV_nolen(workload),
                                          SvCUR(workload),
                                          &result_size, &ret);
    XPUSHs(sv_2mortal(newSViv(ret)));
    if ((ret == GEARMAN_WORK_DATA) || (ret == GEARMAN_SUCCESS) || (ret == GEARMAN_WORK_WARNING))
    {
      XPUSHs(sv_2mortal(newSVpvn(result, result_size)));
      Safefree(result);
    }
    else
      XPUSHs(&PL_sv_undef);

void
do_background(self, function_name, workload, ...)
    gearman_xs_client *self
    const char *function_name
    SV * workload
  PREINIT:
    char *job_handle;
    const char *unique= NULL;
    gearman_return_t ret;
  PPCODE:
    if (items > 3)
      unique= (char *)SvPV(ST(3), PL_na);
    job_handle= safemalloc(GEARMAN_JOB_HANDLE_SIZE);
    ret= gearman_client_do_background(self->client, function_name, unique,
                                      SvPV_nolen(workload), SvCUR(workload),
                                      job_handle);
    XPUSHs(sv_2mortal(newSViv(ret)));
    if (ret != GEARMAN_SUCCESS)
    {
      Safefree(job_handle);
      XPUSHs(&PL_sv_undef);
    }
    else
      XPUSHs(sv_2mortal(newSVpvn(job_handle, strlen(job_handle))));

void
do_high_background(self, function_name, workload, ...)
    gearman_xs_client *self
    const char *function_name
    SV * workload
  PREINIT:
    char *job_handle;
    const char *unique= NULL;
    gearman_return_t ret;
  PPCODE:
    if (items > 3)
      unique= (char *)SvPV(ST(3), PL_na);
    job_handle= safemalloc(GEARMAN_JOB_HANDLE_SIZE);
    ret= gearman_client_do_high_background(self->client, function_name, unique,
                                           SvPV_nolen(workload),
                                           SvCUR(workload), job_handle);
    XPUSHs(sv_2mortal(newSViv(ret)));
    if (ret != GEARMAN_SUCCESS)
    {
      Safefree(job_handle);
      XPUSHs(&PL_sv_undef);
    }
    else
      XPUSHs(sv_2mortal(newSVpvn(job_handle, (size_t)strlen(job_handle))));

void
do_low_background(self, function_name, workload, ...)
    gearman_xs_client *self
    const char *function_name
    SV * workload
  PREINIT:
    char *job_handle;
    const char *unique= NULL;
    gearman_return_t ret;
  PPCODE:
    if (items > 3)
      unique= (char *)SvPV(ST(3), PL_na);
    job_handle= safemalloc(GEARMAN_JOB_HANDLE_SIZE);
    ret= gearman_client_do_low_background(self->client, function_name, unique,
                                          SvPV_nolen(workload),
                                          SvCUR(workload), job_handle);
    XPUSHs(sv_2mortal(newSViv(ret)));
    if (ret != GEARMAN_SUCCESS)
    {
      Safefree(job_handle);
      XPUSHs(&PL_sv_undef);
    }
    else
      XPUSHs(sv_2mortal(newSVpvn(job_handle, strlen(job_handle))));

void
add_task(self, function_name, workload, ...)
    gearman_xs_client *self
    const char *function_name
    SV * workload
  PREINIT:
    gearman_task_st *task;
    const char *unique= NULL;
    gearman_return_t ret;
    gearman_task_fn_arg_st *fn_arg;
    const char *w;
  PPCODE:
    if (items > 3)
      unique= (char *)SvPV(ST(3), PL_na);
    w= savesvpv(workload);
    Newxz(fn_arg, 1, gearman_task_fn_arg_st);
    fn_arg->flags= TASK_FN_ARG_CREATED;
    fn_arg->client= self->client;
    fn_arg->workload= w;
    task= gearman_client_add_task(self->client, NULL, fn_arg, function_name, unique, w,
                                  SvCUR(workload), &ret);

    XPUSHs(sv_2mortal(newSViv(ret)));
    XPUSHs(_bless("Gearman::XS::Task", task));

void
add_task_high(self, function_name, workload, ...)
    gearman_xs_client *self
    const char *function_name
    SV * workload
  PREINIT:
    gearman_task_st *task;
    const char *unique= NULL;
    gearman_return_t ret;
    gearman_task_fn_arg_st *fn_arg;
    const char *w;
  PPCODE:
    if (items > 3)
      unique= (char *)SvPV(ST(3), PL_na);
    w= savesvpv(workload);
    Newxz(fn_arg, 1, gearman_task_fn_arg_st);
    fn_arg->flags= TASK_FN_ARG_CREATED;
    fn_arg->client= self->client;
    fn_arg->workload= w;
    task= gearman_client_add_task_high(self->client, NULL, fn_arg, function_name,
                                       unique, w, SvCUR(workload), &ret);

    XPUSHs(sv_2mortal(newSViv(ret)));
    XPUSHs(_bless("Gearman::XS::Task", task));

void
add_task_low(self, function_name, workload, ...)
    gearman_xs_client *self
    const char *function_name
    SV * workload
  PREINIT:
    gearman_task_st *task;
    const char *unique= NULL;
    gearman_return_t ret;
    gearman_task_fn_arg_st *fn_arg;
    const char *w;
  PPCODE:
    if (items > 3)
      unique= (char *)SvPV(ST(3), PL_na);
    w= savesvpv(workload);
    Newxz(fn_arg, 1, gearman_task_fn_arg_st);
    fn_arg->flags= TASK_FN_ARG_CREATED;
    fn_arg->client= self->client;
    fn_arg->workload= w;
    task= gearman_client_add_task_low(self->client, NULL, fn_arg, function_name,
                                      unique, w, SvCUR(workload), &ret);

    XPUSHs(sv_2mortal(newSViv(ret)));
    XPUSHs(_bless("Gearman::XS::Task", task));

void
add_task_background(self, function_name, workload, ...)
    gearman_xs_client *self
    const char *function_name
    SV * workload
  PREINIT:
    gearman_task_st *task;
    const char *unique= NULL;
    gearman_return_t ret;
    gearman_task_fn_arg_st *fn_arg;
    const char *w;
  PPCODE:
    if (items > 3)
      unique= (char *)SvPV(ST(3), PL_na);
    w= savesvpv(workload);
    Newxz(fn_arg, 1, gearman_task_fn_arg_st);
    fn_arg->flags= TASK_FN_ARG_CREATED;
    fn_arg->client= self->client;
    fn_arg->workload= w;
    task= gearman_client_add_task_background(self->client, NULL, fn_arg, function_name,
                                             unique, w, SvCUR(workload), &ret);

    XPUSHs(sv_2mortal(newSViv(ret)));
    XPUSHs(_bless("Gearman::XS::Task", task));

void
add_task_high_background(self, function_name, workload, ...)
    gearman_xs_client *self
    const char *function_name
    SV * workload
  PREINIT:
    gearman_task_st *task;
    const char *unique= NULL;
    gearman_return_t ret;
    gearman_task_fn_arg_st *fn_arg;
    const char *w;
  PPCODE:
    if (items > 3)
      unique= (char *)SvPV(ST(3), PL_na);
    w= savesvpv(workload);
    Newxz(fn_arg, 1, gearman_task_fn_arg_st);
    fn_arg->flags= TASK_FN_ARG_CREATED;
    fn_arg->client= self->client;
    fn_arg->workload= w;
    task= gearman_client_add_task_high_background(self->client, NULL, fn_arg,
                                                  function_name, unique, w,
                                                  SvCUR(workload), &ret);

    XPUSHs(sv_2mortal(newSViv(ret)));
    XPUSHs(_bless("Gearman::XS::Task", task));

void
add_task_low_background(self, function_name, workload, ...)
    gearman_xs_client *self
    const char *function_name
    SV * workload
  PREINIT:
    gearman_task_st *task;
    const char *unique= NULL;
    gearman_return_t ret;
    gearman_task_fn_arg_st *fn_arg;
    const char *w;
  PPCODE:
    if (items > 3)
      unique= (char *)SvPV(ST(3), PL_na);
    w= savesvpv(workload);
    Newxz(fn_arg, 1, gearman_task_fn_arg_st);
    fn_arg->flags= TASK_FN_ARG_CREATED;
    fn_arg->client= self->client;
    fn_arg->workload= w;
    task= gearman_client_add_task_low_background(self->client, NULL, fn_arg,
                                                 function_name, unique, w,
                                                 SvCUR(workload), &ret);

    XPUSHs(sv_2mortal(newSViv(ret)));
    XPUSHs(_bless("Gearman::XS::Task", task));

gearman_return_t
run_tasks(self)
    gearman_xs_client *self
  CODE:
    RETVAL= gearman_client_run_tasks(self->client);
  OUTPUT:
    RETVAL

void
set_created_fn(self, fn)
    gearman_xs_client *self
    SV * fn
  CODE:
    self->created_fn= newSVsv(fn);
    gearman_client_set_created_fn(self->client, _perl_task_created_fn);

void
set_data_fn(self, fn)
    gearman_xs_client *self
    SV * fn
  CODE:
    self->data_fn= newSVsv(fn);
    gearman_client_set_data_fn(self->client, _perl_task_data_fn);

void
set_complete_fn(self, fn)
    gearman_xs_client *self
    SV * fn
  CODE:
    self->complete_fn= newSVsv(fn);
    gearman_client_set_complete_fn(self->client, _perl_task_complete_fn);

void
set_fail_fn(self, fn)
    gearman_xs_client *self
    SV * fn
  CODE:
    self->fail_fn= newSVsv(fn);
    gearman_client_set_fail_fn(self->client, _perl_task_fail_fn);

void
set_status_fn(self, fn)
    gearman_xs_client *self
    SV * fn
  CODE:
    self->status_fn= newSVsv(fn);
    gearman_client_set_status_fn(self->client, _perl_task_status_fn);

void
set_warning_fn(self, fn)
    gearman_xs_client *self
    SV * fn
  CODE:
    self->warning_fn= newSVsv(fn);
    gearman_client_set_warning_fn(self->client, _perl_task_warning_fn);

const char *
error(self)
    gearman_xs_client *self
  CODE:
    RETVAL= gearman_client_error(self->client);
  OUTPUT:
    RETVAL

void
do_status(self)
    gearman_xs_client *self
  PREINIT:
    uint32_t numerator;
    uint32_t denominator;
  PPCODE:
    gearman_client_do_status(self->client, &numerator, &denominator);
    XPUSHs(sv_2mortal(newSVuv(numerator)));
    XPUSHs(sv_2mortal(newSVuv(denominator)));

void
job_status(self, job_handle="")
    gearman_xs_client *self
    const char *job_handle
  PREINIT:
    gearman_return_t ret;
    bool is_known;
    bool is_running;
    uint32_t numerator;
    uint32_t denominator;
  PPCODE:
    ret= gearman_client_job_status(self->client, job_handle, &is_known, &is_running,
                                   &numerator, &denominator);
    XPUSHs(sv_2mortal(newSViv(ret)));
    XPUSHs(sv_2mortal(newSViv(is_known)));
    XPUSHs(sv_2mortal(newSViv(is_running)));
    XPUSHs(sv_2mortal(newSVuv(numerator)));
    XPUSHs(sv_2mortal(newSVuv(denominator)));

void
DESTROY(self)
    gearman_xs_client *self
  CODE:
    gearman_client_free(self->client);
    Safefree(self);