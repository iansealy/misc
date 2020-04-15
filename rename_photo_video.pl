#!/usr/bin/env perl

# PODNAME: rename_photo_video.pl
# ABSTRACT: Rename photo and video files by date and time

## Author     : Ian Sealy
## Maintainer : Ian Sealy
## Created    : 2018-11-29

use warnings;
use strict;
use autodie;
use Getopt::Long;
use Pod::Usage;
use Carp;
use version; our $VERSION = qv('v0.1.0');

use POSIX qw(strftime);
use Readonly;
use Image::ExifTool;
use File::Find;
use File::stat;
use File::Path qw(make_path);
use File::Compare;
use Algorithm::Combinatorics qw(combinations);
use Digest::MD5;

# Constants
Readonly our %EXT_FOR => (
    '3GP'  => '3gp',
    'AVI'  => 'avi',
    'HEIC' => 'heic',
    'JPEG' => 'jpg',
    'MOV'  => 'mov',
    'MP4'  => 'mp4',
    'MPEG' => 'mpg',
    'PNG'  => 'png',
    'OGV'  => 'ogv',
);
Readonly our %MODEL_FOR => (
    'HTC Desire HD A9191' => 'Desire HD',
    'GT-I9300'            => 'Galaxy S3',
    'SM-G900F'            => 'Galaxy S5',
    'SM-G930F'            => 'Galaxy S7',
    'SM-G960F'            => 'Galaxy S9',
);
Readonly our @TAG_ORDER => qw(
  CreateDate
  DateTimeOriginal
  ModifyDate
  GPSDateTime
);

# Default options
my $dry_run;
my $output_dir;
my $extra_dir;

my ( $debug, $help, $man );

# Get and check command line options
get_and_check_options();

my @all_files;
find(
    {
        wanted => sub {
            if (-f) { push @all_files, $_ }
        },
        no_chdir => 1
    },
    @ARGV
);
@all_files = sort @all_files;

if ($debug) {
    printf {*STDERR} "%s Found %d files\n", timestamp(), scalar @all_files;
}

if ($debug) {
    printf {*STDERR} "%s Searching for duplicates\n", timestamp();
}

my %all_size       = get_file_sizes(@all_files);
my @possible_dupes = filter_out_unique(%all_size);
my @definite_dupes = get_dupes(@possible_dupes);

if (@definite_dupes) {
    printf {*STDERR} "%s duplicate file pairs found:\n", scalar @definite_dupes;
    foreach my $pair ( sort { $a->[0] cmp $b->[0] || $a->[1] cmp $b->[1] }
        @definite_dupes )
    {
        printf {*STDERR} "  %s\t%s\n", $pair->[0], $pair->[1];
    }
    die "Please delete all duplicates before proceeding\n";
}

if ($debug) {
    printf {*STDERR} "%s Finished searching for duplicates\n", timestamp();
}

my $exif = Image::ExifTool->new();
$exif->Options( Unknown    => 2 );                      # Get all tags
$exif->Options( DateFormat => '%Y_%m_%d_%H_%M_%S' );    # Date format
foreach my $file (@all_files) {
    my $info = $exif->ImageInfo($file);
    if ($debug) {
        printf {*STDERR} "%s Tag info for file %s\n", timestamp(), $file;
        foreach my $tag ( sort keys %{$info} ) {
            printf {*STDERR} "  %s\t%s:\t%s\n", $file, $tag, $info->{$tag};
        }
    }

    # Check file is photo or video
    if ( !exists $info->{FileType} || !exists $EXT_FOR{ $info->{FileType} } ) {
        printf {*STDERR} "%s Ignoring unknown file %s\n", timestamp(), $file;
        next;
    }

    # Check if preferred timestamp is present
    my $tag_timestamp;
    foreach my $tag (@TAG_ORDER) {
        if ( exists $info->{$tag} ) {
            $tag_timestamp = $info->{$tag};
            last;
        }
    }
    if ( !$tag_timestamp ) {
        printf {*STDERR} "%s No timestamps for %s\n", timestamp(), $file;
        next;
    }

    # Get camera model
    my $model = get_model($info);

    # Get digest
    my $digest = get_digest($file);

    # Make new filename
    my ( $new_dir, $new_file ) =
      get_new_filename( $tag_timestamp, $digest, $model,
        $EXT_FOR{ $info->{FileType} } );

    if ($dry_run) {
        printf "mv %s %s\n", $file, $new_file;
    }
    else {
        make_path($new_dir);
        rename $file, $new_file;
    }
}

# Get file sizes for a list of files
sub get_file_sizes {
    my @files = @_;

    my %size;

    foreach my $file (@files) {
        push @{ $size{ stat($file)->size } }, $file;
    }

    return %size;
}

# Filter out all files with a unique size
sub filter_out_unique {
    my %size = @_;

    my @dupes;

    foreach my $size ( keys %size ) {
        if ( scalar @{ $size{$size} } > 1 ) {
            push @dupes, \@{ $size{$size} };
        }
    }

    return @dupes;
}

# Get all pairs of files that are duplicates
sub get_dupes {
    my @possibles = @_;

    my @dupes;

    foreach my $possible (@possibles) {
        my $iter = combinations( $possible, 2 );
        while ( my $comb = $iter->next ) {
            if ( !compare( @{$comb} ) ) {
                push @dupes, [ sort @{$comb} ];
            }
        }
    }

    return @dupes;
}

# Get camera model
sub get_model {
    my ($info) = @_;

    my $model = exists $info->{Model} ? $info->{Model} : undef;
    if ( defined $model ) {
        $model = exists $MODEL_FOR{$model} ? $MODEL_FOR{$model} : $model;
        $model =~ s/[\s-]+/_/gxms;
    }

    return $model;
}

# Get file digest
sub get_digest {
    my ($file) = @_;

    open my $fh, q{<}, $file;
    my $digest = Digest::MD5->new->addfile($fh)->hexdigest;
    $digest = substr $digest, 0, 8;    ## no critic (ProhibitMagicNumbers)
    close $fh;

    return $digest;
}

# Make new filename
sub get_new_filename {
    my ( $timestamp, $digest, $model, $extension ) = @_;

    my ( $year, $month, $day, $hour, $min, $sec ) = split /_/xms, $timestamp;
    my $new_file =
      sprintf '%s/%04d/%02d%s/%04d_%02d_%02d-%02d_%02d_%02d-%s%s.%s',
      $output_dir, $year, $month,
      ( defined $extra_dir ? q{/} . $extra_dir : q{} ), $year, $month, $day,
      $hour, $min, $sec,
      $digest, ( defined $model ? q{-} . $model : q{} ), $extension;
    my $new_dir = sprintf '%s/%04d/%02d%s', $output_dir, $year, $month,
      ( defined $extra_dir ? q{/} . $extra_dir : q{} );

    return $new_dir, $new_file;
}

# Generate timestamp for logging
sub timestamp {
    return strftime( '%Y-%m-%d %H:%M:%S', localtime );
}

# Get and check command line options
sub get_and_check_options {

    # Get options
    GetOptions(
        'dry_run'      => \$dry_run,
        'output_dir=s' => \$output_dir,
        'extra_dir=s'  => \$extra_dir,
        'debug'        => \$debug,
        'help'         => \$help,
        'man'          => \$man,
    ) or pod2usage(2);

    # Documentation
    if ($help) {
        pod2usage(1);
    }
    elsif ($man) {
        pod2usage( -verbose => 2 );
    }

    if ( !$output_dir ) {
        pod2usage("--output-dir must be specified\n");
    }
    return;
}

__END__
=pod

=encoding UTF-8

=head1 NAME

rename_photo_video.pl

Rename photo and video files by date and time

=head1 VERSION

version 0.1.0

=head1 DESCRIPTION

This script renames photo and video files according to the date and time they
were created.

=head1 EXAMPLES

    perl rename_photo_video.pl --dry_run --output_dir dir photo-dir video-dir

    perl rename_photo_video.pl --output_dir dir photo-dir video-dir

=head1 USAGE

    rename_photo_video.pl
        [--dry_run]
        [--output_dir dir]
        [--extra_dir dir]
        [--debug]
        [--help]
        [--man]

=head1 OPTIONS

=over 8

=item B<--dry_run>

Don't rename any files.

=item B<--output_dir DIR>

Base output directory.

=item B<--extra_dir DIR>

Extra subdirectory.

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

This software is Copyright (c) 2018 by Ian Sealy.

This is free software, licensed under:

  The GNU General Public License, Version 3, June 2007

=cut
