
use strict;
use warnings;

package HTML::FromMail::Default::Previewers;
use base 'HTML::FromMail::Object';

use Carp;
use File::Basename qw/basename dirname/;

=chapter NAME

Html::FromMail::Default::Previewers - produce smaller versions of data items

=chapter SYNOPSIS

=chapter DESCRIPTION

These functions define the default algorithms to produce previews for
message bodies.  When a message part is inlined, and there is an
htmlifier defined for it, that will be prevailed
(see M<HTML::FromMail::Default::HTMLifiers>).  When inlining is not possible
or not requested, there may be a preview constructed.  The defaults are
defined in this module.

Any function here shall return something reasonable, even if the conversion
fails for some reason.  Each fuction returns the data for a referenve to a
hash of values, which are accessible in the output formatter.  Each hash
must define either
 image => {}, html => ''     # an image is produced, or
 image => '', html => {}     # html was produced

Each of the functions is called with five arguments: PAGE, MESSAGE,
PART, ATTACH, and ARGS argument.  The PAGE is the object which produces pages,
an extension of M<HTML::FromMail::Page>.  The MESSAGE is the main message
which is displayed (a M<Mail::Message> object).  The PART is either
the whole MESSAGE or a part within a multipart or nested message (a
M<Mail::Message::Part> object).  The PART information is to be processed.

As ATTACH, a reference to a hash with information about the created
attachement is passed. This information is needed to produce the preview.
That same hash is extended with more information from the previewer, and
then accessible via the formatter.

The ARGS is a wild combination of information about the formatter
and information defined by it.  For instance, the arguments which are
passed with the tag in the template file can be found in there.  Print the 
content of the hash to see how much information you get... (sorry for this
rough description)

=chapter FUNCTIONS

=cut

our @previewers =
 ( 'text/plain' => \&previewText
 , 'text/html'  => \&previewHtml
 , 'image'      => \&previewImage  # added when Image::Magick is installed
 );

=function previewText PAGE, MESSAGE, PART, ATTACH, ARGS
Produce a small preview of the text, where all wrappig is removed.

=option  text_max_chars INTEGER
=default text_max_chars 250

=example of a plain text preview with the M<Text::MagicTemplate> formatter
 <!--{preview text_max_chars => 120}-->
    <!--{html}-->
       <blockquote><cite>
       <!--{text}-->&nbsp;...
       </cite></blockquote>
    <!--{/html}-->
 <!--{/preview}-->

=cut

sub previewText($$$$$)
{   my ($page, $message, $part, $attach, $args) = @_;

    my $decoded  = $attach->{decoded}->string;
    for($decoded)
    {   s/^\s+//;
        s/\s+/ /gs;     # lists of blanks
        s/([!@#$%^&*<>?|:;+=\s-]{5,})/substr($1, 0, 3)/ge;
    }

    my $max = $args->{text_max_chars} || 250;
    substr($decoded, $max) = '' if length $decoded > $max;

    +{ %$attach
     , image => ''            # this is not an image
     , html  => { text => $decoded }
     }
}

=function previewHtml PAGE, MESSAGE, PART, ATTACH, ARGS
Produce a small preview of the html, where first the title is taken
and put in bold. The rest of the header is removed.  Then the first
characters of the rest of the content are displayed.

=option  text_max_chars INTEGER
=default text_max_chars 250

=example of a plain text preview with the M<Text::MagicTemplate> formatter
 <!--{preview text_max_chars => 120}-->
    <!--{html}-->
       <blockquote><cite>
       <!--{text}-->&nbsp;...
       </cite></blockquote>
    <!--{/html}-->
 <!--{/preview}-->

=cut

sub previewHtml($$$$$)
{   my ($page, $message, $part, $attach, $args) = @_;

    my $decoded = $attach->{decoded}->string;
    my $title   = $decoded =~ s!\<title\b[^>]*\>(.*?)\</title\>!!i ? $1 : '';
    for($title)
    {   s/\<[^>]*\>//g;
        s/^\s+//;
        s/\s+/ /gs;
    }

    for($decoded)
    {   s!\<\!\-\-.*?\>!!g;         # remove comment
        s!\<script.*?script\>!!gsi; # remove script blocks
        s!\<style.*?style\>!!gsi;   # remove style-sheets
        s!^.*\<body!<!gi;           # remove all before body
        s!\<[^>]*\>!!gs;            # remove all tags
        s!\s+! !gs;                 # unfold lines
        s/([!@#$%^&*<>?|:;+=\s-]{5,})/substr($1, 0, 3)/ge;
    }

    my $max = $args->{text_max_chars} || 250;
    if(length $title)
    {   $decoded = "<b>$title</b>, $decoded";
        $max    += 7;
    }
    substr($decoded, $max) = '' if length $decoded > $max;

    +{ %$attach
     , image => ''            # this is not an image
     , html  => { text => $decoded }
     };
}

=function previewImage PAGE, MESSAGE, PART, ATTACH, ARGS
Produce a small preview of the html, where first the title is taken
and put in bold. The rest of the header is removed.  Then the first
characters of the rest of the content are displayed.

=option  img_max_width INTEGER
=default img_max_width 250

=option  img_max_height INTEGER
=default img_max_height 250

=example of a plain text preview with the M<Text::MagicTemplate> formatter
 <!--{preview img_max_width => 200, img_max_height => 200}-->
    <!--{image}-->
    <!--{/image}-->
 <!--{/preview}-->

=cut

BEGIN
{   eval { require Image::Magick };
    if($@) { warn "No Image::Magick installed" }
    else   { push @previewers, image => \&previewImage }
}

sub previewImage($$$$$)
{   my ($page, $message, $part, $attach, $args) = @_;

    my $filename = $attach->{filename};
    my $magick   = Image::Magick->new;
    my $error    = $magick->Read($filename);
    if(length $error)
    {   __PACKAGE__->log(ERROR =>
            "Cannot read image from $filename: $error");
        return;
    }

    my %image;
    my ($srcw, $srch) = @image{ qw/width height/ }
       = $magick->Get( qw/width height/ );

    my $base     = basename $filename;
    $base        =~ s/\.[^.]+$//;

    my $dirname  = dirname $filename;

    my $reqw     = $args->{img_max_width}  || 250;
    my $reqh     = $args->{img_max_height} || 250;

    if($reqw < $srcw || $reqh < $srch)
    {   # Size reduction is needed.
        $error   = $magick->Resize(width => $reqw, height => $reqh);
        if(length $error)
        {   __PACKAGE__->log(ERROR =>
                "Cannot resize image from $filename: $error");
            return;
        }

        my ($resw, $resh) = @image{ qw/smallwidth smallheight/ }
           = $magick->Get( qw/width height/ );

        my $outfile = File::Spec->catfile($dirname,"$base-${resw}x${resh}.jpg");
        @image{ qw/smallfile smallurl/ }
            = ($outfile, basename($outfile));

        $error      = $magick->Write($outfile);
        if(length $error)
        {   __PACKAGE__->log(ERROR =>
          "Cannot write smaller image from $filename to $outfile: $error");
            return;
        }
     }
     else
     {   @image{ qw/smallfile smallurl smallwidth smallheight/ }
            = ($filename, $attach->{url}, $srcw, $srch);
     }

    +{ %$attach
     , image => \%image
     , html  => ''            # this is not text
     };
}

1;
