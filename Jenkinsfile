@Library('epidata.pipeline') _

env.FPC_VERSION='3.2.0'
env.COMPONENTS_VERSION='1.0'

node {
    stage("Source Checkout") {
        checkout scm
    }

    stage("Linux-64") {
        epidocker.run "mvn compile -Plinux64"
    }

    stage("Win-64") {
        epidocker.run "mvn compile -Pwin64"
    }

    stage("Mac-64") {
        epidocker.run "mvn compile -Pdarwin64"
    }

    stage("Package & Deploy") {
        sh "mvn versions:set -DnewVersion=${COMPONENTS_VERSION}.${GITHUB_RUN_NUMBER} -f deploy.pom.xml"
        sh "mvn deploy -f deploy.pom.xml"
        sh "mvn clean"
    }
}