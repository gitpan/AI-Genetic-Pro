package AI::Genetic::Pro::Crossover::PointsSimple;

use warnings;
use strict;
use Clone qw( clone );
#use Data::Dumper; $Data::Dumper::Sortkeys = 1;
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
			push @children, $chromosomes->[$elders[0]];
			next;
		}
		
		my @points = map { 1+ int(rand $#{$chromosomes->[0]}) } 1..$self->{points};
		@elders = map { clone($chromosomes->[$_]) } @elders;
		for my $pt(@points){
			@elders = sort {
						splice @$b, 0, $pt, splice( @$a, 0, $pt, @$b[0..$pt-1] );
						0;
							} @elders;
		}
		
		push @children, @elders;
	}
	#-------------------------------------------------------------------
	# wybieranie potomkow ze zbioru nowych osobnikow
	@children = sort { $fitness->($ga, $a) <=> $fitness->($ga, $b) } @children;
	splice @children, 0, scalar(@children) - scalar(@$chromosomes);
	%$_fitness = map { $_ => $fitness->($ga, $children[$_]) } 0..$#children;
	#-------------------------------------------------------------------
	return \@children;
}
#=======================================================================
1;
