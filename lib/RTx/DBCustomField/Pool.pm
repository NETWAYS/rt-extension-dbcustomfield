package RTx::DBCustomField::Pool;

use strict;
use Data::Dumper;
use DBI;
use DBI::Const::GetInfoType;
use version '1.0';

sub new {
	my $classname = shift;
	my $type = ref $classname || $classname;
	return bless {
		'connections' => {},
		'configurations' => {}
	}, $type;
}

sub validConnection {
	my $self = shift;
	my $name = shift;
	if (exists($self->{'connections'}->{$name}) && $self->{'connections'}->{$name}->ping) {
		return 1;
	}
	return;
}

sub validConfiguration {
	my $self = shift;
	my $name = shift;
	return exists($self->{'configurations'}->{$name});
}

sub getConfiguration {
	my $self = shift;
	my $name = shift;
	return $self->{'configurations'}->{$name};
}

sub getConnection {
	my $self = shift;
	my $name = shift;
	
	if ($self->validConfiguration($name)) {
		RT->Logger->info('Acquire connection: '. $name);
		
		unless ($self->validConnection($name)) {
			RT->Logger->info('Creating new: '. $name);
			my $c = $self->getConfiguration($name);
			my $dbh = DBI->connect($c->{'dsn'}, $c->{'username'}, $c->{'password'});
			
			my $rc = $dbh->ping();
			if ($rc) {
				RT->Logger->info("Connection $name successfully pinged");
				
				my $version = $dbh->get_info($GetInfoType{SQL_DBMS_VER});
				if ($version) {
					RT->Logger->info("$name is a $version");
					
					$self->{'connections'}->{$name} = $dbh;
				}
			}
		}
		
		return $self->{'connections'}->{$name};
	}
}

sub init {
	my $self = shift;
	
	RT->Logger->info('Init connections');
	
	my $c = RT->Config->Get('RTx_DBCustomField_Connections');
	
	for my $name (keys(%{$c})) {
		my $config = $c->{$name};
		$self->{'configurations'}->{$name} = $config;
		
		if (exists($config->{'autoconnect'}) && $config->{'autoconnect'} eq 1) {
			$self->getConnection($name);
		}
	}
}

1;