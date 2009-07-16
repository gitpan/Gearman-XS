# Gearman Perl front end
# Copyright (C) 2009 Dennis Schoen
# All rights reserved.
#
# This library is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself, either Perl version 5.8.9 or,
# at your option, any later version of Perl 5 you may have available.

package Gearman::XS;

use 5.006000;
use XSLoader;
use Exporter;

our @ISA= qw(Exporter);

our $VERSION= '0.4';
XSLoader::load(__PACKAGE__, $VERSION);

my @constants = qw/
  GEARMAN_DEFAULT_TCP_HOST
  GEARMAN_DEFAULT_TCP_PORT

  GEARMAN_SUCCESS
  GEARMAN_IO_WAIT
  GEARMAN_SHUTDOWN
  GEARMAN_SHUTDOWN_GRACEFUL
  GEARMAN_ERRNO
  GEARMAN_EVENT
  GEARMAN_TOO_MANY_ARGS
  GEARMAN_NO_ACTIVE_FDS
  GEARMAN_INVALID_MAGIC
  GEARMAN_INVALID_COMMAND
  GEARMAN_INVALID_PACKET
  GEARMAN_UNEXPECTED_PACKET
  GEARMAN_GETADDRINFO
  GEARMAN_NO_SERVERS
  GEARMAN_LOST_CONNECTION
  GEARMAN_MEMORY_ALLOCATION_FAILURE)
  GEARMAN_JOB_EXISTS
  GEARMAN_JOB_QUEUE_FULL
  GEARMAN_SERVER_ERROR
  GEARMAN_WORK_ERROR
  GEARMAN_WORK_DATA
  GEARMAN_WORK_WARNING
  GEARMAN_WORK_STATUS
  GEARMAN_WORK_EXCEPTION
  GEARMAN_WORK_FAIL
  GEARMAN_NOT_CONNECTED
  GEARMAN_COULD_NOT_CONNECT
  GEARMAN_SEND_IN_PROGRESS
  GEARMAN_RECV_IN_PROGRESS
  GEARMAN_NOT_FLUSHING
  GEARMAN_DATA_TOO_LARGE
  GEARMAN_INVALID_FUNCTION_NAME
  GEARMAN_INVALID_WORKER_FUNCTION
  GEARMAN_NO_REGISTERED_FUNCTIONS
  GEARMAN_NO_JOBS
  GEARMAN_ECHO_DATA_CORRUPTION
  GEARMAN_NEED_WORKLOAD_FN
  GEARMAN_PAUSE
  GEARMAN_UNKNOWN_STATE
  GEARMAN_PTHREAD
  GEARMAN_PIPE_EOF

  GEARMAN_WORKER_ALLOCATED
  GEARMAN_WORKER_NON_BLOCKING
  GEARMAN_WORKER_PACKET_INIT
  GEARMAN_WORKER_GRAB_JOB_IN_USE
  GEARMAN_WORKER_PRE_SLEEP_IN_USE
  GEARMAN_WORKER_WORK_JOB_IN_USE
  GEARMAN_WORKER_CHANGE
  GEARMAN_WORKER_GRAB_UNIQ
/;

our %EXPORT_TAGS = (constants => [ @constants ]);
our @EXPORT_OK = @constants;

=head1 NAME

Gearman::XS - Perl front end for the Gearman C library.

=head1 DESCRIPTION

This is the Perl API for Gearman, a distributed job system.
More information is available at:

  http://www.gearman.org

It aims to provide a simple interface closely tied to the C library.

=head1 BUGS

Any in libgearman plus many others of my own.

=head1 COPYRIGHT

Copyright (C) 2009 Dennis Schoen

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.9 or,
at your option, any later version of Perl 5 you may have available.

=head1 WARRANTY

This is free software. IT COMES WITHOUT WARRANTY OF ANY KIND.

=head1 AUTHORS

Dennis Schoen <dennis@blogma.de>

=cut

1;