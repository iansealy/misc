#!/usr/bin/env perl

# PODNAME: crate_puzzle.pl
# ABSTRACT: Solve school crate puzzle

## Author     : Ian Sealy
## Maintainer : Ian Sealy
## Created    : 2019-03-07

use warnings;
use strict;
use autodie;
use Getopt::Long;
use Pod::Usage;
use Carp;
use version; our $VERSION = qv('v0.1.0');

# Default options
## no critic (ProhibitMagicNumbers)
my $crate_rows  = 4;
my $crate_cols  = 4;
my $num_bottles = 6;
## use critic

my ( $debug, $help, $man );

my $found_solution = 0;
my @crate;
my $count = 0;
while ( !$found_solution ) {
    $count++;

    # Initialise crate
    foreach my $row ( 0 .. $crate_rows - 1 ) {
        foreach my $col ( 0 .. $crate_cols - 1 ) {
            $crate[$row][$col] = 0;
        }
    }

    # Randomly fill crate
    foreach ( 1 .. $num_bottles ) {
        my $bottle_placed = 0;
        while ( !$bottle_placed ) {
            my $row = int rand $crate_rows;
            my $col = int rand $crate_cols;
            if ( !$crate[$row][$col] ) {
                $crate[$row][$col] = 1;
                $bottle_placed = 1;
            }
        }
    }

    # Check if found solution
    $found_solution = 1;
    foreach my $row ( 0 .. $crate_rows - 1 ) {
        my $row_count = 0;
        foreach my $col ( 0 .. $crate_cols - 1 ) {
            $row_count += $crate[$row][$col];
        }
        if ( $row_count % 2 ) {
            $found_solution = 0;
            last;
        }
    }
    foreach my $col ( 0 .. $crate_cols - 1 ) {
        my $col_count = 0;
        foreach my $row ( 0 .. $crate_rows - 1 ) {
            $col_count += $crate[$row][$col];
        }
        if ( $col_count % 2 ) {
            $found_solution = 0;
            last;
        }
    }
}

print "After $count tries, found:\n\n";

foreach my $row ( 0 .. $crate_rows - 1 ) {
    foreach my $col ( 0 .. $crate_cols - 1 ) {
        print $crate[$row][$col];
    }
    print "\n";
}

# Get and check command line options
get_and_check_options();

# Get and check command line options
sub get_and_check_options {

    # Get options
    GetOptions(
        'crate_rows=i'  => \$crate_rows,
        'crate_cols=i'  => \$crate_cols,
        'num_bottles=i' => \$num_bottles,
        'debug'         => \$debug,
        'help'          => \$help,
        'man'           => \$man,
    ) or pod2usage(2);

    # Documentation
    if ($help) {
        pod2usage(1);
    }
    elsif ($man) {
        pod2usage( -verbose => 2 );
    }

    return;
}

__END__
=pod

=encoding UTF-8

=head1 NAME

crate_puzzle.pl

Solve school crate puzzle

=head1 VERSION

version 0.1.0

=head1 DESCRIPTION

This script solves a school puzzle where a number of bottles have to placed in
a crate such that all the rows and columns contain even numbers of bottles.

=head1 EXAMPLES

    perl crate_puzzle.pl

    perl crate_puzzle.pl --crate_rows 4 --crate_cols 4 --num_bottles 6

=head1 USAGE

    crate_puzzle.pl
        [--crate_rows int]
        [--crate_cols int]
        [--num_bottles int]
        [--debug]
        [--help]
        [--man]

=head1 OPTIONS

=over 8

=item B<--crate_rows INT>

Number of rows in the crate.

=item B<--crate_cols INT>

Number of columns in the crate.

=item B<--num_bottles INT>

Number of bottles to be put in the crate.

=item B<--debug>

Print debugging information.

=item B<--help>

Print a brief help message and exit.

=item B<--man>

Print this script's manual page and exit.

=back

=head1 DEPENDENCIES

None

=head1 AUTHOR

=over 4

=item *

Ian Sealy

=back

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2019 by Ian Sealy.

This is free software, licensed under:

  The GNU General Public License, Version 3, June 2007

=cut
