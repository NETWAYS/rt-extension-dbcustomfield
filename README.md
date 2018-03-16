# DBCustomField Extension for Request Tracker

#### Table of Contents

1. [About](#about)
2. [License](#license)
3. [Support](#support)
4. [Requirements](#requirements)
5. [Installation](#installation)
6. [Configuration](#configuration)


## About

Connect databases to custom fields.

- Search for multiple values with custom queries.
- Map search and query results into presentation templates.
- Livesearch on custom field creation.
- Custom field stores a single global ID, future ticket views always fetch the external current data.

## License

This project is licensed under the terms of the GNU General Public License Version 2.

This software is Copyright (c) 2018 by NETWAYS GmbH <[support@netways.de](mailto:support@netways.de)>.

## Support

For bugs and feature requests please head over to our [issue tracker](https://github.com/NETWAYS/rt-extension-dbcustomfield/issues).
You may also send us an email to [support@netways.de](mailto:support@netways.de) for general questions or to get technical support.

## Requirements

- RT 4.4.2

## Installation

Extract this extension to a temporary location

Git clone:

```
cd /usr/local/src
git clone https://github.com/NETWAYS/rt-extension-dbcustomfield
```

Tarball download (latest [release](https://github.com/NETWAYS/rt-extension-dbcustomfield/releases/latest)):

```
cd /usr/local/src
wget https://github.com/NETWAYS/rt-extension-dbcustomfield/archive/v1.1.0.zip
unzip v1.1.0.zip
```

Navigate into the source directory and install the extension.

```
perl Makefile.PL
make
make install
```

Clear your mason cache.

```
rm -rf /opt/rt4/var/mason_data/obj
```

Restart your web server.

```
systemctl restart httpd

systemctl restart apache2
```


## Configuration

Edit your `/opt/rt4/etc/RT_SiteConfig.pm` configuration and include the extension.

```
Plugin('RT::Extension::DBCustomField');
```

### Connections

Specify the connection identifier and its settings.

```
Set($DBCustomField_Connections, {
        'sugarcrm' => {
                'dsn'                   => 'DBI:mysql:database=sugarcrm;host=mysql-server.localdomain;port=3306;mysql_enable_utf8=1',
                'username'              => 'username',
                'password'              => 'password',
                'autoconnect'           => 1
        },
});
```

### Queries

Specify the query and its settings. This is where the logic hides for

- Add/Edit the CF value
- Show the CF value in ticket views

Both views require their own queries, selected return field mappings,
where conditions and the global unique ID which is stored as CF value.

You can also control the formatted values as templates for

- livesearch dropdown
- form input
- shown as CF

More details are explained in the example below which queries company details
from sugarCRM.

```
Set ($DBCustomField_Queries, {
        'companies' => {
                # Specify the connection to use defined in $DBCustomField_Connections.
                'connection' => 'sugarcrm',

                ##########################################################
                # Edit CF

                # Specify the search query. This query returns the configured 'fields' with their defined key.
                #
                # '__DBCF_FIELDS__' is a placeholder for the 'fields' setting.
                # '__DBCF_WHERE__' is a placeholder for the 'searchfields' and 'searchop' setting.
                'query' => q{
                        SELECT
                        __DBCF_FIELDS__
                        from accounts a
                        inner join accounts_cstm cstm on cstm.id_c = a.id and cstm.net_global_id_c
                        WHERE a.deleted=0 and (__DBCF_WHERE__)
                        order by shortname
                        LIMIT 300;
                },

                # Define the columns which are compared against the input search value (replaces __DBCF_WHERE__).
                'searchfields'  => ['cstm.shortname_c', 'a.name', 'cstm.net_global_id_c'],
                # Define the searchfields combination operator
                'searchop'      => 'OR',

                # Define which field names are returned in the search result set (replaces __DBCF_FIELDS__).
                'fields'         => {
                        'shortname'     => 'cstm.shortname_c',
                        'globalid'      => 'cstm.net_global_id_c',
                        'name'          => 'a.name'
                },

                # Stored ID as CF value, alias into 'fields' above.
                'field_id' => 'globalid',

                # Specify the template returned by the search. This is rendered via JS dropdown.
                'field_tpl' => q{
                        {name} ({globalid})
                },

                # Extra config for CF edit.
                'field_config' => {},

                ##########################################################
                # View DBCF

                # Specify the view query.
                #
                # '__DBCF_FIELDS__' is a placeholder for the 'returnfields' setting.
                # '?' binds the value of the 'returnfield_id' column into to query as WHERE condition.
                # This selects the stored CF value as global unique ID.
                'returnquery'   => q{
                        SELECT
                        __DBCF_FIELDS__
                        from accounts a
                        inner join accounts_cstm cstm on cstm.id_c = a.id and cstm.net_global_id_c
                        where a.deleted=0 and cstm.net_global_id_c=?
                        LIMIT 100
                },

                # Define which field names are returned in the view query result set (replaces __DBCF_FIELDS__).
                'returnfields'         => {
                        'shortname'     => 'cstm.shortname_c',
                        'globalid'      => 'cstm.net_global_id_c',
                        'name'          => 'a.name'
                },

                # Stored ID as CF value, alias into 'fields' above.
                'returnfield_id' => 'globalid',

                # Specify the template returned by the view query. This is rendered as selected value in the form.
                'returnfield_tpl' => q{
                        {name} {globalid}
                },

                # Specify the template used to show this CF inside the ticket details.
                'returnfield_small_tpl' => q{{shortname} ({globalid})},
		# HTML version
		#'returnfield_small_tpl' => q{<div>{name} (<span style="font-weight: bold;">{globalid}</span>)</div>},

                # Extra config for CF edit.
                'returnfield_config' => {
                        height => 50
                },
        },

});
```


### Custom Fields Map

Map the defined queries to custom field names.

The following example maps the CF `Client` to the `companies` query configured above.

```
Set($DBCustomField_Fields, {
        'Client'            => 'companies',
});

```

