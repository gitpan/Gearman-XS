package    # hide from PAUSE
  TestLib;

use strict;
use warnings;
use FindBin qw( $Bin );

sub new { return bless {}, shift }

sub run_test_server {
  my ($self) = @_;
  if ($self->{test_server_pid}= fork)
  {
    warn("test_server PID is " . $self->{test_server_pid});
  }
  else {
    die "cannot fork: $!"
      if (!defined $self->{test_server_pid});
    $|++;
    my @cmd = ($^X, "$Bin/test_server.pl");
    exec(@cmd)
      or die("Could not exec $Bin/test_server.pl");
    exit;
  }
}

sub run_test_worker {
  my ($self) = @_;
  if ($self->{test_worker_pid} = fork)
  {
    warn("test_worker PID is " . $self->{test_worker_pid});
  }
  else
  {
    die "cannot fork: $!"
      if (!defined $self->{test_worker_pid});
    $|++;
    my @cmd = ($^X, "$Bin/test_worker.pl");
    exec(@cmd)
      or die("Could not exec $Bin/test_worker.pl");
    exit;
  }
}

sub DESTROY {
  my ($self) = @_;

  for my $proc (qw/test_server_pid test_worker_pid/)
  {
    system 'kill', $self->{$proc}
      if $self->{$proc};
  }
}

1;
