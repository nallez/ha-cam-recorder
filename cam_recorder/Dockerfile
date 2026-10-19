FROM alpine:3.21
RUN apk add --no-cache bash ffmpeg rclone jq tzdata
COPY run.sh /run.sh
RUN chmod +x /run.sh
CMD ["/run.sh"]
