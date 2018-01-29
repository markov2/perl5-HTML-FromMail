
use strict;
use warnings;

package HTML::FromMail::Format::Magic;
use base 'HTML::FromMail::Format';

use Carp;

BEGIN
{   eval { require Text::MagicTemplate };
    die "Install Bundle::Text::MagicTemplate for this formatter\n"
       if $@;

    Text::MagicTemplate->VERSION('3.05');
}

=chapter NAME

HTML::FromMail::Format::Magic - convert messages into HTML using Text::MagicTemplate

=chapter SYNOPSIS

=chapter DESCRIPTION

Convert messages into HTML using L<Text::MagicTemplate>.  This is a simple
template system, which focusses on giving produced pieces of HTML a place
in larger HTML structures.

=chapter METHODS

=c_method new OPTIONS

=cut

sub init($)
{   my ($self, $args) = @_;

    $self->SUPER::init($args) or return;

    $self;
}

sub export($@)
{   my ($self, %args) = @_;

    my $magic = $self->{HFFM_magic}
      = Text::MagicTemplate->new
         ( markers       => 'HTML'
         , zone_handlers => sub { $self->lookupTemplate(\%args, @_) }
         );

   $self->log(ERROR => "Cannot write to $args{output}: $!"), return
      unless open my($out), ">", $args{output};

   my $oldout = select $out;
   $magic->print($args{input});
   select $oldout;

   close $out;
   $self;
}


=method magic
Returns the L<Text::MagicTemplate> object which is used.
 
=cut

sub magic() { shift->{HFFM_magic} }

=method lookupTemplate ARGS, ZONE
Kind of autoloader, used to discover the correct method to be invoked
when a pattern must be filled-in.
ZONE is the found L<Ttxt::MagicTemplate::Zone> information.

=cut

sub lookupTemplate($$)
{   my ($self, $args, $zone) = @_;

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
    {   foreach my $pair (split /\s*\,\s*/, $param)
        {   my ($k, $v) = split /\s*\=\>\s*/, $pair, 2;
            $args{$k} = $v;
        }
    }

    my $value = $prod->$method($args{object}, \%args);
    $zone->value = $value if defined $value;
}

our $msg_zone;  # hack
sub containerText($)
{   my ($self, $args) = @_;
    my $zone = $args->{zone};
    $msg_zone = $zone if $zone->id eq 'message';  # hack
    $zone->content;
}

sub processText($$)
{   my ($self, $text, $args) = @_;
    my $zone = $args->{zone};

    # this hack is needed to get things to work :(
    # but this will not work in the future.
    $zone->_s = $msg_zone->_s;
    $zone->_e = $msg_zone->_e;
    $zone->merge;
}

sub lookup($$)
{   my ($self, $what, $args) = @_;
    my $zone  = $args->{zone} or confess;
    $zone->lookup($what);
}

sub onFinalToken($)
{   my ($self, $args) = @_;
    my $zone = $args->{zone} or confess;
    ! defined $zone->content;
}

1;
