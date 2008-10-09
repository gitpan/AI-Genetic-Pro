package AI::Genetic::Pro;

use vars qw($VERSION);

$VERSION = 0.21;
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
	generation
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
	$self->generation(0);
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
	if($self->type ne q/rangevector/){ for(@{$self->_translations}){ $size = $#$_ if $#$_ > $size; } }
	else{ for(@{$self->_translations}){ $size = $_->[1] if $_->[1] > $size; } }
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
		unless($mutator->require){
			$mutator = q/AI::Genetic::Pro::Mutation::Listvector/;
			$mutator->require;
		}
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
		$self->generation($self->generation + 1);
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
# ALIASES ##############################################################
#=======================================================================
sub people { $_[0]->chromosomes() }
#=======================================================================
sub getHistory { $_[0]->_history()  }
#=======================================================================
sub mutProb { shift->mutation(@_) }
#=======================================================================
sub crossProb { shift->crossover(@_) }
#=======================================================================
sub intType { shift->type() }
#=======================================================================
# STATS ################################################################
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
        -type           => 'bitvector',      # type of individuals/chromosomes
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
     
    # save state of GA
    $ga->save('genetic.sga');
    
    # load state of GA
    $ga->load('genetic.sga');

=head1 DESCRIPTION

This module provides efficient implementation of a genetic algorithm for
a professional purpose. It was designed to operate as fast as possible
even on very large populations and big individuals/chromosomes. C<AI::Genetic::Pro> 
was inspired by C<AI::Genetic>, so it is in most cases compatible 
(there are some changes). Additionaly C<AI::Genetic::Pro> isn't pure Perl solution, so it 
B<doesn't have> limitations of its ancestor (ie. seriously slow down in case of big 
populations ( >10000 ) or vectors with size > 33 fields).

If You are looking for pure Perl solution, consider L<AI::Genetic>.

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

=over 4

=item I<$ga>-E<gt>B<new>( %options )

Constructor. It accepts options in hash-value style. See options and 
an example below.

=over 8

=item -fitness

This defines a I<fitness> function. It expects a reference to a subroutine.

=item -terminate 

This defines a I<terminate> function. It expects a reference to a subroutine.

=item -type

This defines the type of chromosomes. Currently, C<AI::Genetic::Pro> supports four types:

=over 12

=item bitvector

Individuals/chromosomes of this type have genes that are bits. Each gene can be in one of two possible states, on or off.

=item listvector

Each gene of a "listvector" individual/chromosome can assume one string value from a specified list of possible string values.

=item rangevector

Each gene of a "rangevector" individual/chromosome can assume one integer value from a range of possible integer values. Note that only integers are supported. The user can always transform any desired fractional values by multiplying and dividing by an appropriate power of 10.

=item combination

Each gene of a "combination" individual/chromosome can assume one string value from a specified list of possible string values. B<All genes are unique.>

=back

=item -population

This defines the size of the population, i.e. how many chromosomes to simultaneously exist at each generation.

=item -crossover 

This defines the crossover rate. Fairest results are achieved with crossover rate ~0.95.

=item -mutation 

This defines the mutation rate. Fairest results are achieved with mutation rate ~0.01.

=item -parents  

This defines how many parents should used in corssover.

=item -selection

This defines how individuals/chromosomes are selected to crossover. It expects an array reference listed below:

    -selection => [ $type, @params ]

where type is one of:

=over 8

=item B<RouletteBasic>

Each individual/chromosome can be selected with probability poportionaly to its fitness.

=item B<Roulette>

At the first best individuals/chromosomes are selected. From this collection
parents are selected with probability poportionaly to its fitness.

=item B<RouletteDistribution>

Each individual/chromosome has portion of roulette wheel proportionaly to its fitness. Selection is done with
specified distribution. Supported distributions and paremeters are listed below.

=over 12

=item C<-selection =E<gt> [ 'RouletteDistribution', 'uniform' ]>

Standard uniform distribution. No additional parameters are needed.

=item C<-selection =E<gt> [ 'RouletteDistribution', 'normal', $av, $sd ]>

Normal distribution, where C<$av> is average (default: size of population /2) and $C<$sd> is standard deviation (default: size of population).


=item C<-selection =E<gt> [ 'RouletteDistribution', 'beta', $aa, $bb ]>

I<Beta> distribution.  The density of the beta is:

    X^($aa - 1) * (1 - X)^($bb - 1) / B($aa , $bb) for 0 < X < 1.

C<$aa> and C<$bb> are set by default to number of parents.

B<Argument restrictions:> Both $aa and $bb must not be less than 1.0E-37.

=item C<-selection =E<gt> [ 'RouletteDistribution', 'binomial' ]>

Binomial distribution. No additional parameters are needed.

=item C<-selection =E<gt> [ 'RouletteDistribution', 'chi_square', $df ]>

Chi-square distribution with C<$df> degrees of freedom. C<$df> by default is set to size of population.

=item C<-selection =E<gt> [ 'RouletteDistribution', 'exponential', $av ]>

Exponential distribution, where C<$av> is average . C<$av> by default is set to size of population.

=item C<-selection =E<gt> [ 'RouletteDistribution', 'poisson', $mu ]>

Poisson distribution, where C<$mu> is mean. C<$mu> by default is set to size of population.

=back

=item B<Distribution>

Chromosomes/individuals are selected with specified distribution. See below.

=over 12

=item C<-selection =E<gt> [ 'Distribution', 'uniform' ]>

Standard uniform distribution. No additional parameters are needed.

=item C<-selection =E<gt> [ 'Distribution', 'normal', $av, $sd ]>

Normal distribution, where C<$av> is average (default: size of population /2) and $C<$sd> is standard deviation (default: size of population).

=item C<-selection =E<gt> [ 'Distribution', 'beta', $aa, $bb ]>

I<Beta> distribution.  The density of the beta is:

    X^($aa - 1) * (1 - X)^($bb - 1) / B($aa , $bb) for 0 < X < 1.

C<$aa> and C<$bb> are set by default to number of parents.

B<Argument restrictions:> Both $aa and $bb must not be less than 1.0E-37.

=item C<-selection =E<gt> [ 'Distribution', 'binomial' ]>

Binomial distribution. No additional parameters are needed.

=item C<-selection =E<gt> [ 'Distribution', 'chi_square', $df ]>

Chi-square distribution with C<$df> degrees of freedom. C<$df> by default is set to size of population.

=item C<-selection =E<gt> [ 'Distribution', 'exponential', $av ]>

Exponential distribution, where C<$av> is average . C<$av> by default is set to size of population.

=item C<-selection =E<gt> [ 'Distribution', 'poisson', $mu ]>

Poisson distribution, where C<$mu> is mean. C<$mu> by default is set to size of population.

=back

=back

=item -strategy 

This defines strategy of crossover operation. It expects an array reference listed below:

    -strategy => [ $type, @params ]

where type is one of:

=over 4

=item PointsSimple

Simple crossover in one or many points. Best chromosomes/individuals are selected to new generation. In example:

    -strategy => [ 'PointsSimple', $n ]

where C<$n> is number of points for crossing.

=item PointsBasic

Crossover in one or many points. In basic crossover selected parents are crossed and one (random) of children is moved to new generation. In example:

    -strategy => [ 'PointsBasic', $n ]

where C<$n> is number of points for crossing.

=item Points

Crossover in one or many points. In normal crossover selected parents are crossed and the best of child is moved to new generation. In example:

    -strategy => [ 'Points', $n ]

where C<$n> is number of points for crossing.

=item PointsAdvenced

Crossover in one or many points. After crossover best chromosomes/individuals from all parents and chidren are selected to new generation. In example:

    -strategy => [ 'PointsAdvanced', $n ]

where C<$n> is number of points for crossing.

=item Distribution

In I<distribution> crossover parents are crossed in points selected with specified distribution. See below.

=over 8

=item C<-strategy =E<gt> [ 'Distribution', 'uniform' ]>

Standard uniform distribution. No additional parameters are needed.

=item C<-strategy =E<gt> [ 'Distribution', 'normal', $av, $sd ]>

Normal distribution, where C<$av> is average (default: size of population /2) and $C<$sd> is standard deviation (default: size of population).

=item C<-strategy =E<gt> [ 'Distribution', 'beta', $aa, $bb ]>

I<Beta> distribution.  The density of the beta is:

    X^($aa - 1) * (1 - X)^($bb - 1) / B($aa , $bb) for 0 < X < 1.

C<$aa> and C<$bb> are set by default to number of parents.

B<Argument restrictions:> Both $aa and $bb must not be less than 1.0E-37.

=item C<-strategy =E<gt> [ 'Distribution', 'binomial' ]>

Binomial distribution. No additional parameters are needed.

=item C<-strategy =E<gt> [ 'Distribution', 'chi_square', $df ]>

Chi-square distribution with C<$df> degrees of freedom. C<$df> by default is set to size of population.

=item C<-strategy =E<gt> [ 'Distribution', 'exponential', $av ]>

Exponential distribution, where C<$av> is average . C<$av> by default is set to size of population.

=item C<-strategy =E<gt> [ 'Distribution', 'poisson', $mu ]>

Poisson distribution, where C<$mu> is mean. C<$mu> by default is set to size of population.

=back

=item PMX

PMX method defined by Goldberg and Lingle in 1985. Parameters: I<none>.

=item OX

OX method defined by Davis (?) in 1985. Parameters: I<none>.

=back

=item -cache    

This defines if cache should be used. Correct values are: 1 or 0 (default: I<0>).

=item -history 

This defines if history should be collected. Correct values are: 1 or 0 (default: I<0>).

Collect history.

=back

=item I<$ga>-E<gt>B<population>($population)

Set/get size of the population. This defines the size of the population, i.e. how many chromosomes to simultaneously exist at each generation.

=item I<$ga>-E<gt>B<indType>()

Get type of individuals/chromosomes. Currently supported types are:

=over 4

=item C<bitvector>

Chromosomes will be just bitvectors. See documentation of C<new> method.

=item C<listvector>

Chromosomes will be lists of specified values. See documentation of C<new> method.

=item C<rangevector>

Chromosomes will be lists of values from specified range. See documentation of C<new> method.

=item C<combination>

Chromosomes will be uniq lists of specified values. This is used for example in I<Traveling Salesman Problem>. See documentation of C<new> method.

=back

In example:

    my $type = $ga->type();

=item I<$ga>-E<gt>B<type>()

Alias for C<indType>.

=item I<$ga>-E<gt>B<crossProb>()

This method is used to query and set the crossover rate.

=item I<$ga>-E<gt>B<crossover>()

Alias for C<crossProb>.

=item I<$ga>-E<gt>B<mutProb>()

This method is used to query and set the mutation rate.

=item I<$ga>-E<gt>B<mutation>()

Alias for C<mutation>.

=item I<$ga>-E<gt>B<parents>($parents)

Set/get number of parents in a crossover.

=item I<$ga>-E<gt>B<init>($args)

This method initializes the population with random individuals/chromosomes. It MUST be called before any call to C<evolve()>. It expects one argument, which depends on the type of individuals/chromosomes:

=over 4

=item B<bitvector>

For bitvectors, the argument is simply the length of the bitvector.

    $ga->init(10);

This initializes a population where each individual/chromosome has 10 genes.

=item B<listvector>

For listvectors, the argument is an anonymous list of lists. The number of sub-lists is equal to the number of genes of each individual/chromosome. Each sub-list defines the possible string values that the corresponding gene can assume.

    $ga->init([
               [qw/red blue green/],
               [qw/big medium small/],
               [qw/very_fat fat fit thin very_thin/],
              ]);

This initializes a population where each individual/chromosome has 3 genes and each gene can assume one of the given values.

=item B<rangevector>

For rangevectors, the argument is an anonymous list of lists. The number of sub-lists is equal to the number of genes of each individual/chromosome. Each sub-list defines the minimum and maximum integer values that the corresponding gene can assume.

    $ga->init([
               [1, 5],
               [0, 20],
               [4, 9],
              ]);

This initializes a population where each individual/chromosome has 3 genes and each gene can assume an integer within the corresponding range.

=item B<combination>

For combination, the argument is an anonymous list of possible values of gene.

    $ga->init( [ 'a', 'b', 'c' ] );

This initializes a population where each chromosome has 3 genes and each gene is uniq combination of 'a', 'b' and 'c'. For example genes looks something like that:

    [ 'a', 'b', 'c' ]    # gene 1
    [ 'c', 'a', 'b' ]    # gene 2
    [ 'b', 'c', 'a' ]    # gene 3
    # ...and so on...

=back

=item I<$ga>-E<gt>B<evolve>()

This method causes the GA to evolve the population for the specified number of generations. 

=item I<$ga>-E<gt>B<getHistory>()

Get history of the evolution. It is in a format listed below:

	[
		# gen0   gen1   gen2   ...          # generations
		[ max0,  max1,  max2,  ... ],       # max values
		[ mean,  mean1, mean2, ... ],       # mean values
		[ min0,  min1,  min2,  ... ],       # min values
	]

=item I<$ga>-E<gt>B<getAvgFitness>()

Get I<max>, I<mean> and I<min> score of the current generation. In example:

    my ($max, $mean, $min) = $ga->getAvgFitness();

=item I<$ga>-E<gt>B<getFittest>()

Get fittest chromosome.

=item I<$ga>-E<gt>B<generation>()

Get number of generation.

=item I<$ga>-E<gt>B<people>()

Returns an anonymous list of individuals/chromosomes of the current population. 

B<IMPORTANT:> the actual array reference used by the C<AI::Genetic::Pro> object is returned, so any changes to it will be reflected in I<$ga>.

=item I<$ga>-E<gt>B<chromosomes>()

Alias for C<people>.

=item I<$ga>-E<gt>B<chart>(%options)

Generate a chart describing changes of min, mean, max scores in Your
population. To satisfy Your needs, You can pass following options:

=over 4

=item -filename

File to save a chart in (B<obligatory>).

=item -title

Title of a chart (default: I<Evolution>).

=item -x_label

X label (default: I<Generations>).

=item -y_label

Y label (default: I<Value>).

=item -format

Format of values, like C<sprintf> (default: I<'%.2f'>).

=item -legend1

Description of min line (default: I<Min value>).

=item -legend2

Description of min line (default: I<Mean value>).

=item -legend3

Description of min line (default: I<Max value>).

=item -width

Width of a chart (default: I<640>).

=item -height

Height of a chart (default: I<480>).

=item -font

Path to font in (*.ttf format) to be used (default: none).

=item -logo

Path to logo (png/jpg image) to embed in a chart (default: none).

=item In example:

	$ga->chart(-width => 480, height => 320, -filename => 'chart.png');

=back

=item I<$ga>-E<gt>B<save>($file)

Save current state of the genetic algorithm to a specified file.

=item I<$ga>-E<gt>B<load>($file)

Load a state of the genetic algorithm from a specified file. 

=item I<$ga>-E<gt>B<as_array>($chromosome)

Return an array representing specified chromosome.

=item I<$ga>-E<gt>B<as_value>($chromosome)

Return score of specified chromosome. Value of I<chromosome> is 
calculated by fitness function.

=item I<$ga>-E<gt>B<as_string>($chromosome)

Return string-representation of specified chromosome. 

=back

=head1 DOCUMENTATION

This documentation is still incomplete, however it is based on POD of L<AI::Genetic>.
So if You are in a trouble, try to take a look to the documentation of L<AI::Genetic>.

=head1 SUPPORT

C<AI::Genetic::Pro> is still under development and it has poor 
documentation (for now). However it is used in many production environments.

=head1 TODO

=over 4

=item Examples.

=item More tests.

=item Warnings in case of incorrect parameters.

=back

=head1 REPORTING BUGS

When reporting bugs/problems please include as much information as possible.
It may be difficult for me to reproduce the problem as almost every setup
is different.

A small script which yields the problem will probably be of help. 

=head1 THANKS

Christoph Meissner for reporting a bug.

Alec Chen for reporting some bugs.

=head1 AUTHOR

Strzelecki Lukasz <strzelec@rswsystems.com>

=head1 SEE ALSO

L<AI::Genetic>

=head1 COPYRIGHT

Copyright (c) Strzelecki Lukasz. All rights reserved.
This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
