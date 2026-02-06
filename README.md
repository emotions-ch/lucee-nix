# Lucee NixOS Module

A NixOS module that provides declarative packaging and deployment infrastructure for [Lucee Server](https://www.lucee.org/), an open-source CFML (ColdFusion Markup Language) engine.

## Overview

This project enables easy deployment of [Single Mode](https://docs.lucee.org/recipes/single-vs-multi-mode.html#what-is-single-mode) Lucee applications on NixOS systems using declarative configuration. It provides a modern, infrastructure-as-code approach to deploying CFML applications with the benefits of NixOS's reproducible builds and atomic deployments.

## Features

- **Declarative Configuration**: Full NixOS-style declarative setup
- **Multiple Tomcat Versions**: Support for Apache Tomcat 9, 10, and 11
- **Extension Management**: Automated deployment of Lucee extensions (.lex files)
- **Clean Startup**: Optional, and highly recomended, purification of Lucee directories on restart
- **Proper Permissions**: Automatic user/group management for Tomcat/Lucee files
- **Reproducible Builds**: Leverages Nix's functional package management

## Components

The project consists of four main Nix modules:

### `lucee.nix`
Core Lucee packaging logic that:
- Downloads and packages Lucee JAR files from cdn.lucee.org
- Integrates with different Tomcat versions
- Configures Tomcat with Lucee-specific settings
- Provides example web applications

### `extensions.nix`
Lucee extension management that:
- Defines packaging for Lucee extensions (.lex files)
- Includes predefined extensions
- Provides deployment scripts for extension installation

### `systemd.nix`
SystemD service configuration that:
- Sets up Lucee-specific SystemD services
- Manages directory initialization and permissions
- Handles extension deployment during service startup
- Provides cleanup on service stop (when purifyOnStart is enabled)

### `example.nix`
[Example NixOS configuration](./example.nix) demonstrating:
- How to integrate the Lucee module into a NixOS system
- Tomcat service configuration with Lucee
- Extension usage patterns

### and some External Dependencies
- Lucee JAR files from https://cdn.lucee.org/
- Lucee extensions from https://ext.lucee.org/
- Lucee dockerfiles from GitHub for default config & example WebPage ([lucee/lucee-dockerfiles](https://github.com/lucee/lucee-dockerfiles))

## Development

### Getting Started

This project uses Nix Flakes for development. To get started:

```bash
# Clone the repository
git clone https://github.com/emotions-ch/lucee-nix.git
cd lucee-nix

# Enter the development environment
nix develop

# Run validation tests
validate-all
```

## Contributing

Go ahead ;3
