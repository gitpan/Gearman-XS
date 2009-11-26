# Gearman Perl front end
# Copyright (C) 2009 Dennis Schoen
# All rights reserved.
#
# This library is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself, either Perl version 5.8.9 or,
# at your option, any later version of Perl 5 you may have available.

package Gearman::XS::Server;

use strict;
use warnings;

our $VERSION= '0.7';

use Gearman::XS;

1;
__END__

=head1 NAME

Gearman::XS::Server - Perl gearman server using libgearman-server

=head1 SYNOPSIS

  use Gearman::XS qw(:constants);
  use Gearman::XS::Server;

  $server = Gearman::XS::Server->new();
  $server->run();

=head1 DESCRIPTION

Gearman::XS::Server is a server class for the Gearman distributed job system
using libgearman-server.

=head1 CONSTRUCTOR

=head2 Gearman::XS::Server->new($host, $port)

Create a server instance. If host and port are not specified they default to
GEARMAN_DEFAULT_TCP_HOST and GEARMAN_DEFAULT_TCP_PORT.
Returns a Gearman::XS::Server object.

=head1 METHODS

=head2 $server->run()

Run the server instance. Returns a standard gearman return value.

=head2 $server->set_backlog($num)

Set number of backlog connections for listening connection.

=head2 $server->set_job_retries($num)

Set maximum job retry count.

=head2 $server->set_threads($num)

Set number of I/O threads for server to use.

=head1 BUGS

Any in libgearman-server plus many others of my own.

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
