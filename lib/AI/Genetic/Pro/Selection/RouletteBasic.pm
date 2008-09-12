package AI::Genetic::Pro::Selection::RouletteBasic;

use warnings;
use strict;
use feature 'say';
use Data::Dumper; $Data::Dumper::Sortkeys = 1;
use List::MoreUtils qw(first_index);
#use AI::Genetic::Pro::Array::PackTemplate;
#=======================================================================
sub new { bless \$_[0], $_[0]; }
#=======================================================================
sub run {
	my ($self, $ga) = @_;
	
	my ($fitness, $chromosomes) = ($ga->_fitness, $ga->chromosomes);
	my $parents = $ga->parents;
	my (@parents, @wheel);
	my $total = 0;
	#-------------------------------------------------------------------
	foreach my $key (keys %$fitness){
		$total += $fitness->{$key};
		push @wheel, [ $key, $total ];
	}
	
	for(0..$#$chromosomes){
		my @group;
		for(1..$parents){
			my $rand = rand($total);
			my $idx = first_index { $_->[1] > $rand } @wheel;
			if($idx == 0){ $idx = 1 }
			elsif($idx == -1 ) { $idx = scalar @wheel; }
			push @group, $wheel[$idx-1]->[0];
		}
		push @parents, pack 'I*', @group;
	}
	
	#-------------------------------------------------------------------
	return \@parents;
}
#=======================================================================

1;
