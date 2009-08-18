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
#define NEED_newCONSTSUB
#define NEED_sv_2pv_flags
#include "ppport.h"

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
  SV * warning_fn;
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

  newCONSTSUB(stash, "GEARMAN_ALLOCATED", newSViv(GEARMAN_ALLOCATED));
  newCONSTSUB(stash, "GEARMAN_ARGS_BUFFER_SIZE", newSViv(GEARMAN_ARGS_BUFFER_SIZE));
  newCONSTSUB(stash, "GEARMAN_CLIENT_ALLOCATED", newSViv(GEARMAN_CLIENT_ALLOCATED));
  newCONSTSUB(stash, "GEARMAN_CLIENT_FREE_TASKS", newSViv(GEARMAN_CLIENT_FREE_TASKS));
  newCONSTSUB(stash, "GEARMAN_CLIENT_NON_BLOCKING", newSViv(GEARMAN_CLIENT_NON_BLOCKING));
  newCONSTSUB(stash, "GEARMAN_CLIENT_NO_NEW", newSViv(GEARMAN_CLIENT_NO_NEW));
  newCONSTSUB(stash, "GEARMAN_CLIENT_STATE_IDLE", newSViv(GEARMAN_CLIENT_STATE_IDLE));
  newCONSTSUB(stash, "GEARMAN_CLIENT_STATE_NEW", newSViv(GEARMAN_CLIENT_STATE_NEW));
  newCONSTSUB(stash, "GEARMAN_CLIENT_STATE_PACKET", newSViv(GEARMAN_CLIENT_STATE_PACKET));
  newCONSTSUB(stash, "GEARMAN_CLIENT_STATE_SUBMIT", newSViv(GEARMAN_CLIENT_STATE_SUBMIT));
  newCONSTSUB(stash, "GEARMAN_CLIENT_TASK_IN_USE", newSViv(GEARMAN_CLIENT_TASK_IN_USE));
  newCONSTSUB(stash, "GEARMAN_CLIENT_UNBUFFERED_RESULT", newSViv(GEARMAN_CLIENT_UNBUFFERED_RESULT));
  newCONSTSUB(stash, "GEARMAN_COMMAND_ALL_YOURS", newSViv(GEARMAN_COMMAND_ALL_YOURS));
  newCONSTSUB(stash, "GEARMAN_COMMAND_CANT_DO", newSViv(GEARMAN_COMMAND_CANT_DO));
  newCONSTSUB(stash, "GEARMAN_COMMAND_CAN_DO", newSViv(GEARMAN_COMMAND_CAN_DO));
  newCONSTSUB(stash, "GEARMAN_COMMAND_CAN_DO_TIMEOUT", newSViv(GEARMAN_COMMAND_CAN_DO_TIMEOUT));
  newCONSTSUB(stash, "GEARMAN_COMMAND_ECHO_REQ", newSViv(GEARMAN_COMMAND_ECHO_REQ));
  newCONSTSUB(stash, "GEARMAN_COMMAND_ECHO_RES", newSViv(GEARMAN_COMMAND_ECHO_RES));
  newCONSTSUB(stash, "GEARMAN_COMMAND_ERROR", newSViv(GEARMAN_COMMAND_ERROR));
  newCONSTSUB(stash, "GEARMAN_COMMAND_GET_STATUS", newSViv(GEARMAN_COMMAND_GET_STATUS));
  newCONSTSUB(stash, "GEARMAN_COMMAND_GRAB_JOB", newSViv(GEARMAN_COMMAND_GRAB_JOB));
  newCONSTSUB(stash, "GEARMAN_COMMAND_GRAB_JOB_UNIQ", newSViv(GEARMAN_COMMAND_GRAB_JOB_UNIQ));
  newCONSTSUB(stash, "GEARMAN_COMMAND_JOB_ASSIGN", newSViv(GEARMAN_COMMAND_JOB_ASSIGN));
  newCONSTSUB(stash, "GEARMAN_COMMAND_JOB_ASSIGN_UNIQ", newSViv(GEARMAN_COMMAND_JOB_ASSIGN_UNIQ));
  newCONSTSUB(stash, "GEARMAN_COMMAND_JOB_CREATED", newSViv(GEARMAN_COMMAND_JOB_CREATED));
  newCONSTSUB(stash, "GEARMAN_COMMAND_MAX", newSViv(GEARMAN_COMMAND_MAX));
  newCONSTSUB(stash, "GEARMAN_COMMAND_NOOP", newSViv(GEARMAN_COMMAND_NOOP));
  newCONSTSUB(stash, "GEARMAN_COMMAND_NO_JOB", newSViv(GEARMAN_COMMAND_NO_JOB));
  newCONSTSUB(stash, "GEARMAN_COMMAND_OPTION_REQ", newSViv(GEARMAN_COMMAND_OPTION_REQ));
  newCONSTSUB(stash, "GEARMAN_COMMAND_OPTION_RES", newSViv(GEARMAN_COMMAND_OPTION_RES));
  newCONSTSUB(stash, "GEARMAN_COMMAND_PRE_SLEEP", newSViv(GEARMAN_COMMAND_PRE_SLEEP));
  newCONSTSUB(stash, "GEARMAN_COMMAND_RESET_ABILITIES", newSViv(GEARMAN_COMMAND_RESET_ABILITIES));
  newCONSTSUB(stash, "GEARMAN_COMMAND_SET_CLIENT_ID", newSViv(GEARMAN_COMMAND_SET_CLIENT_ID));
  newCONSTSUB(stash, "GEARMAN_COMMAND_STATUS_RES", newSViv(GEARMAN_COMMAND_STATUS_RES));
  newCONSTSUB(stash, "GEARMAN_COMMAND_SUBMIT_JOB", newSViv(GEARMAN_COMMAND_SUBMIT_JOB));
  newCONSTSUB(stash, "GEARMAN_COMMAND_SUBMIT_JOB_BG", newSViv(GEARMAN_COMMAND_SUBMIT_JOB_BG));
  newCONSTSUB(stash, "GEARMAN_COMMAND_SUBMIT_JOB_EPOCH", newSViv(GEARMAN_COMMAND_SUBMIT_JOB_EPOCH));
  newCONSTSUB(stash, "GEARMAN_COMMAND_SUBMIT_JOB_HIGH", newSViv(GEARMAN_COMMAND_SUBMIT_JOB_HIGH));
  newCONSTSUB(stash, "GEARMAN_COMMAND_SUBMIT_JOB_HIGH_BG", newSViv(GEARMAN_COMMAND_SUBMIT_JOB_HIGH_BG));
  newCONSTSUB(stash, "GEARMAN_COMMAND_SUBMIT_JOB_LOW", newSViv(GEARMAN_COMMAND_SUBMIT_JOB_LOW));
  newCONSTSUB(stash, "GEARMAN_COMMAND_SUBMIT_JOB_LOW_BG", newSViv(GEARMAN_COMMAND_SUBMIT_JOB_LOW_BG));
  newCONSTSUB(stash, "GEARMAN_COMMAND_SUBMIT_JOB_SCHED", newSViv(GEARMAN_COMMAND_SUBMIT_JOB_SCHED));
  newCONSTSUB(stash, "GEARMAN_COMMAND_TEXT", newSViv(GEARMAN_COMMAND_TEXT));
  newCONSTSUB(stash, "GEARMAN_COMMAND_UNUSED", newSViv(GEARMAN_COMMAND_UNUSED));
  newCONSTSUB(stash, "GEARMAN_COMMAND_WORK_COMPLETE", newSViv(GEARMAN_COMMAND_WORK_COMPLETE));
  newCONSTSUB(stash, "GEARMAN_COMMAND_WORK_DATA", newSViv(GEARMAN_COMMAND_WORK_DATA));
  newCONSTSUB(stash, "GEARMAN_COMMAND_WORK_EXCEPTION", newSViv(GEARMAN_COMMAND_WORK_EXCEPTION));
  newCONSTSUB(stash, "GEARMAN_COMMAND_WORK_FAIL", newSViv(GEARMAN_COMMAND_WORK_FAIL));
  newCONSTSUB(stash, "GEARMAN_COMMAND_WORK_STATUS", newSViv(GEARMAN_COMMAND_WORK_STATUS));
  newCONSTSUB(stash, "GEARMAN_COMMAND_WORK_WARNING", newSViv(GEARMAN_COMMAND_WORK_WARNING));
  newCONSTSUB(stash, "GEARMAN_CONF_ALLOCATED", newSViv(GEARMAN_CONF_ALLOCATED));
  newCONSTSUB(stash, "GEARMAN_CONF_DISPLAY_WIDTH", newSViv(GEARMAN_CONF_DISPLAY_WIDTH));
  newCONSTSUB(stash, "GEARMAN_CONF_MAX_OPTION_SHORT", newSViv(GEARMAN_CONF_MAX_OPTION_SHORT));
  newCONSTSUB(stash, "GEARMAN_CONF_MODULE_ALLOCATED", newSViv(GEARMAN_CONF_MODULE_ALLOCATED));
  newCONSTSUB(stash, "GEARMAN_CON_ALLOCATED", newSViv(GEARMAN_CON_ALLOCATED));
  newCONSTSUB(stash, "GEARMAN_CON_CLOSE_AFTER_FLUSH", newSViv(GEARMAN_CON_CLOSE_AFTER_FLUSH));
  newCONSTSUB(stash, "GEARMAN_CON_EXTERNAL_FD", newSViv(GEARMAN_CON_EXTERNAL_FD));
  newCONSTSUB(stash, "GEARMAN_CON_IGNORE_LOST_CONNECTION", newSViv(GEARMAN_CON_IGNORE_LOST_CONNECTION));
  newCONSTSUB(stash, "GEARMAN_CON_PACKET_IN_USE", newSViv(GEARMAN_CON_PACKET_IN_USE));
  newCONSTSUB(stash, "GEARMAN_CON_READY", newSViv(GEARMAN_CON_READY));
  newCONSTSUB(stash, "GEARMAN_CON_RECV_STATE_NONE", newSViv(GEARMAN_CON_RECV_STATE_NONE));
  newCONSTSUB(stash, "GEARMAN_CON_RECV_STATE_READ", newSViv(GEARMAN_CON_RECV_STATE_READ));
  newCONSTSUB(stash, "GEARMAN_CON_RECV_STATE_READ_DATA", newSViv(GEARMAN_CON_RECV_STATE_READ_DATA));
  newCONSTSUB(stash, "GEARMAN_CON_SEND_STATE_FLUSH", newSViv(GEARMAN_CON_SEND_STATE_FLUSH));
  newCONSTSUB(stash, "GEARMAN_CON_SEND_STATE_FLUSH_DATA", newSViv(GEARMAN_CON_SEND_STATE_FLUSH_DATA));
  newCONSTSUB(stash, "GEARMAN_CON_SEND_STATE_FORCE_FLUSH", newSViv(GEARMAN_CON_SEND_STATE_FORCE_FLUSH));
  newCONSTSUB(stash, "GEARMAN_CON_SEND_STATE_NONE", newSViv(GEARMAN_CON_SEND_STATE_NONE));
  newCONSTSUB(stash, "GEARMAN_CON_SEND_STATE_PRE_FLUSH", newSViv(GEARMAN_CON_SEND_STATE_PRE_FLUSH));
  newCONSTSUB(stash, "GEARMAN_CON_STATE_ADDRINFO", newSViv(GEARMAN_CON_STATE_ADDRINFO));
  newCONSTSUB(stash, "GEARMAN_CON_STATE_CONNECT", newSViv(GEARMAN_CON_STATE_CONNECT));
  newCONSTSUB(stash, "GEARMAN_CON_STATE_CONNECTED", newSViv(GEARMAN_CON_STATE_CONNECTED));
  newCONSTSUB(stash, "GEARMAN_CON_STATE_CONNECTING", newSViv(GEARMAN_CON_STATE_CONNECTING));
  newCONSTSUB(stash, "GEARMAN_COULD_NOT_CONNECT", newSViv(GEARMAN_COULD_NOT_CONNECT));
  newCONSTSUB(stash, "GEARMAN_DATA_TOO_LARGE", newSViv(GEARMAN_DATA_TOO_LARGE));
  newCONSTSUB(stash, "GEARMAN_DEFAULT_BACKLOG", newSViv(GEARMAN_DEFAULT_BACKLOG));
  newCONSTSUB(stash, "GEARMAN_DEFAULT_MAX_QUEUE_SIZE", newSViv(GEARMAN_DEFAULT_MAX_QUEUE_SIZE));
  newCONSTSUB(stash, "GEARMAN_DEFAULT_SOCKET_RECV_SIZE", newSViv(GEARMAN_DEFAULT_SOCKET_RECV_SIZE));
  newCONSTSUB(stash, "GEARMAN_DEFAULT_SOCKET_SEND_SIZE", newSViv(GEARMAN_DEFAULT_SOCKET_SEND_SIZE));
  newCONSTSUB(stash, "GEARMAN_DEFAULT_SOCKET_TIMEOUT", newSViv(GEARMAN_DEFAULT_SOCKET_TIMEOUT));
  newCONSTSUB(stash, "GEARMAN_DEFAULT_TCP_HOST", newSVpv(GEARMAN_DEFAULT_TCP_HOST,strlen(GEARMAN_DEFAULT_TCP_HOST)));
  newCONSTSUB(stash, "GEARMAN_DEFAULT_TCP_PORT", newSViv(GEARMAN_DEFAULT_TCP_PORT));
  newCONSTSUB(stash, "GEARMAN_DONT_TRACK_PACKETS", newSViv(GEARMAN_DONT_TRACK_PACKETS));
  newCONSTSUB(stash, "GEARMAN_ECHO_DATA_CORRUPTION", newSViv(GEARMAN_ECHO_DATA_CORRUPTION));
  newCONSTSUB(stash, "GEARMAN_ERRNO", newSViv(GEARMAN_ERRNO));
  newCONSTSUB(stash, "GEARMAN_EVENT", newSViv(GEARMAN_EVENT));
  newCONSTSUB(stash, "GEARMAN_FLUSH_DATA", newSViv(GEARMAN_FLUSH_DATA));
  newCONSTSUB(stash, "GEARMAN_GETADDRINFO", newSViv(GEARMAN_GETADDRINFO));
  newCONSTSUB(stash, "GEARMAN_IGNORE_PACKET", newSViv(GEARMAN_IGNORE_PACKET));
  newCONSTSUB(stash, "GEARMAN_INVALID_COMMAND", newSViv(GEARMAN_INVALID_COMMAND));
  newCONSTSUB(stash, "GEARMAN_INVALID_FUNCTION_NAME", newSViv(GEARMAN_INVALID_FUNCTION_NAME));
  newCONSTSUB(stash, "GEARMAN_INVALID_MAGIC", newSViv(GEARMAN_INVALID_MAGIC));
  newCONSTSUB(stash, "GEARMAN_INVALID_PACKET", newSViv(GEARMAN_INVALID_PACKET));
  newCONSTSUB(stash, "GEARMAN_INVALID_WORKER_FUNCTION", newSViv(GEARMAN_INVALID_WORKER_FUNCTION));
  newCONSTSUB(stash, "GEARMAN_IO_WAIT", newSViv(GEARMAN_IO_WAIT));
  newCONSTSUB(stash, "GEARMAN_JOB_ALLOCATED", newSViv(GEARMAN_JOB_ALLOCATED));
  newCONSTSUB(stash, "GEARMAN_JOB_ASSIGNED_IN_USE", newSViv(GEARMAN_JOB_ASSIGNED_IN_USE));
  newCONSTSUB(stash, "GEARMAN_JOB_EXISTS", newSViv(GEARMAN_JOB_EXISTS));
  newCONSTSUB(stash, "GEARMAN_JOB_FINISHED", newSViv(GEARMAN_JOB_FINISHED));
  newCONSTSUB(stash, "GEARMAN_JOB_HANDLE_SIZE", newSViv(GEARMAN_JOB_HANDLE_SIZE));
  newCONSTSUB(stash, "GEARMAN_JOB_HASH_SIZE", newSViv(GEARMAN_JOB_HASH_SIZE));
  newCONSTSUB(stash, "GEARMAN_JOB_PRIORITY_HIGH", newSViv(GEARMAN_JOB_PRIORITY_HIGH));
  newCONSTSUB(stash, "GEARMAN_JOB_PRIORITY_LOW", newSViv(GEARMAN_JOB_PRIORITY_LOW));
  newCONSTSUB(stash, "GEARMAN_JOB_PRIORITY_MAX", newSViv(GEARMAN_JOB_PRIORITY_MAX));
  newCONSTSUB(stash, "GEARMAN_JOB_PRIORITY_NORMAL", newSViv(GEARMAN_JOB_PRIORITY_NORMAL));
  newCONSTSUB(stash, "GEARMAN_JOB_QUEUE_FULL", newSViv(GEARMAN_JOB_QUEUE_FULL));
  newCONSTSUB(stash, "GEARMAN_JOB_WORK_IN_USE", newSViv(GEARMAN_JOB_WORK_IN_USE));
  newCONSTSUB(stash, "GEARMAN_LOST_CONNECTION", newSViv(GEARMAN_LOST_CONNECTION));
  newCONSTSUB(stash, "GEARMAN_MAGIC_REQUEST", newSViv(GEARMAN_MAGIC_REQUEST));
  newCONSTSUB(stash, "GEARMAN_MAGIC_RESPONSE", newSViv(GEARMAN_MAGIC_RESPONSE));
  newCONSTSUB(stash, "GEARMAN_MAGIC_TEXT", newSViv(GEARMAN_MAGIC_TEXT));
  newCONSTSUB(stash, "GEARMAN_MAX_COMMAND_ARGS", newSViv(GEARMAN_MAX_COMMAND_ARGS));
  newCONSTSUB(stash, "GEARMAN_MAX_ERROR_SIZE", newSViv(GEARMAN_MAX_ERROR_SIZE));
  newCONSTSUB(stash, "GEARMAN_MAX_FREE_SERVER_CLIENT", newSViv(GEARMAN_MAX_FREE_SERVER_CLIENT));
  newCONSTSUB(stash, "GEARMAN_MAX_FREE_SERVER_CON", newSViv(GEARMAN_MAX_FREE_SERVER_CON));
  newCONSTSUB(stash, "GEARMAN_MAX_FREE_SERVER_JOB", newSViv(GEARMAN_MAX_FREE_SERVER_JOB));
  newCONSTSUB(stash, "GEARMAN_MAX_FREE_SERVER_PACKET", newSViv(GEARMAN_MAX_FREE_SERVER_PACKET));
  newCONSTSUB(stash, "GEARMAN_MAX_FREE_SERVER_WORKER", newSViv(GEARMAN_MAX_FREE_SERVER_WORKER));
  newCONSTSUB(stash, "GEARMAN_MAX_RETURN", newSViv(GEARMAN_MAX_RETURN));
  newCONSTSUB(stash, "GEARMAN_MEMORY_ALLOCATION_FAILURE", newSViv(GEARMAN_MEMORY_ALLOCATION_FAILURE));
  newCONSTSUB(stash, "GEARMAN_NEED_WORKLOAD_FN", newSViv(GEARMAN_NEED_WORKLOAD_FN));
  newCONSTSUB(stash, "GEARMAN_NON_BLOCKING", newSViv(GEARMAN_NON_BLOCKING));
  newCONSTSUB(stash, "GEARMAN_NOT_CONNECTED", newSViv(GEARMAN_NOT_CONNECTED));
  newCONSTSUB(stash, "GEARMAN_NOT_FLUSHING", newSViv(GEARMAN_NOT_FLUSHING));
  newCONSTSUB(stash, "GEARMAN_NO_ACTIVE_FDS", newSViv(GEARMAN_NO_ACTIVE_FDS));
  newCONSTSUB(stash, "GEARMAN_NO_JOBS", newSViv(GEARMAN_NO_JOBS));
  newCONSTSUB(stash, "GEARMAN_NO_REGISTERED_FUNCTIONS", newSViv(GEARMAN_NO_REGISTERED_FUNCTIONS));
  newCONSTSUB(stash, "GEARMAN_NO_SERVERS", newSViv(GEARMAN_NO_SERVERS));
  newCONSTSUB(stash, "GEARMAN_OPTION_SIZE", newSViv(GEARMAN_OPTION_SIZE));
  newCONSTSUB(stash, "GEARMAN_PACKET_ALLOCATED", newSViv(GEARMAN_PACKET_ALLOCATED));
  newCONSTSUB(stash, "GEARMAN_PACKET_COMPLETE", newSViv(GEARMAN_PACKET_COMPLETE));
  newCONSTSUB(stash, "GEARMAN_PACKET_FREE_DATA", newSViv(GEARMAN_PACKET_FREE_DATA));
  newCONSTSUB(stash, "GEARMAN_PACKET_HEADER_SIZE", newSViv(GEARMAN_PACKET_HEADER_SIZE));
  newCONSTSUB(stash, "GEARMAN_PAUSE", newSViv(GEARMAN_PAUSE));
  newCONSTSUB(stash, "GEARMAN_PIPE_BUFFER_SIZE", newSViv(GEARMAN_PIPE_BUFFER_SIZE));
  newCONSTSUB(stash, "GEARMAN_PIPE_EOF", newSViv(GEARMAN_PIPE_EOF));
  newCONSTSUB(stash, "GEARMAN_PTHREAD", newSViv(GEARMAN_PTHREAD));
  newCONSTSUB(stash, "GEARMAN_QUEUE_ERROR", newSViv(GEARMAN_QUEUE_ERROR));
  newCONSTSUB(stash, "GEARMAN_RECV_BUFFER_SIZE", newSViv(GEARMAN_RECV_BUFFER_SIZE));
  newCONSTSUB(stash, "GEARMAN_RECV_IN_PROGRESS", newSViv(GEARMAN_RECV_IN_PROGRESS));
  newCONSTSUB(stash, "GEARMAN_SEND_BUFFER_SIZE", newSViv(GEARMAN_SEND_BUFFER_SIZE));
  newCONSTSUB(stash, "GEARMAN_SEND_BUFFER_TOO_SMALL", newSViv(GEARMAN_SEND_BUFFER_TOO_SMALL));
  newCONSTSUB(stash, "GEARMAN_SEND_IN_PROGRESS", newSViv(GEARMAN_SEND_IN_PROGRESS));
  newCONSTSUB(stash, "GEARMAN_SERVER_ALLOCATED", newSViv(GEARMAN_SERVER_ALLOCATED));
  newCONSTSUB(stash, "GEARMAN_SERVER_CLIENT_ALLOCATED", newSViv(GEARMAN_SERVER_CLIENT_ALLOCATED));
  newCONSTSUB(stash, "GEARMAN_SERVER_CON_DEAD", newSViv(GEARMAN_SERVER_CON_DEAD));
  newCONSTSUB(stash, "GEARMAN_SERVER_CON_EXCEPTIONS", newSViv(GEARMAN_SERVER_CON_EXCEPTIONS));
  newCONSTSUB(stash, "GEARMAN_SERVER_CON_ID_SIZE", newSViv(GEARMAN_SERVER_CON_ID_SIZE));
  newCONSTSUB(stash, "GEARMAN_SERVER_CON_SLEEPING", newSViv(GEARMAN_SERVER_CON_SLEEPING));
  newCONSTSUB(stash, "GEARMAN_SERVER_ERROR", newSViv(GEARMAN_SERVER_ERROR));
  newCONSTSUB(stash, "GEARMAN_SERVER_FUNCTION_ALLOCATED", newSViv(GEARMAN_SERVER_FUNCTION_ALLOCATED));
  newCONSTSUB(stash, "GEARMAN_SERVER_JOB_ALLOCATED", newSViv(GEARMAN_SERVER_JOB_ALLOCATED));
  newCONSTSUB(stash, "GEARMAN_SERVER_JOB_IGNORE", newSViv(GEARMAN_SERVER_JOB_IGNORE));
  newCONSTSUB(stash, "GEARMAN_SERVER_JOB_QUEUED", newSViv(GEARMAN_SERVER_JOB_QUEUED));
  newCONSTSUB(stash, "GEARMAN_SERVER_PROC_THREAD", newSViv(GEARMAN_SERVER_PROC_THREAD));
  newCONSTSUB(stash, "GEARMAN_SERVER_QUEUE_REPLAY", newSViv(GEARMAN_SERVER_QUEUE_REPLAY));
  newCONSTSUB(stash, "GEARMAN_SERVER_THREAD_ALLOCATED", newSViv(GEARMAN_SERVER_THREAD_ALLOCATED));
  newCONSTSUB(stash, "GEARMAN_SERVER_WORKER_ALLOCATED", newSViv(GEARMAN_SERVER_WORKER_ALLOCATED));
  newCONSTSUB(stash, "GEARMAN_SHUTDOWN", newSViv(GEARMAN_SHUTDOWN));
  newCONSTSUB(stash, "GEARMAN_SHUTDOWN_GRACEFUL", newSViv(GEARMAN_SHUTDOWN_GRACEFUL));
  newCONSTSUB(stash, "GEARMAN_SUCCESS", newSViv(GEARMAN_SUCCESS));
  newCONSTSUB(stash, "GEARMAN_TASK_ALLOCATED", newSViv(GEARMAN_TASK_ALLOCATED));
  newCONSTSUB(stash, "GEARMAN_TASK_SEND_IN_USE", newSViv(GEARMAN_TASK_SEND_IN_USE));
  newCONSTSUB(stash, "GEARMAN_TASK_STATE_COMPLETE", newSViv(GEARMAN_TASK_STATE_COMPLETE));
  newCONSTSUB(stash, "GEARMAN_TASK_STATE_CREATED", newSViv(GEARMAN_TASK_STATE_CREATED));
  newCONSTSUB(stash, "GEARMAN_TASK_STATE_DATA", newSViv(GEARMAN_TASK_STATE_DATA));
  newCONSTSUB(stash, "GEARMAN_TASK_STATE_EXCEPTION", newSViv(GEARMAN_TASK_STATE_EXCEPTION));
  newCONSTSUB(stash, "GEARMAN_TASK_STATE_FAIL", newSViv(GEARMAN_TASK_STATE_FAIL));
  newCONSTSUB(stash, "GEARMAN_TASK_STATE_FINISHED", newSViv(GEARMAN_TASK_STATE_FINISHED));
  newCONSTSUB(stash, "GEARMAN_TASK_STATE_NEW", newSViv(GEARMAN_TASK_STATE_NEW));
  newCONSTSUB(stash, "GEARMAN_TASK_STATE_STATUS", newSViv(GEARMAN_TASK_STATE_STATUS));
  newCONSTSUB(stash, "GEARMAN_TASK_STATE_SUBMIT", newSViv(GEARMAN_TASK_STATE_SUBMIT));
  newCONSTSUB(stash, "GEARMAN_TASK_STATE_WARNING", newSViv(GEARMAN_TASK_STATE_WARNING));
  newCONSTSUB(stash, "GEARMAN_TASK_STATE_WORK", newSViv(GEARMAN_TASK_STATE_WORK));
  newCONSTSUB(stash, "GEARMAN_TASK_STATE_WORKLOAD", newSViv(GEARMAN_TASK_STATE_WORKLOAD));
  newCONSTSUB(stash, "GEARMAN_TEXT_RESPONSE_SIZE", newSViv(GEARMAN_TEXT_RESPONSE_SIZE));
  newCONSTSUB(stash, "GEARMAN_TOO_MANY_ARGS", newSViv(GEARMAN_TOO_MANY_ARGS));
  newCONSTSUB(stash, "GEARMAN_UNEXPECTED_PACKET", newSViv(GEARMAN_UNEXPECTED_PACKET));
  newCONSTSUB(stash, "GEARMAN_UNIQUE_SIZE", newSViv(GEARMAN_UNIQUE_SIZE));
  newCONSTSUB(stash, "GEARMAN_UNKNOWN_OPTION", newSViv(GEARMAN_UNKNOWN_OPTION));
  newCONSTSUB(stash, "GEARMAN_UNKNOWN_STATE", newSViv(GEARMAN_UNKNOWN_STATE));
  newCONSTSUB(stash, "GEARMAN_VERBOSE_CRAZY", newSViv(GEARMAN_VERBOSE_CRAZY));
  newCONSTSUB(stash, "GEARMAN_VERBOSE_DEBUG", newSViv(GEARMAN_VERBOSE_DEBUG));
  newCONSTSUB(stash, "GEARMAN_VERBOSE_ERROR", newSViv(GEARMAN_VERBOSE_ERROR));
  newCONSTSUB(stash, "GEARMAN_VERBOSE_FATAL", newSViv(GEARMAN_VERBOSE_FATAL));
  newCONSTSUB(stash, "GEARMAN_VERBOSE_INFO", newSViv(GEARMAN_VERBOSE_INFO));
  newCONSTSUB(stash, "GEARMAN_VERBOSE_MAX", newSViv(GEARMAN_VERBOSE_MAX));
  newCONSTSUB(stash, "GEARMAN_WORKER_ALLOCATED", newSViv(GEARMAN_WORKER_ALLOCATED));
  newCONSTSUB(stash, "GEARMAN_WORKER_CHANGE", newSViv(GEARMAN_WORKER_CHANGE));
  newCONSTSUB(stash, "GEARMAN_WORKER_FUNCTION_CHANGE", newSViv(GEARMAN_WORKER_FUNCTION_CHANGE));
  newCONSTSUB(stash, "GEARMAN_WORKER_FUNCTION_PACKET_IN_USE", newSViv(GEARMAN_WORKER_FUNCTION_PACKET_IN_USE));
  newCONSTSUB(stash, "GEARMAN_WORKER_FUNCTION_REMOVE", newSViv(GEARMAN_WORKER_FUNCTION_REMOVE));
  newCONSTSUB(stash, "GEARMAN_WORKER_GRAB_JOB_IN_USE", newSViv(GEARMAN_WORKER_GRAB_JOB_IN_USE));
  newCONSTSUB(stash, "GEARMAN_WORKER_GRAB_UNIQ", newSViv(GEARMAN_WORKER_GRAB_UNIQ));
  newCONSTSUB(stash, "GEARMAN_WORKER_NON_BLOCKING", newSViv(GEARMAN_WORKER_NON_BLOCKING));
  newCONSTSUB(stash, "GEARMAN_WORKER_PACKET_INIT", newSViv(GEARMAN_WORKER_PACKET_INIT));
  newCONSTSUB(stash, "GEARMAN_WORKER_PRE_SLEEP_IN_USE", newSViv(GEARMAN_WORKER_PRE_SLEEP_IN_USE));
  newCONSTSUB(stash, "GEARMAN_WORKER_STATE_CONNECT", newSViv(GEARMAN_WORKER_STATE_CONNECT));
  newCONSTSUB(stash, "GEARMAN_WORKER_STATE_FUNCTION_SEND", newSViv(GEARMAN_WORKER_STATE_FUNCTION_SEND));
  newCONSTSUB(stash, "GEARMAN_WORKER_STATE_GRAB_JOB_RECV", newSViv(GEARMAN_WORKER_STATE_GRAB_JOB_RECV));
  newCONSTSUB(stash, "GEARMAN_WORKER_STATE_GRAB_JOB_SEND", newSViv(GEARMAN_WORKER_STATE_GRAB_JOB_SEND));
  newCONSTSUB(stash, "GEARMAN_WORKER_STATE_PRE_SLEEP", newSViv(GEARMAN_WORKER_STATE_PRE_SLEEP));
  newCONSTSUB(stash, "GEARMAN_WORKER_STATE_START", newSViv(GEARMAN_WORKER_STATE_START));
  newCONSTSUB(stash, "GEARMAN_WORKER_WAIT_TIMEOUT", newSViv(GEARMAN_WORKER_WAIT_TIMEOUT));
  newCONSTSUB(stash, "GEARMAN_WORKER_WORK_JOB_IN_USE", newSViv(GEARMAN_WORKER_WORK_JOB_IN_USE));
  newCONSTSUB(stash, "GEARMAN_WORKER_WORK_STATE_COMPLETE", newSViv(GEARMAN_WORKER_WORK_STATE_COMPLETE));
  newCONSTSUB(stash, "GEARMAN_WORKER_WORK_STATE_FAIL", newSViv(GEARMAN_WORKER_WORK_STATE_FAIL));
  newCONSTSUB(stash, "GEARMAN_WORKER_WORK_STATE_FUNCTION", newSViv(GEARMAN_WORKER_WORK_STATE_FUNCTION));
  newCONSTSUB(stash, "GEARMAN_WORKER_WORK_STATE_GRAB_JOB", newSViv(GEARMAN_WORKER_WORK_STATE_GRAB_JOB));
  newCONSTSUB(stash, "GEARMAN_WORK_DATA", newSViv(GEARMAN_WORK_DATA));
  newCONSTSUB(stash, "GEARMAN_WORK_ERROR", newSViv(GEARMAN_WORK_ERROR));
  newCONSTSUB(stash, "GEARMAN_WORK_EXCEPTION", newSViv(GEARMAN_WORK_EXCEPTION));
  newCONSTSUB(stash, "GEARMAN_WORK_FAIL", newSViv(GEARMAN_WORK_FAIL));
  newCONSTSUB(stash, "GEARMAN_WORK_STATUS", newSViv(GEARMAN_WORK_STATUS));
  newCONSTSUB(stash, "GEARMAN_WORK_WARNING", newSViv(GEARMAN_WORK_WARNING));
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
    if ((ret == GEARMAN_WORK_DATA) || (ret == GEARMAN_SUCCESS) || (ret == GEARMAN_WORK_WARNING))
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
    if ((ret == GEARMAN_WORK_DATA) || (ret == GEARMAN_SUCCESS) || (ret == GEARMAN_WORK_WARNING))
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
    if ((ret == GEARMAN_WORK_DATA) || (ret == GEARMAN_SUCCESS) || (ret == GEARMAN_WORK_WARNING))
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
grab_job(self)
    gearman_xs_worker *self
  PREINIT:
    gearman_return_t ret;
  PPCODE:
    (void)gearman_worker_grab_job(self, &(self->work_job), &ret);
    XPUSHs(sv_2mortal(newSViv(ret)));
    if (ret == GEARMAN_SUCCESS)
      XPUSHs(_bless("Gearman::XS::Job", &(self->work_job)));

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

const char *
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

gearman_return_t
complete(self, result)
    gearman_xs_job *self
    SV * result
  CODE:
    RETVAL= gearman_job_complete(self, SvPV_nolen(result), SvCUR(result));
  OUTPUT:
    RETVAL

gearman_return_t
warning(self, warning)
    gearman_xs_job *self
    SV * warning
  CODE:
    RETVAL= gearman_job_warning(self, SvPV_nolen(warning), SvCUR(warning));
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
