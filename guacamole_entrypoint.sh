#!/bin/sh

echo "Creating trap function"
term_handler()
{
    echo "Terminating guacamole from SIG$1..."
    GUACAMOLE_PID=$(ps -o pid,comm|awk '$2=="java"{print $1}')
    echo "Sending SIGTERM to guacamole (PID $GUACAMOLE_PID)..."
    kill -TERM "$GUACAMOLE_PID"

    wait "$GUACAMOLE_PID"
    echo "Guacamole process has ended."
    exit 0
}

trap "term_handler INT" INT #ctrl c
trap "term_handler TERM" TERM #15- stop signal from docker stop

/opt/guacamole/bin/entrypoint.sh &
GUACAMOLE_PID=$!
wait "$GUACAMOLE_PID"
