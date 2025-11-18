#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package HTML::FromMail::Format::OODoc;
use base 'HTML::FromMail::Format';

use strict;
use warnings;

use Carp;
use OODoc::Template;

#--------------------
=chapter NAME

HTML::FromMail::Format::OODoc - convert messages into HTML using OODoc::Template

=chapter SYNOPSIS

  my $fmt = HTML::FromMail->new(
    templates => ...,
    formatter => 'OODoc',   # but this is also the default
  );

=chapter DESCRIPTION

Convert messages into HTML using L<OODoc::Template>.  This is a simple
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

	my $oodoc  = $self->{HFFM_oodoc} = OODoc::Template->new;

	my $output = $args{output};
	open my($out), ">", $output
		or $self->log(ERROR => "Cannot write to $output: $!"), return;

	my $input  = $args{input};
	open my($in), "<", $input
		or $self->log(ERROR => "Cannot open template file $input: $!"), return;

	my $template = join '', <$in>;
	close $in;

	my %defaults = (
		DYNAMIC => sub { $self->expand(\%args, @_) },
	);

	my $oldout   = select $out;
	$oodoc->parse($template, \%defaults);
	select $oldout;

	close $out;
	$self;
}

=method oodoc
Returns the L<OODoc::Template> object which is used.
=cut

sub oodoc() { $_[0]->{HFFM_oodoc} }

=method expand ARGS, TAG, ATTRS, TEXTREF
Kind of autoloader, used to discover the correct method to be invoked
when a pattern must be filled-in.

=cut

sub expand($$$)
{	my ($self, $args, $tag, $attrs, $textref) = @_;

	# Lookup the method to be called.
	my $method = 'html' . ucfirst($tag);
	my $prod   = $args->{producer};

	$prod->can($method) or return undef;

	my %info  = (%$args, %$attrs, textref => $textref);
	$prod->$method($args->{object}, \%info);
}

sub containerText($)
{	my ($self, $args) = @_;
	my $textref = $args->{textref};
	defined $textref ? $$textref : undef;
}

sub processText($$)
{	my ($self, $text, $args) = @_;
	$self->oodoc->parse($text, {});
}

sub lookup($$)
{	my ($self, $what, $args) = @_;
	$self->oodoc->valueFor($what);
}

sub onFinalToken($)
{	my ($self, $args) = @_;
	not (defined $args->{textref} && defined ${$args->{textref}});
}

1;
