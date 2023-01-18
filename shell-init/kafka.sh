#!/usr/bin/env bash

# TODO: this script is only relevant on apple silicon
KAFKA_VER=3.2.1
KAFKA_BOOTSTRAP_SERVER="${KBS:-localhost:9092}"

KAFKA_DIR=/opt/homebrew/Cellar/kafka/$KAFKA_VER/libexec

KAFKA_DATA_DIR=$KAFKA_DIR/data

# required by kafka
## ^ however 3.2 doesnt require the --zookeeper arg
zoo_start() {
  ## make sure you update zookeeper properties when updating kafka versions
  zookeeper-server-start $KAFKA_DIR/config/zookeeper.properties
}

kafka_start() {
  kafka-server-start $KAFKA_DIR/config/server.properties
}

kafka_stop() {
  kafka-server-stop
}

kafka_create_topic() {
  if [[ $# -eq 1 ]]; then

    kafka-topics --create --topic "$1" --bootstrap-server "$KAFKA_BOOTSTRAP_SERVER"
  else
    echo "\$1 === topic_name"
  fi
}

kafka_describe_topic() {
  if [[ $# -eq 1 ]]; then
    kafka-topics --describe --topic "$1" --bootstrap-server "$KAFKA_BOOTSTRAP_SERVER"
  else
    echo "\$1 === topic_name"
  fi
}

kafka_list_topics() {
  kafka-topics --list --bootstrap-server "$KAFKA_BOOTSTRAP_SERVER"
}

kafka_list_group_ids() {
  kafka-consumer-groups --list --bootstrap-server "$KAFKA_BOOTSTRAP_SERVER"
}

kafka_send() {
  if [[ $# -eq 1 ]]; then
    # echo -e "sending\n---\n${@:2}\n---"
    # echo "to this topic: $1"
    kafka-console-producer --topic "$1" --bootstrap-server "$KAFKA_BOOTSTRAP_SERVER"
  else
    echo "\$1 === topic_name, then paste in events, ctrlD exit"
  fi
}

kafka_list_topic_partitions() {
  if [[ $# -eq 1 ]]; then
    kafka-run-class kafka.tools.GetOffsetShell --broker-list "$KAFKA_BOOTSTRAP_SERVER" --topic "$1"
  else
    echo "\$1 === topic_name, then paste in events, ctrlD exit"
  fi
}

kafka_listen_for_topic_events() {
  if [[ $# -eq 2 ]]; then
    # echo -e "sending\n---\n${@:2}\n---"
    # echo "to this topic: $1"
    kafka-console-consumer --bootstrap-server "$KAFKA_BOOTSTRAP_SERVER" --topic "$1" --offset 20 --partition "$2"

  else
    echo "\$1 === topic_name, \$2 === partition"
  fi
}

kafka_clean() {
  if [ -z ${KAFKA_DATA_DIR+x} ]; then
    echo "KAFKA_DATA_DIR is not set; exiting"
  else
    echo "removing files $KAFKA_DATA_DIR/{kafka,zookeeper}/*"
    rm -rf $KAFKA_DATA_DIR/{zookeeper,kafka}/*
  fi
}
