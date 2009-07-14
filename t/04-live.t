# Gearman Perl front end
# Copyright (C) 2009 Dennis Schoen
# All rights reserved.
#
# This library is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself, either Perl version 5.8.9 or,
# at your option, any later version of Perl 5 you may have available.

use strict;
use warnings;
use Test::More;
use Storable;
use Gearman::XS qw(:constants);
use FindBin qw( $Bin );
use lib ("$Bin/lib", "$Bin/../lib");
use TestLib;

plan tests => 94;

my ($ret, $result, $job_handle, $task);

my $completed = 0;
my $failed    = 0;
my $numerator = 0;

SKIP: {
  skip('Set $ENV{GEARMAN_LIVE_TEST} to run this test', 94)
    if !$ENV{GEARMAN_LIVE_TEST};

  # client
  my $client= new Gearman::XS::Client;
  isa_ok($client, 'Gearman::XS::Client');

  is($client->error(), '');
  is($client->add_server('127.0.0.1', 4731), GEARMAN_SUCCESS);

  # worker
  my $worker= new Gearman::XS::Worker;
  isa_ok($worker, 'Gearman::XS::Worker');

  is($worker->error(), '');
  is($worker->add_server('127.0.0.1', 4731), GEARMAN_SUCCESS);

  my $testlib = new TestLib;
  $testlib->run_gearmand();
  $testlib->run_test_worker();

  # gearman server running?
  is($client->echo("blubbtest"), GEARMAN_SUCCESS);
  is($worker->echo("blahfasel"), GEARMAN_SUCCESS);

  # single task interface
  ($ret, $result) = $client->do("reverse", 'do');
  is($ret, GEARMAN_SUCCESS);
  is($result, reverse('do'));

  # this tests perls INT return type
  ($ret, $result) = $client->do("add", '3 4');
  is($ret, GEARMAN_SUCCESS);
  is($result, 7);

  # test binary data
  my %hash= (key => 'value');
  my $storable= Storable::nfreeze(\%hash);
  ($ret, $result) = $client->do("storable", $storable);
  is($ret, GEARMAN_SUCCESS);
  is_deeply(\%hash, Storable::thaw($result));

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
  isa_ok($task, 'Gearman::XS::Task');

  ($ret, $task) = $client->add_task_high("reverse", 'high');
  is($ret, GEARMAN_SUCCESS);
  isa_ok($task, 'Gearman::XS::Task');

  ($ret, $task) = $client->add_task_low("reverse", 'low');
  is($ret, GEARMAN_SUCCESS);
  isa_ok($task, 'Gearman::XS::Task');

  # concurrent async interface
  ($ret, $task) = $client->add_task_background("reverse", 'background normal');
  is($ret, GEARMAN_SUCCESS);
  isa_ok($task, 'Gearman::XS::Task');

  ($ret, $task) = $client->add_task_high_background("reverse", 'background high');
  is($ret, GEARMAN_SUCCESS);
  isa_ok($task, 'Gearman::XS::Task');

  ($ret, $task) = $client->add_task_low_background("reverse", 'background low');
  is($ret, GEARMAN_SUCCESS);
  isa_ok($task, 'Gearman::XS::Task');

  # test fail callback
  ($ret, $task) = $client->add_task("quit", "I'll be dead");
  is($ret, GEARMAN_SUCCESS);
  isa_ok($task, 'Gearman::XS::Task');

  ($ret, $task) = $client->add_task("fail", "I will fail.");
  is($ret, GEARMAN_SUCCESS);
  isa_ok($task, 'Gearman::XS::Task');

  # test status callback
  ($ret, $task) = $client->add_task("status", "I'll phone back 4 times");
  is($ret, GEARMAN_SUCCESS);
  isa_ok($task, 'Gearman::XS::Task');
  is($task->numerator(), 0);
  is($task->denominator(), 0);

  # callback functions
  $client->set_created_fn(\&created_cb);
  $client->set_data_fn(\&data_cb);
  $client->set_complete_fn(\&completed_cb);
  $client->set_fail_fn(\&fail_cb);
  $client->set_status_fn(\&status_cb);

  # run concurrent tasks
  is($client->run_tasks(), GEARMAN_SUCCESS);

  # check callback results
  is($completed, 4);
  is($failed, 2);
}

sub created_cb {
  my ($task) = @_;

  like($task->job_handle(), qr/H:.+:.+/);

  return GEARMAN_SUCCESS;
}

sub data_cb {
  my ($task) = @_;

  like($task->job_handle(), qr/H:.+:.+/);
  like($task->data(), qr/\w+/);

  return GEARMAN_SUCCESS;
}

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
  like($task->function(), qr/(fail|quit)/);

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
