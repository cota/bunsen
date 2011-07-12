#!/usr/bin/perl

use warnings;
use strict;
use Text::CSV;
use Getopt::Long;
use Pod::Usage;

my $help = 0;
my $man = 0;
my $stdio = 0;
my $limit = 0;
my $top_items = 0;

GetOptions(
    'help|?|h' => \$help,
    'limit|l=s'  => \$limit,
    'man'      => \$man,
    'top|t=s' => \$top_items,
    '' => \$stdio,
    ) or pod2usage(2);
pod2usage(1) if $help;
pod2usage(-exitstatus => 0, -verbose => 2) if $man;

my $inputfile;
if ($stdio) {
    $inputfile = "-";
} elsif (@ARGV) {
    $inputfile = $ARGV[0];
} else {
    print STDERR "Missing input file.\n";
    pod2usage(2);
}

my $csv = Text::CSV->new ( { binary => 1 } )
    or die "Cannot use CSV: ".Text::CSV->error_diag();
open my $fh, $inputfile or die "$inputfile: $!";
my $data = parse_chase_csv($csv, $fh);
$csv->eof or $csv->error_diag();
close $fh;

@$data = sort { $a->{date} cmp $b->{date} } @$data;

my %pilenames = (
    in	=> 'Income',
    out	=> 'Expenses'
    );

my %recs;
foreach my $item (@$data) {
    my $year	= $item->{dateh}->{y};
    my $month	= $item->{dateh}->{m};
    my $pile	= $item->{amount} > 0 ? 'in' : 'out';

    $item->{amount} = abs($item->{amount});
    my $amount = $item->{amount};

    if (!$limit or $amount < $limit) {
	push @{$recs{$pile}->{$year}->{$month}}, $item;
    }
}

foreach (keys %recs) {
    my $year = $recs{$_};
    foreach my $y (keys %$year) {
	my $month = $year->{$y};
	foreach my $m (keys %$month) {
	    my $entries = $month->{$m};
	    @$entries = sort { $b->{amount} <=> $a->{amount} } @$entries;
	}
    }
}

foreach (sort keys %recs) {
    print "$pilenames{$_}\n";
    my $year = $recs{$_};
    foreach my $y (sort keys %$year) {
	print_year($year->{$y}, $y);
    }
}

sub print_year
{
    my ($months, $y) = @_;

    print " $y\n";
    foreach my $m (sort keys %$months) {
	print_month($months->{$m}, $m);
    }
}

sub print_month
{
    my ($entries, $m) = @_;

    my $total = 0;
    foreach (@$entries) {
	$total += $_->{amount};
    }

    print "  $m: $total\n";
}

# Some samples from Chase:
# DEBIT,07/05/2011,"ATM WITHDRAWAL",-100.0
# CREDIT,06/30/2011,"PAYROLL",1116.38
sub parse_chase_csv
{
    my ($csv, $fh) = @_;
    my @data = ();

    while (my $row = $csv->getline($fh)) {
	my @date_array = split("/", $row->[1]);
	my @reordered = @date_array[2, 0, 1];
	my %hash = (
	    'date' => join("-", @reordered),
	    'dateh' => {
		'y' => $date_array[2],
		'm' => $date_array[0],
		'd' => $date_array[1],
	    },
	    'desc' => $row->[2],
	    'amount' => $row->[3],
	    );
	push @data, \%hash;
    }
    return \@data;
}

=head1 NAME

bunsen burner - A nice little earner.

=head1 SYNOPSIS

bunsen [options] INPUT_FILE

bunsen - Prints a report on the expenses/income reported by the input file.

=head1 OPTIONS

=over 8

=item B<--help -h -?>

Prints a brief help message and exits.

=item B<--limit -l>

Ignores amounts over the specified limit.

=item B<--man>

Prints the manual page and exits.

=back

=head1 AUTHOR

Written by Emilio G. Cota <cota@braap.org>.

=cut
