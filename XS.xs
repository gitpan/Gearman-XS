/* Gearman Perl front end
 * Copyright (C) 2009 Dennis Schoen
 * All rights reserved.
 *
 * This library is free software; you can redistribute it and/or modify
 * it under the same terms as Perl itself, either Perl version 5.8.9 or,
 * at your option, any later version of Perl 5 you may have available.
 */

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <libgearman/gearman.h>

typedef enum {
  TASK_FN_ARG_CREATED= (1 << 0)
} gearman_task_fn_arg_st_flags;

typedef struct gearman_worker_st gearman_xs_worker;
typedef struct gearman_job_st gearman_xs_job;
typedef struct gearman_task_st gearman_xs_task;

typedef struct gearman_xs_client {
  gearman_client_st *client;
  /* used for keeping track of task interface callbacks */
  SV * created_fn;
  SV * data_fn;
  SV * complete_fn;
  SV * fail_fn;
  SV * status_fn;
} gearman_xs_client;

/* worker cb_arg to pass our actual perl function */
typedef struct
{
  SV * func;
  const char *cb_arg;
} gearman_worker_cb;

/* client task fn_arg */
typedef struct
{
  gearman_task_fn_arg_st_flags flags;
  gearman_client_st *client;
  const char *workload;
} gearman_task_fn_arg_st;

#define XS_STATE(type, x) (INT2PTR(type, SvROK(x) ? SvIV(SvRV(x)) : SvIV(x)))

#define XS_STRUCT2OBJ(sv, class, obj) if (obj == NULL) {  sv_setsv(sv, &PL_sv_undef); } else {  sv_setref_pv(sv, class, (void *) obj);  }

inline
SV *_bless(const char *class, void *obj) {
  SV * ret = newSViv(0);
  XS_STRUCT2OBJ(ret, class, obj);
  return ret;
}

void _perl_free(void *ptr, void *arg)
{
  Safefree(ptr);
}

static void *_perl_malloc(size_t size, void *arg)
{
  return safemalloc(size);
}

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
    result=savesvpv(result_sv);
    *result_size= SvCUR(result_sv);

    *ret_ptr= GEARMAN_SUCCESS;
  }

  PUTBACK;
  FREETMPS;
  LEAVE;

  return result;
}

static gearman_return_t _perl_task_complete_fn(gearman_task_st *task)
{
  gearman_task_fn_arg_st *fn_arg_st;
  gearman_xs_client *self;
  int count;
  gearman_return_t ret;

  dSP;

  ENTER;
  SAVETMPS;

  fn_arg_st= (gearman_task_fn_arg_st *)gearman_task_fn_arg(task);
  self= (gearman_xs_client *)gearman_client_data(fn_arg_st->client);

  PUSHMARK(SP);
  XPUSHs(_bless("Gearman::XS::Task", task));
  PUTBACK;

  count= call_sv(self->complete_fn, G_SCALAR);
  if (count != 1)
    croak("Invalid number of return values.\n");

  SPAGAIN;

  ret= POPi;

  PUTBACK;
  FREETMPS;
  LEAVE;

  return ret;
}

static gearman_return_t _perl_task_fail_fn(gearman_task_st *task)
{
  gearman_task_fn_arg_st *fn_arg_st;
  gearman_xs_client *self;
  int count;
  gearman_return_t ret;

  dSP;

  ENTER;
  SAVETMPS;

  fn_arg_st= (gearman_task_fn_arg_st *)gearman_task_fn_arg(task);
  self= (gearman_xs_client *)gearman_client_data(fn_arg_st->client);

  PUSHMARK(SP);
  XPUSHs(_bless("Gearman::XS::Task", task));
  PUTBACK;

  count= call_sv(self->fail_fn, G_SCALAR);
  if (count != 1)
    croak("Invalid number of return values.\n");

  SPAGAIN;

  ret= POPi;

  PUTBACK;
  FREETMPS;
  LEAVE;

  return ret;
}

static gearman_return_t _perl_task_status_fn(gearman_task_st *task)
{
  gearman_task_fn_arg_st *fn_arg_st;
  gearman_xs_client *self;
  int count;
  gearman_return_t ret;

  dSP;

  ENTER;
  SAVETMPS;

  fn_arg_st= (gearman_task_fn_arg_st *)gearman_task_fn_arg(task);
  self= (gearman_xs_client *)gearman_client_data(fn_arg_st->client);

  PUSHMARK(SP);
  XPUSHs(_bless("Gearman::XS::Task", task));
  PUTBACK;

  count= call_sv(self->status_fn, G_SCALAR);
  if (count != 1)
    croak("Invalid number of return values.\n");

  SPAGAIN;

  ret= POPi;

  PUTBACK;
  FREETMPS;
  LEAVE;

  return ret;
}

static gearman_return_t _perl_task_created_fn(gearman_task_st *task)
{
  gearman_task_fn_arg_st *fn_arg_st;
  gearman_xs_client *self;
  int count;
  gearman_return_t ret;

  dSP;

  ENTER;
  SAVETMPS;

  fn_arg_st= (gearman_task_fn_arg_st *)gearman_task_fn_arg(task);
  self= (gearman_xs_client *)gearman_client_data(fn_arg_st->client);

  PUSHMARK(SP);
  XPUSHs(_bless("Gearman::XS::Task", task));
  PUTBACK;

  count= call_sv(self->created_fn, G_SCALAR);
  if (count != 1)
    croak("Invalid number of return values.\n");

  SPAGAIN;

  ret= POPi;

  PUTBACK;
  FREETMPS;
  LEAVE;

  return ret;
}

static gearman_return_t _perl_task_data_fn(gearman_task_st *task)
{
  gearman_task_fn_arg_st *fn_arg_st;
  gearman_xs_client *self;
  int count;
  gearman_return_t ret;

  dSP;

  ENTER;
  SAVETMPS;

  fn_arg_st= (gearman_task_fn_arg_st *)gearman_task_fn_arg(task);
  self= (gearman_xs_client *)gearman_client_data(fn_arg_st->client);

  PUSHMARK(SP);
  XPUSHs(_bless("Gearman::XS::Task", task));
  PUTBACK;

  count= call_sv(self->data_fn, G_SCALAR);
  if (count != 1)
    croak("Invalid number of return values.\n");

  SPAGAIN;

  ret= POPi;

  PUTBACK;
  FREETMPS;
  LEAVE;

  return ret;
}

SV* _create_client() {
  gearman_xs_client * self;

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

MODULE = Gearman::XS    PACKAGE = Gearman::XS

PROTOTYPES: ENABLE

BOOT:
{
  HV *stash;
  stash= gv_stashpvn("Gearman::XS", 11, TRUE);

  # defines
  newCONSTSUB(stash, "GEARMAN_DEFAULT_TCP_HOST", newSVpv(GEARMAN_DEFAULT_TCP_HOST,strlen(GEARMAN_DEFAULT_TCP_HOST)));
  newCONSTSUB(stash, "GEARMAN_DEFAULT_TCP_PORT", newSViv(GEARMAN_DEFAULT_TCP_PORT));

  # gearman_return_t
  newCONSTSUB(stash, "GEARMAN_SUCCESS", newSViv(GEARMAN_SUCCESS));
  newCONSTSUB(stash, "GEARMAN_IO_WAIT", newSViv(GEARMAN_IO_WAIT));
  newCONSTSUB(stash, "GEARMAN_SHUTDOWN", newSViv(GEARMAN_SHUTDOWN));
  newCONSTSUB(stash, "GEARMAN_SHUTDOWN_GRACEFUL", newSViv(GEARMAN_SHUTDOWN_GRACEFUL));
  newCONSTSUB(stash, "GEARMAN_ERRNO", newSViv(GEARMAN_ERRNO));
  newCONSTSUB(stash, "GEARMAN_EVENT", newSViv(GEARMAN_EVENT));
  newCONSTSUB(stash, "GEARMAN_TOO_MANY_ARGS", newSViv(GEARMAN_TOO_MANY_ARGS));
  newCONSTSUB(stash, "GEARMAN_NO_ACTIVE_FDS", newSViv(GEARMAN_NO_ACTIVE_FDS));
  newCONSTSUB(stash, "GEARMAN_INVALID_MAGIC", newSViv(GEARMAN_INVALID_MAGIC));
  newCONSTSUB(stash, "GEARMAN_INVALID_COMMAND", newSViv(GEARMAN_INVALID_COMMAND));
  newCONSTSUB(stash, "GEARMAN_INVALID_PACKET", newSViv(GEARMAN_INVALID_PACKET));
  newCONSTSUB(stash, "GEARMAN_UNEXPECTED_PACKET", newSViv(GEARMAN_UNEXPECTED_PACKET));
  newCONSTSUB(stash, "GEARMAN_GETADDRINFO", newSViv(GEARMAN_GETADDRINFO));
  newCONSTSUB(stash, "GEARMAN_NO_SERVERS", newSViv(GEARMAN_NO_SERVERS));
  newCONSTSUB(stash, "GEARMAN_LOST_CONNECTION", newSViv(GEARMAN_LOST_CONNECTION));
  newCONSTSUB(stash, "GEARMAN_MEMORY_ALLOCATION_FAILURE", newSViv(GEARMAN_MEMORY_ALLOCATION_FAILURE));
  newCONSTSUB(stash, "GEARMAN_JOB_EXISTS", newSViv(GEARMAN_JOB_EXISTS));
  newCONSTSUB(stash, "GEARMAN_JOB_QUEUE_FULL", newSViv(GEARMAN_JOB_QUEUE_FULL));
  newCONSTSUB(stash, "GEARMAN_SERVER_ERROR", newSViv(GEARMAN_SERVER_ERROR));
  newCONSTSUB(stash, "GEARMAN_WORK_ERROR", newSViv(GEARMAN_WORK_ERROR));
  newCONSTSUB(stash, "GEARMAN_WORK_DATA", newSViv(GEARMAN_WORK_DATA));
  newCONSTSUB(stash, "GEARMAN_WORK_WARNING", newSViv(GEARMAN_WORK_WARNING));
  newCONSTSUB(stash, "GEARMAN_WORK_STATUS", newSViv(GEARMAN_WORK_STATUS));
  newCONSTSUB(stash, "GEARMAN_WORK_EXCEPTION", newSViv(GEARMAN_WORK_EXCEPTION));
  newCONSTSUB(stash, "GEARMAN_WORK_FAIL", newSViv(GEARMAN_WORK_FAIL));
  newCONSTSUB(stash, "GEARMAN_NOT_CONNECTED", newSViv(GEARMAN_NOT_CONNECTED));
  newCONSTSUB(stash, "GEARMAN_COULD_NOT_CONNECT", newSViv(GEARMAN_COULD_NOT_CONNECT));
  newCONSTSUB(stash, "GEARMAN_SEND_IN_PROGRESS", newSViv(GEARMAN_SEND_IN_PROGRESS));
  newCONSTSUB(stash, "GEARMAN_RECV_IN_PROGRESS", newSViv(GEARMAN_RECV_IN_PROGRESS));
  newCONSTSUB(stash, "GEARMAN_NOT_FLUSHING", newSViv(GEARMAN_NOT_FLUSHING));
  newCONSTSUB(stash, "GEARMAN_DATA_TOO_LARGE", newSViv(GEARMAN_DATA_TOO_LARGE));
  newCONSTSUB(stash, "GEARMAN_INVALID_FUNCTION_NAME", newSViv(GEARMAN_INVALID_FUNCTION_NAME));
  newCONSTSUB(stash, "GEARMAN_INVALID_WORKER_FUNCTION", newSViv(GEARMAN_INVALID_WORKER_FUNCTION));
  newCONSTSUB(stash, "GEARMAN_NO_REGISTERED_FUNCTIONS", newSViv(GEARMAN_NO_REGISTERED_FUNCTIONS));
  newCONSTSUB(stash, "GEARMAN_NO_JOBS", newSViv(GEARMAN_NO_JOBS));
  newCONSTSUB(stash, "GEARMAN_ECHO_DATA_CORRUPTION", newSViv(GEARMAN_ECHO_DATA_CORRUPTION));
  newCONSTSUB(stash, "GEARMAN_NEED_WORKLOAD_FN", newSViv(GEARMAN_NEED_WORKLOAD_FN));
  newCONSTSUB(stash, "GEARMAN_PAUSE", newSViv(GEARMAN_PAUSE));
  newCONSTSUB(stash, "GEARMAN_UNKNOWN_STATE", newSViv(GEARMAN_UNKNOWN_STATE));
  newCONSTSUB(stash, "GEARMAN_PTHREAD", newSViv(GEARMAN_PTHREAD));
  newCONSTSUB(stash, "GEARMAN_PIPE_EOF", newSViv(GEARMAN_PIPE_EOF));

  # gearman_worker_options_t
  newCONSTSUB(stash, "GEARMAN_WORKER_ALLOCATED", newSViv(GEARMAN_WORKER_ALLOCATED));
  newCONSTSUB(stash, "GEARMAN_WORKER_NON_BLOCKING", newSViv(GEARMAN_WORKER_NON_BLOCKING));
  newCONSTSUB(stash, "GEARMAN_WORKER_PACKET_INIT", newSViv(GEARMAN_WORKER_PACKET_INIT));
  newCONSTSUB(stash, "GEARMAN_WORKER_GRAB_JOB_IN_USE", newSViv(GEARMAN_WORKER_GRAB_JOB_IN_USE));
  newCONSTSUB(stash, "GEARMAN_WORKER_PRE_SLEEP_IN_USE", newSViv(GEARMAN_WORKER_PRE_SLEEP_IN_USE));
  newCONSTSUB(stash, "GEARMAN_WORKER_WORK_JOB_IN_USE", newSViv(GEARMAN_WORKER_WORK_JOB_IN_USE));
  newCONSTSUB(stash, "GEARMAN_WORKER_CHANGE", newSViv(GEARMAN_WORKER_CHANGE));
  newCONSTSUB(stash, "GEARMAN_WORKER_GRAB_UNIQ", newSViv(GEARMAN_WORKER_GRAB_UNIQ));
}

MODULE = Gearman::XS    PACKAGE = Gearman::XS::Client

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
    if ((ret == GEARMAN_WORK_DATA) || (ret == GEARMAN_SUCCESS))
    {
      XPUSHs(sv_2mortal(newSVpvn(result, result_size)));
      Safefree(result);
    }

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
    if ((ret == GEARMAN_WORK_DATA) || (ret == GEARMAN_SUCCESS))
    {
      XPUSHs(sv_2mortal(newSVpvn(result, result_size)));
      Safefree(result);
    }

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
    if ((ret == GEARMAN_WORK_DATA) || (ret == GEARMAN_SUCCESS))
    {
      XPUSHs(sv_2mortal(newSVpvn(result, result_size)));
      Safefree(result);
    }

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
    }
    else
    {
      XPUSHs(sv_2mortal(newSVpvn(job_handle, strlen(job_handle))));
    }

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
    }
    else
    {
      XPUSHs(sv_2mortal(newSVpvn(job_handle, (size_t)strlen(job_handle))));
    }

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
    }
    else
    {
      XPUSHs(sv_2mortal(newSVpvn(job_handle, strlen(job_handle))));
    }

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

MODULE = Gearman::XS    PACKAGE = Gearman::XS::Worker

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
DESTROY(self)
    gearman_xs_worker *self
  CODE:
    gearman_worker_free(self);

MODULE = Gearman::XS    PACKAGE = Gearman::XS::Job

SV *
workload(self)
    gearman_xs_job *self
  CODE:
    RETVAL= newSVpvn(gearman_job_workload(self), gearman_job_workload_size(self));
  OUTPUT:
    RETVAL

char *
handle(self)
    gearman_xs_job *self
  CODE:
    RETVAL= gearman_job_handle(self);
  OUTPUT:
    RETVAL

gearman_return_t
status(self, numerator, denominator)
    gearman_xs_job *self
    uint32_t numerator
    uint32_t denominator
  CODE:
    RETVAL= gearman_job_status(self, numerator, denominator);
  OUTPUT:
    RETVAL

const char *
function_name(self)
    gearman_xs_job *self
  CODE:
    RETVAL= gearman_job_function_name(self);
  OUTPUT:
    RETVAL

char *
unique(self)
    gearman_xs_job *self
  CODE:
    RETVAL= gearman_job_unique(self);
  OUTPUT:
    RETVAL

gearman_return_t
data(self, data)
    gearman_xs_job *self
    SV * data
  CODE:
    RETVAL= gearman_job_data(self, SvPV_nolen(data), SvCUR(data));
  OUTPUT:
    RETVAL

gearman_return_t
fail(self)
    gearman_xs_job *self
  CODE:
    RETVAL= gearman_job_fail(self);
  OUTPUT:
    RETVAL

MODULE = Gearman::XS    PACKAGE = Gearman::XS::Task

const char *
job_handle(self)
    gearman_xs_task *self
  CODE:
    RETVAL= gearman_task_job_handle(self);
  OUTPUT:
    RETVAL

SV *
data(self)
    gearman_xs_task *self
  CODE:
    RETVAL= newSVpvn(gearman_task_data(self), gearman_task_data_size(self));
  OUTPUT:
    RETVAL

int
data_size(self)
    gearman_xs_task *self
  CODE:
    RETVAL= gearman_task_data_size(self);
  OUTPUT:
    RETVAL

const char *
function(self)
    gearman_xs_task *self
  CODE:
    RETVAL= gearman_task_function(self);
  OUTPUT:
    RETVAL

uint32_t
numerator(self)
    gearman_xs_task *self
  CODE:
    RETVAL= gearman_task_numerator(self);
  OUTPUT:
    RETVAL

uint32_t
denominator(self)
    gearman_xs_task *self
  CODE:
    RETVAL= gearman_task_denominator(self);
  OUTPUT:
    RETVAL

const char *
uuid(self)
    gearman_xs_task *self
  CODE:
    RETVAL= gearman_task_uuid(self);
  OUTPUT:
    RETVAL
