# mjpg-streamer on Alpine Linux

This folder contains notes and a sample conf for running `mjpg-streamer` as an OpenRC service.

## Install

```
apk add mjpg-streamer
```

Depending on the camera, you may need `v4l-utils` for capability checks:

```
apk add v4l-utils
v4l2-ctl --list-devices
v4l2-ctl --device=/dev/video0 --list-formats-ext
```

## Service configuration

Copy the OpenRC service we provide into place (or use Alpine's own if present):

```
# service script (if not provided by the package)
install -m 0755 alpine/openrc/mjpg-streamer /etc/init.d/mjpg-streamer
# defaults
install -m 0644 mjpg/conf.d/mjpg-streamer /etc/conf.d/mjpg-streamer
rc-update add mjpg-streamer default
rc-service mjpg-streamer start
```

## HTTP endpoint

The service here listens on `127.0.0.1:8090`.

Caddy proxies the stream at:

- `/video/stream/?action=stream`

Embed in HTML:

```html
<img src="/video/stream/?action=stream" alt="Webcam Stream">
```

## Tuning

- Reduce `--framerate` for low CPU devices (e.g. 10–15 fps)
- Try different resolutions if frames drop (`v4l2-ctl` can list supported modes)
- If USB bandwidth is limited, prefer 640x480 @ 15 fps
