package AI::Genetic::Pro::Mutation::Bitvector;

use warnings;
use strict;
#use Data::Dumper; $Data::Dumper::Sortkeys = 1;
#=======================================================================
sub new { bless \$_[0], $_[0]; }
#=======================================================================
sub run {
	my ($self, $ga) = @_;

	# this is declared here just for speed
	my $mut = $ga->mutation;
	my $inv = $mut / 2;
	
	# main loop
	foreach my $chromosome (@{$ga->{chromosomes}}){
		my $rand = rand;
		if($rand < $inv) { tied(@$chromosome)->reverse; }
		elsif(rand() < $mut){
			my $idx = int rand @$chromosome;
			$chromosome->[$idx] = $chromosome->[$idx] ? 0 : 1;
		}
	}
	
	return 1;
}
#=======================================================================
# too slow; mutation is too dangerous in this solution
sub run0 {
	my ($self, $ga) = @_;

	my $mutation = $ga->mutation; # this is declared here just for speed
	foreach my $chromosome (@{$ga->{chromosomes}}){
		if(rand() < $mutation){ tied(@$chromosome)->reverse; }
		else{
			for(0..$#$chromosome){
				next if rand > $mutation;
				$chromosome->[$_] = $chromosome->[$_] ? 0 : 1;
			}
		}
	}
	
	return 1;
}
#=======================================================================
1;
