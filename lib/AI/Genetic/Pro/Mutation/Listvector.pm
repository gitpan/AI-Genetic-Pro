package AI::Genetic::Pro::Mutation::Listvector;

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
		if($rand < 0.2 and $#$chromosome > 1){
			pop @$chromosome;
		}elsif($rand < 0.6 and $#$chromosome < $#{$ga->_translations}){
			push @$chromosome, int rand @{$ga->_translations->[-1]};
		}else{
			my $idx = int rand @$chromosome;
			$chromosome->[$idx] = int rand @{$ga->_translations->[$idx]};
		}
	}
	
	return 1;
}
#=======================================================================
1;
