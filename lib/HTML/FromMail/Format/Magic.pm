#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package HTML::FromMail::Format::Magic;
use base 'HTML::FromMail::Format';

use strict;
use warnings;

use Carp;

BEGIN
{	eval { require Template::Magic };
	$@ and die "Install Bundle::Template::Magic for this formatter\n";
}

#--------------------
=chapter NAME

HTML::FromMail::Format::Magic - convert messages into HTML using Template::Magic

=chapter SYNOPSIS

=chapter DESCRIPTION

Convert messages into HTML using L<Template::Magic>.  This is a simple
template system, which focusses on giving produced pieces of HTML a place
in larger HTML structures.

=chapter METHODS

=c_method new OPTIONS

=cut

sub init($)
{	my ($self, $args) = @_;
	$self->SUPER::init($args) or return;
	$self;
}

sub export($@)
{	my ($self, %args) = @_;

	my $magic = $self->{HFFM_magic} = Template::Magic->new(
		markers       => 'HTML',
		zone_handlers => sub { $self->lookupTemplate(\%args, @_) },
	);

	open my($out), ">", $args{output}
		or $self->log(ERROR => "Cannot write to $args{output}: $!"), return;

	my $oldout = select $out;
	$magic->print($args{input});
	select $oldout;

	close $out;
	$self;
}


=method magic
Returns the L<Template::Magic> object which is used.
=cut

sub magic() { $_[0]->{HFFM_magic} }

=method lookupTemplate ARGS, ZONE
Kind of autoloader, used to discover the correct method to be invoked
when a pattern must be filled-in.
ZONE is the found L<Template::Magic::Zone> information.
=cut

sub lookupTemplate($$)
{	my ($self, $args, $zone) = @_;

	# Lookup the method to be called.
	my $method = 'html' . ucfirst($zone->id);
	my $prod   = $args->{producer};
	return undef unless $prod->can($method);

	# Split zone attributes into hash.  Added to %$args.
	my $param = $zone->attributes || '';
	$param =~ s/^\s+//;
	$param =~ s/\s+$//;

	my %args  = (%$args, zone => $zone);
	if(length $param)
	{	foreach my $pair (split /\s*\,\s*/, $param)
		{	my ($k, $v) = split /\s*\=\>\s*/, $pair, 2;
			$args{$k} = $v;
		}
	}

	my $value = $prod->$method($args{object}, \%args);
	$zone->value = $value if defined $value;
}

our $msg_zone;  # hack
sub containerText($)
{	my ($self, $args) = @_;
	my $zone = $args->{zone};
	$msg_zone = $zone if $zone->id eq 'message';  # hack
	$zone->content;
}

sub processText($$)
{	my ($self, $text, $args) = @_;
	my $zone = $args->{zone};

	# this hack is needed to get things to work :(
	# but this will not work in the future.
	$zone->_s = $msg_zone->_s;
	$zone->_e = $msg_zone->_e;
	$zone->merge;
}

sub lookup($$)
{	my ($self, $what, $args) = @_;
	my $zone  = $args->{zone} or confess;
	$zone->lookup($what);
}

sub onFinalToken($)
{	my ($self, $args) = @_;
	my $zone = $args->{zone} or confess;
	! defined $zone->content;
}

1;
