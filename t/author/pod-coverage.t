use Test::Pod::Coverage tests=>2;

pod_coverage_ok( "POE::Filter::SAXBuilder", {
		coverage_class => 'Pod::Coverage::CountParents',
	});

pod_coverage_ok( "POE::Filter::SAXBuilder::Builder", {
		coverage_class => 'Pod::Coverage::CountParents',
		trustme => [qw(characters start_element end_element start_document xml_decl)]
	});
