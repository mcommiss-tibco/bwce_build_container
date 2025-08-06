#!/bin/bash

if [ ! -d ${1}/*.parent ]; then
  echo "Cannot find BWCE project at path '${1}"
  echo "Provide path to project directory within Docker container as a parameter"
  echo "eg docker run --rm -v <path-to-project>:/myprojectdir <tag> /myprojectdir"
  exit 1
fi

for dir in ${1}/*; do
  if [ -f ${dir}/pom.xml ]; then
    echo "Updating paths in pom.xml - ${dir}"
    sed -i -e "s#<bw.Home>.*</bw.Home>#<bw.Home>/bwce/2.10</bw.Home>#" ${dir}/pom.xml
    sed -i -e "s#<tibco.Home>.*</tibco.Home>#<tibco.Home>/opt/tibco/bwce</tibco.Home>#" ${dir}/pom.xml
  fi
done

echo "Patching JRE path"
ln -s /opt/tibco/bwce/tibcojre64 /opt/tibco/tibcojre64

echo "Running tests in project -  ${1}"
cd ${1}/*.parent
mvn clean test