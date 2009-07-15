package Net::AMQP::Frame;

=head1 NAME

Net::AMQP::Frame - AMQP wire-level Frame object

=cut

use strict;
use warnings;
use base qw(Class::Data::Inheritable Class::Accessor);
use Net::AMQP::Common qw(:all);
use Params::Validate qw(validate validate_with);
use Carp;

BEGIN {
    __PACKAGE__->mk_classdata('type_id');
    __PACKAGE__->mk_accessors(qw(
        channel
        size
        payload
    ));
}

# Use all the subclasses
use Net::AMQP::Frame::Method;
use Net::AMQP::Frame::Header;
use Net::AMQP::Frame::Body;

our $VERSION = 0.01;

=head1 CLASS METHODS

=head2 new (...)

=over 4

Takes an arbitrary list of key/value pairs and casts it into this class.  Nothing special here.

=back

=cut

sub new {
    my ($class, %self) = @_;
    return bless \%self, $class;
}

=head2 factory (...)

=over 4

Pass in 'type_id', 'channel' and 'payload'.  Will attempt to identify a L<Net::AMQP::Frame> subclass for further parsing, and will croak on failure.  Returns a L<Net::AMQP::Frame> subclass object.

=back

=cut

sub factory {
    my $class = shift;
    my %args = validate(@_, {
        type_id => 1,
        channel => 1,
        payload => 1,
    });

    my $subclass;
    if ($args{type_id} == 1) {
        $subclass = 'Method';
    }
    elsif ($args{type_id} == 2) {
        $subclass = 'Header';
    }
    elsif ($args{type_id} == 3) {
        $subclass = 'Body';
    }
    else {
        croak "Unknown type_id $args{type_id}";
    }

    $subclass = 'Net::AMQP::Frame::' . $subclass;
    my $object = bless \%args, $subclass;
    $object->parse_payload();
    return $object;
}

=head1 OBJECT METHODS

=head2 Field accessors

=over 4

Each subclass extends these accessors, but they share in common the following:

=over 4

=item I<type_id>

=item I<channel>

=item I<size>

=item I<payload>

=back

=back

=head2 parse_payload

=over 4

Performs the parsing of the 'payload' binary data.

=back

=head2 to_raw_payload

=over 4

Returns the binary data the represents this frame's payload.

=back

=head2 to_raw_frame

=over 4

Returns a raw binary string representing this frame on the wire.

=back

=cut

sub to_raw_frame {
    my $self = shift;
    my $class = ref $self;

    if (! defined $self->channel) {
        $self->channel(0);
    }

    return pack('Cn', $self->type_id, $self->channel)
        . pack_long_string($self->to_raw_payload())
        . pack('C', 206);
}

=head2 type_string

=over 4

Returns a string that uniquely represents this frame type, such as 'Method Basic.Consume', 'Header Basic' or 'Body'

=back

=cut

sub type_string {
    my $self = shift;

    my ($type) = ref($self) =~ m{::([^:]+)$};

    my $subtype;
    if ($self->can('method_frame')) {
        ($subtype) = ref($self->method_frame) =~ m{^Net::AMQP::Protocol::(.+)$};
        my ($class, $method) = split /::/, $subtype;
        $subtype = join '.', $class, $method;
    }
    elsif ($self->can('header_frame')) {
        ($subtype) = ref($self->header_frame) =~ m{^Net::AMQP::Protocol::(.+)::ContentHeader$};
    }

    return $type . ($subtype ? " $subtype" : '');
}

=head1 SEE ALSO

L<Net::AMQP>

=head1 COPYRIGHT

Copyright (c) 2009 Eric Waters and XMission LLC (http://www.xmission.com/).  All rights reserved.  This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the LICENSE file included with this module.

=head1 AUTHOR

Eric Waters <ewaters@gmail.com>

=cut

1;