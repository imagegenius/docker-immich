pipeline {
  agent {
    label 'X86-64-MULTI'
  }
  options {
    buildDiscarder(logRotator(numToKeepStr: '10', daysToKeepStr: '60'))
    parallelsAlwaysFailFast()
  }
  // Input to determine if this is a package check
  parameters {
     string(defaultValue: 'false', description: 'package check run', name: 'PACKAGE_CHECK')
  }
  // Configuration for the variables used for this specific repo
  environment {
    BUILDS_DISCORD=credentials('build_webhook_url')
    GITHUB_TOKEN=credentials('github_token')
    JSON_URL = 'https://api.github.com/repos/immich-app/immich/releases/latest'
    JSON_PATH = '.tag_name'
    BUILD_VERSION_ARG = 'IMMICH_VERSION'
    USER = 'hydazz'
    REPO = 'docker-immich'
    CONTAINER_NAME = 'immich'
    DOCKERHUB_IMAGE = 'hydaz/immich'
    DEV_DOCKERHUB_IMAGE = 'dev/immich'
    PR_DOCKERHUB_IMAGE = 'pipepr/immich'
    DIST_IMAGE = 'ubuntu'
    MULTIARCH = 'false'
    CI = 'false'
    CI_WEB = 'true'
    CI_PORT = '2283'
    CI_SSL = 'false'
    CI_DELAY = '120'
    CI_DOCKERENV = 'TZ=Europe/London'
    CI_AUTH = ''
    CI_WEBPATH = ''
  }
  stages {
    // Setup all the basic environment variables needed for the build
    stage("Set ENV Variables base"){
      steps{
        script{
          env.EXIT_STATUS = ''
          env.RELEASE = sh(
            script: '''docker run --rm ghcr.io/linuxserver/alexeiled-skopeo sh -c 'skopeo inspect docker://docker.io/'${DOCKERHUB_IMAGE}':latest 2>/dev/null' | jq -r '.Labels.build_version' | awk '{print $3}' | grep '\\-' || : ''',
            returnStdout: true).trim()
          env.RELEASE_NOTES = sh(
            script: '''cat readme-vars.yml | awk -F \\" '/date: "[0-9][0-9].[0-9][0-9].[0-9][0-9]:/ {print $4;exit;}' | sed -E ':a;N;$!ba;s/\\r{0,1}\\n/\\\\n/g' ''',
            returnStdout: true).trim()
          env.GITHUB_DATE = sh(
            script: '''date '+%Y-%m-%dT%H:%M:%S%:z' ''',
            returnStdout: true).trim()
          env.COMMIT_SHA = sh(
            script: '''git rev-parse HEAD''',
            returnStdout: true).trim()
          env.CODE_URL = 'https://github.com/' + env.USER + '/' + env.REPO + '/commit/' + env.GIT_COMMIT
          env.DOCKERHUB_LINK = 'https://hub.docker.com/r/' + env.DOCKERHUB_IMAGE + '/tags/'
          env.PULL_REQUEST = env.CHANGE_ID
          env.TEMPLATED_FILES = 'Jenkinsfile README.md LICENSE .editorconfig  ./.github/workflows/external_trigger_scheduler.yml  ./.github/workflows/package_trigger_scheduler.yml  ./.github/workflows/external_trigger.yml ./.github/workflows/package_trigger.yml'
        }
        script{
          env.RELEASE_NUMBER = sh(
            script: '''echo ${RELEASE} |sed 's/^.*-//g' ''',
            returnStdout: true).trim()
        }
        script{
          env.TAG_NUMBER = sh(
            script: '''#! /bin/bash
                       tagsha=$(git rev-list -n 1 ${RELEASE} 2>/dev/null)
                       if [ "${tagsha}" == "${COMMIT_SHA}" ]; then
                         echo ${RELEASE_NUMBER}
                       elif [ -z "${GIT_COMMIT}" ]; then
                         echo ${RELEASE_NUMBER}
                       else
                         echo $((${RELEASE_NUMBER} + 1))
                       fi''',
            returnStdout: true).trim()
        }
      }
    }
    /* #######################
       Package Version Tagging
       ####################### */
    // Grab the current package versions in Git to determine package tag
    stage("Set Package tag"){
      steps{
        script{
          env.PACKAGE_TAG = sh(
            script: '''#!/bin/bash
                       if [ -e package_versions.txt ] ; then
                         cat package_versions.txt | md5sum | cut -c1-8
                       else
                         echo none
                       fi''',
            returnStdout: true).trim()
        }
      }
    }
    /* ########################
       External Release Tagging
       ######################## */
    // If this is a custom json endpoint parse the return to get external tag
    stage("Set ENV custom_json"){
     steps{
       script{
         env.EXT_RELEASE = sh(
           script: '''curl -s ${JSON_URL} | jq -r ". | ${JSON_PATH}" ''',
           returnStdout: true).trim()
         env.RELEASE_LINK = env.JSON_URL
       }
     }
    }
    // Sanitize the release tag and strip illegal docker or github characters
    stage("Sanitize tag"){
      steps{
        script{
          env.EXT_RELEASE_CLEAN = sh(
            script: '''echo ${EXT_RELEASE} | sed 's/[~,%@+;:/]//g' ''',
            returnStdout: true).trim()

          def semver = env.EXT_RELEASE_CLEAN =~ /(\d+)\.(\d+)\.(\d+)/
          if (semver.find()) {
            env.SEMVER = "${semver[0][1]}.${semver[0][2]}.${semver[0][3]}"
          } else {
            semver = env.EXT_RELEASE_CLEAN =~ /(\d+)\.(\d+)(?:\.(\d+))?(.*)/
            if (semver.find()) {
              if (semver[0][3]) {
                env.SEMVER = "${semver[0][1]}.${semver[0][2]}.${semver[0][3]}"
              } else if (!semver[0][3] && !semver[0][4]) {
                env.SEMVER = "${semver[0][1]}.${semver[0][2]}.${(new Date()).format('YYYYMMdd')}"
              }
            }
          }

          if (env.SEMVER != null) {
            if (BRANCH_NAME != "master" && BRANCH_NAME != "main") {
              env.SEMVER = "${env.SEMVER}-${BRANCH_NAME}"
            }
            println("SEMVER: ${env.SEMVER}")
          } else {
            println("No SEMVER detected")
          }

        }
      }
    }
    // If this is a main build use live docker endpoints
    stage("Set ENV live build"){
      when {
        branch "main"
        environment name: 'CHANGE_ID', value: ''
      }
      steps {
        script{
          env.IMAGE = env.DOCKERHUB_IMAGE
          env.GITHUBIMAGE = 'ghcr.io/' + env.USER + '/' + env.CONTAINER_NAME
          if (env.MULTIARCH == 'true') {
            env.CI_TAGS = 'amd64-' + env.EXT_RELEASE_CLEAN + '-' + env.TAG_NUMBER + '|arm32v7-' + env.EXT_RELEASE_CLEAN + '-' + env.TAG_NUMBER + '|arm64v8-' + env.EXT_RELEASE_CLEAN + '-' + env.TAG_NUMBER
          } else {
            env.CI_TAGS = env.EXT_RELEASE_CLEAN + '-' + env.TAG_NUMBER
          }
          env.VERSION_TAG = env.EXT_RELEASE_CLEAN + '-' + env.TAG_NUMBER
          env.META_TAG = env.EXT_RELEASE_CLEAN + '-' + env.TAG_NUMBER
          env.EXT_RELEASE_TAG = 'version-' + env.EXT_RELEASE_CLEAN
        }
      }
    }
    // If this is a dev build use dev docker endpoints
    stage("Set ENV dev build"){
      when {
        not {branch "main"}
        environment name: 'CHANGE_ID', value: ''
      }
      steps {
        script{
          env.IMAGE = env.DEV_DOCKERHUB_IMAGE
          env.GITHUBIMAGE = 'ghcr.io/' + env.USER + '/dev-' + env.CONTAINER_NAME
          if (env.MULTIARCH == 'true') {
            env.CI_TAGS = 'amd64-' + env.EXT_RELEASE_CLEAN + '-pkg-' + env.PACKAGE_TAG + '-dev-' + env.COMMIT_SHA + '|arm32v7-' + env.EXT_RELEASE_CLEAN + '-pkg-' + env.PACKAGE_TAG + '-dev-' + env.COMMIT_SHA + '|arm64v8-' + env.EXT_RELEASE_CLEAN + '-pkg-' + env.PACKAGE_TAG + '-dev-' + env.COMMIT_SHA
          } else {
            env.CI_TAGS = env.EXT_RELEASE_CLEAN + '-pkg-' + env.PACKAGE_TAG + '-dev-' + env.COMMIT_SHA
          }
          env.VERSION_TAG = env.EXT_RELEASE_CLEAN + '-pkg-' + env.PACKAGE_TAG + '-dev-' + env.COMMIT_SHA
          env.META_TAG = env.EXT_RELEASE_CLEAN + '-pkg-' + env.PACKAGE_TAG + '-dev-' + env.COMMIT_SHA
          env.EXT_RELEASE_TAG = 'version-' + env.EXT_RELEASE_CLEAN
          env.DOCKERHUB_LINK = 'https://hub.docker.com/r/' + env.DEV_DOCKERHUB_IMAGE + '/tags/'
        }
      }
    }
    // If this is a pull request build use dev docker endpoints
    stage("Set ENV PR build"){
      when {
        not {environment name: 'CHANGE_ID', value: ''}
      }
      steps {
        script{
          env.IMAGE = env.PR_DOCKERHUB_IMAGE
          env.GITHUBIMAGE = 'ghcr.io/' + env.USER + '/pipepr-' + env.CONTAINER_NAME
          if (env.MULTIARCH == 'true') {
            env.CI_TAGS = 'amd64-' + env.EXT_RELEASE_CLEAN + '-pkg-' + env.PACKAGE_TAG + '-pr-' + env.PULL_REQUEST + '|arm32v7-' + env.EXT_RELEASE_CLEAN + '-pkg-' + env.PACKAGE_TAG + '-pr-' + env.PULL_REQUEST + '|arm64v8-' + env.EXT_RELEASE_CLEAN + '-pkg-' + env.PACKAGE_TAG + '-pr-' + env.PULL_REQUEST
          } else {
            env.CI_TAGS = env.EXT_RELEASE_CLEAN + '-pkg-' + env.PACKAGE_TAG + '-pr-' + env.PULL_REQUEST
          }
          env.VERSION_TAG = env.EXT_RELEASE_CLEAN + '-pkg-' + env.PACKAGE_TAG + '-pr-' + env.PULL_REQUEST
          env.META_TAG = env.EXT_RELEASE_CLEAN + '-pkg-' + env.PACKAGE_TAG + '-pr-' + env.PULL_REQUEST
          env.EXT_RELEASE_TAG = 'version-' + env.EXT_RELEASE_CLEAN
          env.CODE_URL = 'https://github.com/' + env.USER + '/' + env.REPO + '/pull/' + env.PULL_REQUEST
          env.DOCKERHUB_LINK = 'https://hub.docker.com/r/' + env.PR_DOCKERHUB_IMAGE + '/tags/'
        }
      }
    }
    // Run ShellCheck below
    // Use helper containers to render templated files
    stage('Update-Templates') {
      when {
        branch "main"
        environment name: 'CHANGE_ID', value: ''
        expression {
          env.CONTAINER_NAME != null
        }
      }
      steps {
        sh '''#! /bin/bash
              set -e
              TEMPDIR=$(mktemp -d)
              docker pull ghcr.io/hydazz/jenkins-builder:latest
              docker run --rm -e CONTAINER_NAME=${CONTAINER_NAME} -e GITHUB_BRANCH=main -v ${TEMPDIR}:/ansible/jenkins ghcr.io/hydazz/jenkins-builder:latest 
              # Stage 1 - Jenkinsfile update
              if [[ "$(md5sum Jenkinsfile | awk '{ print $1 }')" != "$(md5sum ${TEMPDIR}/docker-${CONTAINER_NAME}/Jenkinsfile | awk '{ print $1 }')" ]]; then
                mkdir -p ${TEMPDIR}/repo
                git clone https://github.com/${USER}/${REPO}.git ${TEMPDIR}/repo/${REPO}
                cd ${TEMPDIR}/repo/${REPO}
                git checkout -f main
                cp ${TEMPDIR}/docker-${CONTAINER_NAME}/Jenkinsfile ${TEMPDIR}/repo/${REPO}/
                git add Jenkinsfile
                git commit -m 'Bot Updating Templated Files'
                git push https://Jenkins-CI:${GITHUB_TOKEN}@github.com/${USER}/${REPO}.git --all
                echo "true" > /tmp/${COMMIT_SHA}-${BUILD_NUMBER}
                echo "Updating Jenkinsfile"
                rm -Rf ${TEMPDIR}
                exit 0
              else
                echo "Jenkinsfile is up to date."
              fi
              # Stage 2 - Update templates
              CURRENTHASH=$(grep -hs ^ ${TEMPLATED_FILES} | md5sum | cut -c1-8)
              cd ${TEMPDIR}/docker-${CONTAINER_NAME}
              NEWHASH=$(grep -hs ^ ${TEMPLATED_FILES} | md5sum | cut -c1-8)
              if [[ "${CURRENTHASH}" != "${NEWHASH}" ]] || ! grep -q '.jenkins-external' "${WORKSPACE}/.gitignore" 2>/dev/null; then
                mkdir -p ${TEMPDIR}/repo
                git clone https://github.com/${USER}/${REPO}.git ${TEMPDIR}/repo/${REPO}
                cd ${TEMPDIR}/repo/${REPO}
                git checkout -f main
                cd ${TEMPDIR}/docker-${CONTAINER_NAME}
                mkdir -p ${TEMPDIR}/repo/${REPO}/.github/workflows
                cp --parents ${TEMPLATED_FILES} ${TEMPDIR}/repo/${REPO}/ || :
                cd ${TEMPDIR}/repo/${REPO}/
                if ! grep -q '.jenkins-external' .gitignore 2>/dev/null; then
                  echo ".jenkins-external" >> .gitignore
                  git add .gitignore
                fi
                git add ${TEMPLATED_FILES}
                git commit -m 'Bot Updating Templated Files'
                git push https://Jenkins-CI:${GITHUB_TOKEN}@github.com/${USER}/${REPO}.git --all
                echo "true" > /tmp/${COMMIT_SHA}-${BUILD_NUMBER}
              else
                echo "false" > /tmp/${COMMIT_SHA}-${BUILD_NUMBER}
              fi
              mkdir -p ${TEMPDIR}/unraid
              git clone https://github.com/hydazz/docker-templates.git ${TEMPDIR}/unraid/docker-templates
              git clone https://github.com/hydazz/templates.git ${TEMPDIR}/unraid/templates
              if [[ -f ${TEMPDIR}/unraid/docker-templates/hydaz/img/${CONTAINER_NAME}.png ]]; then
                sed -i "s|main/hydaz/img/default.png|main/hydaz/img/${CONTAINER_NAME}.png|" ${TEMPDIR}/docker-${CONTAINER_NAME}/.jenkins-external/${CONTAINER_NAME}.xml
              fi
              if [[ ("${BRANCH_NAME}" == "master") || ("${BRANCH_NAME}" == "main") ]] && [[ (! -f ${TEMPDIR}/unraid/templates/unraid/${CONTAINER_NAME}.xml) || ("$(md5sum ${TEMPDIR}/unraid/templates/unraid/${CONTAINER_NAME}.xml | awk '{ print $1 }')" != "$(md5sum ${TEMPDIR}/docker-${CONTAINER_NAME}/.jenkins-external/${CONTAINER_NAME}.xml | awk '{ print $1 }')") ]]; then
                cd ${TEMPDIR}/unraid/templates/
                if grep -wq "${CONTAINER_NAME}" ${TEMPDIR}/unraid/templates/unraid/ignore.list; then
                  echo "Image is on the ignore list, marking Unraid template as deprecated"
                  cp ${TEMPDIR}/docker-${CONTAINER_NAME}/.jenkins-external/${CONTAINER_NAME}.xml ${TEMPDIR}/unraid/templates/unraid/
                  git add -u unraid/${CONTAINER_NAME}.xml
                  git mv unraid/${CONTAINER_NAME}.xml unraid/deprecated/${CONTAINER_NAME}.xml || :
                  git commit -m 'Bot Moving Deprecated Unraid Template' || :
                else
                  cp ${TEMPDIR}/docker-${CONTAINER_NAME}/.jenkins-external/${CONTAINER_NAME}.xml ${TEMPDIR}/unraid/templates/unraid/
                  git add unraid/${CONTAINER_NAME}.xml
                  git commit -m 'Bot Updating Unraid Template'
                fi
                git push https://Jenkins-CI:${GITHUB_TOKEN}@github.com/hydazz/templates.git --all
              fi
              rm -Rf ${TEMPDIR}'''
        script{
          env.FILES_UPDATED = sh(
            script: '''cat /tmp/${COMMIT_SHA}-${BUILD_NUMBER}''',
            returnStdout: true).trim()
        }
      }
    }
    // Exit the build if the Templated files were just updated
    stage('Template-exit') {
      when {
        branch "main"
        environment name: 'CHANGE_ID', value: ''
        environment name: 'FILES_UPDATED', value: 'true'
        expression {
          env.CONTAINER_NAME != null
        }
      }
      steps {
        script{
          env.EXIT_STATUS = 'ABORTED'
        }
      }
    }
    /* ###############
       Build Container
       ############### */
    // Build Docker container for push to LS Repo
    stage('Build-Single') {
      when {
        expression {
          env.MULTIARCH == 'false' || params.PACKAGE_CHECK == 'true'
        }
        environment name: 'EXIT_STATUS', value: ''
      }
      steps {
        echo "Running on node: ${NODE_NAME}"
        sh "docker build \
          --label \"org.opencontainers.image.created=${GITHUB_DATE}\" \
          --label \"org.opencontainers.image.authors=hyde.services\" \
          --label \"org.opencontainers.image.url=https://github.com/hydazz/docker-immich/packages\" \
          --label \"org.opencontainers.image.source=https://github.com/hydazz/docker-immich\" \
          --label \"org.opencontainers.image.version=${EXT_RELEASE_CLEAN}-${TAG_NUMBER}\" \
          --label \"org.opencontainers.image.revision=${COMMIT_SHA}\" \
          --label \"org.opencontainers.image.vendor=hyde.services\" \
          --label \"org.opencontainers.image.licenses=GPL-3.0-only\" \
          --label \"org.opencontainers.image.ref.name=${COMMIT_SHA}\" \
          --label \"org.opencontainers.image.title=Immich\" \
          --label \"org.opencontainers.image.description=[Immich](https://immich.app/) - High performance self-hosted photo and video backup solution.\" \
          --no-cache --pull -t ${IMAGE}:${META_TAG} \
          --build-arg ${BUILD_VERSION_ARG}=${EXT_RELEASE} --build-arg VERSION=\"${VERSION_TAG}\" --build-arg BUILD_DATE=${GITHUB_DATE} ."
      }
    }
    // Build MultiArch Docker containers for push to LS Repo
    stage('Build-Multi') {
      when {
        allOf {
          environment name: 'MULTIARCH', value: 'true'
          expression { params.PACKAGE_CHECK == 'false' }
        }
        environment name: 'EXIT_STATUS', value: ''
      }
      parallel {
        stage('Build X86') {
          steps {
            echo "Running on node: ${NODE_NAME}"
            sh "docker build \
              --label \"org.opencontainers.image.created=${GITHUB_DATE}\" \
              --label \"org.opencontainers.image.authors=hyde.services\" \
              --label \"org.opencontainers.image.url=https://github.com/hydazz/docker-immich/packages\" \
              --label \"org.opencontainers.image.source=https://github.com/hydazz/docker-immich\" \
              --label \"org.opencontainers.image.version=${EXT_RELEASE_CLEAN}-${TAG_NUMBER}\" \
              --label \"org.opencontainers.image.revision=${COMMIT_SHA}\" \
              --label \"org.opencontainers.image.vendor=hyde.services\" \
              --label \"org.opencontainers.image.licenses=GPL-3.0-only\" \
              --label \"org.opencontainers.image.ref.name=${COMMIT_SHA}\" \
              --label \"org.opencontainers.image.title=Immich\" \
              --label \"org.opencontainers.image.description=[Immich](https://immich.app/) - High performance self-hosted photo and video backup solution.\" \
              --no-cache --pull -t ${IMAGE}:amd64-${META_TAG} \
              --build-arg ${BUILD_VERSION_ARG}=${EXT_RELEASE} --build-arg VERSION=\"${VERSION_TAG}\" --build-arg BUILD_DATE=${GITHUB_DATE} ."
          }
        }
        stage('Build ARMHF') {
          steps {
            echo "Running on node: ${NODE_NAME}"
            echo 'Logging into Github'
            sh '''#! /bin/bash
                  echo $GITHUB_TOKEN | docker login ghcr.io -u Jenkins-CI --password-stdin
               '''
            sh "docker buildx build --platform=linux/arm/v7 --output \"type=docker\" \
              --label \"org.opencontainers.image.created=${GITHUB_DATE}\" \
              --label \"org.opencontainers.image.authors=hyde.services\" \
              --label \"org.opencontainers.image.url=https://github.com/hydazz/docker-immich/packages\" \
              --label \"org.opencontainers.image.source=https://github.com/hydazz/docker-immich\" \
              --label \"org.opencontainers.image.version=${EXT_RELEASE_CLEAN}-${TAG_NUMBER}\" \
              --label \"org.opencontainers.image.revision=${COMMIT_SHA}\" \
              --label \"org.opencontainers.image.vendor=hyde.services\" \
              --label \"org.opencontainers.image.licenses=GPL-3.0-only\" \
              --label \"org.opencontainers.image.ref.name=${COMMIT_SHA}\" \
              --label \"org.opencontainers.image.title=Immich\" \
              --label \"org.opencontainers.image.description=[Immich](https://immich.app/) - High performance self-hosted photo and video backup solution.\" \
              --no-cache --pull -f Dockerfile.armhf -t ${IMAGE}:arm32v7-${META_TAG} \
              --build-arg ${BUILD_VERSION_ARG}=${EXT_RELEASE} --build-arg VERSION=\"${VERSION_TAG}\" --build-arg BUILD_DATE=${GITHUB_DATE} ."
            sh "docker tag ${IMAGE}:arm32v7-${META_TAG} ghcr.io/hydazz/dev-buildcache:arm32v7-${COMMIT_SHA}-${BUILD_NUMBER}"
            retry(5) {
              sh "docker push ghcr.io/hydazz/dev-buildcache:arm32v7-${COMMIT_SHA}-${BUILD_NUMBER}"
            }
            sh '''docker rmi \
                  ${IMAGE}:arm32v7-${META_TAG} \
                  ghcr.io/hydazz/dev-buildcache:arm32v7-${COMMIT_SHA}-${BUILD_NUMBER} || :'''
          }
        }
        stage('Build ARM64') {
          steps {
            echo "Running on node: ${NODE_NAME}"
            echo 'Logging into Github'
            sh '''#! /bin/bash
                  echo $GITHUB_TOKEN | docker login ghcr.io -u Jenkins-CI --password-stdin
               '''
            sh "docker buildx build --platform=linux/arm64 --output \"type=docker\" \
              --label \"org.opencontainers.image.created=${GITHUB_DATE}\" \
              --label \"org.opencontainers.image.authors=hyde.services\" \
              --label \"org.opencontainers.image.url=https://github.com/hydazz/docker-immich/packages\" \
              --label \"org.opencontainers.image.source=https://github.com/hydazz/docker-immich\" \
              --label \"org.opencontainers.image.version=${EXT_RELEASE_CLEAN}-${TAG_NUMBER}\" \
              --label \"org.opencontainers.image.revision=${COMMIT_SHA}\" \
              --label \"org.opencontainers.image.vendor=hyde.services\" \
              --label \"org.opencontainers.image.licenses=GPL-3.0-only\" \
              --label \"org.opencontainers.image.ref.name=${COMMIT_SHA}\" \
              --label \"org.opencontainers.image.title=Immich\" \
              --label \"org.opencontainers.image.description=[Immich](https://immich.app/) - High performance self-hosted photo and video backup solution.\" \
              --no-cache --pull -f Dockerfile.aarch64 -t ${IMAGE}:arm64v8-${META_TAG} \
              --build-arg ${BUILD_VERSION_ARG}=${EXT_RELEASE} --build-arg VERSION=\"${VERSION_TAG}\" --build-arg BUILD_DATE=${GITHUB_DATE} ."
            sh "docker tag ${IMAGE}:arm64v8-${META_TAG} ghcr.io/hydazz/dev-buildcache:arm64v8-${COMMIT_SHA}-${BUILD_NUMBER}"
            retry(5) {
              sh "docker push ghcr.io/hydazz/dev-buildcache:arm64v8-${COMMIT_SHA}-${BUILD_NUMBER}"
            }
            sh '''docker rmi \
                  ${IMAGE}:arm64v8-${META_TAG} \
                  ghcr.io/hydazz/dev-buildcache:arm64v8-${COMMIT_SHA}-${BUILD_NUMBER} || :'''
          }
        }
      }
    }
    // Take the image we just built and dump package versions for comparison
    stage('Update-packages') {
      when {
        branch "main"
        environment name: 'CHANGE_ID', value: ''
        environment name: 'EXIT_STATUS', value: ''
      }
      steps {
        sh '''#! /bin/bash
              set -e
              TEMPDIR=$(mktemp -d)
              if [ "${MULTIARCH}" == "true" ] && [ "${PACKAGE_CHECK}" == "false" ]; then
                LOCAL_CONTAINER=${IMAGE}:amd64-${META_TAG}
              else
                LOCAL_CONTAINER=${IMAGE}:${META_TAG}
              fi
              if [ "${DIST_IMAGE}" == "alpine" ]; then
                docker run --rm --entrypoint '/bin/sh' -v ${TEMPDIR}:/tmp ${LOCAL_CONTAINER} -c '\
                  apk info -v > /tmp/package_versions.txt && \
                  sort -o /tmp/package_versions.txt  /tmp/package_versions.txt && \
                  chmod 777 /tmp/package_versions.txt'
              elif [ "${DIST_IMAGE}" == "ubuntu" ]; then
                docker run --rm --entrypoint '/bin/sh' -v ${TEMPDIR}:/tmp ${LOCAL_CONTAINER} -c '\
                  apt list -qq --installed | sed "s#/.*now ##g" | cut -d" " -f1 > /tmp/package_versions.txt && \
                  sort -o /tmp/package_versions.txt  /tmp/package_versions.txt && \
                  chmod 777 /tmp/package_versions.txt'
              elif [ "${DIST_IMAGE}" == "fedora" ]; then
                docker run --rm --entrypoint '/bin/sh' -v ${TEMPDIR}:/tmp ${LOCAL_CONTAINER} -c '\
                  rpm -qa > /tmp/package_versions.txt && \
                  sort -o /tmp/package_versions.txt  /tmp/package_versions.txt && \
                  chmod 777 /tmp/package_versions.txt'
              elif [ "${DIST_IMAGE}" == "arch" ]; then
                docker run --rm --entrypoint '/bin/sh' -v ${TEMPDIR}:/tmp ${LOCAL_CONTAINER} -c '\
                  pacman -Q > /tmp/package_versions.txt && \
                  chmod 777 /tmp/package_versions.txt'
              fi
              NEW_PACKAGE_TAG=$(md5sum ${TEMPDIR}/package_versions.txt | cut -c1-8 )
              echo "Package tag sha from current packages in buit container is ${NEW_PACKAGE_TAG} comparing to old ${PACKAGE_TAG} from github"
              if [ "${NEW_PACKAGE_TAG}" != "${PACKAGE_TAG}" ]; then
                git clone https://github.com/${USER}/${REPO}.git ${TEMPDIR}/${REPO}
                git --git-dir ${TEMPDIR}/${REPO}/.git checkout -f main
                cp ${TEMPDIR}/package_versions.txt ${TEMPDIR}/${REPO}/
                cd ${TEMPDIR}/${REPO}/
                wait
                git add package_versions.txt
                git commit -m 'Bot Updating Package Versions'
                git push https://Jenkins-CI:${GITHUB_TOKEN}@github.com/${USER}/${REPO}.git --all
                echo "true" > /tmp/packages-${COMMIT_SHA}-${BUILD_NUMBER}
                echo "Package tag updated, stopping build process"
              else
                echo "false" > /tmp/packages-${COMMIT_SHA}-${BUILD_NUMBER}
                echo "Package tag is same as previous continue with build process"
              fi
              rm -Rf ${TEMPDIR}'''
        script{
          env.PACKAGE_UPDATED = sh(
            script: '''cat /tmp/packages-${COMMIT_SHA}-${BUILD_NUMBER}''',
            returnStdout: true).trim()
        }
      }
    }
    // Exit the build if the package file was just updated
    stage('PACKAGE-exit') {
      when {
        branch "main"
        environment name: 'CHANGE_ID', value: ''
        environment name: 'PACKAGE_UPDATED', value: 'true'
        environment name: 'EXIT_STATUS', value: ''
      }
      steps {
        sh '''#! /bin/bash
              echo "Packages were updated. Cleaning up the image and exiting."
              if [ "${MULTIARCH}" == "true" ] && [ "${PACKAGE_CHECK}" == "false" ]; then
                docker rmi ${IMAGE}:amd64-${META_TAG}
              else
                docker rmi ${IMAGE}:${META_TAG}
              fi'''
        script{
          env.EXIT_STATUS = 'ABORTED'
        }
      }
    }
    // Exit the build if this is just a package check and there are no changes to push
    stage('PACKAGECHECK-exit') {
      when {
        branch "main"
        environment name: 'CHANGE_ID', value: ''
        environment name: 'PACKAGE_UPDATED', value: 'false'
        environment name: 'EXIT_STATUS', value: ''
        expression {
          params.PACKAGE_CHECK == 'true'
        }
      }
      steps {
        sh '''#! /bin/bash
              echo "There are no package updates. Cleaning up the image and exiting."
              if [ "${MULTIARCH}" == "true" ] && [ "${PACKAGE_CHECK}" == "false" ]; then
                docker rmi ${IMAGE}:amd64-${META_TAG}
              else
                docker rmi ${IMAGE}:${META_TAG}
              fi'''
        script{
          env.EXIT_STATUS = 'ABORTED'
        }
      }
    }
    /* #######
       Testing
       ####### */
    // Run Container tests
    stage('Test') {
      when {
        environment name: 'CI', value: 'true'
        environment name: 'EXIT_STATUS', value: ''
      }
      steps {
        script{
          env.CI_URL = 'https://ci-tests.hyde.services/' + env.IMAGE + '/' + env.META_TAG + '/index.html'
        }
        sh '''#! /bin/bash
              set -e
              if [ "${MULTIARCH}" == "true" ]; then
                docker pull ghcr.io/hydazz/dev-buildcache:arm32v7-${COMMIT_SHA}-${BUILD_NUMBER}
                docker pull ghcr.io/hydazz/dev-buildcache:arm64v8-${COMMIT_SHA}-${BUILD_NUMBER}
                docker tag ghcr.io/hydazz/dev-buildcache:arm32v7-${COMMIT_SHA}-${BUILD_NUMBER} ${IMAGE}:arm32v7-${META_TAG}
                docker tag ghcr.io/hydazz/dev-buildcache:arm64v8-${COMMIT_SHA}-${BUILD_NUMBER} ${IMAGE}:arm64v8-${META_TAG}
              fi'''
      }
    }
    /* ##################
         Release Logic
       ################## */
    // If this is an amd64 only image only push a single image
    stage('Docker-Push-Single') {
      when {
        environment name: 'MULTIARCH', value: 'false'
        environment name: 'EXIT_STATUS', value: ''
      }
      steps {
        withCredentials([
          [
            $class: 'UsernamePasswordMultiBinding',
            credentialsId: 'docker_creds',
            usernameVariable: 'DOCKERUSER',
            passwordVariable: 'DOCKERPASS'
          ]
        ]) {
          retry(5) {
            sh '''#! /bin/bash
                  set -e
                  echo $DOCKERPASS | docker login -u $DOCKERUSER --password-stdin
                  echo $GITHUB_TOKEN | docker login ghcr.io -u Jenkins-CI --password-stdin
                  for PUSHIMAGE in "${GITHUBIMAGE}" "${IMAGE}"; do
                    docker tag ${IMAGE}:${META_TAG} ${PUSHIMAGE}:${META_TAG}
                    docker tag ${PUSHIMAGE}:${META_TAG} ${PUSHIMAGE}:latest
                    docker tag ${PUSHIMAGE}:${META_TAG} ${PUSHIMAGE}:${EXT_RELEASE_TAG}
                    if [ -n "${SEMVER}" ]; then
                      docker tag ${PUSHIMAGE}:${META_TAG} ${PUSHIMAGE}:${SEMVER}
                    fi
                    docker push ${PUSHIMAGE}:latest
                    docker push ${PUSHIMAGE}:${META_TAG}
                    docker push ${PUSHIMAGE}:${EXT_RELEASE_TAG}
                    if [ -n "${SEMVER}" ]; then
                     docker push ${PUSHIMAGE}:${SEMVER}
                    fi
                  done
               '''
          }
          sh '''#! /bin/bash
                for DELETEIMAGE in "${GITHUBIMAGE}" "${IMAGE}"; do
                  docker rmi \
                  ${DELETEIMAGE}:${META_TAG} \
                  ${DELETEIMAGE}:${EXT_RELEASE_TAG} \
                  ${DELETEIMAGE}:latest || :
                  if [ -n "${SEMVER}" ]; then
                    docker rmi ${DELETEIMAGE}:${SEMVER} || :
                  fi
                done
             '''
        }
      }
    }
    // If this is a multi arch release push all images and define the manifest
    stage('Docker-Push-Multi') {
      when {
        environment name: 'MULTIARCH', value: 'true'
        environment name: 'EXIT_STATUS', value: ''
      }
      steps {
        withCredentials([
          [
            $class: 'UsernamePasswordMultiBinding',
            credentialsId: 'docker_creds',
            usernameVariable: 'DOCKERUSER',
            passwordVariable: 'DOCKERPASS'
          ]
        ]) {
          retry(5) {
            sh '''#! /bin/bash
                  set -e
                  echo $DOCKERPASS | docker login -u $DOCKERUSER --password-stdin
                  echo $GITHUB_TOKEN | docker login ghcr.io -u Jenkins-CI --password-stdin
                  if [ "${CI}" == "false" ]; then
                    docker pull ghcr.io/hydazz/dev-buildcache:arm32v7-${COMMIT_SHA}-${BUILD_NUMBER}
                    docker pull ghcr.io/hydazz/dev-buildcache:arm64v8-${COMMIT_SHA}-${BUILD_NUMBER}
                    docker tag ghcr.io/hydazz/dev-buildcache:arm32v7-${COMMIT_SHA}-${BUILD_NUMBER} ${IMAGE}:arm32v7-${META_TAG}
                    docker tag ghcr.io/hydazz/dev-buildcache:arm64v8-${COMMIT_SHA}-${BUILD_NUMBER} ${IMAGE}:arm64v8-${META_TAG}
                  fi
                  for MANIFESTIMAGE in "${IMAGE}" "${GITHUBIMAGE}"; do
                    docker tag ${IMAGE}:amd64-${META_TAG} ${MANIFESTIMAGE}:amd64-${META_TAG}
                    docker tag ${IMAGE}:arm32v7-${META_TAG} ${MANIFESTIMAGE}:arm32v7-${META_TAG}
                    docker tag ${IMAGE}:arm64v8-${META_TAG} ${MANIFESTIMAGE}:arm64v8-${META_TAG}
                    docker tag ${MANIFESTIMAGE}:amd64-${META_TAG} ${MANIFESTIMAGE}:amd64-latest
                    docker tag ${MANIFESTIMAGE}:arm32v7-${META_TAG} ${MANIFESTIMAGE}:arm32v7-latest
                    docker tag ${MANIFESTIMAGE}:arm64v8-${META_TAG} ${MANIFESTIMAGE}:arm64v8-latest
                    docker tag ${MANIFESTIMAGE}:amd64-${META_TAG} ${MANIFESTIMAGE}:amd64-${EXT_RELEASE_TAG}
                    docker tag ${MANIFESTIMAGE}:arm32v7-${META_TAG} ${MANIFESTIMAGE}:arm32v7-${EXT_RELEASE_TAG}
                    docker tag ${MANIFESTIMAGE}:arm64v8-${META_TAG} ${MANIFESTIMAGE}:arm64v8-${EXT_RELEASE_TAG}
                    if [ -n "${SEMVER}" ]; then
                      docker tag ${MANIFESTIMAGE}:amd64-${META_TAG} ${MANIFESTIMAGE}:amd64-${SEMVER}
                      docker tag ${MANIFESTIMAGE}:arm32v7-${META_TAG} ${MANIFESTIMAGE}:arm32v7-${SEMVER}
                      docker tag ${MANIFESTIMAGE}:arm64v8-${META_TAG} ${MANIFESTIMAGE}:arm64v8-${SEMVER}
                    fi
                    docker push ${MANIFESTIMAGE}:amd64-${META_TAG}
                    docker push ${MANIFESTIMAGE}:arm32v7-${META_TAG}
                    docker push ${MANIFESTIMAGE}:arm64v8-${META_TAG}
                    docker push ${MANIFESTIMAGE}:amd64-latest
                    docker push ${MANIFESTIMAGE}:arm32v7-latest
                    docker push ${MANIFESTIMAGE}:arm64v8-latest
                    docker push ${MANIFESTIMAGE}:amd64-${EXT_RELEASE_TAG}
                    docker push ${MANIFESTIMAGE}:arm32v7-${EXT_RELEASE_TAG}
                    docker push ${MANIFESTIMAGE}:arm64v8-${EXT_RELEASE_TAG}
                    if [ -n "${SEMVER}" ]; then
                      docker push ${MANIFESTIMAGE}:amd64-${SEMVER}
                      docker push ${MANIFESTIMAGE}:arm32v7-${SEMVER}
                      docker push ${MANIFESTIMAGE}:arm64v8-${SEMVER}
                    fi
                    docker manifest push --purge ${MANIFESTIMAGE}:latest || :
                    docker manifest create ${MANIFESTIMAGE}:latest ${MANIFESTIMAGE}:amd64-latest ${MANIFESTIMAGE}:arm32v7-latest ${MANIFESTIMAGE}:arm64v8-latest
                    docker manifest annotate ${MANIFESTIMAGE}:latest ${MANIFESTIMAGE}:arm32v7-latest --os linux --arch arm
                    docker manifest annotate ${MANIFESTIMAGE}:latest ${MANIFESTIMAGE}:arm64v8-latest --os linux --arch arm64 --variant v8
                    docker manifest push --purge ${MANIFESTIMAGE}:${META_TAG} || :
                    docker manifest create ${MANIFESTIMAGE}:${META_TAG} ${MANIFESTIMAGE}:amd64-${META_TAG} ${MANIFESTIMAGE}:arm32v7-${META_TAG} ${MANIFESTIMAGE}:arm64v8-${META_TAG}
                    docker manifest annotate ${MANIFESTIMAGE}:${META_TAG} ${MANIFESTIMAGE}:arm32v7-${META_TAG} --os linux --arch arm
                    docker manifest annotate ${MANIFESTIMAGE}:${META_TAG} ${MANIFESTIMAGE}:arm64v8-${META_TAG} --os linux --arch arm64 --variant v8
                    docker manifest push --purge ${MANIFESTIMAGE}:${EXT_RELEASE_TAG} || :
                    docker manifest create ${MANIFESTIMAGE}:${EXT_RELEASE_TAG} ${MANIFESTIMAGE}:amd64-${EXT_RELEASE_TAG} ${MANIFESTIMAGE}:arm32v7-${EXT_RELEASE_TAG} ${MANIFESTIMAGE}:arm64v8-${EXT_RELEASE_TAG}
                    docker manifest annotate ${MANIFESTIMAGE}:${EXT_RELEASE_TAG} ${MANIFESTIMAGE}:arm32v7-${EXT_RELEASE_TAG} --os linux --arch arm
                    docker manifest annotate ${MANIFESTIMAGE}:${EXT_RELEASE_TAG} ${MANIFESTIMAGE}:arm64v8-${EXT_RELEASE_TAG} --os linux --arch arm64 --variant v8
                    if [ -n "${SEMVER}" ]; then
                      docker manifest push --purge ${MANIFESTIMAGE}:${SEMVER} || :
                      docker manifest create ${MANIFESTIMAGE}:${SEMVER} ${MANIFESTIMAGE}:amd64-${SEMVER} ${MANIFESTIMAGE}:arm32v7-${SEMVER} ${MANIFESTIMAGE}:arm64v8-${SEMVER}
                      docker manifest annotate ${MANIFESTIMAGE}:${SEMVER} ${MANIFESTIMAGE}:arm32v7-${SEMVER} --os linux --arch arm
                      docker manifest annotate ${MANIFESTIMAGE}:${SEMVER} ${MANIFESTIMAGE}:arm64v8-${SEMVER} --os linux --arch arm64 --variant v8
                    fi
                    docker manifest push --purge ${MANIFESTIMAGE}:latest
                    docker manifest push --purge ${MANIFESTIMAGE}:${META_TAG} 
                    docker manifest push --purge ${MANIFESTIMAGE}:${EXT_RELEASE_TAG} 
                    if [ -n "${SEMVER}" ]; then
                      docker manifest push --purge ${MANIFESTIMAGE}:${SEMVER} 
                    fi
                  done
               '''
          }
          sh '''#! /bin/bash
                for DELETEIMAGE in "${GITHUBIMAGE}" "${IMAGE}"; do
                  docker rmi \
                  ${DELETEIMAGE}:amd64-${META_TAG} \
                  ${DELETEIMAGE}:amd64-latest \
                  ${DELETEIMAGE}:amd64-${EXT_RELEASE_TAG} \
                  ${DELETEIMAGE}:arm32v7-${META_TAG} \
                  ${DELETEIMAGE}:arm32v7-latest \
                  ${DELETEIMAGE}:arm32v7-${EXT_RELEASE_TAG} \
                  ${DELETEIMAGE}:arm64v8-${META_TAG} \
                  ${DELETEIMAGE}:arm64v8-latest \
                  ${DELETEIMAGE}:arm64v8-${EXT_RELEASE_TAG} || :
                  if [ -n "${SEMVER}" ]; then
                    docker rmi \
                    ${DELETEIMAGE}:amd64-${SEMVER} \
                    ${DELETEIMAGE}:arm32v7-${SEMVER} \
                    ${DELETEIMAGE}:arm64v8-${SEMVER} || :
                  fi
                done
                docker rmi \
                ghcr.io/hydazz/dev-buildcache:arm32v7-${COMMIT_SHA}-${BUILD_NUMBER} \
                ghcr.io/hydazz/dev-buildcache:arm64v8-${COMMIT_SHA}-${BUILD_NUMBER} || :
             '''
        }
      }
    }
    // If this is a public release tag it in the LS Github
    stage('Github-Tag-Push-Release') {
      when {
        branch "main"
        expression {
          env.RELEASE != env.EXT_RELEASE_CLEAN + '-' + env.TAG_NUMBER
        }
        environment name: 'CHANGE_ID', value: ''
        environment name: 'EXIT_STATUS', value: ''
      }
      steps {
        echo "Pushing New tag for current commit ${META_TAG}"
        sh '''curl -H "Authorization: token ${GITHUB_TOKEN}" -X POST https://api.github.com/repos/${USER}/${REPO}/git/tags \
        -d '{"tag":"'${META_TAG}'",\
             "object": "'${COMMIT_SHA}'",\
             "message": "Tagging Release '${EXT_RELEASE_CLEAN}'-'${TAG_NUMBER}' to main",\
             "type": "commit",\
             "tagger": {"name": "Jenkins-CI","email": "jenkins@hyde.services","date": "'${GITHUB_DATE}'"}}' '''
        echo "Pushing New release for Tag"
        sh '''#! /bin/bash
              echo "Data change at JSON endpoint ${JSON_URL}" > releasebody.json
              echo '{"tag_name":"'${META_TAG}'",\
                     "target_commitish": "main",\
                     "name": "'${META_TAG}'",\
                     "body": "**Image Changes:**\\n\\n'${RELEASE_NOTES}'\\n\\n**Remote Changes:**\\n\\n' > start
              printf '","draft": false,"prerelease": false}' >> releasebody.json
              paste -d'\\0' start releasebody.json > releasebody.json.done
              curl -H "Authorization: token ${GITHUB_TOKEN}" -X POST https://api.github.com/repos/${USER}/${REPO}/releases -d @releasebody.json.done'''
      }
    }
    // Use helper container to sync the current README on master to the dockerhub endpoint
    stage('Sync-README') {
      when {
        environment name: 'CHANGE_ID', value: ''
        environment name: 'EXIT_STATUS', value: ''
      }
      steps {
        withCredentials([
          [
            $class: 'UsernamePasswordMultiBinding',
            credentialsId: 'docker_creds',
            usernameVariable: 'DOCKERUSER',
            passwordVariable: 'DOCKERPASS'
          ]
        ]) {
          sh '''#! /bin/bash
                set -e
                TEMPDIR=$(mktemp -d)
                docker pull ghcr.io/hydazz/jenkins-builder:latest
                docker run --rm -e CONTAINER_NAME=${CONTAINER_NAME} -e GITHUB_BRANCH="${BRANCH_NAME}" -v ${TEMPDIR}:/ansible/jenkins ghcr.io/hydazz/jenkins-builder:latest
                docker pull ghcr.io/linuxserver/readme-sync
                docker run --rm=true \
                  -e DOCKERHUB_USERNAME=$DOCKERUSER \
                  -e DOCKERHUB_PASSWORD=$DOCKERPASS \
                  -e GIT_REPOSITORY=${USER}/${REPO} \
                  -e DOCKER_REPOSITORY=${IMAGE} \
                  -e GIT_BRANCH=master \
                  -v ${TEMPDIR}/docker-${CONTAINER_NAME}:/mnt \
                  ghcr.io/linuxserver/readme-sync bash -c 'node sync'
                rm -Rf ${TEMPDIR} '''
        }
      }
    }
    // If this is a Pull request send the CI link as a comment on it
    stage('Pull Request Comment') {
      when {
        not {environment name: 'CHANGE_ID', value: ''}
        environment name: 'CI', value: 'true'
        environment name: 'EXIT_STATUS', value: ''
      }
      steps {
        sh '''curl -H "Authorization: token ${GITHUB_TOKEN}" -X POST https://api.github.com/repos/${USER}/${REPO}/issues/${PULL_REQUEST}/comments \
        -d '{"body": "I am a bot, here are the test results for this PR: \\n'${CI_URL}' \\n'${SHELLCHECK_URL}'"}' '''
      }
    }
  }
  /* ######################
     Send status to Discord
     ###################### */
  post {
    always {
      script{
        if (env.EXIT_STATUS == "ABORTED"){
          sh 'echo "build aborted"'
        }
        else if (currentBuild.currentResult == "SUCCESS"){
          sh ''' curl -X POST -H "Content-Type: application/json" --data '{"avatar_url": "https://wiki.jenkins.io/JENKINS/attachments/2916393/57409617.png","embeds": [{"color": 1681177,\
                 "description": "**Build:**  '${BUILD_NUMBER}'\\n**CI Results:**  '${CI_URL}'\\n**ShellCheck Results:**  '${SHELLCHECK_URL}'\\n**Status:**  Success\\n**Job:** '${RUN_DISPLAY_URL}'\\n**Change:** '${CODE_URL}'\\n**External Release:**: '${RELEASE_LINK}'\\n**DockerHub:** '${DOCKERHUB_LINK}'\\n"}],\
                 "username": "Jenkins"}' ${BUILDS_DISCORD} '''
        }
        else {
          sh ''' curl -X POST -H "Content-Type: application/json" --data '{"avatar_url": "https://wiki.jenkins.io/JENKINS/attachments/2916393/57409617.png","embeds": [{"color": 16711680,\
                 "description": "**Build:**  '${BUILD_NUMBER}'\\n**CI Results:**  '${CI_URL}'\\n**ShellCheck Results:**  '${SHELLCHECK_URL}'\\n**Status:**  failure\\n**Job:** '${RUN_DISPLAY_URL}'\\n**Change:** '${CODE_URL}'\\n**External Release:**: '${RELEASE_LINK}'\\n**DockerHub:** '${DOCKERHUB_LINK}'\\n"}],\
                 "username": "Jenkins"}' ${BUILDS_DISCORD} '''
        }
      }
    }
    cleanup {
      cleanWs()
    }
  }
}
