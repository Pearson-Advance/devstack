# Docker Builder

Tools to create custom docker images of the services used in pearson.

## How to use

* The Dockerfile of each service should be placed in `./service_name/Dockerfile`, i.e. `./edxapp/Dockerfile`
* To create a new image use: `make build.service_name`, i.e. `make build.edxapp`. The image will be created as ednxops/service_name:juniper.pearson

