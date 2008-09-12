package AI::Genetic::Pro;

use vars qw($VERSION);

$VERSION = 0.14;
#---------------

use warnings;
use strict;
use lib qw(../lib/perl);
use Carp;
use Perl6::Say;
use List::Util qw(sum);
use List::MoreUtils qw(minmax first_index);
use Data::Dumper; $Data::Dumper::Sortkeys = 1;
use UNIVERSAL::require;
use Digest::MD4 qw(md4_hex);
use AI::Genetic::Pro::Array::Type qw(get_package_by_element_size);
use AI::Genetic::Pro::Chromosome;
use base qw(Class::Accessor::Fast);
#-----------------------------------------------------------------------
__PACKAGE__->mk_accessors(qw( 
	mutation type population fitness terminate
	history chromosomes selection parents crossover
	selection strategy
	fitness _fitness _fitness_real
	cache _cache
	_translations _parents _selector _strategist
	_generation
));
#=======================================================================
my $_Cache = { };
#=======================================================================
sub new {
	my $class = shift;
	
	my %opts = map { if(ref $_){$_}else{ /^-?(.*)$/o; $1 }} @_;
	return bless \%opts, $class;
}
#=======================================================================
# INIT #################################################################
#=======================================================================
sub _fitness_cached {
	my ($self, $chromosome) = @_;
	my $key = md4_hex ${tied(@$chromosome)};
	return $_Cache->{$key} if exists $_Cache->{$key};
	$_Cache->{$key} = $self->_fitness_real->($self, $chromosome);
	return $_Cache->{$key};
}
#=======================================================================
sub set_cache {
	my ($self) = @_;
	#$self->_cache( { } );
	$self->_fitness_real($self->fitness);
	$self->fitness(\&_fitness_cached);
	return;
}
#=======================================================================
sub init { 
	my ($self, $data) = @_;
	
	croak q/You have to pass some data to "init"!/ unless $data;
	$self->_generation(0);
	$self->_fitness( { } );
	$self->set_cache if $self->cache;
	
	if($self->type eq q/listvector/){
		croak(q/You have to pass array reference if "type" is set to "listvector"/) unless ref $data eq 'ARRAY';
		$self->_translations( $data );
	}elsif($self->type eq q/bitvector/){
		croak(q/You have to pass integer if "type" is set to "bitvector"/) if $data !~ /^\d+$/o;
		$self->_translations( [ [ 0, 1 ] ] );
		$self->_translations->[$_] = $self->_translations->[0] for 1..$data-1;
	}elsif($self->type eq q/combination/){
		croak(q/You have to pass array reference if "type" is set to "combination"/) unless ref $data eq 'ARRAY';
		$self->_translations( [ $data ] );
		$self->_translations->[$_] = $self->_translations->[0] for 1..$#$data;
	}elsif($self->type eq q/rangevector/){
		croak(q/You have to pass array reference if "type" is set to "listvector"/) unless ref $data eq 'ARRAY';
		$self->_translations( $data );
	}else{
		croak(q/You have to specify first "type" of vector!/);
	}
	
	my $size = 0;
	for(@{$self->_translations}){ $size = $#$_ if $#$_ > $size; }
	my $package = get_package_by_element_size($size);

	$self->chromosomes( [ ] );
	push @{$self->chromosomes}, 
		AI::Genetic::Pro::Chromosome->new($self->_translations, $self->type, $package)
			for 1..$self->population;
}
#=======================================================================
# SAVE / LOAD ##########################################################
#=======================================================================
sub save { }
#=======================================================================
sub load { }
#=======================================================================
# CHARTS ###############################################################
#=======================================================================
sub chart { }
#=======================================================================
# TRANSLATIONS #########################################################
#=======================================================================
sub as_array {
	my ($self, $chromosome) = @_;
	
	if($self->type eq q/bitvector/ or $self->type eq q/rangevector/){
		return @$chromosome if wantarray;
		return $chromosome;
	}else{
		my $cnt = 0;
		return map { $self->_translations->[$cnt++]->[$_] } @$chromosome if wantarray;
		return \map { $self->_translations->[$cnt++]->[$_] } @$chromosome;
	}
}
#=======================================================================
sub as_string {	
	return join(q//, @{$_[1]}) if $_[0]->type eq q/bitvector/;
	return join(q/___/, $_[0]->as_array($_[1]));
}
#=======================================================================
sub as_value { 
	my ($self, $chromosome) = @_;
	croak(q/You MUST call 'as_value' as method of 'AI::Genetic::Pro' object./)
		unless defined $_[0] and ref $_[0] and ref $_[0] eq 'AI::Genetic::Pro';
	croak(q/You MUST pass 'AI::Genetic::Pro::Chromosome' object to 'as_value' method./) 
		unless defined $_[1] and ref $_[1] and ref $_[1] eq 'AI::Genetic::Pro::Chromosome';
	return $self->fitness()->($self, $chromosome);  
}
#=======================================================================
# ALGORITHM ############################################################
#=======================================================================
sub _calculate_fitness_cached {
	my ($self, $chromosome) = @_;
	my $key = ${tied(@$chromosome)};
	return $self->_cache->{$key} if exists $self->_cache->{$key};
	$self->_cache->{$key} = $self->fitness()->($self, $chromosome);
	return $self->_cache->{$key};
}
#=======================================================================
sub _calculate_fitness_all {
	my ($self) = @_;
	
	$self->_fitness( { } );
	$self->_fitness->{$_} = $self->fitness()->($self, $self->chromosomes->[$_]) 
		for 0..$#{$self->chromosomes};
	
	my (@chromosomes, %fitness);
	for my $idx (sort { $self->_fitness->{$a} <=> $self->_fitness->{$b} } keys %{$self->_fitness}){
		push @chromosomes, $self->chromosomes->[$idx];
		$fitness{$#chromosomes} = $self->_fitness->{$idx};
		delete $self->_fitness->{$idx};
		delete $self->chromosomes->[$idx];
	}
	
	$self->_fitness(\%fitness);
	$self->chromosomes(\@chromosomes);
		
	return;
}
#=======================================================================
sub _select_parents {
	my ($self) = @_;
	unless($self->_selector){
		my $selector = q/AI::Genetic::Pro::Selection::/ . shift @{$self->selection};
		$selector->require;
		$self->_selector($selector->new(@{$self->selection}));
	}
	
	$self->_parents($self->_selector->run($self));
	
	return;
}
#=======================================================================
sub _crossover {
	my ($self) = @_;
	
	unless($self->_strategist){
		my $strategist = q/AI::Genetic::Pro::Crossover::/ . shift @{$self->strategy};
		$strategist->require;
		$self->_strategist($strategist->new(@{$self->strategy}));
	}

	my $a = $self->_strategist->run($self);
	$self->chromosomes( $a );
	
	return;
}
#=======================================================================
sub _mutation {
	my ($self) = @_;
	
	if($self->type eq q/bitvector/){
		foreach my $chromosome (@{$self->{chromosomes}}){
			for(0..$#$chromosome){
				next if rand > $self->{mutation};
				$chromosome->[$_] = $chromosome->[$_] ? 0 : 1;
			}
		}
	}elsif($self->type eq q/combination/){
		for my $chromosome(@{$self->chromosomes}){
			for my $idx (0..$#$chromosome){
				next if rand() <= $self->mutation;
				my $new = int rand @{$self->_translations->[0]};
				next if $new == $chromosome->[$idx];
				my $id = first_index { $_ == $new } @$chromosome;
				$chromosome->[$id] = $chromosome->[$idx] if defined $id and $id != -1;
				$chromosome->[$idx] = $new;
			}
		}
	}
}
#=======================================================================
sub evolve {
	my ($self, $generations) = @_;
	
	$self->_calculate_fitness_all() unless keys %{ $self->_fitness };
	
	for my $generation(1..$generations){
		# update generation --------------------------------------------
		$self->_generation($self->_generation + 1);
		# selection ----------------------------------------------------
		$self->_select_parents();
		# crossover ----------------------------------------------------
		$self->_crossover();
		# mutation -----------------------------------------------------
		$self->_mutation();
		# terminate ----------------------------------------------------
		last if $self->terminate and $self->terminate->($self);
	}
}
#=======================================================================
# STATS ################################################################
#=======================================================================
sub generation { $_[0]->_generation }
#=======================================================================
sub getFittest {
	my ($self, $n) = @_;
	$n ||= 0;
	
	$self->_calculate_fitness_all() unless scalar %{ $self->_fitness };
	my @keys = sort { $self->_fitness->{$a} <=> $self->_fitness->{$b} } 0..$#{$self->chromosomes};
	
	return reverse @{$self->chromosomes}[ splice @keys, $#keys - $n, scalar @keys];
}
#=======================================================================
sub getAvgFitness {
	my ($self) = @_;
	
	my @minmax = minmax values %{$self->_fitness};
	my $mean = sum(values %{$self->_fitness}) / scalar values %{$self->_fitness};
	return $minmax[0], int($mean), $minmax[1];
}
#=======================================================================
1;


__END__

=head1 NAME

AI::Genetic::Pro - Efficient genetic algorithms for professional purpose

=head1 SYNOPSIS

    use AI::Genetic::Pro;
    
    sub fitness {
        my ($ga, $chromosome) = @_;
        return oct('0b' . $ga->as_string($chromosome)); 
    }
    
    sub terminate {
        my ($ga) = @_;
        my $result = oct('0b' . $ga->as_string($ga->getFittest));
        return $result == 4294967295 ? 1 : 0;
    }
    
    my $ga = AI::Genetic::Pro->new(        
        -fitness    	=> \&fitness,        # fitness function
        -terminate  	=> \&terminate,      # terminate function
        -type           => 'bitvector',      # type of individuals
        -population 	=> 1000,             # population
        -crossover  	=> 0.9,              # probab. of crossover
        -mutation   	=> 0.01,             # probab. of mutation
        -parents        => 2,                # number  of parents
        -selection      => [ 'Roulette' ],   # selection strategy
        -strategy       => [ 'Points', 2 ],  # crossover strategy
        -cache          => 0,                # cache results
        -history        => 1,                # remember best results
    );
	
    # init population of 32-bit vectors
    $ga->init(32);
	
    # evolve 10 generations
    $ga->evolve(10);
    
    # best score
    print "SCORE: ", oct('0b' . $ga->as_string($ga->getFittest)), ".\n";
    
=head1 DESCRIPTION

This module provides efficient implementation of a genetic algorithm for
professional purpose. It was designed to operate as fast as possible
even on very large populations and big individuals. C<AI::Genetic::Pro> 
was inspired by C<AI::Genetic>, so it is in most cases compatible 
(there is some changes). Additionaly C<AI::Genetic::Pro> B<doesn't have>
limitations of its ancestor (ie. seriously slow down in case of big 
populations ( >10000 ) or vectors with size > 33 fields).

=over 4

=item 

To provide more flexibility C<AI::Genetic::Pro> supports many 
statistic distributions, such as: C<uniform>, C<natural>, C<chi_square>
and others.

=item 

To increase speed XS code are used, however with portability in 
mind. This distribution was tested on Windows and Linux platforms 
(should work on any other).

=item 

This module was designed to use as little memory as possible. Population
of size 10000 consist 92-bit vectors uses only ~24MB (in C<AI::Genetic> 
something about ~78MB!!!).
	
=back


=head1 METHODS

=over 4

=item new( { param => value, param0 => value0 } )

Constructor.

=item population($population)

Set/get population.

=item type($type)

Set/get type of individuals. Currently it can be set to:

=over 4

=item bitvector,

=item listvector,

=item rangevector,

=item combination.

=back

=item init()

=item evolve()

=item getFittest()

=item generation()

=item history()

=back

=head1 DOCUMENTATION

At the moment for more information see documentation of L<AI::Genetic>.
It is compatible in most cases. 

=head1 SUPPORT

C<AI::Genetic::Pro> is still under development and it has very poor 
documentation. However it is used in many production environments.

=head1 TODO

=over 4

=item More documentation.

=item More tests.

=item Warnings.

=back

=head1 REPORTING BUGS

When reporting bugs/problems please include as much information as possible.
It may be difficult for me to reproduce the problem as almost every setup
is different.

A small script which yields the problem will probably be of help. 

=head1 AUTHOR

Strzelecki Łukasz <strzelec@rswsystems.com>

=head1 SEE ALSO

L<AI::Genetic>

=head1 COPYRIGHT

Copyright (c) Strzelecki Łukasz. All rights reserved.
This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
