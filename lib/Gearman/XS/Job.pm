# Gearman Perl front end
# Copyright (C) 2009 Dennis Schoen
# All rights reserved.
#
# This library is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself, either Perl version 5.8.9 or,
# at your option, any later version of Perl 5 you may have available.

package Gearman::XS::Job;

our $VERSION= '0.3';

use Gearman::XS;

=head1 NAME

Gearman::XS::Job - Perl job for gearman using libgearman

=head1 DESCRIPTION

Gearman::XS::Job is a job class for the Gearman distributed job system
using libgearman.

=head1 METHODS

=head2 $job->workload()

Get the workload for a job.

=head2 $job->handle()

Get job handle.

=head2 $job->status($numerator, $denominator)

Send status information for a running job. Returns a standard gearman return
value.

=head2 $job->function_name()

Get the function name associated with a job.

=head2 $job->unique()

Get the unique ID associated with a job.

=head2 $job->data($data)

Send data for a running job. Returns a standard gearman return value.

=head2 $job->fail()

Send fail status for a job. Returns a standard gearman return value.

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