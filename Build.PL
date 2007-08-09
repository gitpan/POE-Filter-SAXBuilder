use Module::Build;
Module::Build->new
(
	'module_name' => 'POE::Filter::SAXBuilder',
	'license' => 'gpl',
	'create_makefile_pl' => 'passthrough',
	'create_readme' => 1,
	'requires' =>
	{
		'perl'	=>	'5.8.1',
		'POE'	=>	'0.34_01',
		'XML::LibXML' => '1.63',
	}
)->create_build_script();
