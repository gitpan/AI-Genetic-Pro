package AI::Genetic::Pro::Crossover::PointsAdvanced;

use warnings;
use strict;
use Clone qw( clone );
#use Data::Dumper; $Data::Dumper::Sortkeys = 1;
#use AI::Genetic::Pro::Array::PackTemplate;
#=======================================================================
sub new { bless { points => $_[1] ? $_[1] : 1 }, $_[0]; }
#=======================================================================
sub run {
	my ($self, $ga) = @_;
	
	my ($chromosomes, $parents, $crossover) = ($ga->chromosomes, $ga->_parents, $ga->crossover);
	my ($fitness, $_fitness) = ($ga->fitness, $ga->_fitness);
	#-------------------------------------------------------------------
	while(my $elders = shift @$parents){
		my @elders = unpack 'I*', $elders;

		unless(scalar @elders){
			push @$chromosomes, $chromosomes->[$elders[0]];
			next;
		}
	
		# need some more work on it
		my $shortest = 0;
		if($ga->variable_length){
			for my $el(@elders){
				$shortest = $el if $#{$chromosomes->[$el]} < $#{$chromosomes->[$shortest]};
			}
		}
	
		my @points = map { 1+ int(rand $#{$chromosomes->[$shortest]}) } 1..$self->{points};
		@elders = map { clone($chromosomes->[$_]) } @elders;
		for my $pt(@points){
			@elders = sort {
						splice @$b, 0, $pt, splice( @$a, 0, $pt, @$b[0..$pt-1] );
						0;
							} @elders;
		}
		
		push @$chromosomes, @elders;
	}
	#-------------------------------------------------------------------
	# wybieranie potomkow ze zbioru starych i nowych osobnikow
	@$chromosomes = sort { $fitness->($ga, $a) <=> $fitness->($ga, $b) } @$chromosomes;
	splice @$chromosomes, 0, scalar(@$chromosomes) - $ga->population;
	%$_fitness = map { $_ => $fitness->($ga, $chromosomes->[$_]) } 0..$#$chromosomes;
	#-------------------------------------------------------------------
	return $chromosomes;
}
#=======================================================================
1;
