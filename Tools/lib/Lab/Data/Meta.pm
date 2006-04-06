#!/usr/bin/perl -w

#$Id$

package Lab::Data::Meta;

use strict;
use Carp;
use Lab::Data::XMLtree;
use File::Basename;
use Cwd 'abs_path';
use Data::Dumper;
require Exporter;

our @ISA = qw(Exporter Lab::Data::XMLtree);

our $VERSION = sprintf("0.%04d", q$Revision$ =~ / (\d+) /);

our $AUTOLOAD;

our %EXPORT_TAGS = ( 'all' => [ qw() ] );
our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );
our @EXPORT = qw();

my $declaration = {
    data_complete               => ['SCALAR'],

    dataset_title               => ['SCALAR'],
    dataset_description         => ['SCALAR'],
    dataset_sample              => ['SCALAR'],
    data_file                   => ['SCALAR'],  # relativ zur descriptiondatei

    column                  => [
        'ARRAY',
        'id',
        {
            unit                => ['SCALAR'],
            label               => ['SCALAR'],  # evtl. weg
            description         => ['SCALAR'],
            min                 => ['SCALAR'],
            max                 => ['SCALAR'],
        }
    ],
    block                   => [
        'ARRAY',
        'id',
        {
            original_filename   => ['SCALAR'],
            timestamp           => ['SCALAR'],
            comment             => ['SCALAR']
        }
    ],
    axis                    => [
        'ARRAY',
        'id',
        {
            label               => ['SCALAR'],
            unit                => ['SCALAR'],
            expression          => ['SCALAR'],
            min                 => ['SCALAR'],
            max                 => ['SCALAR'],
            description         => ['SCALAR']
        }
    ],
    plot                    => [
        'HASH',
        'name',
        {
            type                => ['SCALAR'],
            'xaxis'             => ['SCALAR'],
            'yaxis'             => ['SCALAR'],
            'zaxis'             => ['SCALAR'],
            'caxis'             => ['SCALAR'],
            logscale            => ['SCALAR'],
        }
    ],
};

sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    bless $class->SUPER::new($declaration,pop @_), $class;
        # this pop is here as a clumsy work-around to
        # when xmltree creates a new Lab::Meta with a declaration
        # as first argument
}

sub new_from_file {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $filename=shift;
    my $self=$class->read_xml($declaration,$filename);
    my $filepath=abs_path($filename);
    my ($file,$path,$suffix)=fileparse($filepath, qr/\.[^.]*/);
    $path=~s/\\/\//g;
    $self->{__abs_path}=$path;
    return $self;
}

sub save {
    my $self = shift;
    my $filename = shift;
    $self->save_xml($filename,$self,'metadata');
    my $filepath=abs_path($filename);
    my ($file,$path,$suffix)=fileparse($filepath, qr/\.[^.]*/);
    $path=~s/\\/\//g;
    $self->{__abs_path}=$path;
}

sub get_abs_path {
    # I think this should really be someone else's job!
    my $self=shift;
    return $self->{__abs_path};
}
1;

__END__

=head1 NAME

Lab::Data::Meta - Meta data for datasets

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 CONSTRUCTOR

=head2 new([$contents])

=head1 METHODS

=head1 AUTHOR/COPYRIGHT

This is $Id$

Copyright 2004 Daniel Schr�er (L<http://www.danielschroeer.de>)

This library is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut
