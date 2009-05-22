# Gearman Perl front end
# Copyright (C) 2009 Dennis Schoen
# All rights reserved.
#
# This library is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself, either Perl version 5.8.9 or,
# at your option, any later version of Perl 5 you may have available.

use strict;
use warnings;

use Test::More tests => 88;
BEGIN { use_ok('Gearman::XS') };
BEGIN { use_ok('Gearman::XS::Client') };
BEGIN { use_ok('Gearman::XS::Worker') };

# import constants
use Gearman::XS qw(:constants);


my ($ret, $result, $job_handle, $task);

my $completed	= 0;
my $failed		= 0;
my $numerator	= 0;

# test some constants
is(GEARMAN_SUCCESS, 0);
is(GEARMAN_WORK_FAIL, 24);

# client
my $client = new Gearman::XS::Client;
isa_ok($client, 'GearmanClientPtr');

is($client->error(), '');

is($client->add_server(), GEARMAN_SUCCESS);
is($client->add_server('localhost'), GEARMAN_SUCCESS);
is($client->add_server('127.0.0.1', 4730), GEARMAN_SUCCESS);

# worker
my $worker = new Gearman::XS::Worker;
isa_ok($worker, 'GearmanWorkerPtr');

$worker->set_options(GEARMAN_WORKER_NON_BLOCKING, 1);
$worker->set_options(GEARMAN_WORKER_NON_BLOCKING, 0);

is($worker->error(), '');

is($worker->add_server(), GEARMAN_SUCCESS);
is($worker->add_server('127.0.0.1'), GEARMAN_SUCCESS);
is($worker->add_server('localhost', 4730), GEARMAN_SUCCESS);

SKIP: {
    skip "Needs gearman server and t/test_worker.pl", 73;

	# gearman server running?
	is($client->echo("blubbtest"), GEARMAN_SUCCESS);
	is($worker->echo("blahfasel"), GEARMAN_SUCCESS);

	# single task interface
	($ret, $result) = $client->do("reverse", 'do');
	is($ret, GEARMAN_SUCCESS);
	is($result, reverse('do'));

	($ret, $result) = $client->do("reverse", 'do unique', 'unique');
	is($ret, GEARMAN_SUCCESS);
	is($result, reverse('do unique'));

	($ret, $result) = $client->do_high("reverse", 'do high');
	is($ret, GEARMAN_SUCCESS);
	is($result, reverse('do high'));

	($ret, $result) = $client->do_low("reverse", 'do low');
	is($ret, GEARMAN_SUCCESS);
	is($result, reverse('do low'));

	# single async task interface
	($ret, $job_handle) = $client->do_background("reverse", 'do background', 'unique');
	is($ret, GEARMAN_SUCCESS);
	like($job_handle, qr/H:.+:.+/);

	($ret, $job_handle) = $client->do_high_background("reverse", 'do high background');
	is($ret, GEARMAN_SUCCESS);
	like($job_handle, qr/H:.+:.+/);

	($ret, $job_handle) = $client->do_low_background("reverse", 'do low background');
	is($ret, GEARMAN_SUCCESS);
	like($job_handle, qr/H:.+:.+/);

	# concurrent interface
	($ret, $task) = $client->add_task("reverse", 'normal');
	is($ret, GEARMAN_SUCCESS);
	isa_ok($task, 'GearmanTaskPtr');

	($ret, $task) = $client->add_task_high("reverse", 'high');
	is($ret, GEARMAN_SUCCESS);
	isa_ok($task, 'GearmanTaskPtr');

	($ret, $task) = $client->add_task_low("reverse", 'low');
	is($ret, GEARMAN_SUCCESS);
	isa_ok($task, 'GearmanTaskPtr');

	# concurrent async interface
	($ret, $task) = $client->add_task_background("reverse", 'background normal');
	is($ret, GEARMAN_SUCCESS);
	isa_ok($task, 'GearmanTaskPtr');

	($ret, $task) = $client->add_task_high_background("reverse", 'background high');
	is($ret, GEARMAN_SUCCESS);
	isa_ok($task, 'GearmanTaskPtr');

	($ret, $task) = $client->add_task_low_background("reverse", 'background low');
	is($ret, GEARMAN_SUCCESS);
	isa_ok($task, 'GearmanTaskPtr');

	# test fail callback
	($ret, $task) = $client->add_task("fail", "I'll be dead");
	is($ret, GEARMAN_SUCCESS);
	isa_ok($task, 'GearmanTaskPtr');

	# test status callback
	my $status_task;
	($ret, $status_task) = $client->add_task("status", "I'll phone back 4 times");
	is($ret, GEARMAN_SUCCESS);
	isa_ok($task, 'GearmanTaskPtr');
	is($status_task->numerator(), 0);
	is($status_task->denominator(), 0);

	# callback functions
	$client->set_complete_fn(\&completed_cb);
	$client->set_fail_fn(\&fail_cb);
	$client->set_status_fn(\&status_cb);

	# run concurrent tasks
	is($client->run_tasks(), GEARMAN_SUCCESS);

	# check status results
	is($status_task->numerator(), 4);
	is($status_task->denominator(), 4);

	# check callback results
	is($completed, 4);
	is($failed, 1);
};

sub completed_cb {
	my ($task) = @_;

	like($task->job_handle(), qr/H:.+:.+/);
	like($task->data(), qr/\w+/);
	like($task->data_size(), qr/\d+/);
	like($task->function(), qr/\w+/);

	$completed++;

	return GEARMAN_SUCCESS;
}

sub fail_cb {
	my ($task) = @_;

	like($task->job_handle(), qr/H:.+:.+/);
	is($task->function(), "fail");

	$failed++;

	return GEARMAN_SUCCESS;
}

sub status_cb {
	my ($task) = @_;

	like($task->job_handle(), qr/H:.+:.+/);
	is($task->function(), "status");
	is($task->denominator(), 4);
	is($task->numerator(), ++$numerator);

	return GEARMAN_SUCCESS;
}