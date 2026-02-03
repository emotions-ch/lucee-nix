# Lucee Nix Module

A NixOS module for running Lucee CFML server with Tomcat integration.

## Features

- **Lucee Server**: Configurable Lucee versions with zero-extension base
- **Extension Management**: Dynamic deployment of Lucee extensions (.lex files)
- **Tomcat Integration**: Customized Tomcat 11 with Lucee servlet configuration
- **Docker Integration**: Uses official Lucee Docker configurations

## Usage

Import this module in your NixOS configuration:

```nix
{
  imports = [
    ./path/to/lucee-nix
  ];
}
```

The module will:
- Set up Tomcat on port 8888
- Configure Lucee servlet with the specified JAR version
- Deploy configured extensions automatically
- Create necessary directories with proper permissions

## Module Structure

- `default.nix` - Main module entry point
- `example.nix` - Complete Lucee service configuration
- `extensions.nix` - Extension management utilities and definitions
- `luceeJar.nix` - Lucee JAR version management

## Configuration

The module uses Lucee 7.0.1.100 (zero edition) by default and includes:
- CFSpreadsheet extension
- Administrator extension (optional)
- Custom extension deployment system

## History

This module was extracted from the nix-infra-testlab repository to enable reuse across projects while maintaining full development history.