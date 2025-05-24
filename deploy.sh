#!/bin/bash

if [ -f .env ]
then
  export $(cat .env | sed 's/#.*//g' | xargs)
else
  echo ".env file not found"
  exit 1
fi

mv packages/*.ipa packages_archive/
make package
package_name=$(ls packages/*.ipa | awk -F'/' '{print $2}')
$THEOS/bin/sideloader-cli-x86_64-linux-gnu install packages/$package_name -i