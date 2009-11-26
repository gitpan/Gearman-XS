#!/usr/bin/env perl
#
# Gearman Perl front end
# Copyright (C) 2009 Dennis Schoen
# All rights reserved.
# 
# This library is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself, either Perl version 5.8.9 or,
# at your option, any later version of Perl 5 you may have available.

use FindBin qw($Bin);
use lib ("$Bin/../blib/lib", "$Bin/../blib/arch");

use Gearman::XS qw(:constants);
use Gearman::XS::Server;

my $s = Gearman::XS::Server->new('127.0.0.1', 4731);

$s->set_backlog(2);
$s->set_job_retries(3);
$s->set_threads(2);

$s->run();