# Audio::LADSPA perl modules for interfacing with LADSPA plugins
# Copyright (C) 2003  Joost Diepenmaat.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
# See the COPYING file for more information.

package Audio::LADSPA::Network;
use strict;
our $VERSION = sprintf("%d.%03d", '$Name: v0_013-2004-06-30 $' =~ /(\d+)_(\d+)/,0,0);
use Audio::LADSPA;
use Graph::Directed;
use Carp;

sub new {
    my ($class,%args) = @_;
    my $self = bless { 
	graph => Graph::Directed->new,
	sample_rate => $args{sample_rate} || 44100,
	buffer_size => $args{buffer_size} || 1024, 
	run_order => undef, 
	%args,
    },$class;
    return $self;
}

sub sample_rate {
    my $self = shift;
    return $self->{sample_rate};
}

sub _make_plugin {
    my $self = shift;
    my $plugin;
    if (@_ == 1) {
	$plugin = shift; 
        unless (ref ($plugin)) {
	    $plugin = $plugin->new($self->{sample_rate});
	}
    }
    else {
	$plugin = Audio::LADSPA->plugin(@_)->new($self->{sample_rate});
    }
    $plugin->set_monitor($self);    # register callbacks.
    return $plugin;
}

sub graph {
    return $_[0]->{graph};
}

sub add_plugin {
    my ($self) = shift;
    my $plugin = $self->_make_plugin(@_);
    $self->graph->add_vertex($plugin);
    $self->graph->set_attribute('plugin',$plugin,$plugin);
    for ($plugin->ports()) {
	$self->_connect_default($plugin,$_);
    }
    return $plugin; 
}

sub plugins {
    my ($self) = @_;
    if (!$self->{run_order}) {
	$self->{run_order} = [ map { my $p = $self->graph->get_attribute('plugin',$_); $p ? $p : () } $self->graph->toposort() ];
    }

    return @{$self->{run_order}};
}

sub has_plugin {
    my ($self,$plugin) = @_;
    return $self->graph->has_vertex($plugin);
}

sub add_buffer {
    my ($self,$buff) = @_;
    if (!ref $buff) {
	$buff = Audio::LADSPA::Buffer->new($buff);
    }
    $self->graph->add_vertex($buff);
    $self->graph->set_attribute('buffer',$buff,$buff);
    return $buff;
}

sub buffers {
    my ($self) = @_;
    return map { my $b = $self->graph->get_attribute('buffer', $_); $b ? $b : () } $self->graph->vertices();
}
sub has_buffer {
    my ($self,$buffer) = @_;
    return $self->graph->has_vertex($buffer);
}


sub _connect_default {
    my ($self,$plugin,$port) = @_;
    croak "Logic error: port $port already connected" if ($plugin->get_buffer($port));
    my $buffer;
    if ($plugin->is_control($port)) {
	$buffer = $self->add_buffer(1);
	$buffer->set($plugin->default_value($port));
    }
    else {
	$buffer = $self->add_buffer($self->{buffer_size});
    }
    warn "monitor != network for plugin $plugin" if $plugin->monitor ne $self;
    $plugin->connect($port,$buffer);
}

sub DESTROY {
    my ($self) = @_;
    # disconnect all plugins, otherwise the buffers might not
    # be freed (?) I think I already fixed that, but anyway... 
    
    for ($self->plugins()) {
       $_->disconnect_all();
    }

    # this is not really needed, but it make for a nice place
    # for things to break down, if I mix up the reference counts again.
    delete $self->{graph};
    $self->{run_order} = undef;
}

sub run {
    my ($self,$samples) = @_;
    croak "Cannot run for more than buffer_size samples" if ($samples > $self->{buffer_size});
    for ($self->plugins) {
        $_->run($samples);
    }
}

sub connect {
    my ($self,$from_plug,$from_port,$to_plug,$to_port) = @_;
    if ($from_plug eq $to_plug) {
	warn "Cannot create loop to self";
	return 0;
    }
    unless ($from_plug->is_input($from_port) xor $to_plug->is_input($to_port)) {
	warn "Can only connect input to output";
	return 0;
    }
    if ($from_plug->is_input($from_port)) {
	($from_plug,$from_port,$to_plug,$to_port) = ($to_plug,$to_port,$from_plug,$from_port);
    }
    if ($from_plug->is_control($from_port) and ! $to_plug->is_control($to_port)) {
	warn "Can not connect from control to audio port (you CAN do it the other way around)";
	return 0;
    }
    for ($from_plug,$to_plug) {
	$self->add_plugin($_) unless $self->has_plugin($_);
    }
    # note that connecting the other way around will create
    # problems when connecting an audio-out to crontrol-in port
    my $buffer = $from_plug->get_buffer($from_port);
    return $to_plug->connect($to_port => $buffer);
}

sub disconnect {
    my ($self,$plug,$port) = @_;
    $plug->disconnect($port);
    $self->_connect_default($plug,$port);
}

sub cb_connect {
    my ($self,$plug,$port,$buffer) =  @_;
    for ($plug,$port,$buffer) {
        croak("Undef'd plug/port/buffer") unless defined $_;
    }
    if (!$self->has_buffer($buffer)) {
	$self->add_buffer($buffer);
    }
    if (!$self->has_plugin($plug)) {
	$self->add_plugin($plug);
    }

    #   try out to see if we get cycles
    my $H = $self->graph->copy();
    if ($plug->is_input($port)) {
	$H->add_edge($buffer,$plug);
    }
    else {
	$H->add_edge($plug,$buffer);
    }
    if (reduce_to_cycles($H)->vertices) {
	return 0;
    }

    # fine, now for real
    if ($plug->is_input($port)) {
	$self->graph->add_edge($buffer,$plug);
	$self->graph->set_attribute("port",$buffer,$plug,$port);
    }
    else {
	$self->graph->add_edge($plug,$buffer);
	$self->graph->set_attribute("port",$plug,$buffer,$port);
	
    }
    $self->{run_order} = undef;
    return 1;
}

sub cb_disconnect {
    my ($self,$plug,$port) = @_;
    my $buffer = $plug->get_buffer($port);
    if ($buffer) {
	if ($plug->is_input($port)) {
	    $self->graph->delete_edge($buffer,$plug);
	}
	else {
	    $self->graph->delete_edge($plug,$buffer);
	}
    }
    $self->cleanup_buffers();
    $self->{run_order} = undef;
}

sub cleanup_buffers {
    my ($self) = @_;
    for ($self->buffers) {
	$self->graph->delete_vertex($_) unless $self->graph->edges($_);
    }
}

# returns a graph cointaining all vertices that are in one
# or more cycles.
# see also http://www.perlmonks.org/index.pl?node_id=316982

sub cycles {
    my $G = shift;
    my $H = $G->copy;
    return reduce_to_cycles($H);
}

# reduce_to_cycles() modifies the input graph, use cycles() to make
# a copy first.

sub reduce_to_cycles {
    my $G = shift;
    while ($G->vertices) {
# get the 'end' vertices
        my @ends = grep { ! $G->out_edges($_) or ! $G->in_edges($_) } $G->vertices; 
        if (@ends) {
# remove 'end' vertices, and repeat
            $G->delete_vertices(@ends);
            next;
        }
        else {
# Graph is not empty, but also has no end vertices
# any more, so we're left with cycles...
            return $G;     
        }
    }
    return $G;
}   


sub connections {
    my ($self,$plug,$port) = @_;
    my $buffer = $plug->get_buffer($port) or croak "$plug has no buffer for port $port";
    my @res;
    for my $plug2 (grep {defined $_ and ( $_ ne $buffer && $_ ne $plug) } $self->graph->edges($buffer)) {
	my $port2 =  $self->graph->get_attribute("port",$plug2,$buffer) || $self->graph->get_attribute("port",$buffer,$plug2);
	die "no port found for edge $buffer <-> $plug2" unless $port2;
	$plug2 = $self->graph->get_attribute("plugin",$plug2) or die "Can't find $plug2";
	push @res,$plug2,$port2;
    }
    return @res;
}

sub delete {
    my ($self,$plugin) = @_;
    $self->graph->delete_vertex($plugin);
    $plugin->disconnect_all();
}    

sub dump {
    my ($self) = @_;
    return {
	'Audio::LADSPA::Network' => $VERSION,
	'DumpVersion' => 0.01,
	'Plugins' => [ map { $self->dump_plugin($_) } $self->plugins ],
	'SampleRate' => $self->sample_rate,
	'BufferSize' => $self->{buffer_size},
    };
}

sub dump_plugin {
    my ($self,$plug) = @_;
    my $dump = {
	Class => ref($plug),
	Ports => [],
	Id => $plug->sessionid,
    };
    for ($plug->ports) {
	my $port_dump = {
	    Name => $_,
	};
	if ($plug->is_control($_) && $plug->is_input($_)) {
	    $port_dump->{Value} = $plug->get_buffer($_)->get_1;
	}
	unless ($plug->is_input($_)) {
	    my @connections = $self->connections($plug,$_);
	    $port_dump->{Connections} = [];
	    while (my ($plug2,$port2) = splice(@connections,0,2)) {
		push @{$port_dump->{Connections}}, { 
		    Id => $plug2->sessionid, 
		    Port => $port2 };
	    }
	}
	push @{$dump->{Ports}},$port_dump;
    }
    return $dump;
}

sub from_dump {
    my ($self,$dump) = @_;
    croak "Not an Audio::LADSPA::Network dump" unless exists $dump->{'Audio::LADSPA::Network'};
    croak "Incompatible dump version $dump->{Version} (must be < 1.0)" if $dump->{DumpVersion} >= 1.0;
    if (ref $self) {
	if ($self->sample_rate != $dump->{SampleRate}) {
	    warn "SampleRate from dump differs from current sample rate";
	}
	if ($self->{buffer_size} != $dump->{BufferSize}) {
	    warn "BufferSize from dump differs from current buffer size";
	}
    }
    else {
	$self = $self->new( 
	    sample_rate => $dump->{SampleRate}, 
	    buffer_size => $dump->{BufferSize}
	) or croak "Cannot initialize new network";
    }
    my %plug_by_id;
    for my $plugin_dump (reverse @{$dump->{Plugins}}) {
	
	my $plugin = $self->add_plugin($plugin_dump->{Class});
	$plug_by_id{$plugin_dump->{Id}} = $plugin;
	
	for my $port_dump (@{$plugin_dump->{Ports}}) {
	    for my $remote (@{$port_dump->{Connections}}) {
		$self->connect(
		    $plugin,
		    $port_dump->{Name},
		    $plug_by_id{$remote->{Id}},
		    $remote->{Port}
		) or croak "Cannot connect $plugin $port_dump->{Name} => $plug_by_id{$remote->{Id}} ($remote->{Id}) $remote->{Port}";
	    }
	    $plugin->set($port_dump->{Name},$port_dump->{Value}) if exists $port_dump->{Value};
	}
    }
    return $self;
}


1;

__END__

=pod

=head1 NAME

Audio::LADSPA::Network - Semi automatic connection of Audio::LADSPA::* objects

=head1 SYNOPSIS

    use Audio::LADSPA::Network;
    use Audio::LADSPA::Plugin::Play;

    my $net = Audio::LADSPA::Network->new();
    my $sine = $net->add_plugin( label => 'sine_fcac' );
    my $delay = $net->add_plugin( label => 'delay_5s' );
    my $play = $net->add_plugin('Audio::LADSPA::Plugin::Play');

    $net->connect($sine,'Output',$delay,'Input');
    $net->connect($delay,'Output',$play,'Input');
    
    $sine->set('Frequency (Hz)' => 440); # set freq
    $sine->set(Amplitude => 1);   # set amp

    $delay->set('Delay (Seconds)' => 1); # 1 sec delay
    $delay->set('Dry/Wet Balance' => 0.2); # balance - 0.2

    for ( 0 .. 100 ) {
        $net->run(100);
    }
    $sine->set(Amplitude => 0); #just delay from now
    for ( 0 .. 500 ) {
        $net->run(100);
    }

=head1 DESCRIPTION

This module makes it easier to create connecting Audio::LADSPA::Plugin
objects. It automatically keeps the sampling frequencies correct for all plugins,
adds control and audio buffers to unconnected plugins, detects illegal connections etc.

=head1 CLASS METHODS

=head2 new

 my $network = Audio::LADSPA::Network->new( 
    sample_rate => $sample_rate, 
    buffer_size => $buffer_size 
 );

Construct a new Audio::LADSPA::Network. The sample_rate and buffer_size arguments may be omitted.
The default sample_rate is 44100, the default buffer_size is 1024.

=head1 OBJECT METHODS

=head2 add_plugin

 my $plugin = $network->add_plugin( EXPR );

Adds a $plugin to the $network. All unconnected ports will be connected to new C<Audio::LADSPA::Buffer>s.
Control buffers will be initalized with the correct default value for the port.

EXPR can be an Audio::LADSPA::Plugin object, an Audio::LADSPA::Plugin classname or any
expression supported by L<< Audio::LADSPA->plugin()|Audio::LADSPA/plugin >>.

Any $plugin added to a $network will have its monitor set to that $network. This
means that a $plugin cannot be in more than 1 Audio::LADSPA::Network at any given time, and that
all callbacks from the $plugin are handled by the $network. 

See also L<Audio::LADSPA::Plugin/SETTING CALLBACKS>.

=head2 has_plugin

 if ($network->has_plugin($plugin)) {
     # something interesting...
 }

Check if a given $plugin object exists in the $network. $plugin must be an Audio::LADSPA::Plugin object.

=head2 plugins

 my @plugins = $network->plugins();

Returns all @plugins in the $network in topological order - this means that the plugins will
be sorted so that if $plugin2 recieves input from $plugin1, $plugin1 will be before $plugin2
in the @plugins list.

Because the topological sorting is expensive (that is, for semi-realtime audio generation),
the result of this operation is cached as long as the network does not change.

=head2 delete

 $network->delete($plugin);

Delete a plugin from the network

=head2 add_buffer

 my $buffer = $network->add_buffer( EXPR );

Add a $buffer to the $network. EXPR may be an Audio::LADSPA::Buffer object, or an integer
specifying the $buffer's size.

This method is usually not needed by users of the module, as the connect() and
add_plugin() methods take care of creating new buffers for you. Also note that
buffers not immediately connected to a plugin will be removed when the network
changes in any other way.

=head2 has_buffer

 if ($network->has_buffer($buffer)) {
   # ...
 }

Returns true if the $buffer is already in the $network.

=head2 buffers

 my @buffers = $network->buffers();

Returns all the $buffers in the $network.

=head2 connect

 unless ($network->connect( $plugin1, $port1, $plugin2, $port2 )) {
     warn "Connection failed";
 }

Connect $port1 of $plugin1 with $port2 of $plugin2. Plugins are
added to the network and new buffers are created if needed.

This method will only connect input ports to output ports. If the output
port is a control port, the input port must be a control port, if the
output port is an audio port, the type of input port does not matter.
The order in which the plugins are specified does not matter.

I<There is currently no special handling of incompatible value ranges. 
Well behaved plugins should accept any value on any port, even if they specify a
range. Note that generic 0dB audio signals should be in the range -1 .. 1,
but that control signals usually have completely different ranges.>

Returns true on success, false on failure.

B<< You are advised to use this method instead of $plugin->connect( $buffer ) >>.
I<Some> of the magic in this method also works for C<< $plugin->connect() >>, if the
plugin is already added to the network, but that might change if the implementation
changes. YMMV. 

=head2 disconnect

 $network->disconnect($plugin,$port);

Will disconnect the specified port from any buffer, and put
a "dummy" buffer in its place. This means that you can still call
run() the plugin after disconnecting. See also $network->delete().

=head2 delete

 $network->delete($plugin);

Completely remove the plugin from the network. This will also disconnect
the plugin from all buffers that it currently holds. 

=head2 connections

 my @connections = $network->connections($plugin,$port);

Returns a $remote_plug1, $remote_port1, $remote_plug2, $remote_port2 ... list
of all the plugin/port combinations the $plugin's $port is connected to
in this $network. Connecting an input port to more than 1 output port is not
supported, and the rules on connection an output port to more than one input
port are not fixed yet, but keep in mind that this method MAY return more
than one plugin/port pair.

=head2 run

 $network->run( $number_of_samples );

Call $plugin->run( $number_of_samples ) on all plugins in the $network.
Throws an exception when $number_of_samples is higher than the $buffer_size
specified at the L<constructor|CONSTRUCTOR>.

=head1 SERIALIZATION

The internal structure of the network prevents easy serialisation (Data::Dumper
and the like will not give you a dump that you can read back). To overcome this
problem 2 methods have been added:

=head2 dump

 my $dump = $network->dump;

Returns a serializable, nested structure that represents the whole network.
You can use YAML or Data::Dumper or something similar to serialize the structure.

I<YAML is the only serializer I tested this with, because it creates
nice, readable files, but other dumpers should work>.

=head2 from_dump

 my $network = Audio::LADSPA::Network->from_dump($dump);
 
Creates new network based on the $dump. If used as on object method (ie, called
on an existing $network), it tries to import the network into the existing one.

=head1 SEE ALSO

L<Audio::LADSPA>, L<Graph::Base>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2003 Joost Diepenmaat <joost AT hortus-mechanicus.net>

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

