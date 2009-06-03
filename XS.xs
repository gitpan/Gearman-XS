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
	TASK_FN_ARG_CREATED = (1 << 0)
} gearman_task_fn_arg_st_flags;

typedef struct gearman_client_st GearmanClient;
typedef struct gearman_worker_st GearmanWorker;
typedef struct gearman_job_st GearmanJob;
typedef struct gearman_task_st GearmanTask;

/* worker cb_arg to pass our actual perl function */
typedef struct
{
	SV * func;
	const char *cb_arg;
} gearman_worker_cb;

/* client perl callback functions, stored in client->data */
typedef struct
{
	SV * created_fn;
	SV * data_fn;
	SV * complete_fn;
	SV * fail_fn;
	SV * status_fn;
} gearman_client_task_cb;

/* client task fn_arg */
typedef struct
{
	gearman_task_fn_arg_st_flags flags;
	gearman_client_st *client;
	const char *workload;
} gearman_task_fn_arg_st;

void _perl_free(void *ptr, void *arg) {
	Safefree(ptr);
}

static void *_perl_malloc(size_t size, void *arg) {
	return safemalloc(size);
}

/* fn_arg free function to free() the workload */
void _perl_task_free(gearman_task_st *task, void *fn_arg) {
	gearman_task_fn_arg_st *fn_arg_st= (gearman_task_fn_arg_st *)fn_arg;
	if (fn_arg_st->flags == TASK_FN_ARG_CREATED) {
		Safefree(fn_arg_st->workload);
		Safefree(fn_arg_st);
	}
}

/* wrapper function to call our actual perl function,
   passed in through cb_arg */
void *_perl_worker_function_callback(gearman_job_st *job, void *cb_arg,
								size_t *result_size, gearman_return_t *ret_ptr)
{
	gearman_worker_cb *worker_cb;
	int count;
	char *result;
	SV * result_sv;
	SV * job_sv;

	worker_cb= (gearman_worker_cb *)cb_arg;

	dSP;

	ENTER;
	SAVETMPS;

	PUSHMARK(SP);
	job_sv= sv_newmortal();
	sv_setref_pv(job_sv, "GearmanJobPtr", job);
	XPUSHs(job_sv);
	if (worker_cb->cb_arg != NULL) {
		XPUSHs(sv_2mortal(newSVpv(worker_cb->cb_arg, strlen(worker_cb->cb_arg))));
	}
	PUTBACK;

	count= call_sv(worker_cb->func, G_EVAL|G_SCALAR);

	SPAGAIN;

	if (SvTRUE(ERRSV))
	{
		STRLEN n_a;
		fprintf(stderr, "Job: '%s' died with: %s", gearman_job_function_name(job), SvPV(ERRSV, n_a));
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
	gearman_client_task_cb *task_cb;
	SV * task_sv;
	int count;
	gearman_return_t ret;

	fn_arg_st= (gearman_task_fn_arg_st *)gearman_task_fn_arg(task);
	task_cb= (gearman_client_task_cb *)gearman_client_data(fn_arg_st->client);

	dSP;

	ENTER;
	SAVETMPS;

	PUSHMARK(SP);
	task_sv= sv_newmortal();
	sv_setref_pv(task_sv, "GearmanTaskPtr", task);
	XPUSHs(task_sv);
	PUTBACK;

	count= call_sv(task_cb->complete_fn, G_SCALAR);
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
	gearman_client_task_cb *task_cb;
	SV * task_sv;
	int count;
	gearman_return_t ret;

	fn_arg_st= (gearman_task_fn_arg_st *)gearman_task_fn_arg(task);
	task_cb= (gearman_client_task_cb *)gearman_client_data(fn_arg_st->client);

	dSP;

	ENTER;
	SAVETMPS;

	PUSHMARK(SP);
	task_sv= sv_newmortal();
	sv_setref_pv(task_sv, "GearmanTaskPtr", task);
	XPUSHs(task_sv);
	PUTBACK;

	count= call_sv(task_cb->fail_fn, G_SCALAR);
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
	gearman_client_task_cb *task_cb;
	SV * task_sv;
	int count;
	gearman_return_t ret;

	fn_arg_st= (gearman_task_fn_arg_st *)gearman_task_fn_arg(task);
	task_cb= (gearman_client_task_cb *)gearman_client_data(fn_arg_st->client);

	dSP;

	ENTER;
	SAVETMPS;

	PUSHMARK(SP);
	task_sv= sv_newmortal();
	sv_setref_pv(task_sv, "GearmanTaskPtr", task);
	XPUSHs(task_sv);
	PUTBACK;

	count= call_sv(task_cb->status_fn, G_SCALAR);
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
	gearman_client_task_cb *task_cb;
	SV * task_sv;
	int count;
	gearman_return_t ret;

	fn_arg_st= (gearman_task_fn_arg_st *)gearman_task_fn_arg(task);
	task_cb= (gearman_client_task_cb *)gearman_client_data(fn_arg_st->client);

	dSP;

	ENTER;
	SAVETMPS;

	PUSHMARK(SP);
	task_sv= sv_newmortal();
	sv_setref_pv(task_sv, "GearmanTaskPtr", task);
	XPUSHs(task_sv);
	PUTBACK;

	count= call_sv(task_cb->created_fn, G_SCALAR);
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
	gearman_client_task_cb *task_cb;
	SV * task_sv;
	int count;
	gearman_return_t ret;

	fn_arg_st= (gearman_task_fn_arg_st *)gearman_task_fn_arg(task);
	task_cb= (gearman_client_task_cb *)gearman_client_data(fn_arg_st->client);

	dSP;

	ENTER;
	SAVETMPS;

	PUSHMARK(SP);
	task_sv= sv_newmortal();
	sv_setref_pv(task_sv, "GearmanTaskPtr", task);
	XPUSHs(task_sv);
	PUTBACK;

	count= call_sv(task_cb->data_fn, G_SCALAR);
	if (count != 1)
		croak("Invalid number of return values.\n");

	SPAGAIN;

	ret= POPi;

	PUTBACK;
	FREETMPS;
	LEAVE;

	return ret;
}

MODULE = Gearman::XS		PACKAGE = Gearman::XS

PROTOTYPES: ENABLE

BOOT:
{
	HV *stash;
	stash= gv_stashpvn("Gearman::XS", 11, TRUE);

	# defines
	newCONSTSUB(stash, "GEARMAN_DEFAULT_TCP_HOST",			newSVpv(GEARMAN_DEFAULT_TCP_HOST, strlen(GEARMAN_DEFAULT_TCP_HOST))	);
	newCONSTSUB(stash, "GEARMAN_DEFAULT_TCP_PORT",			newSViv(GEARMAN_DEFAULT_TCP_PORT)									);

	# gearman_return_t
	newCONSTSUB(stash, "GEARMAN_SUCCESS",					newSViv(GEARMAN_SUCCESS)											);
	newCONSTSUB(stash, "GEARMAN_IO_WAIT",					newSViv(GEARMAN_IO_WAIT)											);
	newCONSTSUB(stash, "GEARMAN_SHUTDOWN",					newSViv(GEARMAN_SHUTDOWN)											);
	newCONSTSUB(stash, "GEARMAN_SHUTDOWN_GRACEFUL",			newSViv(GEARMAN_SHUTDOWN_GRACEFUL)									);
	newCONSTSUB(stash, "GEARMAN_ERRNO",						newSViv(GEARMAN_ERRNO)												);
	newCONSTSUB(stash, "GEARMAN_EVENT",						newSViv(GEARMAN_EVENT)												);
	newCONSTSUB(stash, "GEARMAN_TOO_MANY_ARGS",				newSViv(GEARMAN_TOO_MANY_ARGS)										);
	newCONSTSUB(stash, "GEARMAN_NO_ACTIVE_FDS",				newSViv(GEARMAN_NO_ACTIVE_FDS)										);
	newCONSTSUB(stash, "GEARMAN_INVALID_MAGIC",				newSViv(GEARMAN_INVALID_MAGIC)										);
	newCONSTSUB(stash, "GEARMAN_INVALID_COMMAND",			newSViv(GEARMAN_INVALID_COMMAND)									);
	newCONSTSUB(stash, "GEARMAN_INVALID_PACKET",			newSViv(GEARMAN_INVALID_PACKET)										);
	newCONSTSUB(stash, "GEARMAN_UNEXPECTED_PACKET",			newSViv(GEARMAN_UNEXPECTED_PACKET)									);
	newCONSTSUB(stash, "GEARMAN_GETADDRINFO",				newSViv(GEARMAN_GETADDRINFO)										);
	newCONSTSUB(stash, "GEARMAN_NO_SERVERS",				newSViv(GEARMAN_NO_SERVERS)											);
	newCONSTSUB(stash, "GEARMAN_LOST_CONNECTION",			newSViv(GEARMAN_LOST_CONNECTION)									);
	newCONSTSUB(stash, "GEARMAN_MEMORY_ALLOCATION_FAILURE",	newSViv(GEARMAN_MEMORY_ALLOCATION_FAILURE)							);
	newCONSTSUB(stash, "GEARMAN_JOB_EXISTS",				newSViv(GEARMAN_JOB_EXISTS)											);
	newCONSTSUB(stash, "GEARMAN_JOB_QUEUE_FULL",			newSViv(GEARMAN_JOB_QUEUE_FULL)										);
	newCONSTSUB(stash, "GEARMAN_SERVER_ERROR",				newSViv(GEARMAN_SERVER_ERROR)										);
	newCONSTSUB(stash, "GEARMAN_WORK_ERROR",				newSViv(GEARMAN_WORK_ERROR)											);
	newCONSTSUB(stash, "GEARMAN_WORK_DATA",					newSViv(GEARMAN_WORK_DATA)											);
	newCONSTSUB(stash, "GEARMAN_WORK_WARNING",				newSViv(GEARMAN_WORK_WARNING)										);
	newCONSTSUB(stash, "GEARMAN_WORK_STATUS",				newSViv(GEARMAN_WORK_STATUS)										);
	newCONSTSUB(stash, "GEARMAN_WORK_EXCEPTION",			newSViv(GEARMAN_WORK_EXCEPTION)										);
	newCONSTSUB(stash, "GEARMAN_WORK_FAIL",					newSViv(GEARMAN_WORK_FAIL)											);
	newCONSTSUB(stash, "GEARMAN_NOT_CONNECTED",				newSViv(GEARMAN_NOT_CONNECTED)										);
	newCONSTSUB(stash, "GEARMAN_COULD_NOT_CONNECT",			newSViv(GEARMAN_COULD_NOT_CONNECT)									);
	newCONSTSUB(stash, "GEARMAN_SEND_IN_PROGRESS",			newSViv(GEARMAN_SEND_IN_PROGRESS)									);
	newCONSTSUB(stash, "GEARMAN_RECV_IN_PROGRESS",			newSViv(GEARMAN_RECV_IN_PROGRESS)									);
	newCONSTSUB(stash, "GEARMAN_NOT_FLUSHING",				newSViv(GEARMAN_NOT_FLUSHING)										);
	newCONSTSUB(stash, "GEARMAN_DATA_TOO_LARGE",			newSViv(GEARMAN_DATA_TOO_LARGE)										);
	newCONSTSUB(stash, "GEARMAN_INVALID_FUNCTION_NAME",		newSViv(GEARMAN_INVALID_FUNCTION_NAME)								);
	newCONSTSUB(stash, "GEARMAN_INVALID_WORKER_FUNCTION",	newSViv(GEARMAN_INVALID_WORKER_FUNCTION)							);
	newCONSTSUB(stash, "GEARMAN_NO_REGISTERED_FUNCTIONS",	newSViv(GEARMAN_NO_REGISTERED_FUNCTIONS)							);
	newCONSTSUB(stash, "GEARMAN_NO_JOBS",					newSViv(GEARMAN_NO_JOBS)											);
	newCONSTSUB(stash, "GEARMAN_ECHO_DATA_CORRUPTION",		newSViv(GEARMAN_ECHO_DATA_CORRUPTION)								);
	newCONSTSUB(stash, "GEARMAN_NEED_WORKLOAD_FN",			newSViv(GEARMAN_NEED_WORKLOAD_FN)									);
	newCONSTSUB(stash, "GEARMAN_PAUSE",						newSViv(GEARMAN_PAUSE)												);
	newCONSTSUB(stash, "GEARMAN_UNKNOWN_STATE",				newSViv(GEARMAN_UNKNOWN_STATE)										);
	newCONSTSUB(stash, "GEARMAN_PTHREAD",					newSViv(GEARMAN_PTHREAD)											);
	newCONSTSUB(stash, "GEARMAN_PIPE_EOF",					newSViv(GEARMAN_PIPE_EOF)											);

	# gearman_worker_options_t
	newCONSTSUB(stash, "GEARMAN_WORKER_ALLOCATED",			newSViv(GEARMAN_WORKER_ALLOCATED)									);
	newCONSTSUB(stash, "GEARMAN_WORKER_NON_BLOCKING",		newSViv(GEARMAN_WORKER_NON_BLOCKING)								);
	newCONSTSUB(stash, "GEARMAN_WORKER_PACKET_INIT",		newSViv(GEARMAN_WORKER_PACKET_INIT)									);
	newCONSTSUB(stash, "GEARMAN_WORKER_GRAB_JOB_IN_USE",	newSViv(GEARMAN_WORKER_GRAB_JOB_IN_USE)								);
	newCONSTSUB(stash, "GEARMAN_WORKER_PRE_SLEEP_IN_USE",	newSViv(GEARMAN_WORKER_PRE_SLEEP_IN_USE)							);
	newCONSTSUB(stash, "GEARMAN_WORKER_WORK_JOB_IN_USE",	newSViv(GEARMAN_WORKER_WORK_JOB_IN_USE)								);
	newCONSTSUB(stash, "GEARMAN_WORKER_CHANGE",				newSViv(GEARMAN_WORKER_CHANGE)										);
	newCONSTSUB(stash, "GEARMAN_WORKER_GRAB_UNIQ",			newSViv(GEARMAN_WORKER_GRAB_UNIQ)									);
}

MODULE = Gearman::XS		PACKAGE = Gearman::XS::Client

GearmanClient *
GearmanClient::new()
	CODE:
		gearman_client_st *gc;
		gearman_client_task_cb *task_cb;

		gc= gearman_client_create(NULL);
		task_cb= safemalloc(sizeof(gearman_client_task_cb));
		if (task_cb == NULL)
			croak("Memory allocation error.\n");

		memset(task_cb, 0, sizeof(gearman_client_task_cb));
		gearman_client_set_data(gc, task_cb);
		gearman_client_set_options(gc, GEARMAN_CLIENT_FREE_TASKS, 1);
		gearman_client_set_workload_malloc(gc, _perl_malloc, NULL);
		gearman_client_set_workload_free(gc, _perl_free, NULL);
		gearman_client_set_task_fn_arg_free(gc, _perl_task_free);
		RETVAL= (GearmanClient *)gc;
	OUTPUT:
		RETVAL

MODULE = Gearman::XS		PACKAGE = GearmanClientPtr		PREFIX = xsgc_

gearman_return_t
xsgc_add_server(gc, ...)
		GearmanClient *gc
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
		RETVAL= gearman_client_add_server(gc, host, port);
	OUTPUT:
		RETVAL

gearman_return_t
xsgc_add_servers(gc, servers)
		GearmanClient *gc
		const char *servers
	CODE:
		RETVAL= gearman_client_add_servers(gc, servers);
	OUTPUT:
		RETVAL

gearman_return_t
xsgc_echo(gc, workload)
		GearmanClient *gc
		SV * workload
	CODE:
		RETVAL= gearman_client_echo(gc, SvPV_nolen(workload), SvCUR(workload));
	OUTPUT:
		RETVAL

void
xsgc_do(gc, function_name, workload, ...)
		GearmanClient *gc
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
		result= gearman_client_do(gc, function_name, unique,
										SvPV_nolen(workload), SvCUR(workload),
										&result_size, &ret);
		XPUSHs(sv_2mortal(newSViv(ret)));
		if ((ret == GEARMAN_WORK_DATA) || (ret == GEARMAN_SUCCESS))
		{
			XPUSHs(sv_2mortal(newSVpvn(result, result_size)));
			Safefree(result);
		}

void
xsgc_do_high(gc, function_name, workload, ...)
		GearmanClient *gc
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
		result= (char *)gearman_client_do_high(gc, function_name, unique,
										SvPV_nolen(workload), SvCUR(workload),
										&result_size, &ret);
		XPUSHs(sv_2mortal(newSViv(ret)));
		if ((ret == GEARMAN_WORK_DATA) || (ret == GEARMAN_SUCCESS))
		{
			XPUSHs(sv_2mortal(newSVpvn(result, result_size)));
			Safefree(result);
		}

void
xsgc_do_low(gc, function_name, workload, ...)
		GearmanClient *gc
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
		result= (char *)gearman_client_do_low(gc, function_name, unique,
										SvPV_nolen(workload), SvCUR(workload),
										&result_size, &ret);
		XPUSHs(sv_2mortal(newSViv(ret)));
		if ((ret == GEARMAN_WORK_DATA) || (ret == GEARMAN_SUCCESS))
		{
			XPUSHs(sv_2mortal(newSVpvn(result, result_size)));
			Safefree(result);
		}

void
xsgc_do_background(gc, function_name, workload, ...)
		GearmanClient *gc
		const char *function_name
		SV * workload
	PREINIT:
		char job_handle[GEARMAN_JOB_HANDLE_SIZE];
		const char *unique= NULL;
		gearman_return_t ret;
	PPCODE:
		if (items > 3)
			unique= (char *)SvPV(ST(3), PL_na);
		ret= gearman_client_do_background(gc, function_name, unique,
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
xsgc_do_high_background(gc, function_name, workload, ...)
		GearmanClient *gc
		const char *function_name
		SV * workload
	PREINIT:
		char job_handle[GEARMAN_JOB_HANDLE_SIZE];
		const char *unique= NULL;
		gearman_return_t ret;
	PPCODE:
		if (items > 3)
			unique= (char *)SvPV(ST(3), PL_na);
		ret= gearman_client_do_high_background(gc, function_name, unique,
										SvPV_nolen(workload), SvCUR(workload),
										job_handle);
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
xsgc_do_low_background(gc, function_name, workload, ...)
		GearmanClient *gc
		const char *function_name
		SV * workload
	PREINIT:
		char job_handle[GEARMAN_JOB_HANDLE_SIZE];
		const char *unique= NULL;
		gearman_return_t ret;
	PPCODE:
		if (items > 3)
			unique= (char *)SvPV(ST(3), PL_na);
		ret= gearman_client_do_low_background(gc, function_name, unique,
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
xsgc_add_task(gc, function_name, workload, ...)
		GearmanClient *gc
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
		fn_arg= safemalloc(sizeof(gearman_task_fn_arg_st));
		if (fn_arg == NULL)
			croak("Memory allocation error.\n");

		memset(fn_arg, 0, sizeof(gearman_task_fn_arg_st));
		fn_arg->flags= TASK_FN_ARG_CREATED;
		fn_arg->client= gc;
		fn_arg->workload= w;
		task= gearman_client_add_task(gc, NULL, fn_arg, function_name, unique,
												w,  SvCUR(workload), &ret);

		SV * task_sv= sv_newmortal();
		sv_setref_pv(task_sv, "GearmanTaskPtr", task);

		XPUSHs(sv_2mortal(newSViv(ret)));
		XPUSHs(task_sv);

void
xsgc_add_task_high(gc, function_name, workload, ...)
		GearmanClient *gc
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
		fn_arg= safemalloc(sizeof(gearman_task_fn_arg_st));
		if (fn_arg == NULL)
			croak("Memory allocation error.\n");

		memset(fn_arg, 0, sizeof(gearman_task_fn_arg_st));
		fn_arg->flags= TASK_FN_ARG_CREATED;
		fn_arg->client= gc;
		fn_arg->workload= w;
		task= gearman_client_add_task_high(gc, NULL, fn_arg, function_name,
										unique, w, SvCUR(workload), &ret);

		SV * task_sv= sv_newmortal();
		sv_setref_pv(task_sv, "GearmanTaskPtr", task);

		XPUSHs(sv_2mortal(newSViv(ret)));
		XPUSHs(task_sv);

void
xsgc_add_task_low(gc, function_name, workload, ...)
		GearmanClient *gc
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
		fn_arg= safemalloc(sizeof(gearman_task_fn_arg_st));
		if (fn_arg == NULL)
			croak("Memory allocation error.\n");

		memset(fn_arg, 0, sizeof(gearman_task_fn_arg_st));
		fn_arg->flags= TASK_FN_ARG_CREATED;
		fn_arg->client= gc;
		fn_arg->workload= w;
		task= gearman_client_add_task_low(gc, NULL, fn_arg, function_name,
										unique, w, SvCUR(workload), &ret);

		SV * task_sv= sv_newmortal();
		sv_setref_pv(task_sv, "GearmanTaskPtr", task);

		XPUSHs(sv_2mortal(newSViv(ret)));
		XPUSHs(task_sv);

void
xsgc_add_task_background(gc, function_name, workload, ...)
		GearmanClient *gc
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
		fn_arg= safemalloc(sizeof(gearman_task_fn_arg_st));
		if (fn_arg == NULL)
			croak("Memory allocation error.\n");

		memset(fn_arg, 0, sizeof(gearman_task_fn_arg_st));
		fn_arg->flags= TASK_FN_ARG_CREATED;
		fn_arg->client= gc;
		fn_arg->workload= w;
		task= gearman_client_add_task_background(gc, NULL, fn_arg, function_name,
										unique, w, SvCUR(workload), &ret);

		SV * task_sv= sv_newmortal();
		sv_setref_pv(task_sv, "GearmanTaskPtr", task);

		XPUSHs(sv_2mortal(newSViv(ret)));
		XPUSHs(task_sv);

void
xsgc_add_task_high_background(gc, function_name, workload, ...)
		GearmanClient *gc
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
		fn_arg= safemalloc(sizeof(gearman_task_fn_arg_st));
		if (fn_arg == NULL)
			croak("Memory allocation error.\n");

		memset(fn_arg, 0, sizeof(gearman_task_fn_arg_st));
		fn_arg->flags= TASK_FN_ARG_CREATED;
		fn_arg->client= gc;
		fn_arg->workload= w;
		task= gearman_client_add_task_high_background(gc, NULL, fn_arg, function_name,
										unique, w, SvCUR(workload), &ret);

		SV * task_sv= sv_newmortal();
		sv_setref_pv(task_sv, "GearmanTaskPtr", task);

		XPUSHs(sv_2mortal(newSViv(ret)));
		XPUSHs(task_sv);

void
xsgc_add_task_low_background(gc, function_name, workload, ...)
		GearmanClient *gc
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
		fn_arg= safemalloc(sizeof(gearman_task_fn_arg_st));
		if (fn_arg == NULL)
			croak("Memory allocation error.\n");

		memset(fn_arg, 0, sizeof(gearman_task_fn_arg_st));
		fn_arg->flags= TASK_FN_ARG_CREATED;
		fn_arg->client= gc;
		fn_arg->workload= w;
		task= gearman_client_add_task_low_background(gc, NULL, fn_arg, function_name,
										unique, w, SvCUR(workload), &ret);

		SV * task_sv= sv_newmortal();
		sv_setref_pv(task_sv, "GearmanTaskPtr", task);

		XPUSHs(sv_2mortal(newSViv(ret)));
		XPUSHs(task_sv);

gearman_return_t
xsgc_run_tasks(gc)
		GearmanClient *gc
	CODE:
		RETVAL= gearman_client_run_tasks(gc);
	OUTPUT:
		RETVAL

void
xsgc_set_created_fn(gc, fn)
		GearmanClient *gc
		SV * fn
	CODE:
		gearman_client_task_cb *task_cb;
		task_cb= (gearman_client_task_cb *)gearman_client_data(gc);
		task_cb->created_fn= newSVsv(fn);
		gearman_client_set_created_fn(gc, _perl_task_created_fn);

void
xsgc_set_data_fn(gc, fn)
		GearmanClient *gc
		SV * fn
	CODE:
		gearman_client_task_cb *task_cb;
		task_cb= (gearman_client_task_cb *)gearman_client_data(gc);
		task_cb->data_fn= newSVsv(fn);
		gearman_client_set_data_fn(gc, _perl_task_data_fn);

void
xsgc_set_complete_fn(gc, fn)
		GearmanClient *gc
		SV * fn
	CODE:
		gearman_client_task_cb *task_cb;
		task_cb= (gearman_client_task_cb *)gearman_client_data(gc);
		task_cb->complete_fn= newSVsv(fn);
		gearman_client_set_complete_fn(gc, _perl_task_complete_fn);

void
xsgc_set_fail_fn(gc, fn)
		GearmanClient *gc
		SV * fn
	CODE:
		gearman_client_task_cb *task_cb;
		task_cb= (gearman_client_task_cb *)gearman_client_data(gc);
		task_cb->fail_fn= newSVsv(fn);
		gearman_client_set_fail_fn(gc, _perl_task_fail_fn);

void
xsgc_set_status_fn(gc, fn)
		GearmanClient *gc
		SV * fn
	CODE:
		gearman_client_task_cb *task_cb;
		task_cb= (gearman_client_task_cb *)gearman_client_data(gc);
		task_cb->status_fn= newSVsv(fn);
		gearman_client_set_status_fn(gc, _perl_task_status_fn);

const char *
xsgc_error(gc)
		GearmanClient *gc
	CODE:
		RETVAL= gearman_client_error(gc);
	OUTPUT:
		RETVAL

void
xsgc_do_status(gc)
		GearmanClient *gc
	PREINIT:
		uint32_t numerator;
		uint32_t denominator;
	PPCODE:
		gearman_client_do_status(gc, &numerator, &denominator);
		XPUSHs(sv_2mortal(newSVuv(numerator)));
		XPUSHs(sv_2mortal(newSVuv(denominator)));

void
xsgc_job_status(gc, job_handle="")
		GearmanClient *gc
		const char *job_handle
	PREINIT:
		gearman_return_t ret;
		bool is_known;
		bool is_running;
		uint32_t numerator;
		uint32_t denominator;
	PPCODE:
		ret= gearman_client_job_status(gc, job_handle, &is_known, &is_running,
										&numerator, &denominator);
		XPUSHs(sv_2mortal(newSViv(ret)));
		XPUSHs(sv_2mortal(newSViv(is_known)));
		XPUSHs(sv_2mortal(newSViv(is_running)));
		XPUSHs(sv_2mortal(newSVuv(numerator)));
		XPUSHs(sv_2mortal(newSVuv(denominator)));

void
xsgc_DESTROY(gc)
		GearmanClient *gc
	CODE:
		gearman_client_task_cb *task_cb;
		task_cb= (gearman_client_task_cb *)gearman_client_data(gc);
		Safefree(task_cb);
		gearman_client_free(gc);

MODULE = Gearman::XS		PACKAGE = Gearman::XS::Worker

GearmanWorker *
GearmanWorker::new()
	CODE:
		gearman_worker_st *gw;
		gw= gearman_worker_create(NULL);
		gearman_worker_set_workload_free(gw, _perl_free, NULL);
		gearman_worker_set_workload_malloc(gw, _perl_malloc, NULL);
		RETVAL= (GearmanWorker *)gw;
	OUTPUT:
		RETVAL

MODULE = Gearman::XS		PACKAGE = GearmanWorkerPtr		PREFIX = xsgw_

gearman_return_t
xsgw_add_server(gw, ...)
		GearmanWorker *gw
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
		RETVAL= gearman_worker_add_server(gw, host, port);
	OUTPUT:
		RETVAL

gearman_return_t
xsgw_add_servers(gw, servers)
		GearmanWorker *gw
		const char *servers
	CODE:
		RETVAL= gearman_worker_add_servers(gw, servers);
	OUTPUT:
		RETVAL

gearman_return_t
xsgw_echo(gw, workload)
		GearmanWorker *gw
		SV * workload
	CODE:
		RETVAL= gearman_worker_echo(gw, SvPV_nolen(workload), SvCUR(workload));
	OUTPUT:
		RETVAL

gearman_return_t
xsgw_add_function(gw, function_name, timeout, worker_fn, fn_arg)
		GearmanWorker *gw
		const char *function_name
		uint32_t timeout
		SV * worker_fn
		const char *fn_arg
	INIT:
		gearman_worker_cb *worker_cb;
	CODE:
		worker_cb= safemalloc(sizeof(gearman_worker_cb));
		if (worker_cb == NULL)
			croak("Memory allocation error.\n");

		memset(worker_cb, 0, sizeof(gearman_worker_cb));
		worker_cb->func= newSVsv(worker_fn);
		worker_cb->cb_arg= fn_arg;
		RETVAL= gearman_worker_add_function(gw, function_name, timeout,
											_perl_worker_function_callback,
											(void *)worker_cb );
	OUTPUT:
		RETVAL

gearman_return_t
xsgw_work(gw)
		GearmanWorker *gw
	CODE:
		RETVAL= gearman_worker_work(gw);
	OUTPUT:
		RETVAL

const char *
xsgw_error(gw)
		GearmanWorker *gw
	CODE:
		RETVAL= gearman_worker_error(gw);
	OUTPUT:
		RETVAL

void
xsgw_set_options(gw, options, data)
		GearmanWorker *gw
		gearman_worker_options_t options
		uint32_t data
	CODE:
		gearman_worker_set_options(gw, options, data);

void
xsgw_DESTROY(gw)
		GearmanWorker *gw
	CODE:
		gearman_worker_free(gw);

MODULE = Gearman::XS		PACKAGE = GearmanJobPtr		PREFIX = xsgj_

SV *
xsgj_workload(gj)
		GearmanJob *gj
	CODE:
		RETVAL= newSVpvn(gearman_job_workload(gj), gearman_job_workload_size(gj));
	OUTPUT:
		RETVAL

char *
xsgj_handle(gj)
		GearmanJob *gj
	CODE:
		RETVAL= gearman_job_handle(gj);
	OUTPUT:
		RETVAL

gearman_return_t
xsgj_status(gj, numerator, denominator)
		GearmanJob *gj
		uint32_t numerator
		uint32_t denominator
	CODE:
		RETVAL= gearman_job_status(gj, numerator, denominator);
	OUTPUT:
		RETVAL

const char *
xsgj_function_name(gj)
		GearmanJob *gj
	CODE:
		RETVAL= gearman_job_function_name(gj);
	OUTPUT:
		RETVAL

char *
xsgj_unique(gj)
		GearmanJob *gj
	CODE:
		RETVAL= gearman_job_unique(gj);
	OUTPUT:
		RETVAL

gearman_return_t
xsgj_data(gj, data)
		GearmanJob *gj
		SV * data
	CODE:
		RETVAL= gearman_job_data(gj, SvPV_nolen(data), SvCUR(data));
	OUTPUT:
		RETVAL

gearman_return_t
xsgj_fail(gj)
		GearmanJob *gj
	CODE:
		RETVAL= gearman_job_fail(gj);
	OUTPUT:
		RETVAL

MODULE = Gearman::XS		PACKAGE = GearmanTaskPtr		PREFIX = xsgt_

const char *
xsgt_job_handle(gt)
		GearmanTask *gt
	CODE:
		RETVAL= gearman_task_job_handle(gt);
	OUTPUT:
		RETVAL

SV *
xsgt_data(gt)
		GearmanTask *gt
	CODE:
		RETVAL= newSVpvn(gearman_task_data(gt), gearman_task_data_size(gt));
	OUTPUT:
		RETVAL

int
xsgt_data_size(gt)
		GearmanTask *gt
	CODE:
		RETVAL= gearman_task_data_size(gt);
	OUTPUT:
		RETVAL

const char *
xsgt_function(gt)
		GearmanTask *gt
	CODE:
		RETVAL= gearman_task_function(gt);
	OUTPUT:
		RETVAL

uint32_t
xsgt_numerator(gt)
		GearmanTask *gt
	CODE:
		RETVAL= gearman_task_numerator(gt);
	OUTPUT:
		RETVAL

uint32_t
xsgt_denominator(gt)
		GearmanTask *gt
	CODE:
		RETVAL= gearman_task_denominator(gt);
	OUTPUT:
		RETVAL

const char *
xsgt_uuid(gt)
		GearmanTask *gt
	CODE:
		RETVAL= gearman_task_uuid(gt);
	OUTPUT:
		RETVAL
