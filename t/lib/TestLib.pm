package    # hide from PAUSE
  TestLib;

use strict;
use warnings;
use FindBin qw( $Bin );

sub new { return bless {}, shift }

sub run_gearmand {
  my ($self) = @_;
  my $gearmand= `which gearmand`;
  chomp $gearmand;
  die "Cannot locate gearmand in $ENV{PATH}"
  if !$gearmand;
  if ($self->{gearmand_pid}= fork)
  {
    warn("gearmand PID is " . $self->{gearmand_pid});
    sleep 2;
  }
  else {
    die "cannot fork: $!"
      if (!defined $self->{gearmand_pid});
    $|++;
    my @cmd= ($gearmand, '-p', 4731);
    exec(@cmd)
      or die("Could not exec $gearmand");
    exit;
  }
}

sub run_test_worker {
  my ($self) = @_;
  if ($self->{test_worker_pid} = fork)
  {
    warn("test_worker PID is " . $self->{test_worker_pid});
    sleep 2;
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

  for my $proc (qw/gearmand_pid test_worker_pid/)
  {
    system 'kill', $self->{$proc}
      if $self->{$proc};
  }
}

1;
