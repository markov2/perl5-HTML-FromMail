#oodist: *** DO NOT USE THIS VERSION FOR PRODUCTION ***
#oodist: This file contains OODoc-style documentation which will get stripped
#oodist: during its release in the distribution.  You can use this file for
#oodist: testing, however the code of this development version may be broken!

package HTML::FromMail::Object;
use base 'Mail::Reporter';

use strict;
use warnings;

#--------------------
=chapter NAME

HTML::FromMail::Object - base-class for convertable items

=chapter SYNOPSIS

=chapter DESCRIPTION

=chapter METHODS

=c_method new %options

=requires topic STRING
A symbolic representation of the group of objects which can be handled
by the producer.  Each extension of this base class will set a value for
this option, so you will usually not specify this yourself.

The topic is used to get the right default settings and templates.  See
M<HTML::FromMail::new(settings)> and M<HTML::FromMail::new(templates)>.

=option  settings \%map
=default settings {}
Contains the special settings for each of the topics.  This expects a %map
from topic names to configuration HASHes.
See M<HTML::FromMail::new(settings)>.

=cut

sub init($)
{	my ($self, $args) = @_;

	$self->SUPER::init($args) or return;

	defined($self->{HFO_topic} = $args->{topic})
		or $self->log(INTERNAL => 'No topic defined for '.ref($self)), exit 1;

	$self->{HFO_settings} = $args->{settings} || {};
	$self;
}

#--------------------
=section Attributes

=method topic
Returns the abstract topic of the producer.

=cut

sub topic() { $_[0]->{HFO_topic} }

=method settings [TOPIC]
Returns the settings for objects with a certain TOPIC, by default
for objects of the current.  An empty hash will be returned when
not settings where specified.
=cut

sub settings(;$)
{	my $self  = shift;
	my $topic = @_ ? shift : $self->topic;
	defined $topic or return {};
	$self->{HFO_settings}{$topic} || {};
}

#--------------------
=section Export

=section Other methods

=method plain2html STRING
Convert a STRING into HTML.
=cut

sub plain2html($)
{	my $self   = shift;
	my $string = join '', @_;
	for($string)
	{	s/\&/\&amp;/g;
		s/\</\&lt;/g;
		s/\>/\&gt;/g;
		s/"/\&quot;/g;
	}
	$string;
}

1;
