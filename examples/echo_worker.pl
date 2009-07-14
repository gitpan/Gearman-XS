#!/usr/bin/env perl

# Gearman Perl front end
# Copyright (C) 2009 Dennis Schoen
# All rights reserved.
#
# This library is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself, either Perl version 5.8.9 or,
# at your option, any later version of Perl 5 you may have available.
#
# Echo Worker

use strict;
use warnings;

use Getopt::Std;

use FindBin qw($Bin);
use lib ("$Bin/../blib/lib", "$Bin/../blib/arch");

use Gearman::XS qw(:constants);
use Gearman::XS::Worker;

my %opts;
if (!getopts('h:p:', \%opts))
{
  usage();
  exit(1);
}

my $host= $opts{h} || '';
my $port= $opts{p} || 0;

if (scalar @ARGV < 1)
{
  usage();
  exit(1);
}

my $worker= new Gearman::XS::Worker;

my $ret= $worker->add_server($host, $port);
if ($ret != GEARMAN_SUCCESS)
{
  printf(STDERR "%s\n", $worker->error());
  exit(1);
}

$ret= $worker->echo($ARGV[0]);
if ($ret != GEARMAN_SUCCESS)
{
  printf(STDERR "%s\n", $worker->error());
}

exit;

sub usage {
  printf("\nusage: $0 [-h <host>] [-p <port>] <string>\n");
  printf("\t-h <host> - job server host\n");
  printf("\t-p <port> - job server port\n");
}