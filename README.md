# DrawTheNet.IO : Diagrams as code for engineers.

![Logo](docs/logo.png)

DrawTheNet.IO draws network diagrams dynamically from a text file describing the placement, layout and icons.

## Live Demo :  https://DrawTheNet.IO

Given a yaml file describing the hierarchy of the network and its connections, a resulting diagram will be created. 

![screenshot](docs/interface.png)


[![Build](https://github.com/remygrandin/DrawTheNet.IO/actions/workflows/docker-image.yml/badge.svg)](https://github.com/remygrandin/DrawTheNet.IO/actions/workflows/docker-image.yml)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE.txt)

## Table of Contents

- [Motivation](#motivation)
- [Features](#features)
- [Quick start](#quick-start)
- [Deploying with Docker](#deploying-with-docker)
- [Deploying Static Files](#deploying-static-files)
- [More Info](#more-info)
- [Vendor Icons](#vendor-icons)
- [Privacy notice](#privacy-notice)
- [Build Instructions](#build-instructions)
- [Built with great open source software](#built-with-great-open-source-software)
- [Contributing](#contributing)
- [Versioning](#versioning)
- [Authors](#authors)
- [License](#license)

# Motivation

Complex network diagrams typically involve specific placement of icons, connections and labels using a tool like Visio or OmniGraffle, using a mouse, and constantly zooming in and out for single pixel placement. 

The goal behind DrawTheNet.IO is to be able to describe the diagram in a text file and have it rendered in SVG in the browser.

Also, being able to store a diagram as text makes it easy to version control and share.

# Features

- **Text-to-Diagram**: Define your network topology using simple YAML syntax.
- **Live Preview**: See changes instantly as you type.
- **Multiple Icon Sets**: Includes icons from AWS, Azure, Google Cloud, Cisco, and more.
- **Export Options**: Save your diagrams as SVG or PNG images.
- **Browser-Based**: Runs entirely in the browser, no backend required for static deployment.
- **Docker Support**: Easy to deploy using the official Docker image.

# Quick start

Go to https://drawthenet.io and start creating diagrams.

Here is a simple example to get you started:

```yaml
diagram:
  columns: 4
  rows: 3

icons:
  internet: { x: 1, y: 0, iconFamily: "Azure", icon: "Website-Staging" }
  firewall: { x: 1, y: 1, iconFamily: "Cisco", icon: "firewall" }
  server:   { x: 1, y: 2, iconFamily: "AWS",   icon: "Compute_EC2" }

connections:
  - { endpoints: ["internet", "firewall"] }
  - { endpoints: ["firewall", "server"] }
```

# Deploying with Docker (Recommended)

## Using the Official Docker Image

You can deploy DrawTheNet.IO using the official Docker image from Docker Hub:

```bash
docker run -d -p 8080:80 --name drawthenet darkphoenics/drawthenet.io:latest
```

The application will be available at `http://localhost:8080`.

## Docker Compose

For easier deployment and management, you can use Docker Compose. Create a `docker-compose.yml` file:

```yaml
version: '3.8'

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
docker-compose up -d
```

## Custom Configuration

If you need to customize the nginx configuration, you can mount your own configuration file:

```bash
docker run -d -p 8080:80 \
  -v /path/to/your/nginx.conf:/etc/nginx/conf.d/default.conf \
  --name drawthenet \
  darkphoenics/drawthenet.io:latest
```

# Deploying Static Files

You can deploy DrawTheNet.IO as a set of static files without using Docker.

1. Download the latest release zip file from the [Releases page](https://github.com/remygrandin/DrawTheNet.IO/releases).
2. Extract the contents of the zip file to your web server's document root (e.g., `/var/www/html` for Apache or Nginx).
3. Ensure your web server is configured to serve static files.

That's it! The application runs entirely in the browser, so no backend application server is required.

# More Info

You can find a detailed help guide, including a full list of available properties integrated into the app by using the ? button in the top left corner of it, or [here](https://DrawTheNet.IO/help.html)

# Vendor Icons
The following vendors are available by default:
 - **Amazon Web Services** (as AWS), from https://aws.amazon.com/architecture/icons/
 - **Microsoft Azure** (as Azure), from https://learn.microsoft.com/azure/architecture/icons/
 - **Microsoft 365** (as M365), from https://learn.microsoft.com/microsoft-365/solutions/architecture-icons-templates
 - **Microsoft Dynamics 365** (as D365), from https://learn.microsoft.com/dynamics365/get-started/icons
 - **Microsoft Power Platform** (as PowerPlatform), from https://learn.microsoft.com/power-platform/guidance/icons
 - **Google Cloud Platform** (as GCP), from https://cloud.google.com/icons
 - **Cisco Meraki** (as Meraki), from https://meraki.cisco.com/product-collateral/cisco-meraki-topology-icons/
 - **Cisco** (as Cisco), from https://www.cisco.com/c/en/us/about/brand-center/network-topology-icons.html
 - **Fortinet** (as Fortinet), from https://www.fortinet.com/resources/icon-library
 
You also have access to all the icons from [Iconify](https://icon-sets.iconify.design/)

# Privacy notice

The app was designed to be used in a browser and does not require any installation. No diagrams are stored anywhere but locally to your PC.

# Build Instructions
## Docker Build (Preferred)

You can easily build the tool to host locally with the provided [Dockerfile](./tools/Dockerfile):

```
cd ./tools/
docker build -t local/drawthenet.io .
```

It will build the docker image from scratch, including downloading the icons from all vendors specified above. It will run the app with nginx, listening on port 80.

## Local Build

To perform a full local build, you need PowerShell and [libvisio2svg](https://github.com/kakwa/libvisio2svg) installed.

The following dependencies are required for `libvisio2svg` (package names may vary by distribution):
- `libxml2-dev`
- `libwmf-dev`
- `gsfonts`
- `libemf2svg-dev`
- `libvisio-dev`
- `librevenge-dev`

If these dependencies are not met, some icon sets (Cisco, Fortinet) will not be generated, but the rest of the application will build correctly.

You can find the build script in the [tools folder](./tools/build.ps1):

```bash
cd ./tools/
pwsh ./build.ps1
```

Additional arguments can be passed to the script to only run parts of the build process, refer to the script for more information.

The result will be created in the ./dist/ folder.

As it is a fully static website, you can host it on any webserver.

# Built with great open source software

- **JQuery:** https://jquery.com/
- **Bootstrap:** https://getbootstrap.com/
- **D3.js:** https://d3js.org/
- **Ace editor:** https://ace.c9.io/
- **Iconify:** https://iconify.design/
- **Fuse.js:** https://fusejs.io/
- **js-yaml:** https://github.com/nodeca/js-yaml
- **JQuery Toast:** https://kamranahmed.info/toast
- **Showdown:** https://github.com/showdownjs/showdown
- **Highlight.js:** https://highlightjs.org/
- **LZ-String:** https://pieroxy.net/blog/pages/lz-string/index.html
- **Luxon:** https://moment.github.io/luxon/
- **Select2:** https://select2.org/
- **jsTree:** https://www.jstree.com/
- **Google Palette:** https://github.com/google/palette.js
- **libvisio2svg:** https://github.com/kakwa/libvisio2svg


# Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3. Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the Branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

# Versioning

1.0 Initial release.

2.0 Updated frameworks & added new saves and icons features.

# Authors

* **Bradley Thornton** - 2016-2022 *Initial work* - [cidrblock](https://github.com/cidrblock)
* **Rémy Grandin** - 2023-Today *Rework & modernization* - [remygrandin](https://github.com/remygrandin)

# License

This project is licensed under the MIT License. (see LICENSE.txt)

The logo of the project is licensed under the Apache 2.0 (https://github.com/bytedance/IconPark/blob/master/LICENSE)