use inc::Module::Install;

name		'POE-Filter-SAXBuilder';
all_from	'lib/POE/Filter/SAXBuilder.pm';


requires	'POE'		=> '1.0';
requires	'XML::LibXML'	=> '1.63';
requires	'Error'		=> '0.15';

test_requires	'Test::More'	=> '0';
test_requires	'Test::Pod'	=> '1.00';

WriteAll;

