package AI::Genetic::Pro::Crossover::PMX;

use warnings;
use strict;
use Clone qw( clone );
use List::MoreUtils qw(first_index);
use Data::Dumper; $Data::Dumper::Sortkeys = 1;
#=======================================================================
sub new { bless \$_[0], $_[0]; }
#=======================================================================
sub save_fitness {
	my ($self, $ga, $idx) = @_;
	$ga->_fitness->{$idx} = $ga->fitness->($ga, $ga->chromosomes->[$idx]);
	return $ga->chromosomes->[$idx];
}
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
		
		my @points = sort { $a <=> $b } map { 1 + int(rand $#{$chromosomes->[0]}) } 0..1;
		
		@elders = sort {
					my @av = @{$a}[$points[0]..$points[1]-1];
					#for my $element(@av){
					#	for my $idx($points[0]..$points[1]-1){
					#		return 0 if $b->[$idx] == $element;
					#	}
					#}
					
					my @bv = splice @$b, $points[0], $points[1] - $points[0], @av;
					
					for my $idx(0..$#av){
						$a->[ first_index { $_ == $bv[$idx] } @$a ] = $av[$idx];
						$b->[ first_index { $_ == $av[$idx] } @$b ] = $bv[$idx];
					}
					#splice @$b, 0, $pt, splice( @$a, 0, $pt, @$b[0..$pt-1] );
					0;
						} map { 
							clone($chromosomes->[$_])
								} @elders;
		
		
		my %elders = map { $_ => $fitness->($ga, $elders[$_]) } 0..$#elders;
		my $max = (sort { $elders{$a} <=> $elders{$b} } keys %elders)[-1];
		$_fitness->{scalar(@children)} = $elders{$max};
		
		push @children, $elders[$max];
	}
	#-------------------------------------------------------------------
	
	return \@children;
}
#=======================================================================
1;
