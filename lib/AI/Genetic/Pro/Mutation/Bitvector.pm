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
	my $mutation = $ga->mutation;
	
	# main loop
	foreach my $chromosome (@{$ga->{chromosomes}}){
		next if rand() >= $mutation;
		
		my $rand = rand();
		if($rand < 0.16 and $#$chromosome > 1){
			pop @$chromosome;
		}elsif($rand < 0.32 and $#$chromosome > 1){
			shift @$chromosome;
		}elsif($rand < 0.48 and $#$chromosome < $#{$ga->_translations}){
			push @$chromosome, rand > 0.5 ? 0 : 1;
		}elsif($rand < 0.64 and $#$chromosome < $#{$ga->_translations}){
			unshift @$chromosome, rand > 0.5 ? 0 : 1;
		}elsif($rand < 0.8){
			tied(@$chromosome)->reverse;
		}else{
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
