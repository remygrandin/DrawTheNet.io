# DrawTheNet.IO

DrawTheNet.IO draws network diagrams dynamically from a text file describing the placement, layout and icons.

## Features

- **Text-to-Diagram**: Define your network topology using simple YAML syntax.
- **Live Preview**: See changes instantly as you type.
- **Multiple Icon Sets**: Includes icons from AWS, Azure, Google Cloud, Cisco, and more.
- **Export Options**: Save your diagrams as SVG or PNG images.
- **Browser-Based**: Runs entirely in the browser, no backend required.

## Quick Start

You can deploy DrawTheNet.IO using this official Docker image:

```bash
docker run -d -p 8080:80 --name drawthenet darkphoenics/drawthenet.io:latest
```

The application will be available at `http://localhost:8080`.

## Docker Compose

Create a `docker-compose.yml` file:

```yaml
services:
  drawthenet:
    image: darkphoenics/drawthenet.io:latest
    container_name: drawthenet
    ports:
      - "8080:80"
    restart: unless-stopped
```

Then start the service:

```bash
docker compose up -d
```

## More Information

For more details, full documentation, and source code, please visit the [GitHub Repository](https://github.com/remygrandin/DrawTheNet.IO).

## License

This project is licensed under the MIT License.
