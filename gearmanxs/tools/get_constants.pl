#!/usr/bin/env perl
use strict;
use warnings;
use Path::Class;

my @paths = ( '/usr/include', '/usr/local/include', '/opt/gearmand/include', '/opt/local/include' );

my @constants = get_constants();

my @string_constants = qw/GEARMAN_DEFAULT_TCP_HOST/;

print_gearman_xs_constants( \@constants );
print_gearman_xs_constsubs( \@constants );

sub get_constants {
  my $constants_h;

  if ( my $path = shift(@ARGV) ) {
    $constants_h = file($path)->slurp;
  }

  else {
    foreach my $path (@paths) {
      eval { $constants_h = file("$path/libgearman/constants.h")->slurp; };
    }
    die "Could not find libgearman/constants.h in " . join ":", @paths unless $constants_h;
  }

  my $regex = qr/ (GEARMAN_[A-Z_]+)/;
  my @constants = $constants_h =~ /$regex/g;

  @constants = sort keys %{ { map { $_ => 1 } @constants } };

  return @constants;
}

sub print_gearman_xs_constants {
  my ($constants) = @_;

  local $" = "\n  ";

  print <<EOF;
# Copy & Paste to lib/Gearman/XS.pm
my \@constants = qw/
  @$constants
/;
EOF
}

sub print_gearman_xs_constsubs {
  my ($constants) = @_;
  print "# Copy & Paste to Const.xs\n";
  foreach my $constant (@$constants) {
    if ( grep $_ eq $constant, @string_constants ) {
      print "  " . qq{newCONSTSUB(stash, "$constant", newSVpv($constant,strlen($constant)));\n};
    }
    else {
      print "  " . qq{newCONSTSUB(stash, "$constant", newSViv($constant));\n};
    }
  }
}
