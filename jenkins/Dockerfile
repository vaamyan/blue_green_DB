FROM jenkins/jenkins:lts-jdk21

USER root
RUN apt-get update \
    && apt-get install --yes --no-install-recommends git postgresql-client \
    && rm -rf /var/lib/apt/lists/*

USER jenkins
