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

plan tests => 42;

my ($ret, $job_handle);
my @handles = ();

SKIP: {
  skip('Set $ENV{GEARMAN_LIVE_TEST} to run this test', 42)
    if !$ENV{GEARMAN_LIVE_TEST};

  # client
  my $client= new Gearman::XS::Client;
  isa_ok($client, 'Gearman::XS::Client');

  is($client->error(), '');
  is($client->add_server('127.0.0.1', 4731), GEARMAN_SUCCESS);

  # worker
  my $worker= new Gearman::XS::Worker;
  isa_ok($worker, 'Gearman::XS::Worker');

  $worker->set_options(GEARMAN_WORKER_GRAB_UNIQ, 1);

  is($worker->error(), '');
  is($worker->add_server('127.0.0.1', 4731), GEARMAN_SUCCESS);
  is($worker->add_function("reverse", 0, \&reverse, ''), GEARMAN_SUCCESS);

  my $testlib = new TestLib;
  $testlib->run_gearmand();

  # gearman server running?
  is($client->echo("blubbtest"), GEARMAN_SUCCESS);
  is($worker->echo("blahfasel"), GEARMAN_SUCCESS);

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