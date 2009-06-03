#!/usr/bin/env perl
#
# Gearman Perl front end
# Copyright (C) 2009 Dennis Schoen
# All rights reserved.
# 
# This library is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself, either Perl version 5.8.9 or,
# at your option, any later version of Perl 5 you may have available.

use Storable;
use Data::Dumper;

use FindBin qw($Bin);
use lib ("$Bin/../blib/lib", "$Bin/../blib/arch");

use Gearman::XS qw(:constants);
use Gearman::XS::Worker;

my $worker = new Gearman::XS::Worker;
$worker->add_servers('127.0.0.1:4730');

$worker->add_function("reverse", 0, \&reverse, '');
$worker->add_function("fail", 0, \&fail, '');
$worker->add_function("status", 0, \&status, '');
$worker->add_function("storable", 0, \&storable, '');
$worker->add_function("add", 0, \&add, '');
$worker->add_function("die", 0, \&die, '');

while (1) {
	my $ret = $worker->work();
	if ($ret != GEARMAN_SUCCESS) {
		printf(STDERR "%s\n", $worker->error());
	}
}

sub reverse {
	my ($job) = @_;

	my $workload	= $job->workload();
	my $result		= reverse($workload);

	printf("Job=%s Function_Name=%s Workload=%s Result=%s\n",
			$job->handle(), $job->function_name(), $job->workload(), $result);

	return $result;
}

sub die {
	my ($job) = @_;

	my $workload = $job->workload();

	printf("Job=%s Function_Name=%s Workload=%s\n",
			$job->handle(), $job->function_name(), $job->workload());

	die "I'm out.\n";
}

sub status {
	my ($job) = @_;

	printf("Job=%s Function_Name=%s Workload=%s\n",
			$job->handle(), $job->function_name(), $job->workload());

	$job->status(1, 4);
	sleep(1);
	$job->status(2, 4);
	sleep(1);
	$job->status(3, 4);
	sleep(1);
	$job->status(4, 4);

	return 1;
}

sub add {
	my ($job) = @_;

	printf("Job=%s Function_Name=%s Workload=%s\n",
			$job->handle(), $job->function_name(), $job->workload());

	my ($a, $b) = split(/\s+/, $job->workload());

	return ($a + $b);
}

sub storable {
	my ($job) = @_;

	my $storable = $job->workload();
	my $workload = Storable::thaw($storable);

	printf("Job=%s Function_Name=%s Workload=%s",
			$job->handle(), $job->function_name(), Dumper($workload), $result);

	return Storable::nfreeze($workload);
}

sub fail {
	my ($job) = @_;

	my $workload = $job->workload();

	printf("Job=%s Function_Name=%s Workload=%s\n",
			$job->handle(), $job->function_name(), $job->workload());

	$job-fail();
}
