# Nginx Hello World

A simple Dockerfile-based nginx application serving a static HTML page.

## Quick Start

### Build the image

```bash
docker build -t nginx-hello .
```

### Run the container

```bash
docker run -d -p 8080:80 nginx-hello
```

Then visit [http://localhost:8080](http://localhost:8080)

## Development with Live Reload

Mount the HTML file for live editing:

```bash
docker run -d -p 8080:80 -v $(pwd)/index.html:/usr/share/nginx/html/index.html nginx-hello
```

Now you can edit `index.html` and refresh your browser to see changes immediately!

## Stop the container

```bash
docker stop $(docker ps -q --filter ancestor=nginx-hello)
```
