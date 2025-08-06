# BWCE docker build image 

* v 1.0 - 20/06/2025 Initial version
* v 1.1 - 30/06/2025 Added support for bwdesign exeuction in container (xfvb and related packages.)
* v 1.2 - 02/07/2025 Fixed issue which caused HF not to be installed properly
* v 1.3 - 07/07/2025 Added section Use of bwce build contaier
* v 1.4 - 05/08/2025 Restructured docker files, now only Dockerfile is required.

## Goal
 Create a container images that can execute BWCE maven goals for pipeline purposes.

## Setup
A BWCE build container image will be created. The image will contain the basic software to be able to execute BWCE maven plugin goals.
Once installed it will decrease execution times while running the maven goals during pipeline execution. This is acomplished by downloading all the required  maven dependencies in the local maven repository in the container image during build time.

 ## Creation of the image

 <b>1) copy the following files ro the directory resources/binaries/bwce</b>
 * TIB_BWCE_2.10.0_linux26_x86_64.zip
 * TIB_BWCE_2.10.0_HF_003.zip
 * product_tibco_eclipse_lgpl_4.4.1.001_linux26gl25_x86_64.zip

 These file can be downloaded from the TIBCO Platform Control Plane Download page.

   In the same directory the file TIBCOUniversalInstaller_bwce_2.10.0.silent is already existing with the preconfigured settings for the container environment.

 <b>2) build the first docker image with the following command</b>
* docker build -t bwce-builder:2.10.0-hf003 .


## Push image to container registry

In order for your pipeline to access the images it should be pushed to a container registry which is used by the pipeline agent.
Follow the instructions of that container registry to do so.
In general the steps will be:

 <b>1) log in to the container registry with credentials</b>

 <b>2) tag the image on your container build environment to the pattern used in your container registry.</b>
Example: docker tag bwce-builder:2.10.0-hf003  {containerregistryname}}/tibco/bwce-builder:2.10.0HF3

 <b>3) push the tagged contianer image to the container registry</b>
Example: docker push {containerregistryname}/tibco/bwce-builder:2.10.0HF3

This image can now be used in your pipeline to execut on the pipeline agent. For more information on this please consult your devops platform documenation.


 ## Use of bwce build contaier

 This bwce build container can be used for various tasks on BWCE projects. 
 In order for the container to have access to the BWCE project it is expecting the directory with the BWCE project code to be mounted in the container to the directory '/project'.
 This is acomplished in the docker run command by providing the 'volume (-v)' command line option. <br>
 The solution assumes all the BWCE projects are mavenized and have a so call .parent directory with the top level maven configuration (pom.xl) for that BWCE project.


In below examples the reference [bwce project directory] should be substituted by the full path to the directory where the BWCE projects reside. The reference to [ dockerBuildImage ]  should be replaced by the full name of the bwce build image (reponame + imagename:tag)

Some samples to execute tasks on BWCE projects:

#### * Validate BWCE project
```
docker run --rm -v [bwce project directory]/repo:/project [dockerBuildImage] sh -c "cd *.parent && mvn com.tibco.plugins:bw6-maven-plugin:bwdesignUtility -DcommandName=validate -Darguments='-Ddebug -Dsun.net.client.defaultConnectTimeout=1000 -Dsun.net.client.defaultReadTimeout=1000'"
```

#### * Generate manifest for BWCE project
```
docker run --rm -v [bwce project directory]/repo:/project [dockerBuildImage] sh -c "cd *.parent && mvn com.tibco.plugins:bw6-maven-plugin:bwdesignUtility -DcommandName=generate_manifest_json -Darguments='-Ddebug -Dsun.net.client.defaultConnectTimeout=1000 -Dsun.net.client.defaultReadTimeout=1000' "
```

#### * Execute unit test
```
docker run --rm -v [bwce project directory]/repo:/project [dockerBuildImage] sh -c "cd *.parent && mvn test -DtestSuiteName=${{ parameters.testSuiteName }} "
 ```

#### * Build bwce ear file
```
docker run --rm -v [bwce project directory]/repo:/project [dockerBuildImage] sh -c "cd *.parent && mvn clean package -DskipTests"
```

#### * Retrieve pom version
```
docker run --rm -v [bwce project directory]/repo:/project [dockerBuildImage] sh -c "cd *.parent && mvn org.apache.maven.plugins:maven-help-plugin:2.1.1:evaluate -Dexpression=project.version | sed -n -e '/^\[.*\]/ !{ /^[0-9]/ { p; q } }'"
```

#### * Increase (minor) pom version
```
docker run --rm -v [bwce project directory]/repo:/project [dockerBuildImage] sh -c "cd *.parent && mvn build-helper:parse-version versions:set -DnewVersion='\${parsedVersion.majorVersion}.\${parsedVersion.minorVersion}.\${parsedVersion.nextIncrementalVersion}'"
```
