# vim: filetype=perl

use strict;
use warnings;

our @doc;
BEGIN {
  @doc = (qw(
	ok:foo ok:bar ok:baz
	ok:foo ok:bar err:1 err:1 err:1
	ok:foo ok:bar ok:baz
	));
}

use Test::More tests => @doc + 2;
#use Test::More qw(no_plan);

use POE qw(
  Wheel::ReadWrite
  Driver::SysRW
  Filter::Line
  Filter::Stream
  Filter::SAXBuilder
  Filter::SAXBuilder::Builder
);

ok(defined $INC{"POE/Filter/SAXBuilder.pm"}, "loaded");

use IO::Handle;
use IO::File;

autoflush STDOUT 1;
my $request_number = 8;

my $session = POE::Session->create(
  inline_states => {
    _start => \&start,
    input => \&input,
    error => \&error,
  },
);

POE::Kernel->run();
exit;

sub start {
  my ($kernel, $heap) = @_[KERNEL, HEAP];

  sysseek(DATA, tell(DATA), 0);

  my $builder = POE::Filter::SAXBuilder::Builder->new(godepth => 2);
  my $filter = POE::Filter::SAXBuilder->new(handler => $builder);

  my $wheel = POE::Wheel::ReadWrite->new (
    Handle => \*DATA,
    Driver => POE::Driver::SysRW->new (BlockSize => 100),
    InputFilter => $filter,
    InputEvent => 'input',
    ErrorEvent => 'error',
  );
  $heap->{'wheel'} = $wheel;
}

sub input {
  my ($kernel, $heap, $data) = @_[KERNEL, HEAP, ARG0];

  my $expected = shift @doc;
  my ($ok, $value) = split (':', $expected);

  if ($ok eq 'ok') {
  	is($data->nodeName, $value, "got correct element");
  } else {
        isa_ok($data, 'Error::Simple');
  }
}

sub error {
  my $heap = $_[HEAP];
  my ($type, $errno, $errmsg, $id) = @_[ARG0..$#_];

  is($errno, 0, "got EOF");
  delete $heap->{wheel};
}

# below is a list of xml documents these are used to drive the tests.

__DATA__
<foo>
 <bar>
  <baz>
   <quux>
   </quux>
  </baz>
 </bar>
</foo>
<foo>
 <bar>
  <baz>
   <quux>
  </baz>
 </bar>
</foo>
<foo>
 <bar>
  <baz>
   <quux>
   </quux>
  </baz>
 </bar>
</foo>
