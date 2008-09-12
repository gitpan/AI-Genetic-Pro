package AI::Genetic::Pro::Crossover::Distribution;

use warnings;
use strict;
use Clone qw( clone );
use feature 'say';
use Data::Dumper; $Data::Dumper::Sortkeys = 1;
#use AI::Genetic::Pro::Array::PackTemplate;
use Math::Random qw(
	random_uniform_integer 
	random_normal 
	random_beta
	random_binomial
	random_chi_square
	random_exponential
	random_poisson
);
#=======================================================================
sub new { 
	my ($class, $type, @params) = @_;
	bless { 
			type 	=> $type,
			params	=> \@params,
		}, $class; 
}
#=======================================================================
sub run {
	my ($self, $ga) = @_;
	
	my ($chromosomes, $parents, $crossover) = ($ga->chromosomes, $ga->_parents, $ga->crossover);
	my ($fitness, $_fitness) = ($ga->fitness, $ga->_fitness);
	my $high  = scalar @{$chromosomes->[0]};
	my $len = $#{$chromosomes->[0]};
	my @children;
	#-------------------------------------------------------------------
	while(my $elders = shift @$parents){
		my @elders = unpack 'I*', $elders;
		
		unless(scalar @elders){
			$_fitness->{scalar(@children)} = $fitness->($ga, $chromosomes->[$elders[0]]);
			push @children, $chromosomes->[$elders[0]];
			next;
		}
		
		#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		my @seq;
		if($self->{type} eq q/uniform/){
			@seq = random_uniform_integer($high, 0, $#elders);
		}elsif($self->{type} eq q/normal/){
			my $av = defined $self->{params}->[0] ? $self->{params}->[0] : $len/2;
			my $sd = defined $self->{params}->[1] ? $self->{params}->[1] : $len;
			@seq = map { int $_ % $high } random_normal($high, $av, $sd)  
		}elsif($self->{type} eq q/beta/){
			my $aa = defined $self->{params}->[0] ? $self->{params}->[0] : $high;
			my $bb = defined $self->{params}->[1] ? $self->{params}->[1] : $high;
			@seq = map { int($_ * $high) } random_beta($high, $aa, $bb)
		}elsif($self->{type} eq q/binomial/){
			@seq = random_binomial($high, $len, rand);
		}elsif($self->{type} eq q/chi_square/){
			my $df = defined $self->{params}->[0] ? $self->{params}->[0] : $high;
			@seq = map { int $_ % $high } random_chi_square($parents, $df);
		}elsif($self->{type} eq q/exponential/){
			my $av = defined $self->{params}->[0] ? $self->{params}->[0] : $len/2;
			@seq = map { int $_ % $high } random_exponential($parents, $av);
		}elsif($self->{type} eq q/poisson/){
			my $mu = defined $self->{params}->[0] ? $self->{params}->[0] : $len/2;
			@seq = map { int $_ % $high } random_poisson($parents, $mu) ;
		}else{
			die qq/Unknown distribution "$self->{type}" in "crossover"!\n/;
		}
		
		$elders[0] = clone($chromosomes->[$elders[0]]);
		for(0..$#seq){
			next unless $seq[$_];
			$elders[0]->[$_] = $chromosomes->[$elders[$seq[$_]]]->[$_];
		}
		#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		
		push @children, $elders[ 0 ];
	}
	#-------------------------------------------------------------------
	
	return \@children;
}
#=======================================================================
1;
