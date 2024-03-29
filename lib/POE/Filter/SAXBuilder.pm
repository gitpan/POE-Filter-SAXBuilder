package POE::Filter::SAXBuilder;
use strict;
use warnings;

our $VERSION = '0.04_01';
use base qw(POE::Filter);

use Error;
use XML::LibXML;
use POE::Filter::SAXBuilder::Builder;

=head1 NAME

POE::Filter::SAXBuilder - A POE Filter for parsing XML with L<XML::LibXML>

=head1 SYSNOPSIS

  use POE::Filter::SAXBuilder;
  my $filter = POE::Filter::SAXBuilder->new();

  my $wheel = POE::Wheel:ReadWrite->new(
 	Filter		=> $filter,
	InputEvent	=> 'input_event',
  );

=head1 DESCRIPTION

L<POE::Filter::SAXBuilder> is a POE Filter to turn an XML file or stream into
a (series of) DOM tree (fragments). It uses the L<XML::LibXML> modules to do
the parsing and for the building of the DOM tree. This gives you very good
support for most(all?) XML features, and allows you to use a host of extra
modules available for use with L<XML::LibXML>.

To make the potentially time-consuming parsing process more compatible with
the cooperative nature of POE, the filter will return a series of document
fragments instead of the entire DOM tree in one go.

There are two modes:

=over 2

=item 

The first builds the entire DOM tree, and just gives you pointers into the
tree at various points. This is useful if you know the xml document you are
parsing is not too big, and you want to be able to run XPATH queries on the
entire tree for example.

=item

The second mode splits up the DOM tree into document fragments and returns
each seperately. You could still build a complete DOM tree from these
fragments. Sometimes that isn't possible, because you're receiving a possibly
endless tree (for example when processing an XMPP stream)

=back

You can control how often you get events by specifying till how deep into
the tree you want to receive notifications. This also controls the size of
the document fragments you'll receive when you're using the second,
'detached' mode.

=head1 PUBLIC METHODS

POE::Filter::SAXBuilder follows the L<POE::Filter> API. This documentation
only covers things that are special to POE::Filter::SAXBuilder.

=head2 new

The constructor accepts two arguments which are both optional:

=over 4

=item buffer

a string that is XML waiting to be parsed (i.e. xml received
from the wheel before the Filter was instantiated)

=item handler

a SAX Handler that builds your data structures from SAX events. The
default is L<POE::Filter::SAXBuilder::Builder>, which creates DOM tree
fragments. But you could create any sort of object/structure you like.

=back

=cut

sub new {
   my $class = shift;

   my %args = @_;

   my $buffer = $args{buffer} ? [$args{buffer}] : [];
   my $handler = $args{handler};
   if(not defined($handler))
   {
      $handler = POE::Filter::SAXBuilder::Builder->new();
   }

   my $self = {
      'parser' => XML::LibXML->new (Handler => $handler),
      'handler'   => $handler,
      'buffer'    => $buffer,
   };

   bless($self, $class);
   return $self;
}

sub clone {
   my $self = shift;

   my $handler = $self->{'handler'}->clone;
   my $new_self = {
      parser => XML::LibXML->new (Handler => $handler),
      handler => $handler,
      buffer => $self->{'buffer'},
   };

   return bless $new_self, ref $self;
}

sub get_pending {
   my $self = shift;

   if (@{$self->{'buffer'}} > 0) {
      my $data = @{$self->{'buffer'}};
      warn "returning $data";
      return [ $data ];
   }
   return undef;
}

sub DESTROY {
   my $self = shift;

   delete $self->{'buffer'};

   delete $self->{'parser'};
   delete $self->{'handler'};
}

sub get_one_start {
   my ($self, $raw) = @_;
   if (defined $raw) {
      foreach my $raw_data (@$raw) {
	 # lookahead because lookbehind can't be variable length
	 # this is so we don't eat the newline.
	 push (@{$self->{'buffer'}},
	       split (/(?=\015?\012|\012\015?)/s, $raw_data));
      }
   }
}

=head2 reset_parser

Resets the filter so it is ready to parse a new document from the beginning.

=cut

sub reset_parser {
   my $self = shift;

   delete $self->{'parser'};

   # we used lookahead to split up the lines, so the
   # newline at the end of a document is still in the buffer
   # if there is an XML declaration, it won't be at the
   # start of document if we don't remove it
   $self->{'buffer'}->[0] =~ s/(\015?\012|\012\015?)// if (@{$self->{'buffer'}});
   $self->{handler}->reset;
   $self->{'parser'} = 
      XML::LibXML->new (Handler => $self->{'handler'}),
}

sub get_one {
   my ($self) = @_;

   if($self->{'handler'}->finished_nodes())
   {
      my $node = $self->{'handler'}->get_node();
      return [$node];

   } else {

      for(0..$#{$self->{'buffer'}})
      {
	 my $line = shift(@{$self->{'buffer'}});

	 next unless($line);

	 eval {
	    $self->{'parser'}->parse_chunk($line);
	 };
	    if($@) {
	       my $err_text = $@;
	       my $err = Error::Simple->new($err_text);
	       $self->reset_parser;
	       return [$err];
	    }

	 if (defined $self->{'handler'}->{'EOD'}) {
	    $self->{'parser'}->parse_chunk("", 1);
	    $self->reset_parser;
	    delete $self->{'handler'}->{'EOD'};
	 }
	 if($self->{'handler'}->finished_nodes()) {
	    my $node = $self->{'handler'}->get_node();
	    return [$node];
	 }
      }
      return [];
   }
}

sub put {
   my($self, $nodes) = @_;

   my $output = [];

   foreach my $node (@$nodes) 
   {
      my $cooked;
      if (ref $node) {
	 $cooked = $node->toString();
      } else {
	 $cooked = $node;
      }
      push(@$output, $cooked);
   }

   return($output);
}

1;

=head1 BUGS AND NOTES

Documentation for this sub project is as clear as mud.

If all else fails, use the source.

=head1 AUTHOR

Martijn van Beers  <martijn@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2006-2008 Martijn van Beers.

Based on POE::Filter::XML, which is Copyright (c) 2003 Nicholas Perez.

Released and distributed under the GPL.

=cut
