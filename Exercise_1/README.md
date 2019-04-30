Docker-Compose Wordpress installation using nginx
=================================================

Starting the environment
------------------------

To start the environment, run `docker-compose up`. 

You can then visit https://demo.wilkinson-rowe.name:8443/ in a web browser. 

Note that due to the installation hardening, you will be prompted for an HTTP Basic Auth username and password before being granted access to the WordPress configuration screen. The default username is _Administrator_ and the default password is _changeit_.

*NB* As `docker-compose.yaml` specifies version 3.7 of the file format, a relatively recent version of Docker Engine (18.06.0+) is required. This is in accordance with the specification ("Use latest docker version syntax").

Structure
---------

Two docker containers are provided, one running nginx with php-fpm, and the second running mariadb.

### Docker Images
The main webserver image is based off the official `nginx:alpine` image - this ensures a small footprint. The database is `mariadb:latest`. There is no `alpine` based version of the official versions of either MySQL or MariaDB, so this image is based on Ubuntu (one of the primary reasons for using Alpine is due to the relative sizes of the images versus standard Ubuntu ones - there is little to no benefit in the case of MySQL/MariaDB). 

### Volumes
The following volumes are created:

- `user-content` - used to store user-uploaded content such as images, videos, etc
- `nginx-logs` - used to store nginx logs (for possible ingestion by log analysis tools, eg Splunk)
- `db-data` - contains the database files created by MariaDB

### Ports
The following ports are available externally:

- *8080* - Plain HTTP, redirects to port HTTPS on port 8443.
- *8443* - HTTPS (TLSv1.2 and TLSv1.3 only) 

The following ports are exposed internal to the application by the database container to allow connections from the webserver container:

- *3306* - Standard MySQL / MariaDB port.

SSL Considerations
------------------
### SSL Certificates

SSL certificates for the nginx instance are stored in the `ssl/` folder, which is exported to the nginx instance.

Both self-signed and CA-signed certificates can be used; during testing I generated a self-signed certificate using the following command:

`openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 -keyout ./ssl/selfsigned.key -out ./ssl/selfsigned.crt -subj "/C=GB/ST=London/L=London/O=DemoCorp/OU=Org/CN=localhost"`

While this suffices for testing, obviously it renders the OCSP stapling configuration (see below) useless. 

### dhparam

A dhparam file has been generated using the following command:
`/usr/bin/openssl dhparam  -out /etc/nginx/ssl/dhparam.pem 4096`

This takes a long time to run due to the difficulty of generating random 4096-bit safe primes (given a prime number _n_, _(n-1)/2_ is also prime).

In the process of researching whether a 4096 bit prime is _really_ necessary, I discovered a service which pre-generates them, here: https://2ton.com.au/dhtool/#service. No doubt using such pre-generated data would be highlighted as a risk in a production level audit, but they may be useful in testing situations.

### OCSP Stapling

To verify that OCSP stapling is in place correctly, I used the Let's Encrypt certbot to generate a test certificate using the following command (using the dns-01 challenge method):

`certbot certonly --manual --preferred-challenges dns -d demo.wilkinson-rowe.name`

Although this only generates a 2048-bit certificate, this is sufficient for a certificate that has a 90-day expiration; certificates of this type are not expected to be regarded as insecure for a further 10 years.

The private key for this certificate is encrypted with a passphrase; this is passed through using Docker's secrets management.

The domain name *demo.wilkinson-rowe.name* has been set up to point to 127.0.0.1. As a result after running `docker-compose up` we can visit https://demo.wilkinson-rowe.name:8443/ in a browser without getting any certificate warnings. 

OCSP stapling is verified by running the following command _twice_:

`openssl s_client -connect demo.wilkinson-rowe.name:8443 -tlsextdebug  -status </dev/null`

The first time, nginx will not yet have gathered an OCSP response to staple so the output will contain the following:
```
OCSP response: no response sent
```

The second (and subsequent times) we should see something like:
```
======================================
OCSP Response Data:
    OCSP Response Status: successful (0x0)
    Response Type: Basic OCSP Response
    Version: 1 (0x0)
    Responder Id: C = US, O = Let's Encrypt, CN = Let's Encrypt Authority X3
    Produced At: Apr 27 11:52:00 2019 GMT
    Responses:
    Certificate ID:
      Hash Algorithm: sha1
      Issuer Name Hash: 7EE66AE7729AB3FCF8A220646C16A12D6071085D
      Issuer Key Hash: A84A6A63047DDDBAE6D139B7A64565EFF3A8ECA1
      Serial Number: 0322A9E8420F9B34FC0AEBC694930387BE3A
    Cert Status: good
    This Update: Apr 27 11:00:00 2019 GMT
    Next Update: May  4 11:00:00 2019 GMT
    ...
```

HTTP Tuning / Security Considerations
-------------------------------------

### Nginx 

#### HTTP Headers
Nginx is configured such that does not announce the version of the software it is running in the `Server` header, in order to make it more difficult for an attacker to discover potential vulnerabilities. 

HTTP/2 has been enabled as this version of the protocol is much more performant.

Additionally the following HTTP headers are returned:

- HTTP Strict Transport Security (`Strict-Transport-Security`)- indicates to a browser that it should never use unencrypted/plain HTTP to communicate with this server
- `X-Frame-Options: DENY` Prevents this site from being displayed in a frame on another website (preventing clickjacking)
- `X-Content-Type-Options: nosniff` Indicates that the browser always should use the content of the `Content-Type` header, rather than attempt to use automatic content detection to determine how to handle a response
- `X-XSS-Protection: 1; mode=block` Uses the browser's XSS detection capabilities to try to block cross-site scripting attacks.
- `Referrer Policy: same-origin` Requests the browser only supply referrer information when accessing pages of the same site. This prevents (for example) the existence of content which is only visible to logged-in users being divulged to third parties.

Depending on eventual use we should also consider using the `Feature-Policy` and `Content-Security-Policy` headers.


#### Microcaching
Nginx microcaching (caching responses for up to 1m) for PHP responses has been enabled, except in the following circumstances: 

- Any path under `/wp-admin`
- Any browser supplying a WordPress cookie (thus again preventing inadvertent leak of private data, and allowing comments to be instantly visible to their owners)

An `X-FastCGI-Cache` header has been added so that we can illustrate the cache is working correctly. In production use we may choose to obfuscate this, or leave it out entirely.

#### Access to `wp-admin` and `wp-login.php`
In order to dissuade brute force attacks attempting to log in to the wordpress interface, basic HTTP Authentication has been enabled. The default username is _Administrator_ and the default password is _changeit_. These can be modified (and should, before exposing the endpoint publically) by updating the htpasswd file under `nginx/wordpress-admin.htpasswd` using a standard htpasswd utility.

We may also choose to only allow access to these pages from a specific IP range, though this makes less sense in the context of a local Docker demonstration.

#### Other Concerns

PHP files which have been uploaded via the WordPress interface to `/wp-content/uploads` are blocked from running. This prevents the upload and then execution of any PHP script which could be used to gain unwanted access to files on the container.

### PHP-FPM

#### Listen Directive
Because PHP-FPM is running within the same container as nginx, we can use a unix socket for communication. This avoids the overhead of additional TCP session negotiations between nginx and PHP-FPM. While strictly speaking this is against the containerisation philosophy (one process per container), the two processes are closely enough related that they can arguably be kept together. 

Were we to split PHP-FPM from nginx (possibly so we could run the containers on seperate machines within the cluster, or so we could have a one-to-many mapping from nginx to PHP-FPM, this would of course have to be revisited, along with the structure of the containers (some files would need to be on shared volumes). 

#### Process Management

For the time being I have left the PHP-FPM process manager set to `dynamic`. As I don't have any insight into the level of traffic expected for this site, it seems a sensible tradeoff betwen the possible slow response time to initial requests that might be caused by `ondemand` and the memory intensity (though high speed) of `static`. Performance testing and monitoring should be used to arrive at a more sensible set of tuned settings.

#### PHP Execution Timeout

I haven't set an explicit timeout in `php.ini` or the PHP-FPM pool configuration; initially the default of 30s seems sensible until sufficient evaluation can be made of desired performance parameters - initial research suggests that for some WordPress installations, this timeout needs to be higher. I have however changed the nginx `fastcgi_read_timeout` setting to match as its default is higher (default of 60s). 
