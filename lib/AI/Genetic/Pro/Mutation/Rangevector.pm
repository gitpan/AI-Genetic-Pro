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
		next if rand() >= $mutation;
		my $idx = int rand @$chromosome;
		$chromosome->[$idx] = random_uniform_integer(1, @{$ga->_translations->[$idx]});
	}
	
	return 1;
}
#=======================================================================
1;
