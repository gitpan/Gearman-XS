# Gearman Perl front end
# Copyright (C) 2009 Dennis Schoen
# All rights reserved.
#
# This library is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself, either Perl version 5.8.9 or,
# at your option, any later version of Perl 5 you may have available.

use strict;
use warnings;

use Test::More tests => 19;

# import constants
use Gearman::XS qw(:constants);

# test some constants
is(GEARMAN_SUCCESS, 0);
is(GEARMAN_WORK_FAIL, 24);

# client
my $client = new Gearman::XS::Client;
isa_ok($client, 'Gearman::XS::Client');

is($client->error(), '');

is($client->add_server(), GEARMAN_SUCCESS);
is($client->add_server('localhost'), GEARMAN_SUCCESS);
is($client->add_server('127.0.0.1', 4730), GEARMAN_SUCCESS);
is($client->add_servers('127.0.0.1:4730,127.0.0.1'), GEARMAN_SUCCESS);

# worker
my $worker = new Gearman::XS::Worker;
isa_ok($worker, 'Gearman::XS::Worker');

$worker->set_options(GEARMAN_WORKER_NON_BLOCKING, 1);
$worker->set_options(GEARMAN_WORKER_NON_BLOCKING, 0);

is($worker->error(), '');

is($worker->add_server(), GEARMAN_SUCCESS);
is($worker->add_server('127.0.0.1'), GEARMAN_SUCCESS);
is($worker->add_server('localhost', 4730), GEARMAN_SUCCESS);
is($client->add_servers('localhost:4730,127.0.0.1'), GEARMAN_SUCCESS);

$client = new Gearman::XS::Client;
$client->add_server('127.0.0.1', 61333);

$worker = new Gearman::XS::Worker;
$worker->add_server('213.3.4.5', 61333);

# no functions
is($worker->work(), GEARMAN_NO_REGISTERED_FUNCTIONS);
is($worker->grab_job(), GEARMAN_NO_REGISTERED_FUNCTIONS);

# no connection
my ($ret, $job_handle) = $client->do_background("reverse", 'do background', 'unique');
is($ret, GEARMAN_COULD_NOT_CONNECT);
is($job_handle, undef);
is($client->error(), 'gearman_con_flush:could not connect');