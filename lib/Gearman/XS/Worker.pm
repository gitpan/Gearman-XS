# Gearman Perl front end
# Copyright (C) 2009 Dennis Schoen
# All rights reserved.
#
# This library is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself, either Perl version 5.8.9 or,
# at your option, any later version of Perl 5 you may have available.

package Gearman::XS::Worker;

use strict;
use warnings;

our $VERSION= '0.5';

use Gearman::XS;

1;
__END__

=head1 NAME

Gearman::XS::Worker - Perl worker for gearman using libgearman

=head1 SYNOPSIS

  use Gearman::XS qw(:constants);
  use Gearman::XS::Worker;

  $worker = new Gearman::XS::Worker;

  $ret = $worker->add_server($host, $port);
  if ($ret != GEARMAN_SUCCESS)
  {
    printf(STDERR "%s\n", $worker->error());
    exit(1);
  }

  $ret = $worker->add_function("reverse", 0, \&reverse, $options);
  if ($ret != GEARMAN_SUCCESS)
  {
    printf(STDERR "%s\n", $worker->error());
  }

  while (1)
  {
    my $ret = $worker->work();
    if ($ret != GEARMAN_SUCCESS)
    {
      printf(STDERR "%s\n", $worker->error());
    }
  }

  sub reverse {
    $job = shift;

    $workload = $job->workload();
    $result   = reverse($workload);

    printf("Job=%s Function_Name=%s Workload=%s Result=%s\n",
            $job->handle(), $job->function_name(), $job->workload(), $result);

    return $result;
  }

=head1 DESCRIPTION

Gearman::XS::Worker is a worker class for the Gearman distributed job system
using libgearman.

=head1 CONSTRUCTOR

=head2 Gearman::XS::Worker->new()

Returns a Gearman::XS::Worker object.

=head1 METHODS

=head2 $worker->add_server($host, $port)

Add a job server to a worker. This goes into a list of servers than can be
used to run tasks. No socket I/O happens here, it is just added to a list.
Returns a standard gearman return value.

=head2 $worker->add_servers($servers)

Add a list of job servers to a worker. The format for the server list is:
SERVER[:PORT][,SERVER[:PORT]]... No socket I/O happens here, it is just added
to a list. Returns a standard gearman return value.

=head2 $worker->echo($data)

Send data to all job servers to see if they echo it back. This is a test
function to see if job servers are responding properly.
Returns a standard gearman return value.

=head2 $worker->add_function($function_name, $timeout, $function, $function_args)

Register and add callback function for worker. Returns a standard gearman
return value.

=head2 $worker->work()

Wait for a job and call the appropriate callback function when it gets one.
Returns a standard gearman return value.

=head2 $worker->grab_job()

Get a job from one of the job servers. Returns a standard gearman return value.

=head2 $worker->error()

Return an error string for the last error encountered.

=head2 $worker->set_options($options, $data)

Set options for a worker structure.

=head1 BUGS

Any in libgearman plus many others of my own.

=head1 COPYRIGHT

Copyright (C) 2009 Dennis Schoen

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.9 or,
at your option, any later version of Perl 5 you may have available.

=head1 WARRANTY

This is free software. IT COMES WITHOUT WARRANTY OF ANY KIND.

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=head1 AUTHOR

Dennis Schoen <dennis@blogma.de>

=cut