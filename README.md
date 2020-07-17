# flight-vault
Initial Notes from DS install on `hub`

Pre-requisites :
* Configure an AWS S3 bucket 
* Create a user which can access this S3 bucket and grab their Access Key + Secret Access Key
* Ruby installed > 2.3
* Bundler gem installed > 1.17

Clone `flight-vault` repo and update `config.yml` with correct S3 bucket names
```
git clone https://github.com/alces-software/flight-vault.git /opt/flight-vault
cd /opt/flight-vault/etc
cp config.yml.ex config.yml
```

Install `flight-vault` 
```
cd /opt/flight-vault
bundle install
```

Update `/usr/local/bin/vault` with the keys for your AWS user:
```
#!/bin/bash
export AWS_SECRET_ACCESS_KEY=XXXXXX
export AWS_ACCESS_KEY_ID=XXXXXX
export EDITOR=${EDITOR:-/usr/bin/vim}
exec /opt/flight-vault/bin/flight-vault "$@"
```
