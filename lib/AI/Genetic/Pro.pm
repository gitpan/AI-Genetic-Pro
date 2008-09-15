package AI::Genetic::Pro;

use vars qw($VERSION);

$VERSION = 0.16;
#---------------

use warnings;
use strict;
use lib qw(../lib/perl);
use Carp;
use List::Util qw(sum);
use List::MoreUtils qw(minmax first_index);
#use Data::Dumper; $Data::Dumper::Sortkeys = 1;
use UNIVERSAL::require;
use AI::Genetic::Pro::Array::Type qw(get_package_by_element_size);
use AI::Genetic::Pro::Chromosome;
use base qw(Class::Accessor::Fast);
#-----------------------------------------------------------------------
__PACKAGE__->mk_accessors(qw( 
	type 
	population 
	terminate
	chromosomes 
	crossover 
	parents 		_parents 
	history 		_history
	fitness 		_fitness 		_fitness_real
	cache   		_cache
	mutation 		_mutator
	strategy 		_strategist
	selection 		_selector 
	_translations
	_generation
));
#=======================================================================
# Additional modules
use constant STORABLE	=> 'Storable';
use constant GD 		=> 'GD::Graph::linespoints'; 
use constant MD			=> 'Digest::MD5';
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
	my $key = md5_hex(${tied(@$chromosome)});
	return $_Cache->{$key} if exists $_Cache->{$key};
	$_Cache->{$key} = $self->_fitness_real->($self, $chromosome);
	return $_Cache->{$key};
}
#=======================================================================
sub _init_cache {
	my ($self) = @_;
	
	MD->use(qw(md5_hex)) or croak(q/You need "/.MD.q/" module to use cache!/);
	
	$self->_fitness_real($self->fitness);
	$self->fitness(\&_fitness_cached);
	return;
}
#=======================================================================
sub init { 
	my ($self, $data) = @_;
	
	croak q/You have to pass some data to "init"!/ unless $data;
	#-------------------------------------------------------------------
	$self->_generation(0);
	$self->_fitness( { } );
	$self->_history( [  [ ], [ ], [ ] ] );
	$self->_init_cache if $self->cache;
	#-------------------------------------------------------------------
	
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
sub save { 
	STORABLE->use(qw(store retrieve)) or croak(q/You need "/.STORABLE.q/" module to save a state of "/.__PACKAGE__.q/"!/);
	$Storable::Deparse = 1;
	$Storable::Eval = 1;
	
	my ($self, $file) = @_;
	croak(q/You have to specify file!/) unless defined $file;

	my $clone = { 
		vector_type	=> ref(tied(@{$self->chromosomes->[0]})),
		chromosomes => [ map { my @genes = @$_; \@genes; } @{$self->chromosomes} ],
		_selector	=> undef,
		_strategist	=> undef,
		_mutator	=> undef,
	};
	
	foreach my $key(keys %$self){
		next if exists $clone->{$key};
		$clone->{$key} = $self->{$key};
	}
	
	store($clone, $file);
}
#=======================================================================
sub load { 
	STORABLE->use(qw(store retrieve)) or croak(q/You need "/.STORABLE.q/" module to load a state of "/.__PACKAGE__.q/"!/);	
	$Storable::Deparse = 1;
	$Storable::Eval = 1;
	
	my ($self, $file) = @_;
	croak(q/You have to specify file!/) unless defined $file;

	my $clone = retrieve($file);
	return carp('Incorrect file!') unless $clone;
	
	$clone->{chromosomes} = [ 
		map {
    		tie my (@genes), $clone->{vector_type};
    			@genes = @$_;
    			\@genes;
    		} @{$clone->{chromosomes}}
    ];
    
    delete $clone->{vector_type};
    
    %$self = %$clone;
    
    return 1;
}
#=======================================================================
# CHARTS ###############################################################
#=======================================================================
sub chart { 
	GD->require or croak(q/You need "/.GD.q/" module to draw chart of evolution!/);	
	my ($self, %params) = (shift, @_);

	my $graph = GD()->new(($params{-width} || 640), ($params{-height} || 480));

	my $data = $self->getHistory;

	if(defined $params{-font}){
    	$graph->set_title_font  ($params{-font}, 12);
    	$graph->set_x_label_font($params{-font}, 10);
    	$graph->set_y_label_font($params{-font}, 10);
    	$graph->set_legend_font ($params{-font},  8);
	}
	
    $graph->set_legend(
    	$params{legend1} || q/Max value/,
    	$params{legend2} || q/Mean value/,
    	$params{legend3} || q/Min value/,
    );

    $graph->set(
        x_label_skip        => int(($data->[0]->[-1]*4)/100),
        x_labels_vertical   => 1,
        x_label_position    => .5,
        y_label_position    => .5,
        y_long_ticks        => 1,   # poziome linie
        x_ticks             => 1,   # poziome linie

        l_margin            => 10,
        b_margin            => 10,
        r_margin            => 10,
        t_margin            => 10,

        show_values         => (defined $params{-show_values} ? 1 : 0),
        values_vertical     => 1,
        values_format       => ($params{-format} || '%.2f'),

        zero_axis           => 1,
        #interlaced          => 1,
        logo_position       => 'BR',
        legend_placement    => 'RT',

        bgclr               => 'white',
        boxclr              => '#FFFFAA',
        transparent         => 0,

        title       		=> ($params{'-title'}   || q/Evolution/ ),
        x_label     		=> ($params{'-x_label'} || q/Generation/),
        y_label     		=> ($params{'-y_label'} || q/Value/     ),
        
        ( $params{-logo} && -f $params{-logo} ? ( logo => $params{-logo} ) : ( ) )
    );
	
	
    my $gd = $graph->plot( [ [ 0..$#{$data->[0]} ], @$data ] ) or croak($@);
    open(my $fh, '>', $params{-filename}) or croak($@);
    binmode $fh;
    print $fh $gd->png;
    close $fh;
    
    return 1;
}
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
		my @tmp = @{$self->selection};
		my $selector = q/AI::Genetic::Pro::Selection::/ . shift @tmp;
		$selector->require;
		$self->_selector($selector->new(@tmp));
	}
	
	$self->_parents($self->_selector->run($self));
	
	return;
}
#=======================================================================
sub _crossover {
	my ($self) = @_;
	
	unless($self->_strategist){
		my @tmp = @{$self->strategy};
		my $strategist = q/AI::Genetic::Pro::Crossover::/ . shift @tmp;
		$strategist->require;
		$self->_strategist($strategist->new(@tmp));
	}

	my $a = $self->_strategist->run($self);
	$self->chromosomes( $a );
	
	return;
}
#=======================================================================
sub _mutation {
	my ($self) = @_;
	
	unless($self->_mutator){
		my $mutator = q/AI::Genetic::Pro::Mutation::/ . ucfirst(lc($self->type));
		$mutator->require;
		$self->_mutator($mutator->new);
	}
	
	return $self->_mutator->run($self);
}
#=======================================================================
sub _save_history {
	my @tmp;
	if($_[0]->history){ @tmp = $_[0]->getAvgFitness; }
	else { @tmp = (undef, undef, undef); }
	
	push @{$_[0]->_history->[0]}, $tmp[0]; 
	push @{$_[0]->_history->[1]}, $tmp[1];
	push @{$_[0]->_history->[2]}, $tmp[2];
	return 1;
}
#=======================================================================
sub evolve {
	my ($self, $generations) = @_;
	
	$self->_calculate_fitness_all() unless keys %{ $self->_fitness };
	
	for my $generation(1..$generations){
		# terminate ----------------------------------------------------
		last if $self->terminate and $self->terminate->($self);
		# update generation --------------------------------------------
		$self->_generation($self->_generation + 1);
		# update history -----------------------------------------------
		$self->_save_history;
		# selection ----------------------------------------------------
		$self->_select_parents();
		# crossover ----------------------------------------------------
		$self->_crossover();
		# mutation -----------------------------------------------------
		$self->_mutation();
	}
}
#=======================================================================
# STATS ################################################################
#=======================================================================
sub generation { $_[0]->_generation }
#=======================================================================
sub getHistory { $_[0]->_history()  }
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
	return $minmax[1], int($mean), $minmax[0];
}
#=======================================================================
1;


__END__

=head1 NAME

AI::Genetic::Pro - Efficient genetic algorithms for professional purpose.

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
        -fitness        => \&fitness,        # fitness function
        -terminate      => \&terminate,      # terminate function
        -type           => 'bitvector',      # type of individuals
        -population     => 1000,             # population
        -crossover      => 0.9,              # probab. of crossover
        -mutation       => 0.01,             # probab. of mutation
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
    print "SCORE: ", $ga->as_value($ga->getFittest), ".\n";
    
    # save evolution path as a chart
    $ga->chart(-filename => 'evolution.png');


=head1 DESCRIPTION

This module provides efficient implementation of a genetic algorithm for
a professional purpose. It was designed to operate as fast as possible
even on very large populations and big individuals. C<AI::Genetic::Pro> 
was inspired by C<AI::Genetic>, so it is in most cases compatible 
(there are some changes). Additionaly C<AI::Genetic::Pro> B<doesn't have>
limitations of its ancestor (ie. seriously slow down in case of big 
populations ( >10000 ) or vectors with size > 33 fields).

=over 4

=item Speed

To increase speed XS code are used, however with portability in 
mind. This distribution was tested on Windows and Linux platforms 
(should work on any other).

=item Memory

This module was designed to use as little memory as possible. Population
of size 10000 consist 92-bit vectors uses only ~24MB (in C<AI::Genetic> 
something about ~78MB!!!).

=item Advanced options

To provide more flexibility C<AI::Genetic::Pro> supports many 
statistic distributions, such as: C<uniform>, C<natural>, C<chi_square>
and others. This feature can be used in selection or/and crossover. See
documentation below.

=back


=head1 METHODS

Simply description of available methods. See below.

=head2 new( %options )

Constructor. It accepts options in hash-value style. See options and 
an example below.

=head3 -fitness

This defines a I<fitness> function. It expects a reference to a subroutine.

=head3 -terminate 

This defines a I<terminate> function. It expects a reference to a subroutine.

=head3 -type

This defines the type of chromosomes. Currently, C<AI::Genetic::Pro> supports four types:

=head4 bitvector

=head4 listvector

=head4 rangevector

=head4 combination

=head3 -population

This defines the size of the population, i.e. how many individuals to simultaneously exist at each generation.

=head3 -crossover 

This defines the crossover rate. Fairest results are achieved with crossover rate ~0.95.

=head3 -mutation 

=head3 -parents  

=head3 -selection

=head3 -strategy 

=head3 -cache    

=head3 -history 


=head2 population($population)

Set/get population.

=head2 type($type)

Set/get type of individuals. Currently it can be set to:

=over 4

=item C<bitvector>,

=item C<listvector>,

=item C<rangevector>,

=item C<combination>.

=back

=head2 parents($parents)

Set/get number of parents in I<Roulette> crossover.

=head2 init()

=head2 evolve()

=head2 history()

=head2 getAvgFitness()

=head2 getFittest()

=head2 getHistory()

=head2 generation()

=head2 chart(%options)

Generate a chart describing changes of min, mean, max scores in Your
population. To satisfy Your needs, You can pass following options:

=head3 -filename

File to save a chart in (B<obligatory>).

=head3 -title

Title of a chart (default: I<Evolution>).

=head3 -x_label

X label (default: I<Generations>).

=head3 -y_label

Y label (default: I<Value>).

=head3 -format

Format of values, like C<sprintf> (default: I<'%.2f'>).

=head3 -legend1

Description of min line (default: I<Min value>).

=head3 -legend2

Description of min line (default: I<Mean value>).

=head3 -legend3

Description of min line (default: I<Max value>).

=head3 -width

Width of a chart (default: I<640>).

=head3 -height

Height of a chart (default: I<480>).

=head3 -font

Path to font in (*.ttf format) to be used (default: none).

=head3 -logo

Path to logo (png/jpg image) to embed in a chart (default: none).

=head3 In example:

	$ga->chart(-width => 480, height => 320, -filename => 'chart.png');

=head2 save($file)

Save current state of the genetic algorithm to a specified file.

=head2 load($file)

Load a state of the genetic algorithm from a specified file. 

=head2 as_array($chromosome)

Return an array representing specified chromosome.

=head2 as_value($chromosome)

Return score of specified chromosome. Value of I<chromosome> is 
calculated by fitness function.

=head2 as_string($chromosome)

Return string-representation of specified chromosome. 


=head1 DOCUMENTATION

At the moment for more information see documentation of L<AI::Genetic>.
It is compatible in most cases. 

=head1 SUPPORT

C<AI::Genetic::Pro> is still under development and it has poor 
documentation (for now). However it is used in many production environments.

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
