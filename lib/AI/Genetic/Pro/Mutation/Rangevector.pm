package AI::Genetic::Pro::Mutation::Rangevector;

use warnings;
use strict;
use Math::Random qw(random_uniform_integer);
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
		next if rand() <= $mutation;
		
		if($ga->variable_length){
			my $rand = rand();
			if($rand < 0.33 and $#$chromosome > 1){
				pop @$chromosome;
			}elsif($rand < 0.66 and $#$chromosome < $#{$ga->_translations}){
				push @$chromosome, random_uniform_integer(1, @{$ga->_translations->[-1]});
			}else{
				my $idx = int rand @$chromosome;
				$chromosome->[$idx] = random_uniform_integer(1, @{$ga->_translations->[$idx]});	
			}
		}else{
			my $idx = int rand @$chromosome;
			$chromosome->[$idx] = random_uniform_integer(1, @{$ga->_translations->[$idx]});		
		}
	}
	
	return 1;
}
#=======================================================================
1;
