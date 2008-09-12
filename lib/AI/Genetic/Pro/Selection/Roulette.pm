package AI::Genetic::Pro::Selection::Roulette;

use warnings;
use strict;
#use feature 'say';
#use Data::Dumper; $Data::Dumper::Sortkeys = 1;
use List::Util qw(sum);
use List::MoreUtils qw(first_index);
#=======================================================================
sub new { bless \$_[0], $_[0]; }
#=======================================================================
sub run {
	my ($self, $ga) = @_;
	
	my ($fitness) = ($ga->_fitness);
	my (@parents, @elders);
	#-------------------------------------------------------------------
	my $total = sum(values %$fitness) + 1;
	my $count = $#{$ga->chromosomes};
	
	# elders 
	for my $idx (0..$count){
		my $cnt = int ( ( $fitness->{$idx} / $total ) * $count);
		push @elders, $idx for 1..$cnt;
	}
	
	if((my $add = $count - scalar @elders) > 0){
		my $idx = $elders[rand @elders];
		push @elders, int rand($count) for 0..$add;
	}
	
	# parents
	for(0..$count){
		if(rand > $ga->crossover){
			push @parents, pack 'I*', $elders[ rand @elders ]
		}else{
			my @group;
			push @group, $elders[ rand @elders ] for 1..$ga->parents;
			push @parents, pack 'I*', @group;
		}
	}
	
	#-------------------------------------------------------------------
	return \@parents;
}
#=======================================================================

1;
