# This code is part of distribution HTML-FromMail.  Meta-POD processed with
# OODoc into POD and HTML manual-pages.  See README.md
# Copyright Mark Overmeer.  Licensed under the same terms as Perl itself.

package HTML::FromMail::Head;
use base 'HTML::FromMail::Page';

use strict;
use warnings;

use HTML::FromMail::Field;

=chapter NAME

HTML::FromMail::Head - output a message header as HTML

=chapter SYNOPSIS

=chapter DESCRIPTION

=chapter METHODS

=c_method new OPTIONS

=default topic C<'head'>

=cut

sub init($)
{   my ($self, $args) = @_;
    $args->{topic} ||= 'head';

    $self->SUPER::init($args) or return;

    $self;
}

=ci_method fields MESSAGE, OPTIONS
Collect information about the header fields.

=option  select STRING
=default select ''
Select only the fields which match the patterns found in STRING.  Multiple
patterns can be specified separated by vertical bars (I<pipes>).  The fields
are ordered as specified in the STRING.
See M<Mail::Message::Head::Complete::grepNames()>.

=option  ignore STRING
=default ignore C<undef>
The reverse of C<select>: which fields not to take.

=option  remove_list_group BOOLEAN
=default remove_list_group 1
Do not select the headers which are added by mailing list software.
See M<Mail::Message::Head::ListGroup>.

=option  remove_spam_groups BOOLEAN
=default remove_spam_groups 1
Do not select headers which were added by spam fighting software.  See
M<Mail::Message::Head::SpamGroup>.

=option  remove_resent_groups BOOLEAN
=default remove_resent_groups 1
Remove all the lines which are related to transport of the message, for
instance the C<Received> and C<Return-Path>, and all lines which start
with C<Resent->.  See M<Mail::Message::Head::ResentGroup>.

=cut

sub fields($$)
{   my ($thing, $realhead, $args) = @_;
    my $head = $realhead->clone;   # we are probably going to remove lines

    my $lg = $args->{remove_list_group};
    $head->removeListGroup    if $lg || !defined $lg;

    my $sg = $args->{remove_spam_groups};
    $head->removeSpamGroups   if $sg || !defined $sg;

    my $rg = $args->{remove_resent_groups};
    $head->removeResentGroups if $rg || !defined $rg;

    my @fields;
    if(my $select = $args->{select})
    {   my @select = split /\|/, $select;
        @fields    = map {$head->grepNames($_)} @select;
    }
    elsif(my $ignore = $args->{ignore})
    {   my @ignore = split /\|/, $ignore;
        local $"   = ")|(?:";
        my $skip   = qr/^(?:@ignore)/i;
        @fields    = grep { $_->name !~ $skip } $head->orderedFields;
    }
    else
    {   @fields    = $head->orderedFields;
    }

    map {$_->study} @fields;
}

1;
