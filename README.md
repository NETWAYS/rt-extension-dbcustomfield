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
