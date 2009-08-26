#!/usr/bin/env perl

# Gearman Perl front end
# Copyright (C) 2009 Dennis Schoen
# All rights reserved.
#
# This library is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself, either Perl version 5.8.9 or,
# at your option, any later version of Perl 5 you may have available.
#
# Example Client

use strict;
use warnings;

use Getopt::Std;

use FindBin qw($Bin);
use lib ("$Bin/../blib/lib", "$Bin/../blib/arch");

use Gearman::XS qw(:constants);
use Gearman::XS::Client;

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

my $client= new Gearman::XS::Client;

my $ret = $client->add_server($host, $port);
if ($ret != GEARMAN_SUCCESS)
{
  printf(STDERR "%s\n", $client->error());
  exit(1);
}

while (1)
{
  my ($ret, $result) = $client->do('reverse', $ARGV[0]);
  if ($ret == GEARMAN_WORK_DATA)
  {
    printf("Data=%s\n", $result);
    next;
  }
  elsif ($ret == GEARMAN_WORK_STATUS)
  {
    my ($numerator, $denominator) = $client->do_status();
    printf("Status: %d/%d\n", $numerator, $denominator);
    next;
  }
  elsif ($ret == GEARMAN_SUCCESS)
  {
    printf("Result=%s\n", ($result || ''));
  }
  elsif ($ret == GEARMAN_WORK_FAIL)
  {
    printf(STDERR "Work failed\n");
  }
  else
  {
    printf(STDERR "%s\n", $client->error());
  }

  last;
}

$ret = $client->echo($ARGV[0]);
if ($ret != GEARMAN_SUCCESS)
{
  printf(STDERR "%s\n", $client->error());
}

exit;

sub usage {
  printf("\nusage: $0 [-h <host>] [-p <port>] <string>\n");
  printf("\t-h <host> - job server host\n");
  printf("\t-p <port> - job server port\n");
}