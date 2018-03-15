<%init>
unless ($session{'CurrentUser'}->Id) {
	return;
}

my $sources = RT::Extension::DBCustomField->new()->getQueries();

$r->content_type('application/x-javascript');
</%init>
<%once>
	use JSON::XS;
</%once>
