#!/usr/bin/perl -w

#
# GPIB Connection class for Lab::Bus::LinuxGPIB
#
package Lab::Connection::MODBUS_RS232;
use strict;
use Scalar::Util qw(weaken);
use Time::HiRes qw (usleep sleep);
use Lab::Connection::GPIB;
use Lab::Exception;

our @ISA = ("Lab::Connection");

our %fields = (
	bus_class => 'Lab::Bus::MODBUS_RS232',
	wait_status=>0, # usec;
	wait_query=>10, # usec;
	read_length=>1000, # bytes
);


sub new {
	my $proto = shift;
	my $class = ref($proto) || $proto;
	my $self = $class->SUPER::new(@_); # getting fields and _permitted from parent class
	$self->_construct(__PACKAGE__, \%fields);

	return $self;
}


# this does not really make sense for MODBUS, as there are no "commands" and "responses"
# disable for the time being
# maybe makes sense: write value to one address, wait, read from another address.
sub Query {
	my $self=shift;
	my $options=undef;
	if (ref $_[0] eq 'HASH') { $options=shift }
	else { $options={@_} }

	warn "Query is not implemented (and makes no sense) for MODBUS connections. Use Read. Ignoring.\n";
	return undef;
}





# 	return undef unless $self->slave_address($self->config()->{'slave_address'});
# 	# check the configuration hash for a valid bus object or bus type, and set the bus
# 	if( defined($self->config()->{'Bus'}) ) {
# 		if($self->_checkbus($self->config()->{'Bus'})) {
# 			$self->Bus($self->config()->{'Bus'});
# 		}
# 		else { 
# 			warn('Given Bus not supported');
# 			return undef;
# 		}
# 	}
# 	else {
# 		if($self->_checkbus($self->config()->{'ConnType'})) {
# 			my $ConnType = $self->config()->{'ConnType'};
# 			my $Port = $self->config()->{'Port'};
# 			my $slave_address = $self->config()->{'slave_address'};
# 			my $Interface = "";
# 			if($ConnType eq 'MODBUS_RS232') {
# 				$self->config()->{'Interface'} = 'RS232';
# 				$self->Bus(new Lab::Bus::MODBUS_RS232( $self->config() )) || croak('Failed to create bus');
# 				#$self->Bus(eval("new Lab::Bus::$ConnType( $self->config() )")) || croak('Failed to create bus');
# 			}
# 			else {
# 				warn('Only RS232 bus type supported for now!\n');
# 				return undef;
# 			 }
# 		}
# 		else {
# 			warn('Given Bus Type not supported');
# 			return undef;
# 		}
# 	}










#
# Nothing to do, Read, Write, Query from Lab::Connection are sufficient.
#


=head1 NAME

Lab::Connection::LinuxGPIB - connection class which uses linux-gpib (libgpib0) as a backend.

=head1 SYNOPSIS

This is not called directly. To make a GPIB suppporting instrument use Lab::Connection::LinuxGPIB, set
the connection_type parameter accordingly:

$instrument = new HP34401A(
   connection_type => 'LinuxGPIB',
   gpib_board => 0,
   gpib_address => 14
)

=head1 DESCRIPTION

C<Lab::Connection::LinuxGPIB> provides a GPIB-type connection with L<Lab::Bus::LinuxGPIB> using L<Linux GPIB (aka libgpib0 in debian)|http://linux-gpib.sourceforge.net/> as backend.

It inherits from L<Lab::Connection::GPIB> and subsequently from L<Lab::Connection>.

For L<Lab::Bus::LinuxGPIB>, the generic methods of L<Lab::Connection> suffice, so only a few defaults are set:
  wait_status=>0, # usec;
  wait_query=>10, # usec;
  read_length=>1000, # bytes

=head1 CONSTRUCTOR

=head2 new

 my $connection = new Lab::Connection::LinuxGPIB(
    gpib_board => 0,
    gpib_address => $address,
    gpib_saddress => $secondary_address
 }

=head1 METHODS

This just calls back on the methods inherited from L<Lab::Connection>.


=head2 config

Provides unified access to the fields in initial @_ to all the cild classes.
E.g.

 $GPIB_PAddress=$instrument->Config(GPIB_PAddress);

Without arguments, returns a reference to the complete $self->Config aka @_ of the constructor.

 $Config = $connection->Config();
 $GPIB_PAddress = $connection->Config()->{'GPIB_PAddress'};
 
=head1 CAVEATS/BUGS

Probably view. Mostly because there's not a lot to be done here. Please report.

=head1 SEE ALSO

=over 4

=item L<Lab::Connection>

=item L<Lab::Connection::GPIB>

=back

=head1 AUTHOR/COPYRIGHT

This is $Id$

 Copyright 2011      Florian Olbrich

This library is free software; you can redistribute it and/or modify it under the same
terms as Perl itself.

=cut

1;