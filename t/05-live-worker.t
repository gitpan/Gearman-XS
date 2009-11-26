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

plan tests => 57;

my ($ret, $job_handle);
my @handles = ();

my $timeout = 0;

# client
my $client= new Gearman::XS::Client;
isa_ok($client, 'Gearman::XS::Client');

is($client->error(), '');
is($client->add_server('127.0.0.1', 4731), GEARMAN_SUCCESS);

# worker
my $worker= new Gearman::XS::Worker;
isa_ok($worker, 'Gearman::XS::Worker');

$worker->set_log_fn(\&log_callback, 9);

$worker->add_options(GEARMAN_WORKER_GRAB_UNIQ);

is($worker->error(), '');
is($worker->add_server('127.0.0.1', 4731), GEARMAN_SUCCESS);

my $testlib = new TestLib;
$testlib->run_test_server();
sleep(2);

# gearman server running?
is($client->echo("blubbtest"), GEARMAN_SUCCESS);
is($worker->echo("blahfasel"), GEARMAN_SUCCESS);

# low-level function registration
is($worker->register('blah'), GEARMAN_SUCCESS);
is($worker->register('blah_timeout', 10), GEARMAN_SUCCESS);
is($worker->unregister('blah'), GEARMAN_SUCCESS);
is($worker->unregister_all(), GEARMAN_SUCCESS);

# gearman_worker_unregister_all() also remove the server from the list?
is($worker->add_server('127.0.0.1', 4731), GEARMAN_SUCCESS);
$worker->add_options(GEARMAN_WORKER_GRAB_UNIQ);

# high-level function registration
is($worker->add_function("reverse", 0, \&reverse, ''), GEARMAN_SUCCESS);

# single async task interface
($ret, $job_handle) = $client->do_background("reverse", 'do background', 'unique');
is($ret, GEARMAN_SUCCESS);
like($job_handle, qr/H:.+:.+/);
push(@handles, $job_handle);

($ret, $job_handle) = $client->do_high_background("reverse", 'do high background');
is($ret, GEARMAN_SUCCESS);
like($job_handle, qr/H:.+:.+/);
push(@handles, $job_handle);

($ret, $job_handle) = $client->do_low_background("reverse", 'do low background');
is($ret, GEARMAN_SUCCESS);
like($job_handle, qr/H:.+:.+/);
push(@handles, $job_handle);

for my $handle (@handles)
{
  my ($ret, $is_known, $is_running, $numerator, $denominator) = $client->job_status($job_handle);
  is($is_known, 1);
  is($is_running, 0);
  is($ret, GEARMAN_SUCCESS);
}

for (1...3)
{
  is($worker->work(), GEARMAN_SUCCESS);
}

$worker->set_timeout(1000); # 1 second
$ret = $worker->work();
is($ret, GEARMAN_TIMEOUT);

is($timeout, 1);

($ret, $job_handle) = $client->do_background("reverse", 'blubb');
my $job;
($ret, $job) = $worker->grab_job();
is($ret, GEARMAN_SUCCESS);
isa_ok($job, 'Gearman::XS::Job');
is($job->handle(), $job_handle);
is($job->workload(), 'blubb');
is($job->function_name(), 'reverse');
is($job->send_warning('aarg'), GEARMAN_SUCCESS);
is($job->send_complete(reverse($job->workload())), GEARMAN_SUCCESS);


sub log_callback {
  my ($line, $verbose) = @_;

  like($verbose, qr/\d/);

  if ($line =~ /.*wait:timeout reached$/)
  {
    $timeout++;
  }
}

sub reverse {
  my ($job) = @_;

  isa_ok($job, 'Gearman::XS::Job');

  like($job->workload(), qr/\w+/);
  like($job->handle(), qr/H:.+:.+/);
  like($job->unique(), qr/\w+/);
  is($job->function_name(), 'reverse');

  return reverse($job->workload());
}
