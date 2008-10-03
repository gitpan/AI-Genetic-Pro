package AI::Genetic::Pro::Mutation::Combination;

use warnings;
use strict;
use List::MoreUtils qw(first_index);
#use Data::Dumper; $Data::Dumper::Sortkeys = 1;
#=======================================================================
sub new { bless \$_[0], $_[0]; }
#=======================================================================
sub run {
	my ($self, $ga) = @_;

	my $mut = $ga->mutation; # this is declared here just for speed
	my $inv = $mut / 2;
	
	# main loop
	foreach my $chromosome (@{$ga->{chromosomes}}){
		my $rand = rand;
		if($rand < $inv) { tied(@$chromosome)->reverse; }
		elsif(rand() < $mut){
			my $idx = int rand @$chromosome;
			my $new = int rand @{$ga->_translations->[0]};
			next if $new == $chromosome->[$idx];
			my $id = first_index { $_ == $new } @$chromosome;
			$chromosome->[$id] = $chromosome->[$idx] if defined $id and $id != -1;
			$chromosome->[$idx] = $new;
		}
	}
	
	return 1;
}
#=======================================================================
sub run0 {
	my ($self, $ga) = @_;

	my $mutation = $ga->mutation; # this is declared here just for speed
	for my $chromosome(@{$self->chromosomes}){
		for my $idx (0..$#$chromosome){
			next if rand() <= $mutation;
			my $new = int rand @{$ga->_translations->[0]};
			next if $new == $chromosome->[$idx];
			my $id = first_index { $_ == $new } @$chromosome;
			$chromosome->[$id] = $chromosome->[$idx] if defined $id and $id != -1;
			$chromosome->[$idx] = $new;
		}
	}
	
	return 1;
}
#=======================================================================
1;
