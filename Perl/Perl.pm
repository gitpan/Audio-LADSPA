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

package Audio::LADSPA::Plugin::Perl;
use strict;
use Audio::LADSPA::Plugin;
our @ISA = qw(Audio::LADSPA::Plugin);
our $VERSION = sprintf("%d.%03d", '$Name: v0_008-2003-12-28 $' =~ /(\d+)_(\d+)/,0,0);
use Carp;
use Scalar::Util qw(weaken);

sub description {
    {
	name => 'Audio::LADSPA::Plugin::Perl',
	label => 'perl',
	maker => 'Joost Diepenmaat',
	copyright => 'GPL',
	id => '0',
	ports => [
	],
    }
}


sub port_count {
    my ($class) = @_;
    return scalar @{$class->description->{ports}};
}

sub _portd {
    my ($class,$port) = @_;
    return $class->description->{ports}->[ $class->port2index($port) ];
}

sub port_name {
    my ($class,$port) = @_;
    return $class->_portd($port)->{name};
}

sub _unregistered_connect {
    my ($self,$port,$buffer) = @_;
    $self->{buffers}->[ $self->port2index($port) ] = $buffer;
}

sub get_buffer {
    my ($self,$port) = @_;
    return $self->{buffers}->[ $self->port2index($port) ];
}

sub _unregistered_disconnect {
    my ($self,$port) = @_;
    $self->{buffers}->[ $self->port2index($port) ] = undef;
}

sub set_monitor {
    my ($self,$monitor) = @_;
    $self->{monitor} = $monitor;
    weaken($self->{monitor}) if defined $self->{monitor};
}

sub monitor {
    my ($self) = @_;
    return $self->{monitor};
}

sub port2index {
    my ($self,$name) = @_;
    croak "Port name/index undefined" unless defined $name;
    if ($name =~ /\D/) {
	unless ($self->{portindex}) {
	    for ( 0 .. $self->port_count -1 ) {
		$self->{portindex}->{ $self->port_name($_) } = $_;
	    }
	}
        croak "No such port $name" unless exists $self->{portindex}->{$name};
	my $index = $self->{portindex}->{$name};
#	warn "found index $index for name $name";
	return $index; 
    }
    return $name;
}

sub new {
    my ($class, $sample_rate)  = @_;
    if ($class eq 'Audio::LADSPA::Plugin::Perl') {
	croak "Audio::LADSPA::Plugin::Perl is an abstract class and cannot be instantiated!";
    }
    my $self = bless {
	sample_rate => $sample_rate,
    },$class;
    $self->init();
    return $self;
}

sub has_run {
    return $_[0]->can('run');
}

sub has_activate {
    return $_[0]->can('activate');
}

sub has_deactivate {
    return $_[0]->can('deactivate');
}

sub has_run_adding {
    return $_[0]->can('run_adding');
}
    

no strict 'refs';
for my $sub qw(id label name maker copyright is_realtime is_hard_rt_capable is_inplace_broken) {
    *{$sub} = sub {
	my ($self) = @_;
	return $self->description->{$sub};
    };
}
for my $sub qw(is_input is_control lower_bound upper_bound is_toggled is_integer is_sample_rate 
    is_logarithmic default) {
    *{$sub} = sub {
	my ($self,$port) = @_;
	return $self->_portd($port)->{$sub};
    };
}

1;

__END__

=pod

=head1 NAME

Audio::LADPSA::Plugin::Perl - Perl representation of ladspa plugins

=head1 DESCRIPTION

This is the base class for Perl based ladspa plugins. It inherits from
Audio::LADSPA::Plugin. This is module is mainly intended to make it
easier to glue other Perl modules to the system.

There is more to be said about this module, but I'll finish that part
when the API is done.

=head1 SEE ALSO

L<Audio::LADSPA::Play> - an implementation of a Perl based ladspa plugin.

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2003 Joost Diepenmaat <joost AT hortus-mechanicus.net>

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

