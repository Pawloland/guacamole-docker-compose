#!/bin/sh

CLOUDFLARE_ENDED_PIPE=/tmp/cloudflared_ended_pipe
rm -f "$CLOUDFLARE_ENDED_PIPE"
mkfifo "$CLOUDFLARE_ENDED_PIPE"

echo "Creating trap function"
term_handler()
{
    echo "Terminating cloudflared tunnel from SIG$1..."
    CLOUDFLARED_PID=$(ps -o pid,comm|awk '$2=="cloudflared"{print $1}')
    echo "Sending SIGINT to cloudflared (PID $CLOUDFLARED_PID)..."
    kill -INT "$CLOUDFLARED_PID"
}

trap "term_handler INT" INT #ctrl c
trap "term_handler TERM" TERM #15- stop signal from docker stop


echo "Removing old cloudflare redirect config if exists"
rm -f /data/cloudflare_redirect.conf

echo "Starting cloudflared tunnel and monitoring output for the tunnel URL..."
{
    cloudflared tunnel --url https://nginx:443 --no-tls-verify 2>&1 |
    tee /dev/stderr |
    awk '
    {
        if (match($0, /https:\/\/[a-zA-Z0-9-]+\.trycloudflare\.com/)) {
            url = substr($0, RSTART, RLENGTH)
            redirect_file = "/data/cloudflare_redirect.conf"
            print "return 302 " url ";" > redirect_file
            close(redirect_file)
        }
    }
    '
    echo "Cloudflared tunnel ended" > "$CLOUDFLARE_ENDED_PIPE"
}&

# Wait indefinitely to keep the container running and allow signal handling every 1 second
while :; do
    if read -t 1 LINE < "$CLOUDFLARE_ENDED_PIPE"; then
        echo "Received signal from pipe: $LINE"
        break
    fi
done

rm -f /data/cloudflare_redirect.conf
echo "Done"