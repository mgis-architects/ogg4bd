# ogg4bd

## What does it do
Installs Oracle Goldengate for Big Data 12.3.1 on an existing Oracle database 

built via https://github.com/mgis-architects/terraform/tree/master/azure/ogg4bd

This script only supports Azure currently, mainly due to the disk persistence method

## Pre-req
Staged binaries on Azure File storage in the following directories

* /mnt/software/ogg4bd12301/V839824-01.zip

### Step 1 Prepare oracledb build

git clone https://github.com/mgis-architects/ogg4bd

cp ogg4bd-build.ini ~/ogg4bd-build.ini

Modify ~/ogg4bd-build.ini

### Step 2 Execute the script using the Terradata repo 

git clone https://github.com/mgis-architects/terraform

cd azure/ogg4bd

cp ogg4bd-azure.tfvars ~/ogg4bd-azure.tfvars

Modify ~/ogg4bd-azure.tfvars

terraform apply -var-file=~/ogg4bd-azure.tfvars

### Notes
Installation takes up to 35 minutes
