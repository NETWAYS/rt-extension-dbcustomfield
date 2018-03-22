package RT::Extension::DBCustomField;

use strict;
use version;
use v5.10.1;

our $VERSION="1.1.0";

RT->AddJavaScript('dbcustomfield-init.js');

use RT::Extension::DBCustomField::Pool;
use utf8;
use Data::Dumper;

use vars qw(
	$INSTANCE
);

sub new {
	my $classname = shift;
	my $type = ref $classname || $classname;

	unless (ref $INSTANCE eq 'RT::Extension::DBCustomField') {
		$INSTANCE = bless {
			'pool'	=> RT::Extension::DBCustomField::Pool->new()
		}, $type;

		RT->Logger->info('Creating new instance of '. ref($INSTANCE));

		$INSTANCE->{pool}->init();
	}

	return $INSTANCE;
}

sub getQueryHash {
	return getConfigByName(@_);
}

sub getConfigByName {
	my $self = shift;
	my $name = shift;

	if (exists (RT->Config->Get('DBCustomField_Queries')->{$name})) {
		return RT->Config->Get('DBCustomField_Queries')->{$name};
	}

	return undef;
}

sub getConfigByCustomFieldName {
	my $self = shift;
	my $name = shift;

	if (exists(RT->Config->Get('DBCustomField_Fields')->{$name})) {
		my $id = RT->Config->Get('DBCustomField_Fields')->{$name};
		return ($id, RT->Config->Get('DBCustomField_Queries')->{$id});
	}
}

sub getQueries {
	my $self = shift;

	my $c = RT->Config->Get('DBCustomField_Queries');
	if (ref($c) eq 'HASH') {
		return $c;
	}

	return {};
}

sub getConfigByCustomField {
	my $self = shift;
	my $cf = shift;
	my $id = undef;

	if (exists(RT->Config->Get('DBCustomField_Fields')->{$cf->Name})) {
		$id = RT->Config->Get('DBCustomField_Fields')->{$cf->Name};
	}
	elsif (exists(RT->Config->Get('DBCustomField_Fields')->{$cf->Id})) {
		$id = RT->Config->Get('DBCustomField_Fields')->{$cf->Id};
	}

	if ($id) {
		return ($id, RT->Config->Get('DBCustomField_Queries')->{$id});
	}
}

sub getReturnValue {
	my $self = shift;
	my $name = shift;
	my $value = shift;
	my $object = shift;

	return undef unless($value);

	if ((my $qref = $self->getQueryHash($name))) {
		if ((my $c = $self->{pool}->getConnection($qref->{'connection'}))) {

			my $query = $self->substituteQuery(
				query	=> $qref->{'returnquery'},
				value   => $value,
				ticket	=> $object
			);

			my $sth = $c->prepare($query);

			if ($query =~ /\?/) {
				$sth->bind_param(1, $value || 'INVALID');
			}

			my $re = $sth->execute();

			my $ref = $sth->fetchrow_hashref();

			if (! $self->{'pool'}->usePool) {
				$sth->finish() if ($sth);
				$c->disconnect();
			}

			return unless ($ref);
			return $self->convertHashToUtf8($ref);
		}
	}

	return undef;
}

sub getReturnValueSmall {
	my $self = shift;
	my $name = shift;
	my $value = shift;
	my $object = shift;
	my $id = undef;

	my $qref = undef;
	if (ref($name) eq 'RT::CustomField') {
		($id, $qref) = $self->getConfigByCustomField($name);
	} else {
		$qref = $self->getQueryHash($name);
		$id = $name;
	}

	if ($qref && $id) {
		my $row = $self->getReturnValue($id, $value, $object);
		return unless($row);
		return $self->wrapHash($row, $qref->{'returnfield_small_tpl'} || '{field_value}');
	}

}

sub getFields {
	my $self = shift;
	my ($fields, $idfield) = @_;

}

sub wrapHash {
	my $self = shift;
	my $row = shift;
	my $format = shift;
	return unless ($row);
	$format =~ s/\{([^\}]+)\}/$row->{$1}/ge;
	return $format;
}

sub substituteQuery {
	my $self = shift;
	my $h = {
		query	=> undef,
		value   => undef,
		ticket	=> undef,
		@_
	};

	my $query = $h->{'query'};

	if (ref($h->{'ticket'}) eq 'RT::Ticket') {
		my $t = $h->{'ticket'};

		$query =~ s/__TICKET\(([^\)]+)\)__/$t->$1/ge;
		$query =~ s/__TICKET__/$t->Id/g;
	}

	if (exists($h->{'value'}) && $h->{'value'}) {
		$query =~ s/__VALUE__/$h->{'value'}/g;
	}

	return $query
}

sub callQuery {
	my $self = shift;

	my $ARGRef = {
		name => undef,
		query => undef,
		ticket => undef,
		@_
	};

	my $name = $ARGRef->{'name'};
	my $q = $ARGRef->{'query'};
	my $ticket = $ARGRef->{'ticket'};

	if ((my $qref = $self->getQueryHash($name))) {
		if ((my $c = $self->{pool}->getConnection($qref->{'connection'}))) {

			my $query = $qref->{'query'};
			$query = $self->substituteQuery(
				query	=> $query,
				ticket	=> $ticket
			);

			my $sth = $c->prepare($query);

			my $questionMarkNo = 0;
			while ($query =~ /((?:LIKE\s+?\?)|(?:(?<!LIKE)\s*?\?))/gi) {
				if (substr(lc($1), 0, 4) eq 'like') {
					$sth->bind_param(++$questionMarkNo, $q . '%');
				} else {
					$sth->bind_param(++$questionMarkNo, $q);
				}
			}

			my $re = $sth->execute();

			if (!$re && $c->errstr()) {
				die ($query. '<br /><br />'. $c->errstr())
			}

			my (@out, $count);
			my $limit = RT->Config->Get('DBCustomField_Suggestion_Limit') || 10;

			while (my $row = $sth->fetchrow_hashref) {
				my $dataRow = $self->convertHashToUtf8($row);
				if (!exists($dataRow->{'field_value'})) {
					RT->Logger->error(
						'Column "field_value" missing in result. Does the "' . $name . '" query return one?'
					);
					last;
				} elsif (!$dataRow->{'field_value'}) {
					RT->Logger->warning('Column "field_value" empty in result. Enable debug log for more details.');
					RT->Logger->debug('Result row was: ' . Dumper($dataRow));
				} else {
					push @out, $dataRow;
					if (++$count == $limit) {
						last;
					}
				}
			}

			if (! $self->{'pool'}->usePool) {
				$sth->finish() if ($sth);
				$c->disconnect();
			}

			return \@out;
		}
	}
}

sub convertHashToUtf8 {
	my $self = shift;
	my $ref = shift;

	if (exists($ref->{'__dbcf_idfield__'})) {
		$ref->{'id'} = $ref->{'__dbcf_idfield__'};
		delete($ref->{'__dbcf_idfield__'});
	}

	foreach (keys %{ $ref }) {
		utf8::decode($ref->{$_});
	}
	return $ref;
}

RT::Extension::DBCustomField->new();
1;
=pod

=head1 NAME

RT::Extension::DBCustomField - Connect databases to custom fields

=head1 VERSION

version 1.1.0

=head1 RT VERSION

Works with RT 4.4.2

=head1 INSTALLATION

=over

=item C<perl Makefile.PL>

=item C<make>

=item C<make install>

May need root permissions

=item Edit your F</opt/rt4/etc/RT_SiteConfig.pm>

    Plugin('RT::Extension::DBCustomField');

=item Clear your mason cache

    rm -rf /opt/rt4/var/mason_data/obj

=item Restart your webserver

=back

=head1 CONFIGURATION

You need to specify C<$DBCustomField_Connections> which is a hash of connections.

   Set($DBCustomField_Connections, {
     'sugarcrm' => {
       'dsn'      => 'DBI:mysql:database=SUGARCRMDB;host=MYHOST;port=3306;mysql_enable_utf8=1',
       'username'    => 'USER',
       'password'    => 'PASS',
       'autoconnect'  => 1
     }
   });

This cannection is then used to define the specific queries. The key identifies the values
returned for later CF assignment. The 'connection' identifier is linked to the specified
connection above.

    Set ($DBCustomField_Queries, {
            'companies' => {

                'connection'    => 'sugarcrm',

                    'query' => q{
                            SELECT
                            cstm.net_global_id_c as field_value, cstm.shortname_c as shortname, a.name
                            from accounts a
                            inner join accounts_cstm cstm on cstm.id_c = a.id and cstm.net_global_id_c
                            WHERE a.deleted=0 and (cstm.net_global_id_c = ? OR cstm.shortname_c LIKE ? OR a.name LIKE ?)
                            order by shortname
                            LIMIT 300;
                    },

                    'field_tpl' => q{
                      <div>
                        <tpl if="shortname">
                          <div><span style="font-weight: bold;">{shortname}</span></div>
                        </tpl>
                        <div>{name} (<span style="font-weight: bold;">{field_value}</span>)</div>
                      </div>
                     },

                    'returnquery'   => q{
                            SELECT
                            cstm.net_global_id_c as field_value, cstm.shortname_c as shortname, a.name
                            from accounts a
                            inner join accounts_cstm cstm on cstm.id_c = a.id and cstm.net_global_id_c
                            where cstm.net_global_id_c=?
                            LIMIT 100
                    },

                    'returnfield_tpl' => q{
                      <div>
                        <tpl if="shortname">
                          <div><span style="font-weight: bold;">{shortname}</span></div>
                        </tpl>
                        <div>{name} (<span style="font-weight: bold;">{field_value}</span>)</div>
                      </div>
                    },

                    'returnfield_small_tpl' => q{{shortname} ({field_value})}


      },
    });

You need to map the database queries into custom fields. One query can be used for multiple fields if needed.

    Set($DBCustomField_Fields, {
      'client' => 'companies'
    });

By default the limit of suggestions displayed to the user is 10. To adjust this you can use the following option:

	Set($DBCustomField_Suggestion_Limit, 25);


=head1 AUTHOR

NETWAYS GmbH <support@netways.de>

=head1 BUGS

All bugs should be reported on L<GitHub|https://github.com/NETWAYS/rt-extension-dbcustomfield>


=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2018 by NETWAYS GmbH <support@netways.de>

This is free software, licensed under:
    GPL Version 2, June 1991

=cut

1;
