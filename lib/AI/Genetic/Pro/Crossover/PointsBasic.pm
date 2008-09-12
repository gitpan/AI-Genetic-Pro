package AI::Genetic::Pro::Crossover::PointsBasic;

use warnings;
use strict;
use Clone qw( clone );
use feature 'say';
use Data::Dumper; $Data::Dumper::Sortkeys = 1;
#use AI::Genetic::Pro::Array::PackTemplate;
#=======================================================================
sub new { bless { points => $_[1] ? $_[1] : 1 }, $_[0]; }
#=======================================================================
sub run {
	my ($self, $ga) = @_;
	
	my ($chromosomes, $parents, $crossover) = ($ga->chromosomes, $ga->_parents, $ga->crossover);
	my ($fitness, $_fitness) = ($ga->fitness, $ga->_fitness);
	my @children;
	#-------------------------------------------------------------------
	while(my $elders = shift @$parents){
		my @elders = unpack 'I*', $elders;
		
		unless(scalar @elders){
			$_fitness->{scalar(@children)} = $fitness->($ga, $chromosomes->[$elders[0]]);
			push @children, $chromosomes->[$elders[0]];
			next;
		}
		
		# DO POPRAWY !!!
		my @points = map { 1 + int(rand $#{$chromosomes->[0]}) } 1..$self->{points};
		@elders = map { clone($chromosomes->[$_]) } @elders;
		for my $pt(@points){
			@elders = sort {
						splice @$b, 0, $pt, splice( @$a, 0, $pt, @$b[0..$pt-1] );
						0;
							} @elders;
		}

		my $idx = int rand @elders;
		$_fitness->{scalar(@children)} = $fitness->($ga, $elders[$idx]);
		push @children, $elders[ $idx ];
	}
	#-------------------------------------------------------------------
	
	return \@children;
}
#=======================================================================
1;
