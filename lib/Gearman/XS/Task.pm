# Gearman Perl front end
# Copyright (C) 2009 Dennis Schoen
# All rights reserved.
#
# This library is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself, either Perl version 5.8.9 or,
# at your option, any later version of Perl 5 you may have available.

package Gearman::XS::Task;

our $VERSION= '0.4';

use Gearman::XS;

=head1 NAME

Gearman::XS::Task - Perl task for gearman using libgearman

=head1 DESCRIPTION

Gearman::XS::Task is a task class for the Gearman distributed job system
using libgearman.

=head1 METHODS

=head2 $task->job_handle()

Get job handle for a task.

=head2 $task->data()

Get data being returned for a task.

=head2 $task->data_size()

Get data size being returned for a task.

=head2 $task->function()

Get function name associated with a task.

=head2 $task->numerator()

Get the numerator of percentage complete for a task.

=head2 $task->denominator()

Get the denominator of percentage complete for a task.

=head2 $task->uuid()

Get unique identifier for a task.

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