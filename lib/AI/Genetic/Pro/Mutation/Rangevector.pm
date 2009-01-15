package AI::Genetic::Pro::Mutation::Rangevector;

use warnings;
use strict;
use List::MoreUtils qw(first_index);
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

		if($ga->variable_length){
			my $rand = rand();
			my $min = first_index { $_ } @$chromosome;
			my $range = $#$chromosome - $min;
		
			if($rand < 0.4 and $range > 2){
				if($rand < 0.2 and $ga->variable_length > 1){ $chromosome->[$min] = 0; }
				else{ pop @$chromosome;	}
			}elsif($rand < 0.8 and $range < $#{$ga->_translations}){
				if($rand < 0.6 and $ga->variable_length > 1 and not defined $chromosome->[0]){
					$chromosome->[ $min - 1 ] = 1 + random_uniform_integer(1, $#{$ga->_translations->[ $min - 1 ]});
				}else{
					push @$chromosome, 1 + random_uniform_integer(1, $#{$ga->_translations->[scalar @$chromosome]});	
				}
			}else{
				my $idx = $min + int rand($range + 1);
				$chromosome->[$idx] = 1 + random_uniform_integer(1, $#{$ga->_translations->[$idx]});	
			}
		}else{
			my $idx = int rand @$chromosome;
			$chromosome->[$idx] = 1 + random_uniform_integer(1, $#{$ga->_translations->[$idx]});	
		}
	}
	
	return 1;
}
#=======================================================================
sub run0 {
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
				push @$chromosome, random_uniform_integer(1, @{$ga->_translations->[scalar @$chromosome]});
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
