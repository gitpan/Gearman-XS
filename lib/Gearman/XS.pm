# Gearman Perl front end
# Copyright (C) 2013 Data Differential, http://datadifferential.com/
# Copyright (C) 2009-2010 Dennis Schoen
# All rights reserved.
#
# This library is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself, either Perl version 5.8.9 or,
# at your option, any later version of Perl 5 you may have available.

package Gearman::XS;

use strict;
use warnings;
use 5.006000;

my @constants = qw/
  GEARMAN_ARGS_BUFFER_SIZE
  GEARMAN_ARGUMENT_TOO_LARGE
  GEARMAN_CLIENT_ALLOCATED
  GEARMAN_CLIENT_FREE_TASKS
  GEARMAN_CLIENT_MAX
  GEARMAN_CLIENT_NON_BLOCKING
  GEARMAN_CLIENT_NO_NEW
  GEARMAN_CLIENT_TASK_IN_USE
  GEARMAN_CLIENT_UNBUFFERED_RESULT
  GEARMAN_COMMAND_ALL_YOURS
  GEARMAN_COMMAND_CANT_DO
  GEARMAN_COMMAND_CAN_DO
  GEARMAN_COMMAND_CAN_DO_TIMEOUT
  GEARMAN_COMMAND_ECHO_REQ
  GEARMAN_COMMAND_ECHO_RES
  GEARMAN_COMMAND_ERROR
  GEARMAN_COMMAND_GET_STATUS
  GEARMAN_COMMAND_GRAB_JOB
  GEARMAN_COMMAND_GRAB_JOB_UNIQ
  GEARMAN_COMMAND_JOB_ASSIGN
  GEARMAN_COMMAND_JOB_ASSIGN_UNIQ
  GEARMAN_COMMAND_JOB_CREATED
  GEARMAN_COMMAND_MAX
  GEARMAN_COMMAND_NOOP
  GEARMAN_COMMAND_NO_JOB
  GEARMAN_COMMAND_OPTION_REQ
  GEARMAN_COMMAND_OPTION_RES
  GEARMAN_COMMAND_PRE_SLEEP
  GEARMAN_COMMAND_RESET_ABILITIES
  GEARMAN_COMMAND_SET_CLIENT_ID
  GEARMAN_COMMAND_STATUS_RES
  GEARMAN_COMMAND_SUBMIT_JOB
  GEARMAN_COMMAND_SUBMIT_JOB_BG
  GEARMAN_COMMAND_SUBMIT_JOB_EPOCH
  GEARMAN_COMMAND_SUBMIT_JOB_HIGH
  GEARMAN_COMMAND_SUBMIT_JOB_HIGH_BG
  GEARMAN_COMMAND_SUBMIT_JOB_LOW
  GEARMAN_COMMAND_SUBMIT_JOB_LOW_BG
  GEARMAN_COMMAND_SUBMIT_JOB_SCHED
  GEARMAN_COMMAND_TEXT
  GEARMAN_COMMAND_UNUSED
  GEARMAN_COMMAND_WORK_COMPLETE
  GEARMAN_COMMAND_WORK_DATA
  GEARMAN_COMMAND_WORK_EXCEPTION
  GEARMAN_COMMAND_WORK_FAIL
  GEARMAN_COMMAND_WORK_STATUS
  GEARMAN_COMMAND_WORK_WARNING
  GEARMAN_CON_CLOSE_AFTER_FLUSH
  GEARMAN_CON_EXTERNAL_FD
  GEARMAN_CON_IGNORE_LOST_CONNECTION
  GEARMAN_CON_MAX
  GEARMAN_CON_PACKET_IN_USE
  GEARMAN_CON_READY
  GEARMAN_COULD_NOT_CONNECT
  GEARMAN_DATA_TOO_LARGE
  GEARMAN_DEFAULT_SOCKET_RECV_SIZE
  GEARMAN_DEFAULT_SOCKET_SEND_SIZE
  GEARMAN_DEFAULT_SOCKET_TIMEOUT
  GEARMAN_DEFAULT_TCP_HOST
  GEARMAN_DEFAULT_TCP_PORT
  GEARMAN_DONT_TRACK_PACKETS
  GEARMAN_ECHO_DATA_CORRUPTION
  GEARMAN_ERRNO
  GEARMAN_EVENT
  GEARMAN_FLUSH_DATA
  GEARMAN_GETADDRINFO
  GEARMAN_IGNORE_PACKET
  GEARMAN_INVALID_COMMAND
  GEARMAN_INVALID_FUNCTION_NAME
  GEARMAN_INVALID_MAGIC
  GEARMAN_INVALID_PACKET
  GEARMAN_INVALID_WORKER_FUNCTION
  GEARMAN_IO_WAIT
  GEARMAN_JOB_EXISTS
  GEARMAN_JOB_HANDLE_SIZE
  GEARMAN_JOB_PRIORITY_HIGH
  GEARMAN_JOB_PRIORITY_LOW
  GEARMAN_JOB_PRIORITY_MAX
  GEARMAN_JOB_PRIORITY_NORMAL
  GEARMAN_JOB_QUEUE_FULL
  GEARMAN_LOST_CONNECTION
  GEARMAN_MAX
  GEARMAN_MAX_COMMAND_ARGS
  GEARMAN_MAX_ERROR_SIZE
  GEARMAN_MAX_RETURN
  GEARMAN_MEMORY_ALLOCATION_FAILURE
  GEARMAN_NEED_WORKLOAD_FN
  GEARMAN_NON_BLOCKING
  GEARMAN_NOT_CONNECTED
  GEARMAN_NOT_FLUSHING
  GEARMAN_NO_ACTIVE_FDS
  GEARMAN_NO_JOBS
  GEARMAN_NO_REGISTERED_FUNCTION
  GEARMAN_NO_REGISTERED_FUNCTIONS
  GEARMAN_NO_SERVERS
  GEARMAN_OPTION_SIZE
  GEARMAN_PACKET_HEADER_SIZE
  GEARMAN_PAUSE
  GEARMAN_PIPE_EOF
  GEARMAN_PTHREAD
  GEARMAN_QUEUE_ERROR
  GEARMAN_RECV_BUFFER_SIZE
  GEARMAN_RECV_IN_PROGRESS
  GEARMAN_SEND_BUFFER_SIZE
  GEARMAN_SEND_BUFFER_TOO_SMALL
  GEARMAN_SEND_IN_PROGRESS
  GEARMAN_SERVER_ERROR
  GEARMAN_SHUTDOWN
  GEARMAN_SHUTDOWN_GRACEFUL
  GEARMAN_SUCCESS
  GEARMAN_TIMEOUT
  GEARMAN_TOO_MANY_ARGS
  GEARMAN_UNEXPECTED_PACKET
  GEARMAN_UNIQUE_SIZE
  GEARMAN_UNKNOWN_OPTION
  GEARMAN_UNKNOWN_STATE
  GEARMAN_VERBOSE_CRAZY
  GEARMAN_VERBOSE_DEBUG
  GEARMAN_VERBOSE_ERROR
  GEARMAN_VERBOSE_FATAL
  GEARMAN_VERBOSE_INFO
  GEARMAN_VERBOSE_MAX
  GEARMAN_VERBOSE_NEVER
  GEARMAN_WORKER_ALLOCATED
  GEARMAN_WORKER_CHANGE
  GEARMAN_WORKER_GRAB_JOB_IN_USE
  GEARMAN_WORKER_GRAB_UNIQ
  GEARMAN_WORKER_MAX
  GEARMAN_WORKER_NON_BLOCKING
  GEARMAN_WORKER_PACKET_INIT
  GEARMAN_WORKER_PRE_SLEEP_IN_USE
  GEARMAN_WORKER_TIMEOUT_RETURN
  GEARMAN_WORKER_WAIT_TIMEOUT
  GEARMAN_WORKER_WORK_JOB_IN_USE
  GEARMAN_WORK_DATA
  GEARMAN_WORK_ERROR
  GEARMAN_WORK_EXCEPTION
  GEARMAN_WORK_FAIL
  GEARMAN_WORK_STATUS
  GEARMAN_WORK_WARNING
/;

our %EXPORT_TAGS = (constants => [ @constants ]);
our @EXPORT_OK = @constants;

our @ISA;
BEGIN {
  our $VERSION= '0.15';

  eval {
    require XSLoader;
    XSLoader::load(__PACKAGE__, $VERSION);
    1;
  } or do {
    require DynaLoader;
    push @ISA, 'DynaLoader';
    __PACKAGE__->bootstrap($VERSION);
  };
  use Exporter 'import';
};

1;
__END__

=head1 NAME

Gearman::XS - Perl front end for the Gearman C library.

=head1 DESCRIPTION

This is the Perl API for Gearman, a distributed job system.
More information is available at:

  http://www.gearman.org

It aims to provide a simple interface closely tied to the C library.

=head1 METHODS

=head2 Gearman::XS::strerror($ret)

Return string translation of return code.

=head1 BUGS

Any in libgearman plus many others of my own.

=head1 COPYRIGHT

Copyright (C) 2013 Data Differential, ala Brian Aker, http://datadifferential.com/
Copyright (C) 2009-2010 Dennis Schoen

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.9 or,
at your option, any later version of Perl 5 you may have available.

=head1 WARRANTY

This is free software. IT COMES WITHOUT WARRANTY OF ANY KIND.

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Brian Aker <brian@tangent.org>

=cut
