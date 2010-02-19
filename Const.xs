/* Gearman Perl front end
 * Copyright (C) 2009 Dennis Schoen
 * All rights reserved.
 *
 * This library is free software; you can redistribute it and/or modify
 * it under the same terms as Perl itself, either Perl version 5.8.9 or,
 * at your option, any later version of Perl 5 you may have available.
 */

#include "gearman_xs.h"

MODULE = Gearman::XS::Const    PACKAGE = Gearman::XS::Const

PROTOTYPES: ENABLE

BOOT:
  HV *stash;
  stash= gv_stashpvn("Gearman::XS", 11, TRUE);
  newCONSTSUB(stash, "GEARMAN_ARGS_BUFFER_SIZE", newSViv(GEARMAN_ARGS_BUFFER_SIZE));
  newCONSTSUB(stash, "GEARMAN_ARGUMENT_TOO_LARGE", newSViv(GEARMAN_ARGUMENT_TOO_LARGE));
  newCONSTSUB(stash, "GEARMAN_CLIENT_ALLOCATED", newSViv(GEARMAN_CLIENT_ALLOCATED));
  newCONSTSUB(stash, "GEARMAN_CLIENT_FREE_TASKS", newSViv(GEARMAN_CLIENT_FREE_TASKS));
  newCONSTSUB(stash, "GEARMAN_CLIENT_MAX", newSViv(GEARMAN_CLIENT_MAX));
  newCONSTSUB(stash, "GEARMAN_CLIENT_NON_BLOCKING", newSViv(GEARMAN_CLIENT_NON_BLOCKING));
  newCONSTSUB(stash, "GEARMAN_CLIENT_NO_NEW", newSViv(GEARMAN_CLIENT_NO_NEW));
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
  newCONSTSUB(stash, "GEARMAN_CON_CLOSE_AFTER_FLUSH", newSViv(GEARMAN_CON_CLOSE_AFTER_FLUSH));
  newCONSTSUB(stash, "GEARMAN_CON_EXTERNAL_FD", newSViv(GEARMAN_CON_EXTERNAL_FD));
  newCONSTSUB(stash, "GEARMAN_CON_IGNORE_LOST_CONNECTION", newSViv(GEARMAN_CON_IGNORE_LOST_CONNECTION));
  newCONSTSUB(stash, "GEARMAN_CON_MAX", newSViv(GEARMAN_CON_MAX));
  newCONSTSUB(stash, "GEARMAN_CON_PACKET_IN_USE", newSViv(GEARMAN_CON_PACKET_IN_USE));
  newCONSTSUB(stash, "GEARMAN_CON_READY", newSViv(GEARMAN_CON_READY));
  newCONSTSUB(stash, "GEARMAN_COULD_NOT_CONNECT", newSViv(GEARMAN_COULD_NOT_CONNECT));
  newCONSTSUB(stash, "GEARMAN_DATA_TOO_LARGE", newSViv(GEARMAN_DATA_TOO_LARGE));
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
  newCONSTSUB(stash, "GEARMAN_JOB_EXISTS", newSViv(GEARMAN_JOB_EXISTS));
  newCONSTSUB(stash, "GEARMAN_JOB_HANDLE_SIZE", newSViv(GEARMAN_JOB_HANDLE_SIZE));
  newCONSTSUB(stash, "GEARMAN_JOB_PRIORITY_HIGH", newSViv(GEARMAN_JOB_PRIORITY_HIGH));
  newCONSTSUB(stash, "GEARMAN_JOB_PRIORITY_LOW", newSViv(GEARMAN_JOB_PRIORITY_LOW));
  newCONSTSUB(stash, "GEARMAN_JOB_PRIORITY_MAX", newSViv(GEARMAN_JOB_PRIORITY_MAX));
  newCONSTSUB(stash, "GEARMAN_JOB_PRIORITY_NORMAL", newSViv(GEARMAN_JOB_PRIORITY_NORMAL));
  newCONSTSUB(stash, "GEARMAN_JOB_QUEUE_FULL", newSViv(GEARMAN_JOB_QUEUE_FULL));
  newCONSTSUB(stash, "GEARMAN_LOST_CONNECTION", newSViv(GEARMAN_LOST_CONNECTION));
  newCONSTSUB(stash, "GEARMAN_MAX", newSViv(GEARMAN_MAX));
  newCONSTSUB(stash, "GEARMAN_MAX_COMMAND_ARGS", newSViv(GEARMAN_MAX_COMMAND_ARGS));
  newCONSTSUB(stash, "GEARMAN_MAX_ERROR_SIZE", newSViv(GEARMAN_MAX_ERROR_SIZE));
  newCONSTSUB(stash, "GEARMAN_MAX_RETURN", newSViv(GEARMAN_MAX_RETURN));
  newCONSTSUB(stash, "GEARMAN_MEMORY_ALLOCATION_FAILURE", newSViv(GEARMAN_MEMORY_ALLOCATION_FAILURE));
  newCONSTSUB(stash, "GEARMAN_NEED_WORKLOAD_FN", newSViv(GEARMAN_NEED_WORKLOAD_FN));
  newCONSTSUB(stash, "GEARMAN_NON_BLOCKING", newSViv(GEARMAN_NON_BLOCKING));
  newCONSTSUB(stash, "GEARMAN_NOT_CONNECTED", newSViv(GEARMAN_NOT_CONNECTED));
  newCONSTSUB(stash, "GEARMAN_NOT_FLUSHING", newSViv(GEARMAN_NOT_FLUSHING));
  newCONSTSUB(stash, "GEARMAN_NO_ACTIVE_FDS", newSViv(GEARMAN_NO_ACTIVE_FDS));
  newCONSTSUB(stash, "GEARMAN_NO_JOBS", newSViv(GEARMAN_NO_JOBS));
  newCONSTSUB(stash, "GEARMAN_NO_REGISTERED_FUNCTION", newSViv(GEARMAN_NO_REGISTERED_FUNCTION));
  newCONSTSUB(stash, "GEARMAN_NO_REGISTERED_FUNCTIONS", newSViv(GEARMAN_NO_REGISTERED_FUNCTIONS));
  newCONSTSUB(stash, "GEARMAN_NO_SERVERS", newSViv(GEARMAN_NO_SERVERS));
  newCONSTSUB(stash, "GEARMAN_OPTION_SIZE", newSViv(GEARMAN_OPTION_SIZE));
  newCONSTSUB(stash, "GEARMAN_PACKET_HEADER_SIZE", newSViv(GEARMAN_PACKET_HEADER_SIZE));
  newCONSTSUB(stash, "GEARMAN_PAUSE", newSViv(GEARMAN_PAUSE));
  newCONSTSUB(stash, "GEARMAN_PIPE_EOF", newSViv(GEARMAN_PIPE_EOF));
  newCONSTSUB(stash, "GEARMAN_PTHREAD", newSViv(GEARMAN_PTHREAD));
  newCONSTSUB(stash, "GEARMAN_QUEUE_ERROR", newSViv(GEARMAN_QUEUE_ERROR));
  newCONSTSUB(stash, "GEARMAN_RECV_BUFFER_SIZE", newSViv(GEARMAN_RECV_BUFFER_SIZE));
  newCONSTSUB(stash, "GEARMAN_RECV_IN_PROGRESS", newSViv(GEARMAN_RECV_IN_PROGRESS));
  newCONSTSUB(stash, "GEARMAN_SEND_BUFFER_SIZE", newSViv(GEARMAN_SEND_BUFFER_SIZE));
  newCONSTSUB(stash, "GEARMAN_SEND_BUFFER_TOO_SMALL", newSViv(GEARMAN_SEND_BUFFER_TOO_SMALL));
  newCONSTSUB(stash, "GEARMAN_SEND_IN_PROGRESS", newSViv(GEARMAN_SEND_IN_PROGRESS));
  newCONSTSUB(stash, "GEARMAN_SERVER_ERROR", newSViv(GEARMAN_SERVER_ERROR));
  newCONSTSUB(stash, "GEARMAN_SHUTDOWN", newSViv(GEARMAN_SHUTDOWN));
  newCONSTSUB(stash, "GEARMAN_SHUTDOWN_GRACEFUL", newSViv(GEARMAN_SHUTDOWN_GRACEFUL));
  newCONSTSUB(stash, "GEARMAN_SUCCESS", newSViv(GEARMAN_SUCCESS));
  newCONSTSUB(stash, "GEARMAN_TIMEOUT", newSViv(GEARMAN_TIMEOUT));
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
  newCONSTSUB(stash, "GEARMAN_VERBOSE_NEVER", newSViv(GEARMAN_VERBOSE_NEVER));
  newCONSTSUB(stash, "GEARMAN_WORKER_ALLOCATED", newSViv(GEARMAN_WORKER_ALLOCATED));
  newCONSTSUB(stash, "GEARMAN_WORKER_CHANGE", newSViv(GEARMAN_WORKER_CHANGE));
  newCONSTSUB(stash, "GEARMAN_WORKER_GRAB_JOB_IN_USE", newSViv(GEARMAN_WORKER_GRAB_JOB_IN_USE));
  newCONSTSUB(stash, "GEARMAN_WORKER_GRAB_UNIQ", newSViv(GEARMAN_WORKER_GRAB_UNIQ));
  newCONSTSUB(stash, "GEARMAN_WORKER_MAX", newSViv(GEARMAN_WORKER_MAX));
  newCONSTSUB(stash, "GEARMAN_WORKER_NON_BLOCKING", newSViv(GEARMAN_WORKER_NON_BLOCKING));
  newCONSTSUB(stash, "GEARMAN_WORKER_PACKET_INIT", newSViv(GEARMAN_WORKER_PACKET_INIT));
  newCONSTSUB(stash, "GEARMAN_WORKER_PRE_SLEEP_IN_USE", newSViv(GEARMAN_WORKER_PRE_SLEEP_IN_USE));
  newCONSTSUB(stash, "GEARMAN_WORKER_TIMEOUT_RETURN", newSViv(GEARMAN_WORKER_TIMEOUT_RETURN));
  newCONSTSUB(stash, "GEARMAN_WORKER_WAIT_TIMEOUT", newSViv(GEARMAN_WORKER_WAIT_TIMEOUT));
  newCONSTSUB(stash, "GEARMAN_WORKER_WORK_JOB_IN_USE", newSViv(GEARMAN_WORKER_WORK_JOB_IN_USE));
  newCONSTSUB(stash, "GEARMAN_WORK_DATA", newSViv(GEARMAN_WORK_DATA));
  newCONSTSUB(stash, "GEARMAN_WORK_ERROR", newSViv(GEARMAN_WORK_ERROR));
  newCONSTSUB(stash, "GEARMAN_WORK_EXCEPTION", newSViv(GEARMAN_WORK_EXCEPTION));
  newCONSTSUB(stash, "GEARMAN_WORK_FAIL", newSViv(GEARMAN_WORK_FAIL));
  newCONSTSUB(stash, "GEARMAN_WORK_STATUS", newSViv(GEARMAN_WORK_STATUS));
  newCONSTSUB(stash, "GEARMAN_WORK_WARNING", newSViv(GEARMAN_WORK_WARNING));
