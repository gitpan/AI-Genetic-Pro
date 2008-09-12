package AI::Genetic::Pro::Chromosome;

use warnings;
use strict;
use List::Util qw(shuffle);
use Tie::Array::Packed;
#use Math::Random qw(random_uniform_integer);
#=======================================================================
sub new {
	my ($class, $data, $type, $package) = @_;

	my @genes;	
	tie @genes, $package if $package;
	
	if($type eq q/bitvector/){
		#@genes = random_uniform_integer(scalar @$data, 0, 1); 			# this is fastest, but uses more memory
		@genes = map { rand > 0.5 ? 1 : 0 } 0..$#$data;					# this is faster
		#@genes =  split(q//, unpack("b*", rand 99999), $#$data + 1);	# slow
	}elsif($type eq q/combination/){ 
		@genes = shuffle 0..$#{$data->[0]}; 
	}elsif($type eq q/rangevector/){
  		@genes = map { $_->[0] + int rand($_->[1] - $_->[0] + 1) } @$data;
	}else{ 
		@genes = map { int(rand @{ $data->[$_] }) } 0..$#$data; 
	}
	
	return bless \@genes, $class;
}
#=======================================================================
1;
